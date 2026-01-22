import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../utils/performance_utils.dart';
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

    // Notificar milestone si es nuevo
    if (currentMilestone > _lastNotifiedMilestone) {
      _triggerMilestoneVibration(currentMilestone);
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
    );
  }

  /// Vibración de celebración en milestones
  Future<void> _triggerMilestoneVibration(int milestone) async {
    if (PerformanceMode.instance.reduceVibrations) return;

    try {
      switch (milestone) {
        case 50:
          try { HapticFeedback.mediumImpact(); } catch (_) {}
          break;
        case 75:
          try { HapticFeedback.heavyImpact(); } catch (_) {}
          break;
        case 100:
          try { HapticFeedback.vibrate(); } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 150));
          try { HapticFeedback.vibrate(); } catch (_) {}
          await Future.delayed(const Duration(milliseconds: 150));
          try { HapticFeedback.vibrate(); } catch (_) {}
          break;
      }
    } catch (_) {}
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
