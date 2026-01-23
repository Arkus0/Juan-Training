import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rutina.dart';
import '../models/ejercicio.dart';
import '../models/ejercicio_en_rutina.dart';
import '../models/sesion.dart';
import '../models/serie_log.dart';
import '../models/progression_engine_models.dart';
import 'main_provider.dart';
import '../repositories/i_training_repository.dart';
import '../utils/performance_utils.dart';
import '../services/timer_platform_service.dart';
import '../services/error_tolerance_system.dart';
import 'session_tolerance_provider.dart';

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
  final bool showTimerBar; // Mostrar/ocultar barra inactiva del timer

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
    this.showAdvancedOptions = true, // Siempre visible por defecto
    this.showTimerBar = true, // UX: Visible por defecto - core feature del gym
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
    bool? showTimerBar,
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
      showTimerBar: showTimerBar ?? this.showTimerBar,
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

  /// Debouncer para optimizar saves a BD (evitar saves excesivos durante input)
  final Debouncer _saveDebouncer = Debouncer(
    delay: const Duration(milliseconds: 500),
  );

  /// Flag para saber si hay un save pendiente que debe ejecutarse inmediatamente
  bool _hasPendingSave = false;

  /// Servicio de comunicación con el timer de plataforma (Android)
  final TimerPlatformService _timerPlatformService = TimerPlatformService.instance;
  StreamSubscription<TimerPlatformEvent>? _timerEventSubscription;
  bool _platformServiceInitialized = false;

  TrainingSessionNotifier(this.ref, this._repository) : super(TrainingState()) {
    _initializePlatformService();
  }

  /// Inicializa el servicio de timer de plataforma y escucha eventos
  Future<void> _initializePlatformService() async {
    if (_platformServiceInitialized) return;

    try {
      await _timerPlatformService.initialize();
      _platformServiceInitialized = true;

      // Escuchar eventos del servicio de plataforma (botones de notificación)
      _timerEventSubscription = _timerPlatformService.eventStream.listen(_handlePlatformTimerEvent);

      Logger().d('TimerPlatformService inicializado en TrainingProvider');
    } catch (e) {
      Logger().e('Error inicializando TimerPlatformService', error: e);
    }
  }

  /// Maneja eventos del timer de plataforma (desde notificación Android)
  void _handlePlatformTimerEvent(TimerPlatformEvent event) {
    switch (event) {
      case TimerPlatformEvent.pause:
        // Solo actualizar estado local, el servicio ya pausó
        if (state.restTimer.isActive && !state.restTimer.isPaused) {
          final remaining = state.restTimer.remainingSeconds.ceil();
          state = state.copyWith(
            restTimer: state.restTimer.copyWith(
              isPaused: true,
              totalSeconds: remaining,
              clearEndTime: true,
            ),
          );
          _saveState();
        }
        break;

      case TimerPlatformEvent.resume:
        // Solo actualizar estado local, el servicio ya reanudó
        if (state.restTimer.isActive && state.restTimer.isPaused) {
          final endTime = DateTime.now().add(Duration(seconds: state.restTimer.totalSeconds));
          state = state.copyWith(
            restTimer: state.restTimer.copyWith(
              isPaused: false,
              endTime: endTime,
            ),
          );
          _saveState();
        }
        break;

      case TimerPlatformEvent.skip:
        // Saltar timer desde notificación
        stopRest(saveRestTime: true);
        break;

      case TimerPlatformEvent.add30:
        // Añadir 30 segundos desde notificación
        addRestTime(30);
        break;

      case TimerPlatformEvent.finished:
        // Timer terminó naturalmente
        stopRest(saveRestTime: true);
        break;
    }
  }

  @override
  void dispose() {
    _timerEventSubscription?.cancel();
    _saveDebouncer.cancel();
    super.dispose();
  }

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
        supersetId: e.supersetId, // Copiar superset para lógica de timer encadenado
        descansoSugeridoSeconds: e.descansoSugerido?.inSeconds,
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
    bool? isWarmup,
    bool skipToleranceCheck = false, // 🎯 Skip validation when user accepted a correction
  }) {
    final exercises = [...state.exercises];
    final exercise = exercises[exerciseIndex];
    final logs = [...exercise.logs];
    final log = logs[setIndex];

    // ═══════════════════════════════════════════════════════════════════════
    // ERROR TOLERANCE: Validación tolerante de peso (nunca bloquea)
    // ═══════════════════════════════════════════════════════════════════════
    double? validatedPeso = peso;
    ToleranceResult? toleranceResult;
    
    // 🎯 FIX: Skip validation if user already accepted a correction (prevents infinite loop)
    if (peso != null && peso > 0 && !skipToleranceCheck) {
      final category = ExerciseCategory.inferFromName(exercise.nombre);
      final lastKnownWeight = log.peso > 0 ? log.peso : _getLastKnownWeight(exercise.nombre);
      
      toleranceResult = ErrorToleranceRules.evaluateDataEntry(
        enteredWeight: peso,
        lastKnownWeight: lastKnownWeight,
        exerciseName: exercise.nombre,
        category: category,
      );
      
      // 🎯 ERROR TOLERANCE: Si es sospechoso, notificar al provider para mostrar diálogo
      if (toleranceResult.severity == ToleranceSeverity.medium && 
          toleranceResult.userMessage != null &&
          lastKnownWeight > 0) {
        // Calcular peso sugerido (detectar error de dedo: 500 → 50)
        double suggestedWeight = lastKnownWeight;
        if (peso > lastKnownWeight * 5) {
          suggestedWeight = peso / 10; // Probablemente un 0 de más
        } else if (peso < lastKnownWeight * 0.2) {
          suggestedWeight = peso * 10; // Probablemente falta un 0
        }
        
        ref.read(suspiciousDataProvider.notifier).setSuspiciousData(
          exerciseName: exercise.nombre,
          enteredWeight: peso,
          suggestedWeight: suggestedWeight,
          exerciseIndex: exerciseIndex,
          setIndex: setIndex,
        );
        Logger().w('Peso sospechoso en ${exercise.nombre}: $peso kg (sugerido: $suggestedWeight kg)');
      } else if (toleranceResult.needsCorrection && toleranceResult.correctedValue != null) {
        Logger().w('Peso sospechoso en ${exercise.nombre}: $peso kg (esperado ~$lastKnownWeight kg)');
      }
    }

    final newLog = SerieLog(
      id: log.id, // Preserve UUID
      peso: validatedPeso ?? log.peso,
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
  
  /// Obtiene el último peso conocido para un ejercicio (del historial)
  double _getLastKnownWeight(String exerciseName) {
    final historyLogs = state.history[exerciseName];
    if (historyLogs != null && historyLogs.isNotEmpty) {
      // Buscar el primer log con peso > 0
      for (final log in historyLogs) {
        if (log.peso > 0) return log.peso;
      }
    }
    return 0.0;
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

  void toggleTimerBar(bool show) {
    state = state.copyWith(showTimerBar: show);
    // No guardar en BD, es solo UI temporal
  }

  void setRestDuration(int seconds) {
    state = state.copyWith(
      defaultRestSeconds: seconds,
      restTimer: state.restTimer.copyWith(totalSeconds: seconds),
    );
    _saveState();
  }

  /// Verifica si el ejercicio es el último de su superset que tiene sets pendientes
  /// Retorna true si debe iniciar el timer, false si hay más ejercicios en el superset
  bool _shouldStartTimerForSuperset(int exerciseIndex, int setIndex) {
    final exercise = state.exercises[exerciseIndex];

    // Si no está en superset, siempre iniciar timer
    if (!exercise.isInSuperset) return true;

    final supersetId = exercise.supersetId!;

    // Encontrar todos los ejercicios del mismo superset
    final supersetExercises = <int>[];
    for (int i = 0; i < state.exercises.length; i++) {
      if (state.exercises[i].supersetId == supersetId) {
        supersetExercises.add(i);
      }
    }

    // Si solo hay un ejercicio en el superset (raro pero posible), iniciar timer
    if (supersetExercises.length <= 1) return true;

    // Verificar si el ejercicio actual es el último del superset en orden
    final currentPositionInSuperset = supersetExercises.indexOf(exerciseIndex);
    final isLastInSuperset = currentPositionInSuperset == supersetExercises.length - 1;

    // Si es el último del superset, iniciar timer
    if (isLastInSuperset) return true;

    // Si no es el último, verificar si el siguiente ejercicio del superset
    // tiene el mismo set (round) pendiente - si no, iniciar timer
    final nextInSuperset = supersetExercises[currentPositionInSuperset + 1];
    final nextExercise = state.exercises[nextInSuperset];

    // Si el siguiente ejercicio ya tiene ese set completado, es que estamos
    // terminando una ronda completa del superset
    if (setIndex < nextExercise.logs.length && nextExercise.logs[setIndex].completed) {
      // La ronda ya fue completada, verificar si hay más rondas
      final allRoundsComplete = supersetExercises.every((idx) {
        final ex = state.exercises[idx];
        return setIndex >= ex.logs.length - 1 || ex.logs[setIndex].completed;
      });
      return allRoundsComplete;
    }

    // El siguiente ejercicio del superset tiene ese set pendiente, no iniciar timer
    return false;
  }

  /// Obtiene el tiempo de descanso sugerido para un superset (del último ejercicio)
  int _getSupersetRestTime(int exerciseIndex) {
    final exercise = state.exercises[exerciseIndex];

    if (!exercise.isInSuperset) {
      return exercise.descansoSugeridoSeconds ?? state.defaultRestSeconds;
    }

    final supersetId = exercise.supersetId!;

    // Buscar el último ejercicio del superset para usar su descanso
    int? lastSupersetRestTime;
    for (int i = state.exercises.length - 1; i >= 0; i--) {
      if (state.exercises[i].supersetId == supersetId) {
        lastSupersetRestTime = state.exercises[i].descansoSugeridoSeconds;
        break;
      }
    }

    return lastSupersetRestTime ?? state.defaultRestSeconds;
  }

  /// Inicia el timer de descanso para un ejercicio específico
  /// @param exerciseIndex Índice del ejercicio que acaba de completarse
  /// @param setIndex Índice del set que acaba de completarse (para auto-focus)
  /// @return true si el timer se inició, false si estamos en medio de un superset
  bool startRestForExercise(int exerciseIndex, {int? setIndex}) {
    // Verificar lógica de superseries
    if (setIndex != null && !_shouldStartTimerForSuperset(exerciseIndex, setIndex)) {
      // Estamos en medio de un superset, no iniciar timer
      return false;
    }

    final exercise = state.exercises[exerciseIndex];
    int restTime = _getSupersetRestTime(exerciseIndex);

    // Fallback: Try to find configured rest time in the active routine
    if (restTime == state.defaultRestSeconds && state.activeRutina != null) {
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
    _saveRestTimerToPrefs();

    // Iniciar timer en servicio de plataforma (notificación Android)
    _timerPlatformService.start(
      seconds: restTime,
      exerciseIndex: exerciseIndex,
      setIndex: setIndex,
    );

    return true;
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
    _saveRestTimerToPrefs();

    // Iniciar timer en servicio de plataforma
    _timerPlatformService.start(seconds: restTime);
  }

  void stopRest({bool saveRestTime = true}) {
    // Guardar el tiempo de descanso en el SerieLog si corresponde
    if (saveRestTime && state.restTimer.isActive) {
      final exerciseIndex = state.restTimer.lastCompletedExerciseIndex;
      final setIndex = state.restTimer.lastCompletedSetIndex;

      if (exerciseIndex != null && setIndex != null) {
        // Calcular el tiempo real descansado
        final totalTime = state.restTimer.totalSeconds;
        final remainingTime = state.restTimer.remainingSeconds.ceil();
        final actualRestTime = totalTime - remainingTime;

        // Solo guardar si descansó al menos un poco
        if (actualRestTime > 0) {
          _updateLogRestTime(exerciseIndex, setIndex, actualRestTime);
        }
      }
    }

    state = state.copyWith(
      isRestActive: false,
      restTimer: const RestTimerState(isActive: false),
    );
    _saveState();
    _saveRestTimerToPrefs();

    // Detener timer en servicio de plataforma
    _timerPlatformService.stop();
  }

  /// Actualiza el tiempo de descanso en un SerieLog específico (para analytics)
  void _updateLogRestTime(int exerciseIndex, int setIndex, int restSeconds) {
    final exercises = [...state.exercises];
    if (exerciseIndex >= exercises.length) return;

    final exercise = exercises[exerciseIndex];
    if (setIndex >= exercise.logs.length) return;

    final logs = [...exercise.logs];
    final log = logs[setIndex];

    logs[setIndex] = SerieLog(
      id: log.id,
      peso: log.peso,
      reps: log.reps,
      completed: log.completed,
      rpe: log.rpe,
      notas: log.notas,
      restSeconds: restSeconds,
      isFailure: log.isFailure,
      isDropset: log.isDropset,
      isWarmup: log.isWarmup,
    );

    exercises[exerciseIndex] = exercise.copyWith(logs: logs);
    state = state.copyWith(exercises: exercises);
    // No llamar _saveState() aquí, se llamará en stopRest()
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
    _saveRestTimerToPrefs();

    // Pausar timer en servicio de plataforma
    _timerPlatformService.pause();
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
    _saveRestTimerToPrefs();

    // Reanudar timer en servicio de plataforma
    _timerPlatformService.resume();
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
    _saveRestTimerToPrefs();

    // Añadir tiempo en servicio de plataforma
    _timerPlatformService.addTime(seconds);
  }

  /// Reinicia el timer de descanso al valor por defecto para el ejercicio actual (o al valor por defecto de la sesión).
  void restartRest() {
    // Determinar tiempo de descanso objetivo: intentar usar el último ejercicio si existe
    final lastIndex = state.restTimer.lastCompletedExerciseIndex;
    int restTime;
    if (lastIndex != null) {
      restTime = _getSupersetRestTime(lastIndex);
    } else {
      restTime = state.defaultRestSeconds;
    }

    final endTime = DateTime.now().add(Duration(seconds: restTime));

    state = state.copyWith(
      restTimer: state.restTimer.copyWith(
        isActive: true,
        isPaused: false,
        totalSeconds: restTime,
        endTime: endTime,
      ),
    );
    _saveState();
    _saveRestTimerToPrefs();

    // Reiniciar timer en servicio de plataforma
    _timerPlatformService.start(
      seconds: restTime,
      exerciseIndex: lastIndex,
      setIndex: state.restTimer.lastCompletedSetIndex,
    );
  }

  /// Actualiza el tiempo de descanso sugerido para un ejercicio específico
  void updateExerciseRestTime(int exerciseIndex, int seconds) {
    final exercises = [...state.exercises];
    final exercise = exercises[exerciseIndex];

    exercises[exerciseIndex] = exercise.copyWith(descansoSugeridoSeconds: seconds);
    state = state.copyWith(exercises: exercises);
    _saveState();
  }

  Future<void> finishSession() async {
    // Modified to allow saving sessions without a routine (Ad-hoc)
    if (state.startTime == null) return;
    if (state.exercises.isEmpty) return; // Should not save empty session

    // Forzar save pendiente antes de finalizar
    await flushPendingSave();

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

    // Cancelar cualquier debouncer pendiente
    _saveDebouncer.cancel();

    state = TrainingState();
    ref.read(bottomNavIndexProvider.notifier).state = 2;
  }

  // --- Persistence ---

  /// Guarda el estado con debounce para evitar saves excesivos durante input rápido.
  /// Use _saveStateImmediate() para saves que necesitan ser inmediatos.
  void _saveState() {
    _hasPendingSave = true;
    _saveDebouncer.run(() {
      _saveStateImmediate();
    });
  }

  /// Guarda el estado inmediatamente sin debounce.
  /// Usar para eventos importantes como completar un set o terminar sesión.
  Future<void> _saveStateImmediate() async {
    _hasPendingSave = false;

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
      // Persist rest timer to SharedPreferences (separate key)
      await _saveRestTimerToPrefs();
    } catch (e) {
      Logger().e('Error saving session state', error: e);
    }
  }

  /// Fuerza el save si hay uno pendiente (llamar antes de operaciones críticas)
  Future<void> flushPendingSave() async {
    if (_hasPendingSave) {
      _saveDebouncer.cancel();
      await _saveStateImmediate();
    }
  }

  Future<void> clearStorage() async {
    await _repository.clearActiveSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('rest_timer');
  }

  Future<void> _saveRestTimerToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rt = state.restTimer;
      if (!rt.isActive) {
        await prefs.remove('rest_timer');
        return;
      }

      final map = {
        'isActive': rt.isActive,
        'isPaused': rt.isPaused,
        'totalSeconds': rt.totalSeconds,
        'endTimeMs': rt.endTime?.millisecondsSinceEpoch,
        'lastExerciseIndex': rt.lastCompletedExerciseIndex,
        'lastSetIndex': rt.lastCompletedSetIndex,
      };

      await prefs.setString('rest_timer', json.encode(map));
    } catch (e) {
      Logger().e('Error saving rest timer to prefs', error: e);
    }
  }

  Future<void> _loadRestTimerFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('rest_timer');
      if (s == null) return;
      final Map<String, dynamic> m = json.decode(s);

      final bool isActive = m['isActive'] == true;
      final bool isPaused = m['isPaused'] == true;
      final int totalSeconds = (m['totalSeconds'] as num?)?.toInt() ?? state.defaultRestSeconds;
      final int? endTimeMs = (m['endTimeMs'] as num?)?.toInt();
      final int? lastExerciseIndex = (m['lastExerciseIndex'] as num?)?.toInt();
      final int? lastSetIndex = (m['lastSetIndex'] as num?)?.toInt();

      DateTime? endTime;
      if (endTimeMs != null) endTime = DateTime.fromMillisecondsSinceEpoch(endTimeMs);

      // Restore into state only if active and endTime in future or paused
      if (isActive) {
        var rt = RestTimerState(
          isActive: true,
          isPaused: isPaused,
          totalSeconds: totalSeconds,
          endTime: endTime,
          lastCompletedExerciseIndex: lastExerciseIndex,
          lastCompletedSetIndex: lastSetIndex,
        );

        // If not paused and endTime in past, treat as finished
        if (!rt.isPaused && rt.endTime != null && rt.remainingSeconds <= 0) {
          // Timer already finished while app was closed
          // We call onTimerFinished behavior: stop and trigger the callbacks when appropriate in UI
          rt = const RestTimerState(isActive: false);
        }

        state = state.copyWith(
          restTimer: rt,
          isRestActive: rt.isActive,
        );
      }
    } catch (e) {
      Logger().e('Error loading rest timer from prefs', error: e);
    }
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
        isRestActive: false, // Do not restore timer active flag until we check prefs
        history: data.history,
        showAdvancedOptions: false,
      );

        // Try to restore active rest timer from SharedPreferences
        await _loadRestTimerFromPrefs();
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

  // Si no hay historial, sugerir el primer día con ejercicios de la primera rutina
  if (lastUsedRutina == null) {
    final firstRutina = rutinas.first;
    if (firstRutina.dias.isEmpty) return null;
    // Buscar primer día que tenga ejercicios
    final firstValidDayIndex = firstRutina.dias.indexWhere((d) => d.ejercicios.isNotEmpty);
    if (firstValidDayIndex == -1) return null; // No hay días con ejercicios
    return SmartWorkoutSuggestion(
      rutina: firstRutina,
      dayIndex: firstValidDayIndex,
      dayName: firstRutina.dias[firstValidDayIndex].nombre,
      reason: 'Comienza tu rutina',
    );
  }

  // Calcular siguiente día basado en el último entrenado
  if (lastSession != null && lastUsedRutina.dias.isNotEmpty) {
    final lastDayIndex = lastSession.dayIndex ?? -1;
    final totalDays = lastUsedRutina.dias.length;

    // Buscar siguiente día que tenga ejercicios (saltando días vacíos)
    int nextDayIndex = (lastDayIndex + 1) % totalDays;
    int attempts = 0;
    while (lastUsedRutina.dias[nextDayIndex].ejercicios.isEmpty && attempts < totalDays) {
      nextDayIndex = (nextDayIndex + 1) % totalDays;
      attempts++;
    }
    
    // Si todos los días están vacíos, no sugerir nada
    if (attempts >= totalDays) return null;
    
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
