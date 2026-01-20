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
  final bool isRestActive;

  // New State Fields
  final Map<String, List<SerieLog>> history; // Key: Exercise Name, Value: Last Session Logs
  final bool showAdvancedOptions;

  TrainingState({
    this.activeRutina,
    this.exercises = const [],
    this.targets = const [],
    this.startTime,
    this.defaultRestSeconds = 90,
    this.isRestActive = false,
    this.history = const {},
    this.showAdvancedOptions = false,
  });

  TrainingState copyWith({
    Rutina? activeRutina,
    List<Ejercicio>? exercises,
    List<Ejercicio>? targets,
    DateTime? startTime,
    int? defaultRestSeconds,
    bool? isRestActive,
    Map<String, List<SerieLog>>? history,
    bool? showAdvancedOptions,
  }) {
    return TrainingState(
      activeRutina: activeRutina ?? this.activeRutina,
      exercises: exercises ?? this.exercises,
      targets: targets ?? this.targets,
      startTime: startTime ?? this.startTime,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      isRestActive: isRestActive ?? this.isRestActive,
      history: history ?? this.history,
      showAdvancedOptions: showAdvancedOptions ?? this.showAdvancedOptions,
    );
  }
}

class TrainingSessionNotifier extends StateNotifier<TrainingState> {
  final Ref ref;

  TrainingSessionNotifier(this.ref) : super(TrainingState());

  void startSession(Rutina rutina) {
    // DISABLED FOR MVP BETA REFACTOR (New Models)
    // Needs update to support Dia -> EjercicioEnRutina mapping to Ejercicio (Session)

    /*
    final now = DateTime.now();
    final box = Hive.box<Sesion>('sesiones');
    // Sort sessions descending by date
    final sessions = box.values.toList()..sort((a, b) => b.fecha.compareTo(a.fecha));

    final Map<String, List<SerieLog>> historyMap = {};

    // Build History Map
    // Fails because rutina.ejercicios doesn't exist anymore (now it's dias)
    /*
    for (var ex in rutina.ejercicios) {
       ...
    }
    */

    // ...
    */

    // Set empty state to avoid crashes if accessed
    state = TrainingState(
      activeRutina: rutina,
      exercises: [],
      targets: [],
      startTime: DateTime.now(),
      defaultRestSeconds: 90,
      isRestActive: false,
      history: {},
      showAdvancedOptions: false,
    );
  }

  void updateLog(int exerciseIndex, int setIndex, {
    double? peso,
    int? reps,
    bool? completed,
    int? rpe,
    String? notas,
    int? restSeconds,
    bool? isFailure,
    bool? isDropset,
    bool? isWarmup
  }) {
    final exercises = [...state.exercises];
    final exercise = exercises[exerciseIndex];
    final logs = [...exercise.logs];
    final log = logs[setIndex];

    final newLog = SerieLog(
      peso: peso ?? log.peso,
      reps: reps ?? log.reps,
      completed: completed ?? log.completed,
      rpe: rpe ?? log.rpe,
      notas: notas ?? log.notas,
      restSeconds: restSeconds ?? log.restSeconds,
      isFailure: isFailure ?? log.isFailure,
      isDropset: isDropset ?? log.isDropset,
      isWarmup: isWarmup ?? log.isWarmup,
    );

    logs[setIndex] = newLog;
    final newExercise = exercise.copyWith(logs: logs);
    exercises[exerciseIndex] = newExercise;

    state = state.copyWith(exercises: exercises);
  }

  void copyPreviousSet(int exerciseIndex, int setIndex) {
    if (setIndex == 0) return; // Cannot copy for first set

    final exercise = state.exercises[exerciseIndex];
    final prevLog = exercise.logs[setIndex - 1];

    updateLog(
      exerciseIndex,
      setIndex,
      peso: prevLog.peso,
      reps: prevLog.reps,
      rpe: prevLog.rpe,
      notas: prevLog.notas,
      // Don't copy completed status usually
    );
  }

  void toggleAdvancedOptions(bool show) {
    state = state.copyWith(showAdvancedOptions: show);
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

    state = TrainingState();
    ref.read(bottomNavIndexProvider.notifier).state = 2;
  }
}

final trainingSessionProvider = StateNotifierProvider<TrainingSessionNotifier, TrainingState>((ref) {
  return TrainingSessionNotifier(ref);
});
