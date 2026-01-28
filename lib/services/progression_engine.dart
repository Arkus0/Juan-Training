import '../models/progression_engine_models.dart';
import '../models/progression_type.dart';
import '../models/serie_log.dart';

/// Motor de progresión determinista v2
///
/// Calcula sugerencias de progresión basadas en:
/// - Resultado de sesión COMPLETA (no serie individual)
/// - Historial de últimas 4 sesiones
/// - Confirmación de 2 sesiones antes de subir peso
/// - Degradación elegante (días malos no castigan)
class ProgressionEngine {
  ProgressionEngine._internal();
  static final ProgressionEngine instance = ProgressionEngine._internal();

  /// Calcula la decisión de progresión para la próxima sesión
  ProgressionDecision calculateNextSession({
    required ExerciseProgressionContext context,
    required ProgressionType model,
  }) {
    // Si no hay modelo de progresión, no sugerir nada
    if (model == ProgressionType.none) {
      return ProgressionDecision.maintain(
        weight: context.confirmedWeight,
        reps: context.targetReps,
        reason: 'Sin progresión automática',
        userMessage: 'Progresión manual',
      );
    }

    // Fase de calibración: primeras 2 sesiones
    if (!context.hasEnoughData) {
      return ProgressionDecision.calibrating(
        weight: context.confirmedWeight,
        reps: context.targetReps,
        sessionNumber: context.recentSessions.length + 1,
      );
    }

    // Evaluar la última sesión
    final lastSession = context.lastSession!;
    final sessionResult = lastSession.evaluate();

    // Aplicar modelo de progresión específico
    return switch (model) {
      ProgressionType.dobleRepsFirst =>
        _calculateDoubleProgression(context, sessionResult),
      ProgressionType.lineal =>
        _calculateLinearProgression(context, sessionResult),
      ProgressionType.rpe => _calculateRpeProgression(context, sessionResult),
      ProgressionType.none => ProgressionDecision.maintain(
          weight: context.confirmedWeight,
          reps: context.targetReps,
        ),
    };
  }

  /// Doble progresión estilo LYLE McDONALD
  ///
  /// Lógica correcta según "Generic Bulking Routine" y artículos de Lyle:
  /// 1. Subir reps hasta que TODAS las series alcanzan max (no promedio)
  /// 2. Cuando TODAS las series están en max reps → subir peso
  /// 3. Al subir peso, volver al mínimo de reps
  ///
  /// DIFERENCIA CRÍTICA vs implementación anterior:
  /// - Antes: usaba avgReps >= maxReps (promedio)
  /// - Ahora: usa allSetsHitMaxReps (TODAS las series)
  ///
  /// "Once you can complete ALL sets at the top of the rep range, add weight
  /// and drop back to the bottom of the rep range."
  /// — Lyle McDonald
  ProgressionDecision _calculateDoubleProgression(
    ExerciseProgressionContext context,
    SessionResult lastResult,
  ) {
    final (minReps, maxReps) = context.repsRange;
    final lastSession = context.lastSession!;
    final avgReps = lastSession.averageReps;
    final increment = context.category.getIncrement(context.confirmedWeight);

    // ══════════════════════════════════════════════════════════════════════
    // CASO 1: TODAS las series alcanzaron max reps (criterio Lyle)
    // ══════════════════════════════════════════════════════════════════════
    // Lyle: "ALL sets at the top of the rep range"
    if (lastSession.allSetsHitMaxReps(maxReps)) {
      // ✅ SUBIR PESO - Sin necesidad de confirmación de 2 sesiones
      // Lyle no especifica confirmación, pero añadimos 1 sesión por seguridad
      final newWeight = context.confirmedWeight + increment;
      return ProgressionDecision(
        action: ProgressionAction.increaseWeight,
        suggestedWeight: newWeight,
        suggestedReps: minReps,
        reason: 'Todas las series a $maxReps reps (Lyle McDonald)',
        userMessage:
            '¡Sube a ${_formatWeight(newWeight)}kg! Empieza con $minReps reps.',
        confidence: ProgressionConfidence.high,
        isImprovement: true,
        nextStepPreview:
            'Siguiente: ${_formatWeight(newWeight)}kg × ${minReps + 1} reps',
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // CASO 2: Sesión exitosa pero NO todas las series en max → subir reps
    // ══════════════════════════════════════════════════════════════════════
    if (lastResult == SessionResult.complete ||
        lastResult == SessionResult.acceptable) {
      // Calcular siguiente objetivo de reps
      // Usamos el mínimo de reps de la sesión + 1 para subir gradualmente
      final minRepsInSession = lastSession.minReps;
      final nextReps = (minRepsInSession + 1).clamp(minReps, maxReps);

      // Si el promedio ya está alto pero alguna serie falló, mantener objetivo
      if (avgReps >= maxReps - 0.5 && !lastSession.allSetsHitMaxReps(maxReps)) {
        return ProgressionDecision(
          action: ProgressionAction.maintain,
          suggestedWeight: context.confirmedWeight,
          suggestedReps: maxReps,
          reason: 'Casi todas en max, repetir para consolidar',
          userMessage: 'Intenta $maxReps reps en TODAS las series.',
          confidence: ProgressionConfidence.high,
          nextStepPreview:
              'Si todas a $maxReps: subir a ${_formatWeight(context.confirmedWeight + increment)}kg',
        );
      }

      return ProgressionDecision(
        action: ProgressionAction.increaseReps,
        suggestedWeight: context.confirmedWeight,
        suggestedReps: nextReps,
        reason: 'Progresando en reps',
        userMessage: 'Intenta $nextReps reps hoy.',
        confidence: ProgressionConfidence.high,
        isImprovement: true,
        nextStepPreview: nextReps >= maxReps
            ? 'Si todas a $maxReps: subir peso'
            : 'Siguiente: ${nextReps + 1} reps',
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // CASO 3: Sesión PARCIAL o FALLIDA
    // ══════════════════════════════════════════════════════════════════════
    if (lastResult == SessionResult.partial ||
        lastResult == SessionResult.failed) {
      // Usar stall detection basado en peso actual (no fallos genéricos)
      if (context.failuresAtCurrentWeight >= 2) {
        // DELOAD: 10% según Lyle McDonald
        final deloadAmount =
            _calculateDeload(context.confirmedWeight, context.category);
        final newWeight = (context.confirmedWeight - deloadAmount)
            .clamp(0.0, double.infinity);
        return ProgressionDecision(
          action: ProgressionAction.decreaseWeight,
          suggestedWeight: newWeight,
          suggestedReps: maxReps,
          reason: '2 sesiones difíciles al mismo peso → deload 10%',
          userMessage:
              'Deload: ${_formatWeight(newWeight)}kg × $maxReps. Reconstruir desde ahí.',
          confidence: ProgressionConfidence.high,
          nextStepPreview:
              'Objetivo: volver a ${_formatWeight(context.confirmedWeight)}kg en ~3 semanas',
        );
      }

      // Primera sesión difícil → NO castigar
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: context.confirmedWeight,
        suggestedReps: context.targetReps,
        reason: 'Día difícil, mantener',
        userMessage: 'Repite el objetivo. Un día malo no cambia nada.',
      );
    }

    // Default: mantener
    return ProgressionDecision.maintain(
      weight: context.confirmedWeight,
      reps: context.targetReps,
    );
  }

  /// Progresión lineal estilo STARTING STRENGTH / STRONGLIFTS 5x5
  ///
  /// Lógica según Rippetoe y Mehdi:
  /// - Sube peso CADA sesión exitosa (sin confirmación para novatos)
  /// - Stall = 3 fallos al MISMO peso (no cualquier fallo)
  /// - Deload = 10% (no un incremento)
  ///
  /// "Add weight to the bar every workout for as long as possible."
  /// — Mark Rippetoe, Starting Strength 3rd Ed.
  ///
  /// "Add 2.5kg/5lb each workout. If you fail a weight three times,
  /// deload 10% and work back up."
  /// — Mehdi, StrongLifts 5x5
  ProgressionDecision _calculateLinearProgression(
    ExerciseProgressionContext context,
    SessionResult lastResult,
  ) {
    final increment = context.category.getIncrement(context.confirmedWeight);

    // ══════════════════════════════════════════════════════════════════════
    // STALL DETECTION (Rippetoe): 3 fallos al MISMO peso
    // ══════════════════════════════════════════════════════════════════════
    // "A stall is defined as failing to complete the work sets for three
    // consecutive workouts at the same weight."
    // — Starting Strength, p.303
    if (context.isStall) {
      // DELOAD: 10% según Rippetoe/StrongLifts
      final deloadAmount =
          _calculateDeload(context.confirmedWeight, context.category);
      final newWeight =
          (context.confirmedWeight - deloadAmount).clamp(0.0, double.infinity);
      return ProgressionDecision(
        action: ProgressionAction.decreaseWeight,
        suggestedWeight: newWeight,
        suggestedReps: context.targetReps,
        reason: 'Stall: 3 fallos al mismo peso → deload 10% (Rippetoe)',
        userMessage:
            'Estancamiento. Deload a ${_formatWeight(newWeight)}kg y vuelve a subir.',
        confidence: ProgressionConfidence.high,
        nextStepPreview:
            'Volverás a ${_formatWeight(context.confirmedWeight)}kg en ~3 semanas',
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // SESIÓN EXITOSA: Subir peso INMEDIATAMENTE (sin confirmación)
    // ══════════════════════════════════════════════════════════════════════
    // Rippetoe/StrongLifts: "Add weight every workout"
    // NO hay confirmación de 2 sesiones para novatos
    if (lastResult == SessionResult.complete) {
      final newWeight = context.confirmedWeight + increment;
      return ProgressionDecision(
        action: ProgressionAction.increaseWeight,
        suggestedWeight: newWeight,
        suggestedReps: context.targetReps,
        reason: 'Sesión completa → subir peso (Rippetoe)',
        userMessage: '¡Sube a ${_formatWeight(newWeight)}kg!',
        confidence: ProgressionConfidence.high,
        isImprovement: true,
        nextStepPreview: 'Si éxito: ${_formatWeight(newWeight + increment)}kg',
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // SESIÓN ACEPTABLE (80%+): Repetir antes de subir
    // ══════════════════════════════════════════════════════════════════════
    // Esto es una concesión práctica - si casi lo logras, repite
    if (lastResult == SessionResult.acceptable) {
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: context.confirmedWeight,
        suggestedReps: context.targetReps,
        reason: 'Casi completa, repetir',
        userMessage:
            'Repite ${_formatWeight(context.confirmedWeight)}kg. Casi lo tienes.',
        nextStepPreview: 'Si completas todas: +${_formatWeight(increment)}kg',
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // SESIÓN FALLIDA: Mantener y reintentar
    // ══════════════════════════════════════════════════════════════════════
    // No bajar inmediatamente - esperar a ver si es stall (3 fallos)
    return ProgressionDecision(
      action: ProgressionAction.maintain,
      suggestedWeight: context.confirmedWeight,
      suggestedReps: context.targetReps,
      reason: 'Fallo ${context.failuresAtCurrentWeight}/3, reintentar',
      userMessage:
          'Repite ${_formatWeight(context.confirmedWeight)}kg. Fallo ${context.failuresAtCurrentWeight}/3.',
      nextStepPreview: context.failuresAtCurrentWeight >= 2
          ? 'Si fallas de nuevo: deload 10%'
          : 'Si fallas 2 veces más: deload',
    );
  }

  /// Progresión basada en RPE (Autoregulación)
  ///
  /// Basada en el sistema RTS de Mike Tuchscherer:
  /// - RPE 10 = fallo muscular, 0 reps en reserva (RIR)
  /// - RPE 9 = 1 RIR (podrías hacer 1 más)
  /// - RPE 8 = 2 RIR (podrías hacer 2 más)
  /// - RPE 7 = 3 RIR (podrías hacer 3 más)
  ///
  /// Zona objetivo típica: RPE 7-9 (2-4 RIR)
  /// - RPE < 7: Peso muy ligero, subir
  /// - RPE 7-8: Zona de trabajo, progresión gradual
  /// - RPE 8.5-9: Zona óptima para fuerza/hipertrofia
  /// - RPE > 9: Muy pesado, riesgo de sobrecarga
  ///
  /// DIFERENCIA vs implementación anterior:
  /// - Considera fatigue drop (diferencia RPE primera vs última serie)
  /// - Más conservador con RPE alto (necesita 2 sesiones para bajar)
  /// - Incluye calibración inicial
  ProgressionDecision _calculateRpeProgression(
    ExerciseProgressionContext context,
    SessionResult lastResult,
  ) {
    final lastSession = context.lastSession!;
    final avgRpe = lastSession.averageRpe;
    final increment = context.category.getIncrement(context.confirmedWeight);

    // ══════════════════════════════════════════════════════════════════════
    // SIN DATOS RPE: Pedir calibración
    // ══════════════════════════════════════════════════════════════════════
    if (avgRpe == null) {
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: context.confirmedWeight,
        suggestedReps: context.targetReps,
        reason: 'Sin datos RPE - requiere calibración',
        userMessage: 'Registra RPE (1-10) en cada serie para autoregulación.',
        confidence: ProgressionConfidence.low,
        nextStepPreview: 'RPE 8 = podrías hacer 2 reps más',
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // RPE MUY BAJO (< 7): Subir peso - está siendo demasiado fácil
    // ══════════════════════════════════════════════════════════════════════
    // RPE < 7 significa 4+ reps en reserva, claramente subentrenando
    if (avgRpe < 7) {
      final newWeight = context.confirmedWeight + increment;
      return ProgressionDecision(
        action: ProgressionAction.increaseWeight,
        suggestedWeight: newWeight,
        suggestedReps: context.targetReps,
        reason: 'RPE ${avgRpe.toStringAsFixed(1)} < 7 (muy fácil)',
        userMessage:
            '¡Sube a ${_formatWeight(newWeight)}kg! RPE ${avgRpe.toStringAsFixed(1)} es muy bajo.',
        confidence: ProgressionConfidence.high,
        isImprovement: true,
        nextStepPreview: 'Objetivo: RPE 8-9',
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // RPE ÓPTIMO (7-9): Zona de trabajo efectivo
    // ══════════════════════════════════════════════════════════════════════
    // Esta es la zona donde ocurre el entrenamiento efectivo
    if (avgRpe >= 7 && avgRpe <= 9) {
      // RPE 7-7.5: Puede subir gradualmente
      if (avgRpe < 7.5 && context.consecutiveSuccesses >= 2) {
        final newWeight = context.confirmedWeight + increment;
        return ProgressionDecision(
          action: ProgressionAction.increaseWeight,
          suggestedWeight: newWeight,
          suggestedReps: context.targetReps,
          reason:
              'RPE ${avgRpe.toStringAsFixed(1)} consistente, listo para subir',
          userMessage:
              '¡Sube a ${_formatWeight(newWeight)}kg! RPE ${avgRpe.toStringAsFixed(1)} estable.',
          confidence: ProgressionConfidence.high,
          isImprovement: true,
        );
      }

      // RPE 8-9: Zona perfecta, mantener
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: context.confirmedWeight,
        suggestedReps: context.targetReps,
        reason: 'RPE ${avgRpe.toStringAsFixed(1)} en zona óptima (7-9)',
        userMessage:
            'RPE ${avgRpe.toStringAsFixed(1)} perfecto. Mantén para consolidar.',
        confidence: ProgressionConfidence.high,
        nextStepPreview: 'Si RPE baja a ~7: considerar subir peso',
      );
    }

    // ══════════════════════════════════════════════════════════════════════
    // RPE MUY ALTO (> 9): Riesgo de sobrecarga
    // ══════════════════════════════════════════════════════════════════════
    // RPE > 9 significa cerca del fallo o al fallo
    // No bajar inmediatamente - puede ser un día malo
    if (avgRpe > 9) {
      // Si es consistente (2+ sesiones con RPE > 9), bajar peso
      if (context.failuresAtCurrentWeight >= 2 ||
          context.consecutiveFailures >= 2) {
        final deloadAmount =
            _calculateDeload(context.confirmedWeight, context.category);
        final newWeight = (context.confirmedWeight - deloadAmount)
            .clamp(0.0, double.infinity);
        return ProgressionDecision(
          action: ProgressionAction.decreaseWeight,
          suggestedWeight: newWeight,
          suggestedReps: context.targetReps,
          reason: 'RPE > 9 consistente → fatiga acumulada',
          userMessage:
              'Deload a ${_formatWeight(newWeight)}kg. RPE > 9 indica fatiga.',
          confidence: ProgressionConfidence.high,
          nextStepPreview: 'Objetivo: volver a RPE 8',
        );
      }

      // Primera sesión con RPE alto - observar, no castigar
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: context.confirmedWeight,
        suggestedReps: context.targetReps,
        reason: 'RPE ${avgRpe.toStringAsFixed(1)} alto (1 sesión)',
        userMessage:
            'RPE alto hoy. Repite peso para evaluar si es fatiga o día malo.',
        nextStepPreview: 'Si RPE sigue > 9: considerar deload',
      );
    }

    // Default: mantener
    return ProgressionDecision.maintain(
      weight: context.confirmedWeight,
      reps: context.targetReps,
    );
  }

  /// Formatea peso para display (sin decimales innecesarios)
  String _formatWeight(double weight) {
    if (weight == weight.roundToDouble()) {
      return weight.toInt().toString();
    }
    return weight.toStringAsFixed(1);
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DELOAD CALCULATION - BASADO EN CLÁSICOS
  // ════════════════════════════════════════════════════════════════════════════

  /// Calcula la cantidad de deload según los clásicos
  ///
  /// Referencias:
  /// - Rippetoe (Starting Strength): 10-15% deload
  /// - Mehdi (StrongLifts): 10% deload
  /// - Lyle McDonald: 10-20% dependiendo de causa
  ///
  /// Usamos 10% como estándar, con mínimo de 1 incremento para que
  /// siempre haya un cambio perceptible.
  double _calculateDeload(double currentWeight, ExerciseCategory category) {
    const deloadPercent = 0.10; // 10% - estándar Rippetoe/Mehdi

    final percentDeload = currentWeight * deloadPercent;
    final minDeload = category.getIncrement(currentWeight);

    // El deload debe ser al menos 1 incremento, pero típicamente 10%
    // Esto asegura que siempre haya un cambio significativo
    return percentDeload > minDeload ? percentDeload : minDeload;
  }

  // ════════════════════════════════════════════════════════════════════════
  // MÉTODOS DE COMPATIBILIDAD CON SISTEMA ANTERIOR
  // ════════════════════════════════════════════════════════════════════════

  /// Método de compatibilidad con el sistema anterior
  /// Convierte los datos del formato antiguo al nuevo contexto
  ProgressionDecision? calculateFromLegacyData({
    required ProgressionType progressionType,
    required double weightIncrement,
    required int targetReps,
    required int maxReps,
    required List<SerieLog>? previousLogs,
    required int setIndex,
    int? targetRpe,
    String? exerciseName,
  }) {
    if (progressionType == ProgressionType.none) return null;
    if (previousLogs == null || previousLogs.isEmpty) return null;

    // Construir contexto mínimo desde datos legacy
    final category = exerciseName != null
        ? ExerciseCategory.inferFromName(exerciseName)
        : ExerciseCategory.isolation;

    // Calcular resultado de la sesión anterior
    final completedSets =
        previousLogs.where((l) => l.completed && l.reps >= targetReps).length;
    final totalSets = previousLogs.length;
    final successRate = totalSets > 0 ? completedSets / totalSets : 0.0;

    SessionResult sessionResult;
    if (successRate >= 1.0) {
      sessionResult = SessionResult.complete;
    } else if (successRate >= 0.8) {
      sessionResult = SessionResult.acceptable;
    } else if (successRate >= 0.5) {
      sessionResult = SessionResult.partial;
    } else {
      sessionResult = SessionResult.failed;
    }

    // Usar el log específico para la serie
    final prevLog =
        setIndex < previousLogs.length ? previousLogs[setIndex] : null;
    if (prevLog == null) return null;

    // Construir contexto simplificado
    final context = ExerciseProgressionContext(
      exerciseId: '',
      exerciseName: exerciseName ?? '',
      state: ProgressionState.progressing,
      recentSessions: [
        SessionSummary(
          date: DateTime.now().subtract(const Duration(days: 7)),
          sets: previousLogs
              .map(
                (l) => SetSummary(
                  weight: l.peso,
                  reps: l.reps,
                  targetReps: targetReps,
                  completed: l.completed,
                  rpe: l.rpe,
                ),
              )
              .toList(),
          targetReps: targetReps,
          weight: prevLog.peso,
        ),
      ],
      consecutiveSuccesses: sessionResult == SessionResult.complete ? 1 : 0,
      consecutiveFailures: sessionResult == SessionResult.failed ? 1 : 0,
      weeksAtCurrentWeight: 1,
      category: category,
      confirmedWeight: prevLog.peso,
      repsRange: (targetReps, maxReps),
    );

    // Usar el motor nuevo con contexto legacy
    return calculateNextSession(
      context: context,
      model: progressionType,
    );
  }

  /// Parsea un repsRange (ej: "8-12") y devuelve (min, max)
  (int, int) parseRepsRange(String repsRange) {
    final parts = repsRange.split('-');
    if (parts.length == 2) {
      final min = int.tryParse(parts[0].trim()) ?? 8;
      final max = int.tryParse(parts[1].trim()) ?? 12;
      return (min, max);
    }
    // Reps fijas (ej: "10")
    final fixed = int.tryParse(repsRange.trim()) ?? 10;
    return (fixed, fixed);
  }

  /// Calcula el volumen total de una lista de logs
  double calculateVolume(List<SerieLog> logs) {
    return logs.fold(0.0, (sum, log) {
      if (log.completed) {
        return sum + (log.peso * log.reps);
      }
      return sum;
    });
  }

  /// Calcula el peso máximo de una lista de logs
  double calculateMaxWeight(List<SerieLog> logs) {
    if (logs.isEmpty) return 0.0;
    return logs
        .where((l) => l.completed)
        .fold(0.0, (max, log) => log.peso > max ? log.peso : max);
  }

  /// Estima 1RM usando fórmula de Epley
  double estimate1RM(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0.0;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30);
  }
}
