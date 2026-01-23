import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progression_type.dart';
import '../models/progression_engine_models.dart';
import '../models/serie_log.dart';
import '../models/ejercicio.dart';
import '../models/sesion.dart';
import '../services/progression_engine.dart';
import '../widgets/session/progression_preview.dart';
import 'training_provider.dart';

/// Provider que calcula las decisiones de progresión para cada ejercicio
/// de la sesión actual usando el nuevo motor v2.
/// 
/// Beneficios:
/// - Análisis de sesión completa (no serie individual)
/// - Confirmación de 2 sesiones antes de subir peso
/// - Mensajes descriptivos para el usuario
/// - Incrementos inteligentes según tipo de ejercicio
final exerciseProgressionProvider = Provider.family<ProgressionDecision?, int>(
  (ref, exerciseIndex) {
    final state = ref.watch(trainingSessionProvider);
    
    if (exerciseIndex >= state.exercises.length) return null;
    
    final exercise = state.exercises[exerciseIndex];
    final historyLogs = state.history[exercise.nombre];
    
    // Sin historial, no hay sugerencia
    if (historyLogs == null || historyLogs.isEmpty) return null;
    
    // Obtener configuración de progresión del ejercicio
    // Por ahora usamos doble progresión como default
    const progressionType = ProgressionType.dobleRepsFirst;
    
    // Parsear rango de reps del ejercicio
    final repsRange = ProgressionEngine.instance.parseRepsRange(
      exercise.reps.toString(), // Simplificación, idealmente vendría del EjercicioEnRutina
    );
    
    // Construir contexto desde datos disponibles
    final context = _buildContextFromHistory(
      exercise: exercise,
      historyLogs: historyLogs,
      repsRange: repsRange,
    );
    
    // Calcular decisión usando el motor v2
    return ProgressionEngine.instance.calculateNextSession(
      context: context,
      model: progressionType,
    );
  },
);

/// Provider async que carga historial expandido y calcula progresión
/// Usa el nuevo método getExpandedHistoryForExercise para análisis completo
final expandedProgressionProvider = FutureProvider.family<ProgressionDecision?, String>(
  (ref, exerciseName) async {
    final repo = ref.watch(trainingRepositoryProvider);
    
    // Cargar últimas 4 sesiones para este ejercicio
    final sessions = await repo.getExpandedHistoryForExercise(exerciseName, limit: 4);
    
    if (sessions.isEmpty) return null;
    
    // Construir contexto expandido
    final context = _buildExpandedContext(
      exerciseName: exerciseName,
      sessions: sessions,
    );
    
    // Calcular decisión
    return ProgressionEngine.instance.calculateNextSession(
      context: context,
      model: ProgressionType.dobleRepsFirst,
    );
  },
);

/// Provider que retorna el mapa completo de decisiones para todos los ejercicios
final allProgressionDecisionsProvider = Provider<Map<int, ProgressionDecision>>((ref) {
  final state = ref.watch(trainingSessionProvider);
  final Map<int, ProgressionDecision> decisions = {};
  
  for (int i = 0; i < state.exercises.length; i++) {
    final decision = ref.watch(exerciseProgressionProvider(i));
    if (decision != null) {
      decisions[i] = decision;
    }
  }
  
  return decisions;
});

/// Provider que indica si hay mejoras disponibles en la sesión
final hasImprovementsProvider = Provider<bool>((ref) {
  final decisions = ref.watch(allProgressionDecisionsProvider);
  return decisions.values.any((d) => d.isImprovement);
});

/// Provider con resumen de progresión para la sesión
final sessionProgressionSummaryProvider = Provider<SessionProgressionSummary>((ref) {
  final decisions = ref.watch(allProgressionDecisionsProvider);
  
  int increaseWeight = 0;
  int increaseReps = 0;
  int maintain = 0;
  int decrease = 0;
  
  for (final decision in decisions.values) {
    switch (decision.action) {
      case ProgressionAction.increaseWeight:
        increaseWeight++;
        break;
      case ProgressionAction.increaseReps:
        increaseReps++;
        break;
      case ProgressionAction.maintain:
        maintain++;
        break;
      case ProgressionAction.decreaseWeight:
      case ProgressionAction.decreaseReps:
        decrease++;
        break;
    }
  }
  
  return SessionProgressionSummary(
    totalExercises: decisions.length,
    increaseWeight: increaseWeight,
    increaseReps: increaseReps,
    maintain: maintain,
    decrease: decrease,
  );
});

/// Resumen de progresión de la sesión
class SessionProgressionSummary {
  final int totalExercises;
  final int increaseWeight;
  final int increaseReps;
  final int maintain;
  final int decrease;
  
  const SessionProgressionSummary({
    required this.totalExercises,
    required this.increaseWeight,
    required this.increaseReps,
    required this.maintain,
    required this.decrease,
  });
  
  /// Número de ejercicios con mejoras (peso o reps)
  int get improvements => increaseWeight + increaseReps;
  
  /// Porcentaje de ejercicios con mejoras
  double get improvementRate => 
      totalExercises > 0 ? improvements / totalExercises : 0.0;
  
  /// Mensaje resumen para el usuario
  String get summaryMessage {
    if (totalExercises == 0) return 'Sin sugerencias de progresión';
    
    final parts = <String>[];
    if (increaseWeight > 0) parts.add('$increaseWeight ↑kg');
    if (increaseReps > 0) parts.add('$increaseReps ↑reps');
    if (maintain > 0) parts.add('$maintain mantener');
    if (decrease > 0) parts.add('$decrease consolidar');
    
    return parts.join(' • ');
  }
}

/// Construye ExerciseProgressionContext desde historial expandido (4 sesiones)
ExerciseProgressionContext _buildExpandedContext({
  required String exerciseName,
  required List<Sesion> sessions,
}) {
  // Inferir categoría del ejercicio
  final category = ExerciseCategory.inferFromName(exerciseName);
  
  // Construir SessionSummary para cada sesión
  final recentSessions = <SessionSummary>[];
  final allLogs = <SerieLog>[];
  
  for (final session in sessions) {
    // Encontrar el ejercicio en la sesión
    final exercise = session.ejerciciosCompletados
        .where((e) => e.nombre == exerciseName)
        .firstOrNull;
    
    if (exercise != null && exercise.logs.isNotEmpty) {
      allLogs.addAll(exercise.logs);
      
      final setsSummaries = exercise.logs.map((log) => SetSummary(
        weight: log.peso,
        reps: log.reps,
        targetReps: 8, // Default, idealmente vendría del ejercicio
        completed: log.completed,
        rpe: log.rpe,
      )).toList();
      
      recentSessions.add(SessionSummary(
        date: session.fecha,
        sets: setsSummaries,
        targetReps: 8,
        weight: exercise.logs.first.peso,
      ));
    }
  }
  
  if (recentSessions.isEmpty) {
    return ExerciseProgressionContext(
      exerciseId: exerciseName,
      exerciseName: exerciseName,
      state: ProgressionState.calibrating,
      recentSessions: [],
      consecutiveSuccesses: 0,
      consecutiveFailures: 0,
      weeksAtCurrentWeight: 0,
      category: category,
      confirmedWeight: 0,
      repsRange: (8, 12),
    );
  }
  
  // Calcular peso confirmado
  final confirmedWeight = _calculateConfirmedWeight(allLogs);
  
  // Calcular éxitos/fallos consecutivos
  int consecutiveSuccesses = 0;
  int consecutiveFailures = 0;
  
  for (final session in recentSessions) {
    final result = session.evaluate();
    if (result == SessionResult.complete || result == SessionResult.acceptable) {
      if (consecutiveFailures == 0) {
        consecutiveSuccesses++;
      } else {
        break; // Encontramos un cambio de patrón
      }
    } else {
      if (consecutiveSuccesses == 0) {
        consecutiveFailures++;
      } else {
        break; // Encontramos un cambio de patrón
      }
    }
  }
  
  // Determinar estado
  ProgressionState state;
  if (recentSessions.length < 2) {
    state = ProgressionState.calibrating;
  } else if (consecutiveSuccesses >= 2) {
    state = ProgressionState.confirming;
  } else if (consecutiveFailures >= 3) {
    state = ProgressionState.plateau;
  } else {
    state = ProgressionState.progressing;
  }
  
  // Calcular semanas en el peso actual
  int weeksAtCurrentWeight = 0;
  for (final session in recentSessions) {
    if (session.weight == confirmedWeight) {
      weeksAtCurrentWeight++;
    } else {
      break;
    }
  }
  
  return ExerciseProgressionContext(
    exerciseId: exerciseName,
    exerciseName: exerciseName,
    state: state,
    recentSessions: recentSessions,
    consecutiveSuccesses: consecutiveSuccesses,
    consecutiveFailures: consecutiveFailures,
    weeksAtCurrentWeight: weeksAtCurrentWeight,
    category: category,
    confirmedWeight: confirmedWeight,
    repsRange: (8, 12), // Default
  );
}

/// Construye ExerciseProgressionContext desde los datos disponibles
ExerciseProgressionContext _buildContextFromHistory({
  required Ejercicio exercise,
  required List<SerieLog> historyLogs,
  required (int, int) repsRange,
}) {
  // Inferir categoría del ejercicio
  final category = ExerciseCategory.inferFromName(exercise.nombre);
  
  // Calcular peso confirmado (peso más común en el historial)
  final confirmedWeight = _calculateConfirmedWeight(historyLogs);
  
  // Evaluar la sesión anterior
  final setsSummaries = historyLogs.map((log) => SetSummary(
    weight: log.peso,
    reps: log.reps,
    targetReps: repsRange.$1,
    completed: log.completed,
    rpe: log.rpe,
  )).toList();
  
  final lastSession = SessionSummary(
    date: DateTime.now().subtract(const Duration(days: 7)), // Aproximación
    sets: setsSummaries,
    targetReps: repsRange.$1,
    weight: confirmedWeight,
  );
  
  // Evaluar éxitos/fallos
  final sessionResult = lastSession.evaluate();
  final consecutiveSuccesses = sessionResult == SessionResult.complete ? 1 : 0;
  final consecutiveFailures = 
      (sessionResult == SessionResult.partial || sessionResult == SessionResult.failed) ? 1 : 0;
  
  return ExerciseProgressionContext(
    exerciseId: exercise.id,
    exerciseName: exercise.nombre,
    state: ProgressionState.progressing,
    recentSessions: [lastSession],
    consecutiveSuccesses: consecutiveSuccesses,
    consecutiveFailures: consecutiveFailures,
    weeksAtCurrentWeight: 1, // Por ahora simplificado
    category: category,
    confirmedWeight: confirmedWeight,
    repsRange: repsRange,
  );
}

/// Calcula el peso "confirmado" (baseline real) del historial
double _calculateConfirmedWeight(List<SerieLog> logs) {
  if (logs.isEmpty) return 0.0;
  
  // Usar el peso más frecuente (moda) como baseline
  final weightCounts = <double, int>{};
  for (final log in logs.where((l) => l.completed)) {
    weightCounts[log.peso] = (weightCounts[log.peso] ?? 0) + 1;
  }
  
  if (weightCounts.isEmpty) {
    return logs.first.peso;
  }
  
  // Encontrar el peso más frecuente
  var maxCount = 0;
  var confirmedWeight = 0.0;
  for (final entry in weightCounts.entries) {
    if (entry.value > maxCount) {
      maxCount = entry.value;
      confirmedWeight = entry.key;
    }
  }
  
  return confirmedWeight;
}

// ════════════════════════════════════════════════════════════════════════════
// EMPATHETIC FEEDBACK PROVIDERS
// ════════════════════════════════════════════════════════════════════════════

/// Resultado de análisis empático para un ejercicio
class EmpatheticFeedbackResult {
  final DifficultDayType? type;
  final String? customMessage;
  final bool shouldShow;
  
  const EmpatheticFeedbackResult({
    this.type,
    this.customMessage,
    required this.shouldShow,
  });
  
  static const hide = EmpatheticFeedbackResult(shouldShow: false);
}

/// Provider que determina si mostrar feedback empático para un ejercicio
/// 
/// Detecta:
/// - Deload/disminución de peso → mostrar mensaje de apoyo
/// - Series fallidas consecutivas en la sesión actual
/// - Plateau prolongado
final exerciseEmpatheticFeedbackProvider = Provider.family<EmpatheticFeedbackResult, int>(
  (ref, exerciseIndex) {
    final state = ref.watch(trainingSessionProvider);
    
    if (exerciseIndex >= state.exercises.length) {
      return EmpatheticFeedbackResult.hide;
    }
    
    final exercise = state.exercises[exerciseIndex];
    final decision = ref.watch(exerciseProgressionProvider(exerciseIndex));
    
    // 1. Si la decisión es deload, mostrar feedback empático
    if (decision != null) {
      if (decision.action == ProgressionAction.decreaseWeight ||
          decision.action == ProgressionAction.decreaseReps) {
        return EmpatheticFeedbackResult(
          type: DifficultDayType.deloadRecommended,
          shouldShow: true,
        );
      }
    }
    
    // 2. Si hay series fallidas en la sesión actual
    final failedSets = exercise.logs.where(
      (log) => log.completed && log.reps < 6, // Asumiendo que <6 reps es "fallo"
    ).length;
    
    if (failedSets >= 2) {
      return EmpatheticFeedbackResult(
        type: DifficultDayType.underperformed,
        customMessage: 'Hoy está siendo difícil',
        shouldShow: true,
      );
    }
    
    // 3. Si hay una serie fallida específica
    final lastCompletedSet = exercise.logs.lastWhere(
      (log) => log.completed,
      orElse: () => SerieLog(peso: 0, reps: 0),
    );
    
    if (lastCompletedSet.completed && lastCompletedSet.reps == 0) {
      // No hay series completadas aún, no mostrar
      return EmpatheticFeedbackResult.hide;
    }
    
    // 4. Plateau: si el maintain tiene razón de "sin progreso"
    if (decision?.action == ProgressionAction.maintain &&
        (decision?.reason.contains('plateau') == true ||
         decision?.reason.contains('estancado') == true)) {
      return EmpatheticFeedbackResult(
        type: DifficultDayType.plateau,
        shouldShow: true,
      );
    }
    
    return EmpatheticFeedbackResult.hide;
  },
);

/// Provider para el mensaje del banner empático de un ejercicio
final exerciseEmpatheticBannerProvider = Provider.family<String?, int>(
  (ref, exerciseIndex) {
    final feedback = ref.watch(exerciseEmpatheticFeedbackProvider(exerciseIndex));
    
    if (!feedback.shouldShow) return null;
    
    return feedback.customMessage ?? switch (feedback.type) {
      DifficultDayType.underperformed => 'No pasa nada',
      DifficultDayType.failedSet => 'Forma parte del proceso',
      DifficultDayType.missedSession => 'Retomamos donde lo dejaste',
      DifficultDayType.plateau => 'Estás consolidando',
      DifficultDayType.deloadRecommended => 'Tu cuerpo pide recuperarse',
      null => null,
    };
  },
);
