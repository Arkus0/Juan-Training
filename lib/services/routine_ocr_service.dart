import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import '../models/library_exercise.dart';
import 'exercise_matching_service.dart';
import 'exercise_parsing_service.dart';
import 'exercise_validation_service.dart';

/// Modelo de ejercicio parseado desde OCR
///
/// NOTA: Esta clase se mantiene por compatibilidad con código existente.
/// Internamente usa [ParsedExercise] de [ExerciseParsingService].
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
  final List<String> validationErrors;

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
    this.validationErrors = const [],
  });

  /// Crea un ParsedExerciseCandidate desde un ParsedExercise
  factory ParsedExerciseCandidate.fromParsedExercise(ParsedExercise parsed) {
    return ParsedExerciseCandidate(
      rawText: parsed.rawText,
      matchedExerciseName: parsed.matchedName,
      matchedExerciseId: parsed.matchedId,
      series: parsed.series,
      reps: parsed.minReps, // Usamos minReps para compatibilidad
      weight: parsed.weight,
      confidence: parsed.confidence,
      isValid: parsed.isValid,
      cleanedText: parsed.cleanedText,
      validationErrors: parsed.validationErrors,
    );
  }

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
    List<String>? validationErrors,
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
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }

  /// Verifica si hay errores de validación
  bool get hasValidationErrors => validationErrors.isNotEmpty;
}

/// Servicio de OCR para importar rutinas desde imágenes.
///
/// Este servicio ahora delega el parsing y matching a los servicios unificados:
/// - [ExerciseParsingService] para extracción de series/reps/peso
/// - [ExerciseMatchingService] para matching contra biblioteca
/// - [ExerciseValidationService] para validación de rangos
///
/// La API pública se mantiene igual para compatibilidad.
class RoutineOcrService {
  static final RoutineOcrService instance = RoutineOcrService._();
  RoutineOcrService._();

  final _picker = ImagePicker();
  final _logger = Logger();

  // Servicios unificados
  final _parsingService = ExerciseParsingService.instance;
  final _matchingService = ExerciseMatchingService.instance;
  final _validationService = ExerciseValidationService.instance;

  /// Escanea una imagen desde cámara o galería.
  /// Devuelve las líneas de texto crudo extraídas.
  Future<List<String>> scanImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
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
      final textRecognizer = TextRecognizer();

      try {
        final recognizedText = await textRecognizer.processImage(inputImage);

        // Extraer líneas de texto (cada bloque puede tener múltiples líneas)
        final lines = <String>[];
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

  /// Parsea las líneas de texto y extrae candidatos de ejercicios.
  ///
  /// Usa [ExerciseParsingService] para el parsing unificado.
  ///
  /// Patrones soportados:
  /// - "Press Banca 4x10" -> 4 series, 10 reps
  /// - "Sentadilla 3 series 12 reps" -> 3 series, 12 reps
  /// - "Curl 4x12 20kg" -> 4 series, 12 reps, 20kg
  /// - "Peso muerto 5x5 100kg" -> 5 series, 5 reps, 100kg
  Future<List<ParsedExerciseCandidate>> parseLines(List<String> lines) async {
    final candidates = <ParsedExerciseCandidate>[];

    for (final line in lines) {
      final candidate = await _parseSingleLine(line);
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    _logger.i(
        'Parseados ${candidates.length} ejercicios de ${lines.length} líneas',);
    return candidates;
  }

  /// Parsea una sola línea de texto usando el servicio unificado.
  Future<ParsedExerciseCandidate?> _parseSingleLine(String line) async {
    // Filtrar líneas inválidas
    final normalized = line.toLowerCase().trim();
    if (normalized.length < 3) return null;
    if (RegExp(r'^[\d\s\-x]+$').hasMatch(normalized)) return null;

    // Usar el servicio de parsing unificado
    final parsed = await _parsingService.parseSingleLine(
      line,
    );

    if (parsed == null) return null;

    // Convertir a formato de compatibilidad
    return ParsedExerciseCandidate.fromParsedExercise(parsed);
  }

  /// Re-matchea un candidato con un nuevo nombre de ejercicio.
  /// Útil cuando el usuario quiere corregir el match.
  Future<ParsedExerciseCandidate> rematchCandidate(
    ParsedExerciseCandidate candidate,
    String newExerciseName,
  ) async {
    final matchResult = await _matchingService.match(newExerciseName);

    return candidate.copyWith(
      matchedExerciseName: matchResult.exercise?.name,
      matchedExerciseId: matchResult.exercise?.id,
      confidence: matchResult.isValid ? 1.0 : matchResult.confidence,
      isValid: matchResult.exercise != null,
    );
  }

  /// Obtiene un LibraryExercise por ID.
  Future<LibraryExercise?> getExerciseById(int id) async {
    return _matchingService.getById(id);
  }

  /// Busca ejercicios alternativos para un nombre dado.
  /// Útil para mostrar sugerencias cuando el match no es seguro.
  Future<List<ExerciseMatchResult>> searchAlternatives(String query,
      {int limit = 5,}) async {
    return _matchingService.matchMultiple(query, limit: limit);
  }

  /// Valida un candidato y retorna errores/advertencias.
  ValidationResult validateCandidate(ParsedExerciseCandidate candidate) {
    // Convertir a ParsedExercise para validar
    final parsed = ParsedExercise(
      rawText: candidate.rawText,
      matchedName: candidate.matchedExerciseName,
      matchedId: candidate.matchedExerciseId,
      series: candidate.series,
      repsRange: candidate.reps.toString(),
      weight: candidate.weight,
      confidence: candidate.confidence,
    );

    return _validationService.validate(parsed);
  }

  /// Limpia el cache de ejercicios (útil para testing o refresh).
  void clearCache() {
    _matchingService.invalidateCache();
  }
}
