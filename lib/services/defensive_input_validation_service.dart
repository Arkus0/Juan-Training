import 'package:logger/logger.dart';
import '../models/raw_input_capture.dart';
import '../models/input_hypothesis.dart';
import '../models/library_exercise.dart';
import 'exercise_matching_service.dart';
import 'exercise_library_service.dart';
import 'defensive_metrics_service.dart';

/// Servicio de Validación Defensiva de Entrada
///
/// ## PRINCIPIO FUNDAMENTAL (NO NEGOCIABLE)
///
/// OCR y Voz:
/// ❌ NO interpretan
/// ❌ NO deciden
/// ✅ SOLO generan hipótesis
///
/// La app:
/// ✅ Valida
/// ✅ Acota
/// ✅ Corrige
/// ✅ Decide
///
/// ## PIPELINE EN DOS FASES
///
/// ### Fase 1 — Captura bruta (sin semántica)
/// OCR/Voz solo devuelven:
/// - Tokens detectados
/// - Confianza
/// - Posición / orden
///
/// ### Fase 2 — Interpretación acotada (app-side)
/// - Matching por lista cerrada (solo ejercicios existentes)
/// - Top N candidatos con confianza
/// - Parsing conservador (si falta info, queda vacío)
/// - NUNCA auto-acepta sin revisión
///
/// ## OBJETIVO
/// Que OCR y voz sean un "asistente torpe pero útil",
/// no un "autómata confiado que se equivoca".
class DefensiveInputValidationService {
  static final DefensiveInputValidationService instance =
      DefensiveInputValidationService._();
  DefensiveInputValidationService._();

  final _logger = Logger();
  final _matchingService = ExerciseMatchingService.instance;
  final _metricsService = DefensiveMetricsService.instance;

  // Configuración
  static const int _maxCandidates = 5;
  static const double _minConfidenceForCandidate = 0.3;
  static const double _highConfidenceThreshold = 0.85;
  static const double _ambiguityThreshold = 0.1;

  /// Inicializa el servicio
  Future<void> initialize() async {
    await _matchingService.initialize();
    await _metricsService.initialize();
    _logger.i('DefensiveInputValidationService inicializado');
  }

  // =========================================
  // FASE 1: CAPTURA BRUTA
  // =========================================

  /// Procesa texto crudo de OCR a captura bruta
  ///
  /// IMPORTANTE: Esta fase NO interpreta semánticamente.
  /// Solo tokeniza y clasifica sintácticamente.
  RawInputCapture captureFromOcrText({
    required String rawText,
    required double imageQuality,
  }) {
    _logger.d('Fase 1: Capturando texto OCR');

    // Dividir en líneas
    final lines = rawText.split('\n').where((l) => l.trim().isNotEmpty).toList();

    final ocrLines = lines.map((line) {
      final words = line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      return OcrLine(
        words: words.map((w) => OcrWord(
          text: w,
          confidence: imageQuality, // Heredar confianza de imagen
        )).toList(),
      );
    }).toList();

    return RawInputCapture.fromOcr(
      rawText: rawText,
      lines: ocrLines,
      imageQuality: imageQuality,
    );
  }

  /// Procesa transcripción de voz a captura bruta
  ///
  /// IMPORTANTE: Esta fase NO interpreta semánticamente.
  /// Solo tokeniza y clasifica sintácticamente.
  RawInputCapture captureFromVoiceTranscript({
    required String transcript,
    required double confidence,
    required bool isFinal,
    Duration? audioDuration,
  }) {
    _logger.d('Fase 1: Capturando transcripción de voz');

    return RawInputCapture.fromVoice(
      transcript: transcript,
      confidence: confidence,
      isFinal: isFinal,
      audioDuration: audioDuration,
    );
  }

  // =========================================
  // FASE 2: INTERPRETACIÓN ACOTADA
  // =========================================

  /// Interpreta una captura bruta en hipótesis acotadas
  ///
  /// REGLAS DE INTERPRETACIÓN:
  /// 1. El ejercicio SOLO puede ser uno de la biblioteca (lista cerrada)
  /// 2. Se devuelven TOP N candidatos, nunca uno solo
  /// 3. Si la confianza < umbral → NO autoasignar
  /// 4. Series/reps: solo patrones claros, si falta info queda vacío
  /// 5. NUNCA inferir por contexto
  Future<List<InputHypothesis>> interpretCapture({
    required RawInputCapture capture,
    required InputContext context,
  }) async {
    _logger.d('Fase 2: Interpretando captura');

    // Verificar calidad mínima
    if (!capture.hasAcceptableQuality) {
      _logger.w('Captura con calidad insuficiente: ${capture.overallConfidence}');
      return [
        _createFailedHypothesis(
          capture,
          'Calidad de captura insuficiente (${(capture.overallConfidence * 100).toInt()}%)',
        ),
      ];
    }

    // Segmentar en potenciales ejercicios
    final segments = _segmentTokensIntoExercises(capture.tokens);

    if (segments.isEmpty) {
      return [
        _createFailedHypothesis(capture, 'No se detectaron ejercicios'),
      ];
    }

    // Aplicar restricciones de contexto
    final allowedSegments = _applyContextRestrictions(segments, context);

    // Interpretar cada segmento
    final hypotheses = <InputHypothesis>[];
    for (final segment in allowedSegments) {
      final hypothesis = await _interpretSegment(capture, segment, context);
      hypotheses.add(hypothesis);
    }

    return hypotheses;
  }

  /// Interpreta un segmento individual
  Future<InputHypothesis> _interpretSegment(
    RawInputCapture capture,
    _TokenSegment segment,
    InputContext context,
  ) async {
    // Extraer nombre del ejercicio (tokens tipo word)
    final exerciseText = segment.tokens
        .where((t) => t.tokenType == RawTokenType.word)
        .map((t) => t.text)
        .join(' ')
        .trim();

    // Obtener candidatos de ejercicio (lista cerrada)
    final exerciseHypothesis = await _matchExerciseCandidates(exerciseText);

    // Parsear series/reps conservadoramente
    final seriesRepsHypothesis = _parseSeriesRepsConservatively(segment.tokens);

    // Calcular estado de la hipótesis
    final status = HypothesisStatusExtension.calculateStatus(
      exercise: exerciseHypothesis,
      seriesReps: seriesRepsHypothesis,
    );

    // Determinar si requiere revisión (casi siempre sí)
    String? reviewReason;
    if (!exerciseHypothesis.hasHighConfidenceCandidate) {
      reviewReason = 'Ejercicio no identificado con certeza';
    } else if (exerciseHypothesis.hasAmbiguity) {
      reviewReason = 'Múltiples ejercicios coincidentes';
    } else if (!seriesRepsHypothesis.isComplete) {
      reviewReason = 'Faltan datos de series o repeticiones';
    } else if (status != HypothesisStatus.highConfidence) {
      reviewReason = 'Confianza insuficiente para auto-aceptar';
    }

    return InputHypothesis(
      rawCapture: capture,
      exerciseHypothesis: exerciseHypothesis,
      seriesRepsHypothesis: seriesRepsHypothesis,
      status: status,
      reviewReason: reviewReason,
      generatedAt: DateTime.now(),
    );
  }

  /// Matching contra lista cerrada de ejercicios
  ///
  /// REGLA CRÍTICA:
  /// El ejercicio SOLO puede ser uno de los existentes en la biblioteca.
  /// NUNCA crear ejercicios nuevos.
  /// NUNCA aceptar un ejercicio no reconocido claramente.
  Future<ExerciseHypothesis> _matchExerciseCandidates(String queryText) async {
    if (queryText.isEmpty) {
      return ExerciseHypothesis.noMatch(queryText);
    }

    // Obtener múltiples candidatos
    final results = await _matchingService.matchMultiple(
      queryText,
      limit: _maxCandidates,
    );

    // Filtrar por confianza mínima
    final candidates = results
        .where((r) => r.confidence >= _minConfidenceForCandidate && r.exercise != null)
        .map((r) => ExerciseCandidate(
              exercise: r.exercise!,
              confidence: r.confidence,
              source: r.source,
              resolvedSynonym: r.resolvedSynonym,
              matchReason: _describeMatchReason(r.source, r.resolvedSynonym),
            ))
        .toList();

    if (candidates.isEmpty) {
      _logger.d('Sin candidatos para: "$queryText"');
      return ExerciseHypothesis.noMatch(queryText);
    }

    _logger.d('${candidates.length} candidatos para "$queryText": '
        '${candidates.map((c) => '${c.exercise.name}(${c.confidencePercent}%)').join(', ')}');

    return ExerciseHypothesis(
      queryText: queryText,
      candidates: candidates,
      primaryMatchSource: candidates.first.source,
    );
  }

  String _describeMatchReason(MatchSource source, String? synonym) {
    switch (source) {
      case MatchSource.exactMatch:
        return 'Coincidencia exacta';
      case MatchSource.synonym:
        return synonym != null ? 'Sinónimo: $synonym' : 'Por sinónimo';
      case MatchSource.keyword:
        return 'Por palabras clave';
      case MatchSource.fuzzy:
        return 'Por similitud';
      case MatchSource.noMatch:
        return 'Sin coincidencia';
    }
  }

  /// Parsing conservador de series y reps
  ///
  /// REGLAS:
  /// - Solo detectar patrones claros ("3x8", "cuatro series de diez")
  /// - Si falta información → se deja vacío
  /// - NUNCA inferir por contexto
  /// - NUNCA copiar de sesiones anteriores sin confirmar
  SeriesRepsHypothesis _parseSeriesRepsConservatively(List<RawToken> tokens) {
    ParsedValue<int>? series;
    ParsedValue<int>? minReps;
    ParsedValue<int>? maxReps;
    ParsedValue<double>? weight;
    String? detectedPattern;
    final warnings = <String>[];

    // Buscar patrón NxM (más claro e inequívoco)
    for (final token in tokens) {
      if (token.tokenType == RawTokenType.setRepPattern) {
        final match = RegExp(r'(\d+)[xX×*](\d+)(?:-(\d+))?').firstMatch(token.text);
        if (match != null) {
          final s = int.tryParse(match.group(1)!);
          final rMin = int.tryParse(match.group(2)!);
          final rMax = match.group(3) != null ? int.tryParse(match.group(3)!) : null;

          if (s != null && rMin != null) {
            series = ParsedValue(
              value: s,
              confidence: token.confidence,
              sourceText: token.text,
            );
            minReps = ParsedValue(
              value: rMin,
              confidence: token.confidence,
              sourceText: token.text,
            );
            if (rMax != null) {
              maxReps = ParsedValue(
                value: rMax,
                confidence: token.confidence,
                sourceText: token.text,
              );
            }
            detectedPattern = token.text;
          }
        }
        break; // Solo procesar el primer patrón encontrado
      }
    }

    // Buscar peso con unidad explícita
    for (final token in tokens) {
      if (token.tokenType == RawTokenType.weightWithUnit) {
        final match = RegExp(r'(\d+(?:[.,]\d+)?)(?:kg|lb)', caseSensitive: false)
            .firstMatch(token.text);
        if (match != null) {
          final w = double.tryParse(match.group(1)!.replaceAll(',', '.'));
          if (w != null) {
            weight = ParsedValue(
              value: w,
              confidence: token.confidence,
              sourceText: token.text,
            );
          }
        }
        break;
      }
    }

    // Si no encontramos patrón NxM, buscar números sueltos pero con MÁS cuidado
    if (series == null) {
      // Buscar palabras como "series", "sets" seguidas de número
      final tokenTexts = tokens.map((t) => t.text.toLowerCase()).toList();
      for (int i = 0; i < tokenTexts.length - 1; i++) {
        if (_isSeriesKeyword(tokenTexts[i])) {
          final nextToken = tokens[i + 1];
          if (nextToken.tokenType == RawTokenType.number) {
            final s = int.tryParse(nextToken.text);
            if (s != null && s >= 1 && s <= 10) {
              series = ParsedValue(
                value: s,
                confidence: nextToken.confidence * 0.8, // Reducir confianza
                sourceText: '${tokenTexts[i]} ${nextToken.text}',
              );
            }
          }
        }
        if (_isRepsKeyword(tokenTexts[i])) {
          final nextToken = tokens[i + 1];
          if (nextToken.tokenType == RawTokenType.number) {
            final r = int.tryParse(nextToken.text);
            if (r != null && r >= 1 && r <= 50) {
              minReps = ParsedValue(
                value: r,
                confidence: nextToken.confidence * 0.8,
                sourceText: '${tokenTexts[i]} ${nextToken.text}',
              );
            }
          }
        }
      }
    }

    // Añadir advertencias si hay datos incompletos
    if (series == null) {
      warnings.add('No se detectaron series claramente');
    }
    if (minReps == null) {
      warnings.add('No se detectaron repeticiones claramente');
    }

    return SeriesRepsHypothesis(
      series: series,
      minReps: minReps,
      maxReps: maxReps,
      weight: weight,
      detectedPattern: detectedPattern,
      warnings: warnings,
    );
  }

  bool _isSeriesKeyword(String text) {
    return RegExp(r'^(series?|sets?|tandas?)$', caseSensitive: false).hasMatch(text);
  }

  bool _isRepsKeyword(String text) {
    return RegExp(r'^(reps?|repeticiones?|veces)$', caseSensitive: false).hasMatch(text);
  }

  // =========================================
  // SEGMENTACIÓN Y RESTRICCIONES
  // =========================================

  /// Segmenta tokens en potenciales ejercicios
  List<_TokenSegment> _segmentTokensIntoExercises(List<RawToken> tokens) {
    final segments = <_TokenSegment>[];
    var currentSegment = <RawToken>[];

    for (final token in tokens) {
      // Un patrón setRep generalmente marca el fin de un ejercicio
      if (token.tokenType == RawTokenType.setRepPattern) {
        currentSegment.add(token);
        if (currentSegment.isNotEmpty) {
          segments.add(_TokenSegment(tokens: List.from(currentSegment)));
          currentSegment = [];
        }
      } else {
        currentSegment.add(token);
      }
    }

    // Añadir último segmento si tiene contenido
    if (currentSegment.isNotEmpty &&
        currentSegment.any((t) => t.tokenType == RawTokenType.word)) {
      segments.add(_TokenSegment(tokens: currentSegment));
    }

    return segments;
  }

  /// Aplica restricciones según el contexto de uso
  ///
  /// RESTRICCIONES DE CONTEXTO:
  ///
  /// En entrenamiento activo:
  /// - Solo actuar sobre ejercicio actual o siguiente
  /// - Nunca detectar rutinas completas
  /// - Nunca añadir ejercicios no visibles
  ///
  /// En creación de rutinas:
  /// - Puede proponer varios ejercicios
  /// - Pero uno por uno, confirmación obligatoria
  List<_TokenSegment> _applyContextRestrictions(
    List<_TokenSegment> segments,
    InputContext context,
  ) {
    switch (context.mode) {
      case InputMode.activeWorkout:
        // Solo permitir 1 ejercicio en entrenamiento activo
        if (segments.length > 1) {
          _logger.d('Contexto activo: limitando a 1 ejercicio de ${segments.length}');
          return [segments.first];
        }
        return segments;

      case InputMode.routineCreation:
        // Permitir múltiples pero con límite razonable
        if (segments.length > context.maxExercisesAllowed) {
          _logger.d('Limitando a ${context.maxExercisesAllowed} ejercicios');
          return segments.take(context.maxExercisesAllowed).toList();
        }
        return segments;

      case InputMode.singleExerciseEdit:
        // Solo 1 ejercicio permitido
        return segments.take(1).toList();
    }
  }

  /// Crea una hipótesis fallida
  InputHypothesis _createFailedHypothesis(RawInputCapture capture, String reason) {
    return InputHypothesis(
      rawCapture: capture,
      exerciseHypothesis: ExerciseHypothesis.noMatch(''),
      seriesRepsHypothesis: SeriesRepsHypothesis.empty(),
      status: HypothesisStatus.failed,
      reviewReason: reason,
      generatedAt: DateTime.now(),
    );
  }

  // =========================================
  // VALIDACIÓN POST-SELECCIÓN
  // =========================================

  /// Valida una selección del usuario antes de confirmar
  ValidationResult validateUserSelection({
    required LibraryExercise exercise,
    required int? series,
    required String? repsRange,
    required double? weight,
  }) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validar series
    if (series == null) {
      errors.add('Debe especificar el número de series');
    } else if (series < 1 || series > 20) {
      errors.add('Series debe estar entre 1 y 20');
    }

    // Validar reps
    if (repsRange == null || repsRange.isEmpty) {
      errors.add('Debe especificar las repeticiones');
    } else {
      final parts = repsRange.split('-');
      final minReps = int.tryParse(parts.first);
      final maxReps = parts.length > 1 ? int.tryParse(parts.last) : minReps;

      if (minReps == null) {
        errors.add('Formato de repeticiones inválido');
      } else if (minReps < 1 || minReps > 100) {
        errors.add('Repeticiones debe estar entre 1 y 100');
      }
      if (maxReps != null && maxReps < (minReps ?? 0)) {
        errors.add('Rango de reps inválido (máximo < mínimo)');
      }
    }

    // Validar peso (opcional pero si existe, debe ser razonable)
    if (weight != null) {
      if (weight < 0) {
        errors.add('El peso no puede ser negativo');
      } else if (weight > 500) {
        warnings.add('Peso muy alto (${weight}kg), ¿es correcto?');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}

/// Contexto de entrada para restricciones
class InputContext {
  /// Modo de entrada actual
  final InputMode mode;

  /// Máximo de ejercicios permitidos en este contexto
  final int maxExercisesAllowed;

  /// ID del ejercicio actualmente enfocado (si aplica)
  final String? currentExerciseId;

  /// IDs de ejercicios visibles en la UI actual
  final List<String> visibleExerciseIds;

  const InputContext({
    required this.mode,
    this.maxExercisesAllowed = 10,
    this.currentExerciseId,
    this.visibleExerciseIds = const [],
  });

  /// Contexto para entrenamiento activo (muy restrictivo)
  factory InputContext.activeWorkout({
    required String currentExerciseId,
    String? nextExerciseId,
  }) {
    return InputContext(
      mode: InputMode.activeWorkout,
      maxExercisesAllowed: 1,
      currentExerciseId: currentExerciseId,
      visibleExerciseIds: [
        currentExerciseId,
        if (nextExerciseId != null) nextExerciseId,
      ],
    );
  }

  /// Contexto para creación de rutina (más permisivo)
  factory InputContext.routineCreation({int maxExercises = 10}) {
    return InputContext(
      mode: InputMode.routineCreation,
      maxExercisesAllowed: maxExercises,
    );
  }

  /// Contexto para editar un solo ejercicio
  factory InputContext.singleEdit({required String exerciseId}) {
    return InputContext(
      mode: InputMode.singleExerciseEdit,
      maxExercisesAllowed: 1,
      currentExerciseId: exerciseId,
      visibleExerciseIds: [exerciseId],
    );
  }
}

/// Modo de entrada
enum InputMode {
  /// Durante entrenamiento activo (muy restrictivo)
  activeWorkout,

  /// Creando/editando una rutina
  routineCreation,

  /// Editando un solo ejercicio
  singleExerciseEdit,
}

/// Resultado de validación
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
}

/// Segmento de tokens que representa un potencial ejercicio
class _TokenSegment {
  final List<RawToken> tokens;

  const _TokenSegment({required this.tokens});

  String get text => tokens.map((t) => t.text).join(' ');
}
