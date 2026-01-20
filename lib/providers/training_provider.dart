import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import '../models/rutina.dart';
import '../models/ejercicio.dart';
import '../models/ejercicio_en_rutina.dart';
import '../models/sesion.dart';
import '../models/serie_log.dart';
import 'main_provider.dart';
import '../repositories/i_training_repository.dart';

final trainingRepositoryProvider = Provider<ITrainingRepository>((ref) {
  throw UnimplementedError('trainingRepositoryProvider not overridden');
});

final rutinasStreamProvider = StreamProvider<List<Rutina>>((ref) {
  final repo = ref.watch(trainingRepositoryProvider);
  return repo.watchRutinas();
});

final sesionesHistoryStreamProvider = StreamProvider<List<Sesion>>((ref) {
  final repo = ref.watch(trainingRepositoryProvider);
  return repo.watchSesionesHistory();
});

final activeSessionStreamProvider = StreamProvider<ActiveSessionData?>((ref) {
  final repo = ref.watch(trainingRepositoryProvider);
  return repo.watchActiveSession();
});

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
  final ITrainingRepository _repository;

  TrainingSessionNotifier(this.ref, this._repository) : super(TrainingState());

  void startSession(Rutina rutina, List<EjercicioEnRutina> routineExercises) {
    // Map EjercicioEnRutina (Type 5) -> Ejercicio (Type 0, Session Model)
    final sessionExercises = routineExercises.map((e) {
      return Ejercicio(
        id: e.instanceId,
        nombre: e.nombre,
        series: e.series,
        reps: int.tryParse(e.repsRange.split('-').first) ?? 0, // Best effort parse
        peso: 0.0,
        notas: e.notas,
        logs: List.generate(e.series, (_) => SerieLog(
          peso: 0.0,
          reps: 0,
          completed: false,
        )),
      );
    }).toList();

    // Build History Map
    final Map<String, List<SerieLog>> historyMap = {};

    for (var ex in sessionExercises) {
       final historyList = _repository.getHistoryForExercise(ex.nombre);
       if (historyList.isNotEmpty) {
         // getHistoryForExercise returns sorted list (newest first)
         final lastSession = historyList.first;
         try {
           final match = lastSession.ejerciciosCompletados.firstWhere((e) => e.nombre == ex.nombre);
           historyMap[ex.nombre] = match.logs;
         } catch (e) {
           // Should not happen if filtered correctly, but safety first
         }
       }
    }

    state = TrainingState(
      activeRutina: rutina,
      exercises: sessionExercises,
      targets: sessionExercises.map((e) => e.copyWith()).toList(), // Snapshot targets
      startTime: DateTime.now(),
      defaultRestSeconds: 90,
      isRestActive: false,
      history: historyMap,
      showAdvancedOptions: false,
    );
    _saveState();
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
    _saveState();
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
    _saveState();
  }

  void setRestDuration(int seconds) {
    state = state.copyWith(defaultRestSeconds: seconds);
    _saveState();
  }

  void startRest() {
    state = state.copyWith(isRestActive: true);
    _saveState();
  }

  void stopRest() {
    state = state.copyWith(isRestActive: false);
    _saveState();
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

    await _repository.saveSesion(sesion);
    await clearStorage();

    state = TrainingState();
    ref.read(bottomNavIndexProvider.notifier).state = 2;
  }

  // --- Persistence ---

  void _saveState() async {
    if (state.activeRutina == null) return;

    final data = ActiveSessionData(
      activeRutina: state.activeRutina,
      exercises: state.exercises,
      targets: state.targets,
      startTime: state.startTime,
      defaultRestSeconds: state.defaultRestSeconds,
      history: state.history,
    );

    await _repository.saveActiveSession(data);
  }

  Future<void> clearStorage() async {
    await _repository.clearActiveSession();
  }

  Future<void> restoreFromStorage() async {
    try {
      final data = await _repository.getActiveSession();

      if (data != null && data.activeRutina != null) {
        state = TrainingState(
          activeRutina: data.activeRutina,
          exercises: data.exercises,
          targets: data.targets,
          startTime: data.startTime ?? DateTime.now(),
          defaultRestSeconds: data.defaultRestSeconds,
          isRestActive: false, // Do not restore timer state for now
          history: data.history,
          showAdvancedOptions: false,
        );
      }
    } catch (e) {
      Logger().e('Error restoring session', error: e);
      await clearStorage();
    }
  }
}

final trainingSessionProvider = StateNotifierProvider<TrainingSessionNotifier, TrainingState>((ref) {
  final repo = ref.watch(trainingRepositoryProvider);
  return TrainingSessionNotifier(ref, repo);
});
