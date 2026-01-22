import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:logger/logger.dart';
import '../models/library_exercise.dart';
import 'exercise_library_service.dart';

/// Modelo de ejercicio parseado desde OCR
class ParsedExerciseCandidate {
  final String rawText;
  final String? matchedExerciseName;
  final int? matchedExerciseId;
  final int series;
  final int reps;
  final double? weight;
  final double confidence; // 0.0 - 1.0
  final bool isValid;

  const ParsedExerciseCandidate({
    required this.rawText,
    this.matchedExerciseName,
    this.matchedExerciseId,
    this.series = 3,
    this.reps = 10,
    this.weight,
    this.confidence = 0.0,
    this.isValid = false,
  });

  ParsedExerciseCandidate copyWith({
    String? rawText,
    String? matchedExerciseName,
    int? matchedExerciseId,
    int? series,
    int? reps,
    double? weight,
    double? confidence,
    bool? isValid,
  }) {
    return ParsedExerciseCandidate(
      rawText: rawText ?? this.rawText,
      matchedExerciseName: matchedExerciseName ?? this.matchedExerciseName,
      matchedExerciseId: matchedExerciseId ?? this.matchedExerciseId,
      series: series ?? this.series,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      confidence: confidence ?? this.confidence,
      isValid: isValid ?? this.isValid,
    );
  }
}

/// Servicio de OCR para importar rutinas desde imágenes
class RoutineOcrService {
  static final RoutineOcrService instance = RoutineOcrService._();
  RoutineOcrService._();

  final _picker = ImagePicker();
  final _logger = Logger();
  
  // Cache de ejercicios para fuzzy matching
  List<LibraryExercise>? _exercisesCache;
  Fuzzy<LibraryExercise>? _fuzzyMatcher;

  /// Inicializa el cache de ejercicios para matching
  Future<void> _ensureExercisesLoaded() async {
    if (_exercisesCache != null) return;
    
    final library = ExerciseLibraryService.instance;
    await library.loadLibrary();
    _exercisesCache = library.exercises;
    
    // Crear fuzzy matcher con los nombres de ejercicios
    _fuzzyMatcher = Fuzzy<LibraryExercise>(
      _exercisesCache!,
      options: FuzzyOptions(
        keys: [
          WeightedKey(
            name: 'name',
            getter: (ex) => ex.name.toLowerCase(),
            weight: 1.0,
          ),
        ],
        threshold: 0.4, // Umbral de similitud (0 = exacto, 1 = cualquier cosa)
        findAllMatches: true,
        isCaseSensitive: false,
      ),
    );
  }

  /// Escanea una imagen desde cámara o galería
  /// Devuelve las líneas de texto crudo extraídas
  Future<List<String>> scanImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85, // Buena calidad sin ser excesivo
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (image == null) {
        _logger.d('Usuario canceló selección de imagen');
        return [];
      }

      final inputImage = InputImage.fromFile(File(image.path));
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        
        // Extraer líneas de texto (cada bloque puede tener múltiples líneas)
        final List<String> lines = [];
        for (final block in recognizedText.blocks) {
          for (final line in block.lines) {
            final trimmed = line.text.trim();
            if (trimmed.isNotEmpty) {
              lines.add(trimmed);
            }
          }
        }

        _logger.i('OCR extrajo ${lines.length} líneas de texto');
        return lines;

      } finally {
        await textRecognizer.close();
      }

    } catch (e, s) {
      _logger.e('Error en OCR', error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Parsea las líneas de texto y extrae candidatos de ejercicios
  /// 
  /// Patrones soportados:
  /// - "Press Banca 4x10" -> 4 series, 10 reps
  /// - "Sentadilla 3 series 12 reps" -> 3 series, 12 reps
  /// - "Curl 4x12 20kg" -> 4 series, 12 reps, 20kg
  /// - "Peso muerto 5x5 100kg" -> 5 series, 5 reps, 100kg
  Future<List<ParsedExerciseCandidate>> parseLines(List<String> lines) async {
    await _ensureExercisesLoaded();

    final List<ParsedExerciseCandidate> candidates = [];

    for (final line in lines) {
      final candidate = _parseSingleLine(line);
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    return candidates;
  }

  /// Parsea una sola línea de texto
  ParsedExerciseCandidate? _parseSingleLine(String line) {
    final normalized = line.toLowerCase().trim();
    
    // Si la línea es muy corta o solo tiene números, ignorar
    if (normalized.length < 3) return null;
    if (RegExp(r'^[\d\s\-x]+$').hasMatch(normalized)) return null;

    int? series;
    int? reps;
    double? weight;
    String exercisePart = line;

    // ========================================
    // EXPLICACIÓN DE LA LÓGICA DE REGEX
    // ========================================
    // 
    // El problema: Distinguir "4 series de 10" (4x10) de "10kg" (peso)
    // 
    // Solución: Orden de prioridad y patrones específicos:
    // 
    // 1. PRIMERO extraemos el peso (kg/lb/kilos) - esto tiene sufijo explícito
    //    Regex: (\d+(?:[.,]\d+)?)\s*(?:kg|kilos?|lb|lbs)
    //    - Busca números seguidos de unidad de peso
    //    - "100kg" → peso = 100, NO es reps
    // 
    // 2. SEGUNDO extraemos series×reps con patrón NxM
    //    Regex: (\d+)\s*[xX×]\s*(\d+)
    //    - "4x10" → series=4, reps=10
    //    - La "x" actúa como separador inequívoco
    // 
    // 3. TERCERO, si no hay patrón NxM, buscamos texto explícito
    //    Regex: (\d+)\s*(?:series|sets?)\s*(?:de\s*)?(\d+)
    //    - "3 series de 12" → series=3, reps=12
    //    - "4 sets 10" → series=4, reps=10
    // 
    // 4. Por último, patrón "N reps" solo (series default = 3)
    //    Regex: (\d+)\s*(?:reps?|repeticiones)
    //    - "12 reps" → reps=12, series=3 (default)
    // 
    // Así "100kg" nunca se confunde con reps porque:
    // - El patrón de peso se extrae PRIMERO y se remueve del texto
    // - Los patrones de reps/series buscan contexto (x, series, reps)
    // ========================================

    // 1. Extraer peso (kg, lb, kilos) - PRIMERO para no confundir con reps
    final weightRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:kg|kilos?|lb|lbs)', caseSensitive: false);
    final weightMatch = weightRegex.firstMatch(normalized);
    if (weightMatch != null) {
      final weightStr = weightMatch.group(1)!.replaceAll(',', '.');
      weight = double.tryParse(weightStr);
      // Remover el peso del texto para no confundir el parsing
      exercisePart = line.replaceAll(weightRegex, ' ');
    }

    // 2. Patrón NxM (ej: 4x10, 3X12, 5×8)
    final nxmRegex = RegExp(r'(\d+)\s*[xX×]\s*(\d+)');
    final nxmMatch = nxmRegex.firstMatch(exercisePart);
    if (nxmMatch != null) {
      series = int.tryParse(nxmMatch.group(1)!);
      reps = int.tryParse(nxmMatch.group(2)!);
      // Remover el patrón del nombre del ejercicio
      exercisePart = exercisePart.replaceAll(nxmRegex, ' ');
    }

    // 3. Patrón "N series de M reps" o "N series M"
    if (series == null || reps == null) {
      final seriesRepsRegex = RegExp(
        r'(\d+)\s*(?:series|sets?)\s*(?:de\s*)?(\d+)\s*(?:reps?|repeticiones)?',
        caseSensitive: false,
      );
      final seriesRepsMatch = seriesRepsRegex.firstMatch(exercisePart);
      if (seriesRepsMatch != null) {
        series ??= int.tryParse(seriesRepsMatch.group(1)!);
        reps ??= int.tryParse(seriesRepsMatch.group(2)!);
        exercisePart = exercisePart.replaceAll(seriesRepsRegex, ' ');
      }
    }

    // 4. Patrón solo "N reps" (series default = 3)
    if (reps == null) {
      final repsOnlyRegex = RegExp(r'(\d+)\s*(?:reps?|repeticiones)', caseSensitive: false);
      final repsOnlyMatch = repsOnlyRegex.firstMatch(exercisePart);
      if (repsOnlyMatch != null) {
        reps = int.tryParse(repsOnlyMatch.group(1)!);
        series ??= 3; // Default
        exercisePart = exercisePart.replaceAll(repsOnlyRegex, ' ');
      }
    }

    // 5. Patrón solo "N series" (reps default = 10)
    if (series == null) {
      final seriesOnlyRegex = RegExp(r'(\d+)\s*(?:series|sets?)', caseSensitive: false);
      final seriesOnlyMatch = seriesOnlyRegex.firstMatch(exercisePart);
      if (seriesOnlyMatch != null) {
        series = int.tryParse(seriesOnlyMatch.group(1)!);
        reps ??= 10; // Default
        exercisePart = exercisePart.replaceAll(seriesOnlyRegex, ' ');
      }
    }

    // Limpiar el nombre del ejercicio
    exercisePart = _cleanExerciseName(exercisePart);
    
    if (exercisePart.isEmpty) {
      return null;
    }

    // Fuzzy matching para encontrar el ejercicio en la BD
    String? matchedName;
    int? matchedId;
    double confidence = 0.0;

    if (_fuzzyMatcher != null && exercisePart.length >= 3) {
      final results = _fuzzyMatcher!.search(exercisePart.toLowerCase());
      
      if (results.isNotEmpty) {
        final best = results.first;
        // Score en fuzzy: 0 = perfecto, 1 = no match
        // Convertimos a confianza: 1 = perfecto, 0 = no match
        confidence = 1.0 - (best.score);
        
        if (confidence >= 0.5) { // Solo aceptar si hay buena confianza
          matchedName = best.item.name;
          matchedId = best.item.id;
        }
      }
    }

    // Determinar si es válido (tiene al menos nombre y algún dato de sets/reps)
    final isValid = matchedName != null && (series != null || reps != null);

    return ParsedExerciseCandidate(
      rawText: line,
      matchedExerciseName: matchedName,
      matchedExerciseId: matchedId,
      series: series ?? 3,
      reps: reps ?? 10,
      weight: weight,
      confidence: confidence,
      isValid: isValid,
    );
  }

  /// Limpia el nombre del ejercicio removiendo números sueltos y caracteres especiales
  String _cleanExerciseName(String text) {
    var cleaned = text
        // Remover números sueltos al inicio o final
        .replaceAll(RegExp(r'^\d+\s*'), '')
        .replaceAll(RegExp(r'\s*\d+$'), '')
        // Remover caracteres especiales comunes en OCR
        .replaceAll(RegExp(r'[•\-–—:,;.!?()[\]{}]'), ' ')
        // Normalizar espacios
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned;
  }

  /// Obtiene un LibraryExercise por ID (para usar después del matching)
  Future<LibraryExercise?> getExerciseById(int id) async {
    await _ensureExercisesLoaded();
    try {
      return _exercisesCache?.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Limpia el cache (útil para testing)
  void clearCache() {
    _exercisesCache = null;
    _fuzzyMatcher = null;
  }
}
