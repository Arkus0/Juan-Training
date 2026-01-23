import '../models/progression_type.dart';
import '../models/progression_engine_models.dart';
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
      ProgressionType.rpe => 
        _calculateRpeProgression(context, sessionResult),
      ProgressionType.none => 
        ProgressionDecision.maintain(
          weight: context.confirmedWeight,
          reps: context.targetReps,
        ),
    };
  }

  /// Doble progresión con confirmación de 2 sesiones
  /// 
  /// Lógica:
  /// 1. Subir reps hasta el máximo del rango
  /// 2. Cuando alcanza max reps en 2 sesiones consecutivas → subir peso
  /// 3. Al subir peso, volver al mínimo de reps
  ProgressionDecision _calculateDoubleProgression(
    ExerciseProgressionContext context,
    SessionResult lastResult,
  ) {
    final (minReps, maxReps) = context.repsRange;
    final lastSession = context.lastSession!;
    final avgReps = lastSession.averageReps;
    final increment = context.category.getIncrement(context.confirmedWeight);
    
    // ══════════════════════════════════════════════════════════════════════
    // CASO 1: Sesión COMPLETA (100%) con reps máximas
    // ══════════════════════════════════════════════════════════════════════
    if (lastResult == SessionResult.complete && avgReps >= maxReps) {
      // ¿Es la 2da sesión exitosa consecutiva en max reps?
      if (context.consecutiveSuccesses >= 1 && _previousWasAtMaxReps(context, maxReps)) {
        // ✅ CONFIRMAR SUBIDA: 2 sesiones exitosas
        final newWeight = context.confirmedWeight + increment;
        return ProgressionDecision(
          action: ProgressionAction.increaseWeight,
          suggestedWeight: newWeight,
          suggestedReps: minReps,
          reason: '2 sesiones exitosas a $maxReps reps',
          userMessage: '¡Sube a ${_formatWeight(newWeight)}kg! Empieza con $minReps reps.',
          confidence: ProgressionConfidence.high,
          isImprovement: true,
          nextStepPreview: 'Siguiente: ${_formatWeight(newWeight)}kg × ${minReps + 1} reps',
        );
      } else {
        // Esperando confirmación (1ra sesión exitosa)
        return ProgressionDecision(
          action: ProgressionAction.maintain,
          suggestedWeight: context.confirmedWeight,
          suggestedReps: maxReps,
          reason: 'Confirmando progreso (1/2)',
          userMessage: 'Repite ${_formatWeight(context.confirmedWeight)}kg × $maxReps. Si lo logras, subirás peso.',
          confidence: ProgressionConfidence.medium,
          nextStepPreview: 'Si éxito: ${_formatWeight(context.confirmedWeight + increment)}kg × $minReps',
        );
      }
    }
    
    // ══════════════════════════════════════════════════════════════════════
    // CASO 2: Sesión COMPLETA pero no en reps máximas → subir reps
    // ══════════════════════════════════════════════════════════════════════
    if (lastResult == SessionResult.complete) {
      final nextReps = (avgReps + 1).clamp(minReps, maxReps).toInt();
      return ProgressionDecision(
        action: ProgressionAction.increaseReps,
        suggestedWeight: context.confirmedWeight,
        suggestedReps: nextReps,
        reason: 'Progresando en reps',
        userMessage: 'Intenta $nextReps reps hoy.',
        confidence: ProgressionConfidence.high,
        isImprovement: true,
        nextStepPreview: nextReps >= maxReps 
            ? 'Próximo hito: confirmar para subir peso'
            : 'Siguiente: ${nextReps + 1} reps',
      );
    }
    
    // ══════════════════════════════════════════════════════════════════════
    // CASO 3: Sesión ACEPTABLE (80%+) → repetir
    // ══════════════════════════════════════════════════════════════════════
    if (lastResult == SessionResult.acceptable) {
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: context.confirmedWeight,
        suggestedReps: context.targetReps,
        reason: 'Casi conseguido, repetir',
        userMessage: 'Repite ${context.targetReps} reps. Estás cerca.',
        confidence: ProgressionConfidence.medium,
      );
    }
    
    // ══════════════════════════════════════════════════════════════════════
    // CASO 4: Sesión PARCIAL o FALLIDA
    // ══════════════════════════════════════════════════════════════════════
    if (lastResult == SessionResult.partial || lastResult == SessionResult.failed) {
      // ¿Es un patrón? (2+ sesiones consecutivas malas)
      if (context.consecutiveFailures >= 2) {
        // Sugerir bajar peso
        final newWeight = (context.confirmedWeight - increment).clamp(0.0, double.infinity);
        return ProgressionDecision(
          action: ProgressionAction.decreaseWeight,
          suggestedWeight: newWeight,
          suggestedReps: maxReps,
          reason: '2 sesiones difíciles consecutivas',
          userMessage: 'Bajamos a ${_formatWeight(newWeight)}kg para consolidar. Es parte del proceso.',
          confidence: ProgressionConfidence.high,
          isImprovement: false,
          nextStepPreview: 'Objetivo: ${_formatWeight(newWeight)}kg × $maxReps → volver a subir',
        );
      }
      
      // Primera sesión difícil → NO castigar, mantener
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: context.confirmedWeight,
        suggestedReps: context.targetReps,
        reason: 'Día difícil, mantener',
        userMessage: 'Repite el objetivo. Un día malo no cambia nada.',
        confidence: ProgressionConfidence.medium,
      );
    }
    
    // Default: mantener
    return ProgressionDecision.maintain(
      weight: context.confirmedWeight,
      reps: context.targetReps,
    );
  }

  /// Progresión lineal: subir peso cada sesión exitosa (con confirmación)
  ProgressionDecision _calculateLinearProgression(
    ExerciseProgressionContext context,
    SessionResult lastResult,
  ) {
    final increment = context.category.getIncrement(context.confirmedWeight);
    
    // Sesión completa o aceptable
    if (lastResult == SessionResult.complete || lastResult == SessionResult.acceptable) {
      // ¿Confirmación de 2 sesiones?
      if (context.consecutiveSuccesses >= 1) {
        final newWeight = context.confirmedWeight + increment;
        return ProgressionDecision(
          action: ProgressionAction.increaseWeight,
          suggestedWeight: newWeight,
          suggestedReps: context.targetReps,
          reason: '2 sesiones exitosas',
          userMessage: '¡Sube a ${_formatWeight(newWeight)}kg!',
          confidence: ProgressionConfidence.high,
          isImprovement: true,
        );
      } else {
        return ProgressionDecision(
          action: ProgressionAction.maintain,
          suggestedWeight: context.confirmedWeight,
          suggestedReps: context.targetReps,
          reason: 'Confirmando (1/2)',
          userMessage: 'Repite para confirmar. Éxito = subir peso.',
          confidence: ProgressionConfidence.medium,
        );
      }
    }
    
    // Sesión difícil
    if (context.consecutiveFailures >= 2) {
      final newWeight = (context.confirmedWeight - increment).clamp(0.0, double.infinity);
      return ProgressionDecision(
        action: ProgressionAction.decreaseWeight,
        suggestedWeight: newWeight,
        suggestedReps: context.targetReps,
        reason: 'Estancamiento detectado',
        userMessage: 'Bajamos a ${_formatWeight(newWeight)}kg para consolidar.',
        confidence: ProgressionConfidence.high,
      );
    }
    
    return ProgressionDecision.maintain(
      weight: context.confirmedWeight,
      reps: context.targetReps,
      userMessage: 'Repite el objetivo.',
    );
  }

  /// Progresión basada en RPE
  ProgressionDecision _calculateRpeProgression(
    ExerciseProgressionContext context,
    SessionResult lastResult,
  ) {
    final lastSession = context.lastSession!;
    final avgRpe = lastSession.averageRpe;
    final increment = context.category.getIncrement(context.confirmedWeight);
    
    // Sin datos de RPE
    if (avgRpe == null) {
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: context.confirmedWeight,
        suggestedReps: context.targetReps,
        reason: 'Sin datos RPE',
        userMessage: 'Registra RPE para sugerencias automáticas.',
        confidence: ProgressionConfidence.low,
      );
    }
    
    // RPE muy bajo (< 7) → subir peso
    if (avgRpe < 7) {
      return ProgressionDecision(
        action: ProgressionAction.increaseWeight,
        suggestedWeight: context.confirmedWeight + increment,
        suggestedReps: context.targetReps,
        reason: 'RPE ${avgRpe.toStringAsFixed(1)} < 7',
        userMessage: 'RPE bajo. Sube ${_formatWeight(increment)}kg.',
        confidence: ProgressionConfidence.high,
        isImprovement: true,
      );
    }
    
    // RPE en rango (7-9) → mantener
    if (avgRpe >= 7 && avgRpe <= 9) {
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: context.confirmedWeight,
        suggestedReps: context.targetReps,
        reason: 'RPE ${avgRpe.toStringAsFixed(1)} en rango',
        userMessage: 'RPE ${avgRpe.toStringAsFixed(1)} perfecto. Mantén.',
        confidence: ProgressionConfidence.high,
      );
    }
    
    // RPE muy alto (> 9) → considerar bajar
    if (avgRpe > 9) {
      // Solo bajar si es consistente
      if (context.consecutiveFailures >= 1) {
        return ProgressionDecision(
          action: ProgressionAction.decreaseWeight,
          suggestedWeight: (context.confirmedWeight - increment).clamp(0.0, double.infinity),
          suggestedReps: context.targetReps,
          reason: 'RPE ${avgRpe.toStringAsFixed(1)} > 9 consistente',
          userMessage: 'RPE muy alto. Baja ${_formatWeight(increment)}kg.',
          confidence: ProgressionConfidence.high,
        );
      }
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: context.confirmedWeight,
        suggestedReps: context.targetReps,
        reason: 'RPE ${avgRpe.toStringAsFixed(1)} alto (1 sesión)',
        userMessage: 'RPE alto. Repite para evaluar.',
        confidence: ProgressionConfidence.medium,
      );
    }
    
    return ProgressionDecision.maintain(
      weight: context.confirmedWeight,
      reps: context.targetReps,
    );
  }

  /// Verifica si la sesión anterior también estaba en max reps
  bool _previousWasAtMaxReps(ExerciseProgressionContext context, int maxReps) {
    if (context.recentSessions.length < 2) return false;
    final prevSession = context.recentSessions[1];
    return prevSession.averageReps >= maxReps;
  }

  /// Formatea peso para display (sin decimales innecesarios)
  String _formatWeight(double weight) {
    if (weight == weight.roundToDouble()) {
      return weight.toInt().toString();
    }
    return weight.toStringAsFixed(1);
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
    final completedSets = previousLogs.where((l) => l.completed && l.reps >= targetReps).length;
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
    final SerieLog? prevLog = setIndex < previousLogs.length ? previousLogs[setIndex] : null;
    if (prevLog == null) return null;
    
    // Construir contexto simplificado
    final context = ExerciseProgressionContext(
      exerciseId: '',
      exerciseName: exerciseName ?? '',
      state: ProgressionState.progressing,
      recentSessions: [
        SessionSummary(
          date: DateTime.now().subtract(const Duration(days: 7)),
          sets: previousLogs.map((l) => SetSummary(
            weight: l.peso,
            reps: l.reps,
            targetReps: targetReps,
            completed: l.completed,
            rpe: l.rpe,
          )).toList(),
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
