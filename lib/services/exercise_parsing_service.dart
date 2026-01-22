import 'package:logger/logger.dart';
import '../models/library_exercise.dart';
import 'exercise_matching_service.dart';
import 'exercise_validation_service.dart';

/// Resultado del parsing de un ejercicio desde texto (OCR o voz)
class ParsedExercise {
  /// Texto original antes de procesar
  final String rawText;

  /// Nombre del ejercicio encontrado en biblioteca (null si no hubo match)
  final String? matchedName;

  /// ID del ejercicio en biblioteca (null si no hubo match)
  final int? matchedId;

  /// Número de series (default: 3)
  final int series;

  /// Rango de repeticiones como string (ej: "10", "8-12")
  final String repsRange;

  /// Peso en kg (null si no especificado)
  final double? weight;

  /// Notas adicionales
  final String? notes;

  /// Confianza del match (0.0 - 1.0)
  final double confidence;

  /// Fuente del match (para debugging)
  final MatchSource matchSource;

  /// Es parte de una superserie
  final bool isSuperset;

  /// Grupo de superserie (0 = no superserie)
  final int supersetGroup;

  /// Texto limpio usado para el matching
  final String cleanedText;

  /// Lista de errores de validación (vacía si todo OK)
  final List<String> validationErrors;

  const ParsedExercise({
    required this.rawText,
    this.matchedName,
    this.matchedId,
    this.series = 3,
    this.repsRange = '10',
    this.weight,
    this.notes,
    this.confidence = 0.0,
    this.matchSource = MatchSource.noMatch,
    this.isSuperset = false,
    this.supersetGroup = 0,
    this.cleanedText = '',
    this.validationErrors = const [],
  });

  /// El ejercicio es válido si tiene match y no tiene errores de validación
  bool get isValid => matchedId != null && validationErrors.isEmpty;

  /// Número mínimo de reps del rango
  int get minReps {
    final parts = repsRange.split('-');
    return int.tryParse(parts.first) ?? 10;
  }

  /// Número máximo de reps del rango (igual a minReps si no es rango)
  int get maxReps {
    final parts = repsRange.split('-');
    if (parts.length > 1) {
      return int.tryParse(parts.last) ?? minReps;
    }
    return minReps;
  }

  ParsedExercise copyWith({
    String? rawText,
    String? matchedName,
    int? matchedId,
    int? series,
    String? repsRange,
    double? weight,
    String? notes,
    double? confidence,
    MatchSource? matchSource,
    bool? isSuperset,
    int? supersetGroup,
    String? cleanedText,
    List<String>? validationErrors,
  }) {
    return ParsedExercise(
      rawText: rawText ?? this.rawText,
      matchedName: matchedName ?? this.matchedName,
      matchedId: matchedId ?? this.matchedId,
      series: series ?? this.series,
      repsRange: repsRange ?? this.repsRange,
      weight: weight ?? this.weight,
      notes: notes ?? this.notes,
      confidence: confidence ?? this.confidence,
      matchSource: matchSource ?? this.matchSource,
      isSuperset: isSuperset ?? this.isSuperset,
      supersetGroup: supersetGroup ?? this.supersetGroup,
      cleanedText: cleanedText ?? this.cleanedText,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }

  @override
  String toString() =>
      'ParsedExercise(name: $matchedName, series: $series, reps: $repsRange, weight: $weight, confidence: ${(confidence * 100).toInt()}%, valid: $isValid)';
}

/// Servicio UNIFICADO para parsing de ejercicios desde texto.
///
/// Este servicio centraliza TODA la lógica de parsing que antes estaba
/// duplicada entre [RoutineOcrService] y [VoiceInputService].
///
/// Soporta patrones:
/// - "Press Banca 4x10" → 4 series, 10 reps
/// - "Sentadilla 3 series 12 reps" → 3 series, 12 reps
/// - "Curl 4x8-12 20kg" → 4 series, 8-12 reps, 20kg
/// - "Peso muerto 5x5 a 100kg" → 5 series, 5 reps, 100kg
/// - "Superserie con press y elevaciones" → detecta superserie
/// - "Nota: usar cinturón" → extrae notas
///
/// Uso:
/// ```dart
/// final exercises = await ExerciseParsingService.instance.parseText(
///   'Press banca 4x10 luego sentadilla 5x5',
///   source: ParseSource.voice,
/// );
/// ```
class ExerciseParsingService {
  static final ExerciseParsingService instance = ExerciseParsingService._();
  ExerciseParsingService._();

  final _logger = Logger();
  final _matchingService = ExerciseMatchingService.instance;
  final _validationService = ExerciseValidationService.instance;

  /// Parsea texto y extrae ejercicios
  ///
  /// [text] Texto a parsear (puede contener múltiples ejercicios)
  /// [source] Fuente del texto (OCR vs voz, afecta tolerancia de errores)
  /// [validateResults] Si true, aplica validación de rangos a los resultados
  Future<List<ParsedExercise>> parseText(
    String text, {
    ParseSource source = ParseSource.ocr,
    bool validateResults = true,
  }) async {
    if (text.trim().isEmpty) return [];

    final normalized = _normalizeInputText(text, source);
    final segments = _splitIntoExerciseSegments(normalized);
    final exercises = <ParsedExercise>[];

    int supersetGroup = 0;
    bool inSuperset = false;

    for (final segment in segments) {
      // Detectar inicio de superserie
      if (_isSupersetIndicator(segment)) {
        supersetGroup++;
        inSuperset = true;
        continue;
      }

      // Detectar fin de superserie (separador explícito)
      if (_isSupersetEnd(segment)) {
        inSuperset = false;
        continue;
      }

      final parsed = await _parseSingleExercise(segment, source: source);
      if (parsed != null) {
        var exercise = parsed.copyWith(
          isSuperset: inSuperset,
          supersetGroup: inSuperset ? supersetGroup : 0,
        );

        // Validar si está habilitado
        if (validateResults) {
          final validationResult = _validationService.validate(exercise);
          exercise = exercise.copyWith(validationErrors: validationResult.errors);
        }

        exercises.add(exercise);
      }
    }

    return exercises;
  }

  /// Parsea una sola línea (para OCR línea por línea)
  Future<ParsedExercise?> parseSingleLine(
    String line, {
    ParseSource source = ParseSource.ocr,
    bool validate = true,
  }) async {
    final results = await parseText(line, source: source, validateResults: validate);
    return results.isEmpty ? null : results.first;
  }

  /// Re-matchea un ejercicio parseado con un nuevo nombre
  /// Útil para correcciones manuales del usuario
  Future<ParsedExercise> rematch(ParsedExercise original, String newName) async {
    final matchResult = await _matchingService.match(newName);

    return original.copyWith(
      matchedName: matchResult.exercise?.name,
      matchedId: matchResult.exercise?.id,
      confidence: matchResult.isValid ? 1.0 : matchResult.confidence, // Corrección manual = alta confianza
      matchSource: matchResult.source,
      rawText: '${original.rawText} → $newName',
    );
  }

  // ========================================
  // NORMALIZACIÓN DE ENTRADA
  // ========================================

  String _normalizeInputText(String text, ParseSource source) {
    var normalized = text.toLowerCase();

    // Normalizar separadores de ejercicios
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    // Normalizar "x" para series
    normalized = normalized
        .replaceAll('×', 'x')
        .replaceAll('*', 'x');

    // Normalizar números hablados (más importante para voz)
    if (source == ParseSource.voice) {
      normalized = normalized
          .replaceAll('una serie', '1 serie')
          .replaceAll('un set', '1 set')
          .replaceAll('dos series', '2 series')
          .replaceAll('tres series', '3 series')
          .replaceAll('cuatro series', '4 series')
          .replaceAll('cinco series', '5 series')
          .replaceAll('seis series', '6 series')
          .replaceAll('diez', '10')
          .replaceAll('doce', '12')
          .replaceAll('quince', '15')
          .replaceAll('veinte', '20');
    }

    // Normalizar unidades
    normalized = normalized
        .replaceAll('repeticiones', 'reps')
        .replaceAll('repeticion', 'rep')
        .replaceAll('kilogramos', 'kg')
        .replaceAll('kilos', 'kg')
        .replaceAll('libras', 'lb');

    return normalized.trim();
  }

  // ========================================
  // SEGMENTACIÓN
  // ========================================

  /// Separa texto en segmentos, cada uno potencialmente un ejercicio
  List<String> _splitIntoExerciseSegments(String text) {
    // Patrones de separación
    const connectors = [
      r'\s+luego\s+',
      r'\s+después\s+',
      r'\s+y\s+(?:después|luego)\s+',
      r'\s+seguido\s+de\s+',
      r'\s+también\s+',
      r'\s*,\s*(?:después|luego)?\s*',
      r'\.\s+',
    ];

    var working = text;
    for (final connector in connectors) {
      working = working.replaceAll(RegExp(connector, caseSensitive: false), '|||');
    }

    return working
        .split('|||')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 2)
        .toList();
  }

  bool _isSupersetIndicator(String segment) {
    return RegExp(r'super\s*serie\s+(?:con|de)?', caseSensitive: false).hasMatch(segment);
  }

  bool _isSupersetEnd(String segment) {
    return segment.contains('fin superserie') || segment.contains('fin de superserie');
  }

  // ========================================
  // PARSING DE EJERCICIO INDIVIDUAL
  // ========================================

  Future<ParsedExercise?> _parseSingleExercise(
    String segment, {
    required ParseSource source,
  }) async {
    // Remover comandos de control
    var text = segment
        .replaceFirst(RegExp(r'^(?:añade|agrega|pon)\s+', caseSensitive: false), '');

    if (text.length < 3) return null;

    // Variables a extraer
    int series = 3;
    String repsRange = '10';
    double? weight;
    String? notes;
    String exercisePart = text;

    // ========================================
    // ORDEN DE EXTRACCIÓN (CRÍTICO)
    // ========================================
    // El orden evita confusiones como "100kg" → reps
    //
    // 1. NOTAS primero (después de "nota:")
    // 2. PESO segundo (tiene sufijo kg/lb explícito)
    // 3. PATRÓN NxM tercero (la x es inequívoca)
    // 4. SERIES/REPS explícitos
    // 5. SOLO REPS o SOLO SERIES
    // ========================================

    // 1. Extraer notas
    final notesMatch = RegExp(
      r'(?:nota[s]?:?\s*|con\s+nota\s*)(.+)$',
      caseSensitive: false,
    ).firstMatch(exercisePart);
    if (notesMatch != null) {
      notes = notesMatch.group(1)?.trim();
      exercisePart = exercisePart.replaceAll(notesMatch.group(0)!, '');
    }

    // 2. Extraer peso
    final weightRegex = RegExp(
      r'(?:a\s+|con\s+)?(\d+(?:[.,]\d+)?)\s*(?:kg|lb)',
      caseSensitive: false,
    );
    final weightMatch = weightRegex.firstMatch(exercisePart);
    if (weightMatch != null) {
      final weightStr = weightMatch.group(1)!.replaceAll(',', '.');
      weight = double.tryParse(weightStr);
      exercisePart = exercisePart.replaceAll(weightRegex, ' ');
    }

    // 3. Patrón NxM o NxM-P (ej: "4x10", "3x8-12")
    final nxmRegex = RegExp(r'(\d+)\s*[xX]\s*(\d+)(?:\s*-\s*(\d+))?');
    final nxmMatch = nxmRegex.firstMatch(exercisePart);
    if (nxmMatch != null) {
      series = int.tryParse(nxmMatch.group(1)!) ?? 3;
      final repsMin = nxmMatch.group(2)!;
      final repsMax = nxmMatch.group(3);
      repsRange = repsMax != null ? '$repsMin-$repsMax' : repsMin;
      exercisePart = exercisePart.replaceAll(nxmRegex, ' ');
    }

    // 4. Patrón "N series de M reps"
    if (nxmMatch == null) {
      final seriesRepsRegex = RegExp(
        r'(\d+)\s*(?:series?|sets?)\s*(?:de\s*)?(\d+)(?:\s*-\s*(\d+))?\s*(?:reps?)?',
        caseSensitive: false,
      );
      final match = seriesRepsRegex.firstMatch(exercisePart);
      if (match != null) {
        series = int.tryParse(match.group(1)!) ?? 3;
        final repsMin = match.group(2)!;
        final repsMax = match.group(3);
        repsRange = repsMax != null ? '$repsMin-$repsMax' : repsMin;
        exercisePart = exercisePart.replaceAll(seriesRepsRegex, ' ');
      }
    }

    // 5. Solo "N reps"
    if (nxmMatch == null) {
      final repsOnlyRegex = RegExp(
        r'(\d+)(?:\s*-\s*(\d+))?\s*(?:reps?)',
        caseSensitive: false,
      );
      final match = repsOnlyRegex.firstMatch(exercisePart);
      if (match != null) {
        final repsMin = match.group(1)!;
        final repsMax = match.group(2);
        repsRange = repsMax != null ? '$repsMin-$repsMax' : repsMin;
        exercisePart = exercisePart.replaceAll(repsOnlyRegex, ' ');
      }
    }

    // 6. Solo "N series"
    final seriesOnlyMatch = RegExp(
      r'(\d+)\s*(?:series?|sets?)',
      caseSensitive: false,
    ).firstMatch(exercisePart);
    if (seriesOnlyMatch != null && nxmMatch == null) {
      series = int.tryParse(seriesOnlyMatch.group(1)!) ?? series;
      exercisePart = exercisePart.replaceAll(seriesOnlyMatch.group(0)!, ' ');
    }

    // Limpiar nombre del ejercicio
    exercisePart = _cleanExerciseName(exercisePart);
    if (exercisePart.length < 3) return null;

    // Matching contra biblioteca
    final matchResult = await _matchingService.match(exercisePart);

    return ParsedExercise(
      rawText: segment,
      matchedName: matchResult.exercise?.name,
      matchedId: matchResult.exercise?.id,
      series: series,
      repsRange: repsRange,
      weight: weight,
      notes: notes,
      confidence: matchResult.confidence,
      matchSource: matchResult.source,
      cleanedText: matchResult.normalizedQuery,
    );
  }

  String _cleanExerciseName(String text) {
    return text
        .replaceAll(RegExp(r'^\d+\s*'), '') // Números al inicio
        .replaceAll(RegExp(r'\s*\d+$'), '') // Números al final
        .replaceAll(RegExp(r'[•\-–—:,;.!?()[\]{}]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

/// Fuente del texto a parsear
enum ParseSource {
  /// Texto extraído de imagen via OCR
  ocr,

  /// Texto de reconocimiento de voz
  voice,

  /// Texto escrito manualmente por usuario
  manual,
}
