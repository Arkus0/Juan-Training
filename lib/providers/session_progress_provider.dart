import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ejercicio.dart';
import 'training_provider.dart';

/// Estado inmutable del progreso de la sesión
class SessionProgress {
  /// Total de series en la sesión
  final int totalSets;

  /// Series completadas
  final int completedSets;

  /// Porcentaje de progreso (0.0 - 1.0)
  final double percentage;

  /// Total de ejercicios
  final int totalExercises;

  /// Ejercicios completados (todos sus sets terminados)
  final int completedExercises;

  /// Último milestone alcanzado (0, 25, 50, 75, 100)
  final int lastMilestone;

  /// Milestone que acaba de alcanzarse (para trigger de haptics desde UI)
  /// Se resetea a null después de ser consumido
  final int? newlyReachedMilestone;

  /// Si la sesión está completa
  final bool isComplete;

  /// Información de superseries
  final List<SupersetProgressInfo> supersets;

  const SessionProgress({
    this.totalSets = 0,
    this.completedSets = 0,
    this.percentage = 0.0,
    this.totalExercises = 0,
    this.completedExercises = 0,
    this.lastMilestone = 0,
    this.isComplete = false,
    this.supersets = const [],
    this.newlyReachedMilestone,
  });

  SessionProgress copyWith({
    int? totalSets,
    int? completedSets,
    double? percentage,
    int? totalExercises,
    int? completedExercises,
    int? lastMilestone,
    bool? isComplete,
    List<SupersetProgressInfo>? supersets,
    int? newlyReachedMilestone,
    bool clearNewlyReachedMilestone = false,
  }) {
    return SessionProgress(
      totalSets: totalSets ?? this.totalSets,
      completedSets: completedSets ?? this.completedSets,
      percentage: percentage ?? this.percentage,
      totalExercises: totalExercises ?? this.totalExercises,
      completedExercises: completedExercises ?? this.completedExercises,
      lastMilestone: lastMilestone ?? this.lastMilestone,
      isComplete: isComplete ?? this.isComplete,
      supersets: supersets ?? this.supersets,
      newlyReachedMilestone: clearNewlyReachedMilestone ? null : (newlyReachedMilestone ?? this.newlyReachedMilestone),
    );
  }

  /// Texto formateado del progreso
  String get formattedPercentage => '${(percentage * 100).round()}%';

  /// Texto de series
  String get setsText => '$completedSets / $totalSets series';

  /// Color basado en progreso (para UI)
  double get intensity {
    if (percentage >= 0.9) return 1.0;
    if (percentage >= 0.75) return 0.85;
    if (percentage >= 0.5) return 0.7;
    return 0.5;
  }
}

/// Info de progreso de un superset específico
class SupersetProgressInfo {
  final String supersetId;
  final List<String> exerciseNames;
  final int totalRounds;
  final int completedRounds;
  final bool isComplete;

  const SupersetProgressInfo({
    required this.supersetId,
    required this.exerciseNames,
    required this.totalRounds,
    required this.completedRounds,
    required this.isComplete,
  });
}

/// Notifier que calcula y gestiona el progreso de la sesión
class SessionProgressNotifier extends StateNotifier<SessionProgress> {
  final Ref ref;
  int _lastNotifiedMilestone = 0;

  SessionProgressNotifier(this.ref) : super(const SessionProgress()) {
    // Escuchar cambios en la sesión de entrenamiento
    ref.listen<TrainingState>(
      trainingSessionProvider,
      (previous, next) {
        _calculateProgress(next.exercises);
      },
    );
  }

  void _calculateProgress(List<Ejercicio> exercises) {
    if (exercises.isEmpty) {
      state = const SessionProgress();
      _lastNotifiedMilestone = 0;
      return;
    }

    int totalSets = 0;
    int completedSets = 0;
    int totalExercises = exercises.length;
    int completedExercises = 0;

    // Mapeo de superseries para contarlas como bloques
    final Map<String, List<Ejercicio>> supersetGroups = {};
    final List<Ejercicio> standaloneExercises = [];

    for (final exercise in exercises) {
      // Contar sets
      totalSets += exercise.logs.length;
      completedSets += exercise.logs.where((log) => log.completed).length;

      // Verificar si el ejercicio está completo
      final exerciseComplete = exercise.logs.every((log) => log.completed);
      if (exerciseComplete && exercise.logs.isNotEmpty) {
        completedExercises++;
      }

      // Agrupar por superset
      if (exercise.isInSuperset) {
        supersetGroups.putIfAbsent(exercise.supersetId!, () => []).add(exercise);
      } else {
        standaloneExercises.add(exercise);
      }
    }

    // Calcular info de superseries
    final List<SupersetProgressInfo> supersetInfos = [];
    for (final entry in supersetGroups.entries) {
      final ssExercises = entry.value;
      if (ssExercises.isEmpty) continue;

      // Un "round" de superset es completar un set de cada ejercicio
      final minSets = ssExercises.map((e) => e.logs.length).reduce((a, b) => a < b ? a : b);

      int completedRounds = 0;
      for (int round = 0; round < minSets; round++) {
        final roundComplete = ssExercises.every(
          (e) => round < e.logs.length && e.logs[round].completed,
        );
        if (roundComplete) completedRounds++;
      }

      supersetInfos.add(SupersetProgressInfo(
        supersetId: entry.key,
        exerciseNames: ssExercises.map((e) => e.nombre).toList(),
        totalRounds: minSets,
        completedRounds: completedRounds,
        isComplete: completedRounds >= minSets,
      ));
    }

    // Calcular porcentaje
    final percentage = totalSets > 0 ? completedSets / totalSets : 0.0;
    final isComplete = completedSets >= totalSets && totalSets > 0;

    // Determinar milestone alcanzado
    int currentMilestone = 0;
    if (percentage >= 1.0) {
      currentMilestone = 100;
    } else if (percentage >= 0.75) {
      currentMilestone = 75;
    } else if (percentage >= 0.50) {
      currentMilestone = 50;
    } else if (percentage >= 0.25) {
      currentMilestone = 25;
    }

    // Detectar si hay un nuevo milestone alcanzado
    // La vibración se delega a la UI que observe newlyReachedMilestone
    int? newMilestone;
    if (currentMilestone > _lastNotifiedMilestone) {
      newMilestone = currentMilestone;
      _lastNotifiedMilestone = currentMilestone;
    }

    state = SessionProgress(
      totalSets: totalSets,
      completedSets: completedSets,
      percentage: percentage,
      totalExercises: totalExercises,
      completedExercises: completedExercises,
      lastMilestone: currentMilestone,
      isComplete: isComplete,
      supersets: supersetInfos,
      newlyReachedMilestone: newMilestone,
    );
  }

  /// Marca el milestone como consumido (llamar desde UI después de trigger haptic)
  void clearNewlyReachedMilestone() {
    if (state.newlyReachedMilestone != null) {
      state = state.copyWith(clearNewlyReachedMilestone: true);
    }
  }

  /// Reinicia el tracking de milestones (para nueva sesión)
  void reset() {
    _lastNotifiedMilestone = 0;
    state = const SessionProgress();
  }

  /// Fuerza recálculo del progreso
  void recalculate() {
    final trainingState = ref.read(trainingSessionProvider);
    _calculateProgress(trainingState.exercises);
  }
}

/// Provider principal del progreso de sesión
final sessionProgressProvider = StateNotifierProvider<SessionProgressNotifier, SessionProgress>(
  (ref) => SessionProgressNotifier(ref),
);

/// Provider de conveniencia para el porcentaje
final sessionPercentageProvider = Provider<double>((ref) {
  return ref.watch(sessionProgressProvider).percentage;
});

/// Provider de conveniencia para verificar si está completo
final sessionCompleteProvider = Provider<bool>((ref) {
  return ref.watch(sessionProgressProvider).isComplete;
});

/// Provider de conveniencia para el texto de progreso
final sessionProgressTextProvider = Provider<String>((ref) {
  final progress = ref.watch(sessionProgressProvider);
  return '${progress.formattedPercentage} completado';
});

/// Provider que retorna los ejercicios pendientes (no completados)
final pendingExercisesProvider = Provider<List<String>>((ref) {
  final state = ref.watch(trainingSessionProvider);
  return state.exercises
      .where((e) => !e.logs.every((log) => log.completed))
      .map((e) => e.nombre)
      .toList();
});

// ════════════════════════════════════════════════════════════════════════════
// EXERCISE COMPLETION TRACKING
// ════════════════════════════════════════════════════════════════════════════

/// Estado de un ejercicio recién completado (para mostrar resumen)
class ExerciseCompletionInfo {
  final int exerciseIndex;
  final String exerciseName;
  final int completedSets;
  final int targetSets;
  final int totalReps;
  final bool metTarget;
  final String? nextSessionHint;

  /// Flag para indicar que este es un evento nuevo que requiere haptic feedback
  /// La UI debe llamar a HapticsController.instance.onExerciseCompleted() y luego
  /// llamar a notifier.markHapticConsumed()
  final bool needsHapticFeedback;

  const ExerciseCompletionInfo({
    required this.exerciseIndex,
    required this.exerciseName,
    required this.completedSets,
    required this.targetSets,
    required this.totalReps,
    required this.metTarget,
    this.nextSessionHint,
    this.needsHapticFeedback = false,
  });

  ExerciseCompletionInfo copyWith({bool? needsHapticFeedback}) {
    return ExerciseCompletionInfo(
      exerciseIndex: exerciseIndex,
      exerciseName: exerciseName,
      completedSets: completedSets,
      targetSets: targetSets,
      totalReps: totalReps,
      metTarget: metTarget,
      nextSessionHint: nextSessionHint,
      needsHapticFeedback: needsHapticFeedback ?? this.needsHapticFeedback,
    );
  }
}

/// Notifier que trackea ejercicios completados y permite mostrar feedback
class ExerciseCompletionNotifier extends StateNotifier<ExerciseCompletionInfo?> {
  final Ref ref;
  Set<int> _completedExercises = {};
  
  ExerciseCompletionNotifier(this.ref) : super(null) {
    // Escuchar cambios en el training state
    ref.listen<TrainingState>(trainingSessionProvider, (prev, next) {
      _checkForNewlyCompletedExercise(prev, next);
    });
  }
  
  void _checkForNewlyCompletedExercise(TrainingState? prev, TrainingState next) {
    for (int i = 0; i < next.exercises.length; i++) {
      final exercise = next.exercises[i];
      final allCompleted = exercise.logs.every((log) => log.completed);

      if (allCompleted && !_completedExercises.contains(i)) {
        // ¡Este ejercicio acaba de completarse!
        _completedExercises.add(i);

        // ═══════════════════════════════════════════════════════════════════════
        // GAME FEEL: Feedback háptico al completar ejercicio
        // ═══════════════════════════════════════════════════════════════════════
        // La vibración se delega al HapticsController desde la UI.
        // El provider solo marca que el ejercicio se completó (justCompleted: true).
        // La UI observa este flag y llama a HapticsController.instance.onExerciseCompleted()
        // ═══════════════════════════════════════════════════════════════════════

        const targetReps = 8; // Default, idealmente vendría del ejercicio
        final completedSets = exercise.logs.where((l) => l.completed).length;
        final totalReps = exercise.logs.fold<int>(0, (sum, log) => sum + log.reps);
        final metTarget = exercise.logs.every((l) => l.reps >= targetReps);
        
        state = ExerciseCompletionInfo(
          exerciseIndex: i,
          exerciseName: exercise.nombre,
          completedSets: completedSets,
          targetSets: exercise.logs.length,
          totalReps: totalReps,
          metTarget: metTarget,
          nextSessionHint: metTarget ? 'Próxima: más peso o reps' : 'Repite este objetivo',
          needsHapticFeedback: true, // La UI debe consumir esto y disparar haptic
        );
        
        // Auto-clear después de 5 segundos si no se dismissea
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && state?.exerciseIndex == i) {
            state = null;
          }
        });
        
        return; // Solo un ejercicio a la vez
      }
    }
  }
  
  /// Limpia el estado de completitud mostrado
  void dismiss() {
    state = null;
  }

  /// Marca que el haptic feedback fue ejecutado (llamar desde UI)
  void markHapticConsumed() {
    if (state?.needsHapticFeedback == true) {
      state = state!.copyWith(needsHapticFeedback: false);
    }
  }

  /// Reset para nueva sesión
  void reset() {
    _completedExercises = {};
    state = null;
  }
}

/// Provider para ejercicio recién completado
final exerciseCompletionProvider = StateNotifierProvider<ExerciseCompletionNotifier, ExerciseCompletionInfo?>(
  (ref) => ExerciseCompletionNotifier(ref),
);
