import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import '../models/rutina.dart';
import '../models/ejercicio.dart';
import '../models/sesion.dart';
import '../models/serie_log.dart';
import 'main_provider.dart';

class TrainingState {
  final Rutina? activeRutina;
  final List<Ejercicio> exercises; // The working copy with logs
  final List<Ejercicio> targets; // Snapshot of targets
  final DateTime? startTime;
  final int defaultRestSeconds;

  // We can track specific timer state if needed, but often UI handles the ticker.
  // We will track if a rest is requested to trigger the UI overlay/widget.
  final bool isRestActive;

  TrainingState({
    this.activeRutina,
    this.exercises = const [],
    this.targets = const [],
    this.startTime,
    this.defaultRestSeconds = 90,
    this.isRestActive = false,
  });

  TrainingState copyWith({
    Rutina? activeRutina,
    List<Ejercicio>? exercises,
    List<Ejercicio>? targets,
    DateTime? startTime,
    int? defaultRestSeconds,
    bool? isRestActive,
  }) {
    return TrainingState(
      activeRutina: activeRutina ?? this.activeRutina,
      exercises: exercises ?? this.exercises,
      targets: targets ?? this.targets,
      startTime: startTime ?? this.startTime,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      isRestActive: isRestActive ?? this.isRestActive,
    );
  }
}

class TrainingSessionNotifier extends StateNotifier<TrainingState> {
  final Ref ref;

  TrainingSessionNotifier(this.ref) : super(TrainingState());

  void startSession(Rutina rutina) {
    final now = DateTime.now();

    // Create working copies for logging
    // We strictly assume Ejercicio has summary fields 'series', 'reps', 'peso'
    final workingExercises = rutina.ejercicios.map((e) {
      // Create 'logs' based on target series
      // Default to target values
      final logs = List.generate(e.series, (index) {
        return SerieLog(
          peso: e.peso,
          reps: e.reps,
          completed: false, // Default not completed
        );
      });

      // Create a detached copy (not in Hive box yet)
      return Ejercicio(
        id: e.id,
        nombre: e.nombre,
        series: e.series,
        reps: e.reps,
        peso: e.peso,
        notas: e.notas,
        logs: logs,
      );
    }).toList();

    // Snapshot of targets (without logs, or logs ignored)
    // We just clone the original exercise list from routine
    // Since Rutina.ejercicios are HiveObjects, we should probably create detached copies
    // to avoid modifying the routine definition by accident if we ever touch them.
    final targetExercises = rutina.ejercicios.map((e) => e.copyWith()).toList();

    state = TrainingState(
      activeRutina: rutina,
      exercises: workingExercises,
      targets: targetExercises,
      startTime: now,
      defaultRestSeconds: 90,
      isRestActive: false,
    );
  }

  void updateLog(int exerciseIndex, int setIndex, {double? peso, int? reps, bool? completed}) {
    final exercises = [...state.exercises];
    final exercise = exercises[exerciseIndex];
    final logs = [...exercise.logs];
    final log = logs[setIndex];

    // Create new log instance (immutable style usually better for Riverpod,
    // but HiveObject is mutable. We'll replace the object in the list)
    // Since SerieLog is HiveObject, we can just mutate it IF it was just a local object.
    // But to trigger Riverpod update, we need to reassign to state.

    // Mutate the log object directly?
    // Since these objects are not in a box yet, they are just Dart objects.
    if (peso != null) {
      // We can't change final fields of SerieLog easily if they are final.
      // Let's check SerieLog definition.
    }

    // Check SerieLog definition: fields are final (peso, reps) except completed?
    // In my generated file: final double peso; final int reps; bool completed;
    // So I must replace the SerieLog object.

    final newLog = SerieLog(
      peso: peso ?? log.peso,
      reps: reps ?? log.reps,
      completed: completed ?? log.completed,
    );

    logs[setIndex] = newLog;

    // We also need to update the exercise object because 'logs' is final in Ejercicio
    // "final List<SerieLog> logs;"
    // So we need to replace the exercise object.

    final newExercise = exercise.copyWith(logs: logs);
    exercises[exerciseIndex] = newExercise;

    state = state.copyWith(exercises: exercises);
  }

  void setRestDuration(int seconds) {
    state = state.copyWith(defaultRestSeconds: seconds);
  }

  void startRest() {
    state = state.copyWith(isRestActive: true);
  }

  void stopRest() {
    state = state.copyWith(isRestActive: false);
  }

  Future<void> finishSession() async {
    if (state.activeRutina == null || state.startTime == null) return;

    final endTime = DateTime.now();
    final durationSeconds = endTime.difference(state.startTime!).inSeconds;

    final sesion = Sesion(
      id: const Uuid().v4(),
      rutinaId: state.activeRutina!.id,
      fecha: endTime,
      ejerciciosCompletados: state.exercises,
      ejerciciosObjetivo: state.targets,
      durationSeconds: durationSeconds,
    );

    final box = Hive.box<Sesion>('sesiones');
    await box.add(sesion);

    // Reset state? Or let the UI dispose/navigate away.
    // Usually good to reset.
    state = TrainingState();

    // Navigate to History (Index 2)
    ref.read(bottomNavIndexProvider.notifier).state = 2;
  }
}

final trainingSessionProvider = StateNotifierProvider<TrainingSessionNotifier, TrainingState>((ref) {
  return TrainingSessionNotifier(ref);
});
