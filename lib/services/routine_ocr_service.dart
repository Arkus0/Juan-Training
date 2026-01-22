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
  final String cleanedText; // Texto limpio usado para matching (debug)

  const ParsedExerciseCandidate({
    required this.rawText,
    this.matchedExerciseName,
    this.matchedExerciseId,
    this.series = 3,
    this.reps = 10,
    this.weight,
    this.confidence = 0.0,
    this.isValid = false,
    this.cleanedText = '',
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
    String? cleanedText,
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
      cleanedText: cleanedText ?? this.cleanedText,
    );
  }
}

/// Diccionario de sinónimos/aliases comunes de ejercicios
/// Mapea texto OCR común → nombre normalizado para búsqueda
const Map<String, List<String>> _exerciseAliases = {
  // Pecho
  'press banca': ['press de banca', 'bench press', 'press banco', 'press plano', 'banca plana'],
  'press inclinado': ['press banca inclinado', 'press inclinado mancuernas', 'incline press'],
  'aperturas': ['aperturas mancuernas', 'flyes', 'flies', 'aperturas pecho'],
  'fondos': ['fondos pecho', 'dips', 'fondos paralelas'],
  'flexiones': ['push ups', 'pushups', 'lagartijas'],
  
  // Espalda
  'dominadas': ['pull ups', 'pullups', 'chin ups', 'chinups', 'jalon'],
  'remo': ['remo con barra', 'remo mancuerna', 'rowing', 'remo t'],
  'peso muerto': ['deadlift', 'dead lift', 'peso muerto rumano', 'rdl'],
  'jalon': ['jalon polea', 'lat pulldown', 'jalon al pecho', 'jalon tras nuca'],
  
  // Piernas
  'sentadilla': ['sentadillas', 'squat', 'squats', 'sentadilla libre'],
  'prensa': ['prensa piernas', 'leg press', 'prensa 45'],
  'extension': ['extension cuadriceps', 'leg extension', 'extensiones'],
  'curl femoral': ['curl pierna', 'leg curl', 'femoral'],
  'zancadas': ['lunges', 'estocadas', 'tijeras'],
  'hip thrust': ['empuje cadera', 'puente gluteo'],
  'gemelos': ['elevacion gemelos', 'calf raises', 'pantorrillas'],
  
  // Hombros
  'press militar': ['press hombro', 'overhead press', 'press arnold', 'press deltoides'],
  'elevaciones laterales': ['laterales', 'lateral raises', 'elevaciones'],
  'elevaciones frontales': ['frontales', 'front raises'],
  'pajaros': ['rear delt', 'face pull', 'elevaciones posteriores'],
  
  // Brazos
  'curl biceps': ['curl barra', 'curl mancuerna', 'bicep curl', 'curl martillo'],
  'triceps': ['extension triceps', 'tricep pushdown', 'patada triceps', 'fondos triceps'],
  'curl martillo': ['hammer curl', 'martillo'],
  
  // Abdominales
  'abdominales': ['abs', 'crunch', 'crunches', 'plancha', 'plank'],
};

/// Servicio de OCR para importar rutinas desde imágenes
class RoutineOcrService {
  static final RoutineOcrService instance = RoutineOcrService._();
  RoutineOcrService._();

  final _picker = ImagePicker();
  final _logger = Logger();
  
  // Cache de ejercicios para fuzzy matching
  List<LibraryExercise>? _exercisesCache;
  Fuzzy<LibraryExercise>? _fuzzyMatcher;
  
  // Mapa de nombre normalizado → ejercicio para búsqueda directa
  Map<String, LibraryExercise>? _exerciseMap;

  /// Inicializa el cache de ejercicios para matching
  Future<void> _ensureExercisesLoaded() async {
    if (_exercisesCache != null) return;
    
    final library = ExerciseLibraryService.instance;
    await library.loadLibrary();
    _exercisesCache = library.exercises;
    
    // Crear mapa de búsqueda directa (nombre normalizado → ejercicio)
    _exerciseMap = {};
    for (final ex in _exercisesCache!) {
      final normalized = _normalizeText(ex.name);
      _exerciseMap![normalized] = ex;
      
      // También añadir palabras clave principales
      final words = normalized.split(' ');
      if (words.length > 1) {
        // Añadir la primera palabra significativa si tiene > 4 letras
        for (final word in words) {
          if (word.length > 4) {
            _exerciseMap!.putIfAbsent(word, () => ex);
          }
        }
      }
    }
    
    // Crear fuzzy matcher con los nombres de ejercicios normalizados
    _fuzzyMatcher = Fuzzy<LibraryExercise>(
      _exercisesCache!,
      options: FuzzyOptions(
        keys: [
          WeightedKey(
            name: 'name',
            getter: (ex) => _normalizeText(ex.name),
            weight: 1.0,
          ),
        ],
        threshold: 0.3, // Más estricto (0 = exacto, 1 = cualquier cosa)
        findAllMatches: true,
        isCaseSensitive: false,
      ),
    );
  }

  /// Normaliza texto para comparación (quita acentos, minúsculas, etc.)
  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
    
    if (exercisePart.isEmpty || exercisePart.length < 3) {
      return null;
    }

    // Normalizar para búsqueda
    final normalizedSearch = _normalizeText(exercisePart);
    
    // === ESTRATEGIA DE MATCHING MULTI-NIVEL ===
    String? matchedName;
    int? matchedId;
    double confidence = 0.0;

    // 1. PRIMERO: Búsqueda exacta en mapa
    if (_exerciseMap != null && _exerciseMap!.containsKey(normalizedSearch)) {
      final match = _exerciseMap![normalizedSearch]!;
      matchedName = match.name;
      matchedId = match.id;
      confidence = 1.0;
      _logger.d('Match exacto: "$normalizedSearch" → "${match.name}"');
    }

    // 2. SEGUNDO: Buscar por aliases/sinónimos
    if (matchedName == null) {
      final aliasMatch = _findByAlias(normalizedSearch);
      if (aliasMatch != null) {
        matchedName = aliasMatch.name;
        matchedId = aliasMatch.id;
        confidence = 0.95;
        _logger.d('Match por alias: "$normalizedSearch" → "${aliasMatch.name}"');
      }
    }

    // 3. TERCERO: Búsqueda por palabras clave contenidas
    if (matchedName == null) {
      final keywordMatch = _findByKeywords(normalizedSearch);
      if (keywordMatch != null) {
        matchedName = keywordMatch.exercise.name;
        matchedId = keywordMatch.exercise.id;
        confidence = keywordMatch.confidence;
        _logger.d('Match por keywords: "$normalizedSearch" → "${keywordMatch.exercise.name}" (${(confidence * 100).toInt()}%)');
      }
    }

    // 4. CUARTO: Fuzzy matching como fallback
    if (matchedName == null && _fuzzyMatcher != null) {
      final results = _fuzzyMatcher!.search(normalizedSearch);
      
      if (results.isNotEmpty) {
        final best = results.first;
        // Score en fuzzy: 0 = perfecto, 1 = no match
        confidence = 1.0 - best.score;
        
        // Más estricto: requiere > 60% de confianza
        if (confidence >= 0.6) {
          matchedName = best.item.name;
          matchedId = best.item.id;
          _logger.d('Match fuzzy: "$normalizedSearch" → "${best.item.name}" (${(confidence * 100).toInt()}%)');
        }
      }
    }

    // Determinar si es válido
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
      cleanedText: normalizedSearch,
    );
  }

  /// Busca un ejercicio por sus aliases/sinónimos
  LibraryExercise? _findByAlias(String searchText) {
    for (final entry in _exerciseAliases.entries) {
      final mainName = entry.key;
      final aliases = entry.value;
      
      // Verificar si el texto contiene el nombre principal o algún alias
      if (searchText.contains(mainName) || 
          aliases.any((alias) => searchText.contains(alias) || alias.contains(searchText))) {
        // Buscar el ejercicio correspondiente en la BD
        return _findExerciseByKeyword(mainName);
      }
    }
    return null;
  }

  /// Busca ejercicio por palabra clave en el nombre
  LibraryExercise? _findExerciseByKeyword(String keyword) {
    if (_exercisesCache == null) return null;
    
    final normalizedKeyword = _normalizeText(keyword);
    
    // Buscar ejercicio cuyo nombre contenga la palabra clave
    for (final ex in _exercisesCache!) {
      final normalizedName = _normalizeText(ex.name);
      if (normalizedName.contains(normalizedKeyword) || 
          normalizedKeyword.contains(normalizedName)) {
        return ex;
      }
    }
    return null;
  }

  /// Clase auxiliar para resultado de búsqueda por keywords
  /// Busca ejercicios donde el nombre contenga palabras del texto de búsqueda
  _KeywordMatch? _findByKeywords(String searchText) {
    if (_exercisesCache == null) return null;
    
    final searchWords = searchText.split(' ').where((w) => w.length > 3).toList();
    if (searchWords.isEmpty) return null;

    LibraryExercise? bestMatch;
    int bestScore = 0;

    for (final ex in _exercisesCache!) {
      final exName = _normalizeText(ex.name);
      final exWords = exName.split(' ');
      
      int matchCount = 0;
      for (final searchWord in searchWords) {
        for (final exWord in exWords) {
          // Coincidencia parcial: la palabra del ejercicio contiene la búsqueda o viceversa
          if (exWord.contains(searchWord) || searchWord.contains(exWord)) {
            matchCount++;
            break;
          }
        }
      }

      // También verificar si el nombre completo está contenido
      if (exName.contains(searchText) || searchText.contains(exName)) {
        matchCount += 2;
      }

      if (matchCount > bestScore) {
        bestScore = matchCount;
        bestMatch = ex;
      }
    }

    if (bestMatch != null && bestScore >= 1) {
      // Calcular confianza basada en palabras coincidentes
      final confidence = (bestScore / (searchWords.length + 1)).clamp(0.5, 0.9);
      return _KeywordMatch(bestMatch, confidence);
    }

    return null;
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
    _exerciseMap = null;
  }
}

/// Clase auxiliar para resultados de búsqueda por keywords
class _KeywordMatch {
  final LibraryExercise exercise;
  final double confidence;
  
  _KeywordMatch(this.exercise, this.confidence);
}
