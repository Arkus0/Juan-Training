import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
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

/// Estado avanzado del timer de descanso
class RestTimerState {
  final bool isActive;
  final bool isPaused;
  final int totalSeconds;
  final DateTime? endTime; // Tiempo absoluto de fin (para persistir entre rebuilds)
  final int? lastCompletedExerciseIndex;
  final int? lastCompletedSetIndex;

  const RestTimerState({
    this.isActive = false,
    this.isPaused = false,
    this.totalSeconds = 90,
    this.endTime,
    this.lastCompletedExerciseIndex,
    this.lastCompletedSetIndex,
  });

  RestTimerState copyWith({
    bool? isActive,
    bool? isPaused,
    int? totalSeconds,
    DateTime? endTime,
    int? lastCompletedExerciseIndex,
    int? lastCompletedSetIndex,
    bool clearEndTime = false,
  }) {
    return RestTimerState(
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      lastCompletedExerciseIndex: lastCompletedExerciseIndex ?? this.lastCompletedExerciseIndex,
      lastCompletedSetIndex: lastCompletedSetIndex ?? this.lastCompletedSetIndex,
    );
  }

  /// Calcula segundos restantes basado en endTime
  double get remainingSeconds {
    if (!isActive || endTime == null) return totalSeconds.toDouble();
    if (isPaused) return totalSeconds.toDouble(); // Cuando pausado, mantener el valor pausado
    final remaining = endTime!.difference(DateTime.now()).inMilliseconds / 1000.0;
    return remaining > 0 ? remaining : 0;
  }

  /// Progreso del timer (0.0 a 1.0)
  double get progress {
    if (totalSeconds <= 0) return 1.0;
    return 1.0 - (remainingSeconds / totalSeconds);
  }
}

class TrainingState {
  final Rutina? activeRutina;
  final String? dayName; // Nombre del día siendo entrenado
  final int? dayIndex; // Índice del día en la rutina
  final List<Ejercicio> exercises; // The working copy with logs
  final List<Ejercicio> targets; // Snapshot of targets
  final DateTime? startTime;
  final int defaultRestSeconds;
  final bool isRestActive; // DEPRECATED: usar restTimer.isActive
  final RestTimerState restTimer; // Nuevo estado avanzado del timer

  // New State Fields
  final Map<String, List<SerieLog>> history; // Key: Exercise Name, Value: Last Session Logs
  final bool showAdvancedOptions;

  TrainingState({
    this.activeRutina,
    this.dayName,
    this.dayIndex,
    this.exercises = const [],
    this.targets = const [],
    this.startTime,
    this.defaultRestSeconds = 90,
    this.isRestActive = false,
    this.restTimer = const RestTimerState(),
    this.history = const {},
    this.showAdvancedOptions = false,
  });

  TrainingState copyWith({
    Rutina? activeRutina,
    String? dayName,
    int? dayIndex,
    List<Ejercicio>? exercises,
    List<Ejercicio>? targets,
    DateTime? startTime,
    int? defaultRestSeconds,
    bool? isRestActive,
    RestTimerState? restTimer,
    Map<String, List<SerieLog>>? history,
    bool? showAdvancedOptions,
  }) {
    return TrainingState(
      activeRutina: activeRutina ?? this.activeRutina,
      dayName: dayName ?? this.dayName,
      dayIndex: dayIndex ?? this.dayIndex,
      exercises: exercises ?? this.exercises,
      targets: targets ?? this.targets,
      startTime: startTime ?? this.startTime,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      isRestActive: isRestActive ?? this.isRestActive,
      restTimer: restTimer ?? this.restTimer,
      history: history ?? this.history,
      showAdvancedOptions: showAdvancedOptions ?? this.showAdvancedOptions,
    );
  }

  /// Obtiene el índice del siguiente set no completado (para auto-focus)
  ({int exerciseIndex, int setIndex})? get nextIncompleteSet {
    for (int exIdx = 0; exIdx < exercises.length; exIdx++) {
      final exercise = exercises[exIdx];
      for (int setIdx = 0; setIdx < exercise.logs.length; setIdx++) {
        if (!exercise.logs[setIdx].completed) {
          return (exerciseIndex: exIdx, setIndex: setIdx);
        }
      }
    }
    return null;
  }
}

class TrainingSessionNotifier extends StateNotifier<TrainingState> {
  final Ref ref;
  final ITrainingRepository _repository;

  TrainingSessionNotifier(this.ref, this._repository) : super(TrainingState());

  Future<void> startSession(Rutina rutina, List<EjercicioEnRutina> routineExercises, {String? dayName, int? dayIndex}) async {
    // Map EjercicioEnRutina (Type 5) -> Ejercicio (Type 0, Session Model)
    final sessionExercises = routineExercises.map((e) {
      return Ejercicio(
        id: e.instanceId, // Use the stable Instance ID
        libraryId: e.id,  // Reference to the library
        nombre: e.nombre,
        musculosPrincipales: e.musculosPrincipales,
        musculosSecundarios: e.musculosSecundarios,
        series: e.series,
        reps: int.tryParse(e.repsRange.split('-').first) ?? 0, // Best effort parse
        peso: 0.0,
        notas: e.notas,
        logs: List.generate(e.series, (_) => SerieLog(
          // ID is generated automatically in constructor
          peso: 0.0,
          reps: 0,
          completed: false,
        )),
      );
    }).toList();

    // Build History Map
    final Map<String, List<SerieLog>> historyMap = {};

    for (var ex in sessionExercises) {
       final historyList = await _repository.getHistoryForExercise(ex.nombre);
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
      dayName: dayName,
      dayIndex: dayIndex,
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
      id: log.id, // Preserve UUID
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
    state = state.copyWith(
      defaultRestSeconds: seconds,
      restTimer: state.restTimer.copyWith(totalSeconds: seconds),
    );
    _saveState();
  }

  /// Inicia el timer de descanso para un ejercicio específico
  /// @param exerciseIndex Índice del ejercicio que acaba de completarse
  /// @param setIndex Índice del set que acaba de completarse (para auto-focus)
  void startRestForExercise(int exerciseIndex, {int? setIndex}) {
    final exercise = state.exercises[exerciseIndex];
    int restTime = state.defaultRestSeconds;

    // Try to find configured rest time in the active routine
    if (state.activeRutina != null) {
      for (final day in state.activeRutina!.dias) {
        final match = day.ejercicios.firstWhereOrNull((e) => e.instanceId == exercise.id);
        if (match != null && match.descansoSugerido != null) {
          restTime = match.descansoSugerido!.inSeconds;
          break;
        }
      }
    }

    final endTime = DateTime.now().add(Duration(seconds: restTime));

    state = state.copyWith(
      defaultRestSeconds: restTime,
      isRestActive: true,
      restTimer: RestTimerState(
        isActive: true,
        isPaused: false,
        totalSeconds: restTime,
        endTime: endTime,
        lastCompletedExerciseIndex: exerciseIndex,
        lastCompletedSetIndex: setIndex,
      ),
    );
    _saveState();
  }

  void startRest() {
    final restTime = state.defaultRestSeconds;
    final endTime = DateTime.now().add(Duration(seconds: restTime));

    state = state.copyWith(
      isRestActive: true,
      restTimer: RestTimerState(
        isActive: true,
        isPaused: false,
        totalSeconds: restTime,
        endTime: endTime,
      ),
    );
    _saveState();
  }

  void stopRest() {
    state = state.copyWith(
      isRestActive: false,
      restTimer: const RestTimerState(isActive: false),
    );
    _saveState();
  }

  /// Pausa el timer de descanso (guarda el tiempo restante)
  void pauseRest() {
    if (!state.restTimer.isActive || state.restTimer.isPaused) return;

    final remaining = state.restTimer.remainingSeconds.ceil();
    state = state.copyWith(
      restTimer: state.restTimer.copyWith(
        isPaused: true,
        totalSeconds: remaining, // Guardar tiempo restante
        clearEndTime: true,
      ),
    );
    _saveState();
  }

  /// Reanuda el timer de descanso desde donde estaba pausado
  void resumeRest() {
    if (!state.restTimer.isActive || !state.restTimer.isPaused) return;

    final endTime = DateTime.now().add(Duration(seconds: state.restTimer.totalSeconds));
    state = state.copyWith(
      restTimer: state.restTimer.copyWith(
        isPaused: false,
        endTime: endTime,
      ),
    );
    _saveState();
  }

  /// Añade tiempo al timer actual
  void addRestTime(int seconds) {
    if (!state.restTimer.isActive) return;

    final newTotal = state.restTimer.totalSeconds + seconds;
    if (state.restTimer.isPaused) {
      state = state.copyWith(
        restTimer: state.restTimer.copyWith(totalSeconds: newTotal),
      );
    } else {
      final newEndTime = state.restTimer.endTime?.add(Duration(seconds: seconds));
      state = state.copyWith(
        restTimer: state.restTimer.copyWith(
          totalSeconds: newTotal,
          endTime: newEndTime,
        ),
      );
    }
    _saveState();
  }

  Future<void> finishSession() async {
    // Modified to allow saving sessions without a routine (Ad-hoc)
    if (state.startTime == null) return;
    if (state.exercises.isEmpty) return; // Should not save empty session

    final endTime = DateTime.now();
    final durationSeconds = endTime.difference(state.startTime!).inSeconds;

    final sesion = Sesion(
      id: const Uuid().v4(),
      rutinaId: state.activeRutina?.id ?? '', // Handle null routine
      dayName: state.dayName,
      dayIndex: state.dayIndex,
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

  Future<void> _saveState() async {
    // Removed strict check for activeRutina to allow Ad-Hoc saves
    if (state.exercises.isEmpty) return;

    final data = ActiveSessionData(
      activeRutina: state.activeRutina,
      exercises: state.exercises,
      targets: state.targets,
      startTime: state.startTime,
      defaultRestSeconds: state.defaultRestSeconds,
      history: state.history,
    );

    try {
      await _repository.saveActiveSession(data);
    } catch (e) {
      Logger().e('Error saving session state', error: e);
    }
  }

  Future<void> clearStorage() async {
    await _repository.clearActiveSession();
  }

  Future<void> restoreFromStorage() async {
    try {
      final data = await _repository.getActiveSession();

      if (data != null) {
        // Safe Restore: Load data even if activeRutina is missing (deleted routine)
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
      // Fallback: If critical failure, clear storage to prevent crash loop.
      // Ideally, we could try to rescue partial data here, but getActiveSession
      // handles the DB read. If that threw, the data is likely corrupt.
      await clearStorage();
    }
  }
}

final trainingSessionProvider = StateNotifierProvider<TrainingSessionNotifier, TrainingState>((ref) {
  final repo = ref.watch(trainingRepositoryProvider);
  return TrainingSessionNotifier(ref, repo);
});

/// Modelo de sugerencia inteligente de próximo día a entrenar.
class SmartWorkoutSuggestion {
  final Rutina rutina;
  final int dayIndex;
  final String dayName;
  final String reason;

  const SmartWorkoutSuggestion({
    required this.rutina,
    required this.dayIndex,
    required this.dayName,
    required this.reason,
  });
}

/// Provider que calcula el próximo día sugerido basado en el historial.
/// Lógica: Mira la última sesión de la rutina activa y sugiere el siguiente día.
final smartSuggestionProvider = FutureProvider<SmartWorkoutSuggestion?>((ref) async {
  final rutinasAsync = ref.watch(rutinasStreamProvider);
  final sessionsAsync = ref.watch(sesionesHistoryStreamProvider);

  final rutinas = rutinasAsync.valueOrNull ?? [];
  final sessions = sessionsAsync.valueOrNull ?? [];

  if (rutinas.isEmpty) return null;

  // Buscar la rutina más reciente usada en sesiones
  Rutina? lastUsedRutina;
  Sesion? lastSession;

  for (final session in sessions) {
    final matchingRutina = rutinas.firstWhereOrNull((r) => r.id == session.rutinaId);
    if (matchingRutina != null) {
      lastUsedRutina = matchingRutina;
      lastSession = session;
      break;
    }
  }

  // Si no hay historial, sugerir el primer día de la primera rutina
  if (lastUsedRutina == null) {
    final firstRutina = rutinas.first;
    if (firstRutina.dias.isEmpty) return null;
    return SmartWorkoutSuggestion(
      rutina: firstRutina,
      dayIndex: 0,
      dayName: firstRutina.dias.first.nombre,
      reason: 'Comienza tu rutina',
    );
  }

  // Calcular siguiente día basado en el último entrenado
  if (lastSession != null && lastUsedRutina.dias.isNotEmpty) {
    final lastDayIndex = lastSession.dayIndex ?? -1;
    final totalDays = lastUsedRutina.dias.length;

    // Siguiente día en ciclo
    final nextDayIndex = (lastDayIndex + 1) % totalDays;
    final nextDay = lastUsedRutina.dias[nextDayIndex];

    // Determinar razón
    String reason;
    if (nextDayIndex == 0 && lastDayIndex >= 0) {
      reason = 'Nueva semana, reinicia ciclo';
    } else {
      reason = 'Siguiente día en tu rutina';
    }

    return SmartWorkoutSuggestion(
      rutina: lastUsedRutina,
      dayIndex: nextDayIndex,
      dayName: nextDay.nombre,
      reason: reason,
    );
  }

  return null;
});
