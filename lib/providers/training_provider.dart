import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import '../models/rutina.dart';
import '../models/ejercicio.dart';
import '../models/ejercicio_en_rutina.dart';
import '../models/sesion.dart';
import '../models/serie_log.dart';
import '../models/progression_engine_models.dart';
import '../models/library_exercise.dart';
import 'main_provider.dart';
import '../repositories/i_training_repository.dart';
import '../services/error_tolerance_system.dart';
import '../services/rest_timer_controller.dart';
import '../services/session_persistence_service.dart';
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

// RestTimerState importado desde rest_timer_controller.dart

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
  final Map<String, List<SerieLog>> history; // Key: Ejercicio.historyKey, Value: Last Session Logs
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

  /// Obtiene el índice del siguiente set no completado (para auto-focus).
  ///
  /// Nota: Itera en orden lineal por índice de ejercicio. Si el usuario añade
  /// ejercicios dinámicamente y luego edita ejercicios anteriores, el auto-focus
  /// siempre irá al primer set no completado en orden de lista, lo cual puede
  /// resultar en saltos de foco no intuitivos en algunos casos edge.
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

  /// Controlador de timer de descanso (delegación de responsabilidad)
  late final RestTimerController _timerController;

  /// Servicio de persistencia (delegación de responsabilidad)
  late final SessionPersistenceService _persistenceService;

  TrainingSessionNotifier(this.ref, this._repository) : super(TrainingState()) {
    _initializeServices();
  }

  /// Inicializa los servicios delegados
  Future<void> _initializeServices() async {
    // Inicializar controlador de timer
    _timerController = RestTimerController();
    _timerController.onStateChanged = _onTimerStateChanged;
    _timerController.onTimerFinishedWhileAway = () {
      // Timer terminó mientras app cerrada - el getter lo expondrá al UI
    };
    await _timerController.initialize();

    // Inicializar servicio de persistencia
    _persistenceService = SessionPersistenceService(_repository);
    _persistenceService.getSessionData = _getCurrentSessionData;
  }

  /// Callback cuando el timer cambia de estado
  void _onTimerStateChanged(RestTimerState timerState) {
    state = state.copyWith(
      restTimer: timerState,
      isRestActive: timerState.isActive,
    );
  }

  /// Obtiene los datos de sesión actuales para persistencia
  ActiveSessionData _getCurrentSessionData() {
    return ActiveSessionData(
      activeRutina: state.activeRutina,
      exercises: state.exercises,
      targets: state.targets,
      startTime: state.startTime,
      defaultRestSeconds: state.defaultRestSeconds,
      history: state.history,
    );
  }

  /// Getter para que el UI pueda verificar si el timer terminó mientras estaba cerrado
  bool get timerFinishedWhileAway => _timerController.timerFinishedWhileAway;

  /// Limpia el flag de timer terminado (llamar después de mostrar feedback)
  void clearTimerFinishedWhileAway() {
    _timerController.clearTimerFinishedWhileAway();
  }

  @override
  void dispose() {
    _timerController.dispose();
    _persistenceService.dispose();
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
           historyMap[ex.historyKey] = match.logs;
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
    if (exerciseIndex < 0 || exerciseIndex >= state.exercises.length) {
      Logger().w('updateLog: invalid exerciseIndex $exerciseIndex');
      return;
    }

    final exercises = [...state.exercises];
    final exercise = exercises[exerciseIndex];
    if (setIndex < 0 || setIndex >= exercise.logs.length) {
      Logger().w('updateLog: invalid setIndex $setIndex for exercise ${exercise.nombre}');
      return;
    }
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
      final lastKnownWeight = log.peso > 0 ? log.peso : _getLastKnownWeight(exercise);
      
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

    // ═══════════════════════════════════════════════════════════════════════
    // HARD LIMITS: Forzar límites absolutos para proteger integridad de datos
    // Esto evita que outliers arruinen gráficas y análisis
    // ═══════════════════════════════════════════════════════════════════════
    final finalPeso = ErrorToleranceRules.enforceWeightLimits(validatedPeso ?? log.peso);
    final finalReps = ErrorToleranceRules.enforceRepsLimits(reps ?? log.reps);

    final newLog = SerieLog(
      id: log.id, // Preserve UUID
      peso: finalPeso,
      reps: finalReps,
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
  double _getLastKnownWeight(Ejercicio exercise) {
    final historyLogs = state.history[exercise.historyKey];
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

  /// Añade una serie adicional a un ejercicio durante la sesión
  void addSetToExercise(int exerciseIndex) {
    if (exerciseIndex >= state.exercises.length) return;

    final exercises = [...state.exercises];
    final exercise = exercises[exerciseIndex];

    // Crear una nueva serie vacía (o copiando peso/reps de la última si existe)
    SerieLog newLog;
    if (exercise.logs.isNotEmpty) {
      final lastLog = exercise.logs.last;
      newLog = SerieLog(
        peso: lastLog.peso,
        reps: lastLog.reps,
        completed: false,
      );
    } else {
      newLog = SerieLog(peso: 0.0, reps: 0, completed: false);
    }

    final newLogs = [...exercise.logs, newLog];
    final newExercise = exercise.copyWith(
      logs: newLogs,
      series: newLogs.length,
    );
    exercises[exerciseIndex] = newExercise;

    // NO actualizamos targets - la rutina original permanece intacta
    // Esto permite que la sesión sea flexible sin afectar futuros entrenamientos

    state = state.copyWith(exercises: exercises);
    _saveState();
  }

  /// Elimina una serie de un ejercicio durante la sesión activa
  ///
  /// 🎯 FIX #2: Ahora permite eliminar TODAS las series de un ejercicio.
  /// Si el ejercicio se queda sin series, se elimina de la sesión.
  ///
  /// IMPORTANTE: Solo afecta a la sesión actual, NO modifica:
  /// - La rutina base (targets permanecen intactos)
  /// - Futuros entrenamientos
  /// - El motor de progresión (usa ejerciciosCompletados, no targets)
  void removeSetFromExercise(int exerciseIndex, int setIndex) {
    if (exerciseIndex >= state.exercises.length) return;

    final exercises = [...state.exercises];
    final exercise = exercises[exerciseIndex];

    // Protección: índice válido
    if (setIndex < 0 || setIndex >= exercise.logs.length) return;

    final newLogs = [...exercise.logs]..removeAt(setIndex);

    // 🎯 FIX #2: Si el ejercicio se queda sin series, eliminarlo de la sesión
    // pero NO de targets (la rutina original permanece intacta para futuros entrenamientos)
    if (newLogs.isEmpty) {
      exercises.removeAt(exerciseIndex);
      // targets NO se modifica - la rutina base permanece intacta
      state = state.copyWith(exercises: exercises);
      _saveState();
      return;
    }

    final newExercise = exercise.copyWith(
      logs: newLogs,
      series: newLogs.length,
    );
    exercises[exerciseIndex] = newExercise;

    // NO tocamos targets - la rutina original permanece intacta
    state = state.copyWith(exercises: exercises);
    _saveState();
  }

  /// Añade un ejercicio a la sesión activa desde la biblioteca
  Future<void> addExerciseToSession(LibraryExercise libExercise, {int series = 3, int reps = 10}) async {
    final newExercise = Ejercicio(
      id: const Uuid().v4(),
      libraryId: libExercise.id.toString(),
      nombre: libExercise.name,
      musculosPrincipales: libExercise.muscles,
      musculosSecundarios: libExercise.secondaryMuscles,
      series: series,
      reps: reps,
      logs: List.generate(series, (_) => SerieLog(
        peso: 0.0,
        reps: 0,
        completed: false,
      )),
    );

    final exercises = [...state.exercises, newExercise];
    final targets = [...state.targets, newExercise.copyWith()];

    final historyMap = Map<String, List<SerieLog>>.from(state.history);
    final historyList = await _repository.getHistoryForExercise(newExercise.nombre);
    if (historyList.isNotEmpty) {
      final lastSession = historyList.first;
      final match = lastSession.ejerciciosCompletados.firstWhereOrNull(
        (e) => e.nombre == newExercise.nombre,
      );
      if (match != null) {
        historyMap[newExercise.historyKey] = match.logs;
      }
    }

    state = state.copyWith(exercises: exercises, targets: targets, history: historyMap);
    _saveState();
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

  // ═══════════════════════════════════════════════════════════════════════════
  // TIMER DE DESCANSO - Delegado a RestTimerController
  // ═══════════════════════════════════════════════════════════════════════════

  /// Inicia el timer de descanso para un ejercicio específico
  /// @param exerciseIndex Índice del ejercicio que acaba de completarse
  /// @param setIndex Índice del set que acaba de completarse (para auto-focus)
  /// @return true si el timer se inició, false si estamos en medio de un superset
  bool startRestForExercise(int exerciseIndex, {int? setIndex}) {
    // Verificar lógica de superseries usando el controlador
    if (setIndex != null && !_timerController.shouldStartTimerForSuperset(
      exerciseIndex: exerciseIndex,
      setIndex: setIndex,
      exercises: state.exercises,
    )) {
      return false;
    }

    final exercise = state.exercises[exerciseIndex];
    int restTime = _timerController.getSupersetRestTime(
      exerciseIndex: exerciseIndex,
      exercises: state.exercises,
      defaultRestSeconds: state.defaultRestSeconds,
    );

    // Fallback: buscar tiempo configurado en la rutina activa
    if (restTime == state.defaultRestSeconds && state.activeRutina != null) {
      for (final day in state.activeRutina!.dias) {
        final match = day.ejercicios.firstWhereOrNull((e) => e.instanceId == exercise.id);
        if (match != null && match.descansoSugerido != null) {
          restTime = match.descansoSugerido!.inSeconds;
          break;
        }
      }
    }

    state = state.copyWith(defaultRestSeconds: restTime);
    _timerController.start(
      seconds: restTime,
      exerciseIndex: exerciseIndex,
      setIndex: setIndex,
    );
    _saveState();
    return true;
  }

  void startRest() {
    _timerController.start(seconds: state.defaultRestSeconds);
    _saveState();
  }

  void stopRest({bool saveRestTime = true}) {
    // Guardar el tiempo de descanso real en el SerieLog (para analytics)
    if (saveRestTime && state.restTimer.isActive) {
      final exerciseIndex = state.restTimer.lastCompletedExerciseIndex;
      final setIndex = state.restTimer.lastCompletedSetIndex;
      if (exerciseIndex != null && setIndex != null) {
        final actualRestTime = _timerController.stop(saveRestTime: true);
        if (actualRestTime != null && actualRestTime > 0) {
          _updateLogRestTime(exerciseIndex, setIndex, actualRestTime);
        }
      } else {
        _timerController.stop(saveRestTime: false);
      }
    } else {
      _timerController.stop(saveRestTime: false);
    }
    _saveState();
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
  }

  void pauseRest() {
    _timerController.pause();
    _saveState();
  }

  void resumeRest() {
    _timerController.resume();
    _saveState();
  }

  void addRestTime(int seconds) {
    _timerController.addTime(seconds);
    _saveState();
  }

  void restartRest() {
    final lastIndex = state.restTimer.lastCompletedExerciseIndex;
    int restTime = lastIndex != null
        ? _timerController.getSupersetRestTime(
            exerciseIndex: lastIndex,
            exercises: state.exercises,
            defaultRestSeconds: state.defaultRestSeconds,
          )
        : state.defaultRestSeconds;
    _timerController.restart(restTime);
    _saveState();
  }

  /// Actualiza el tiempo de descanso sugerido para un ejercicio específico
  void updateExerciseRestTime(int exerciseIndex, int seconds) {
    final exercises = [...state.exercises];
    final exercise = exercises[exerciseIndex];

    exercises[exerciseIndex] = exercise.copyWith(descansoSugeridoSeconds: seconds);
    state = state.copyWith(exercises: exercises);
    _saveState();
  }

  /// Resultado del guardado de sesión para feedback al usuario
  SessionSaveResult? _lastSaveResult;

  /// Getter para obtener el resultado del último guardado
  SessionSaveResult? get lastSaveResult => _lastSaveResult;

  /// Limpia el resultado del guardado (llamar después de mostrar feedback)
  void clearLastSaveResult() {
    _lastSaveResult = null;
  }

  Future<void> finishSession() async {
    if (state.startTime == null) return;
    if (state.exercises.isEmpty) {
      await _persistenceService.clearActiveSession();
      await _timerController.clearPrefs();
      state = TrainingState();
      return;
    }

    await flushPendingSave();

    final endTime = DateTime.now();
    final durationSeconds = endTime.difference(state.startTime!).inSeconds;

    // Contar series completadas para feedback
    int completedSets = 0;
    int totalSets = 0;
    for (final ex in state.exercises) {
      for (final log in ex.logs) {
        totalSets++;
        if (log.completed) completedSets++;
      }
    }

    final sesion = Sesion(
      id: const Uuid().v4(),
      rutinaId: state.activeRutina?.id ?? '',
      dayName: state.dayName,
      dayIndex: state.dayIndex,
      fecha: endTime,
      ejerciciosCompletados: state.exercises,
      ejerciciosObjetivo: state.targets,
      durationSeconds: durationSeconds,
    );

    // Guardar sesión y limpiar de forma atómica
    await _repository.finishAndClearSession(sesion);
    await _timerController.clearPrefs();

    // Guardar resultado para feedback
    _lastSaveResult = SessionSaveResult(
      success: true,
      completedSets: completedSets,
      totalSets: totalSets,
      durationMinutes: durationSeconds ~/ 60,
    );

    state = TrainingState();
    ref.read(bottomNavIndexProvider.notifier).state = 2;
  }

  /// Descarta la sesión activa sin guardarla
  Future<void> discardSession() async {
    // Detener timer si está activo
    if (state.restTimer.isActive) {
      _timerController.stop(saveRestTime: false);
    }

    // Descartar sesión (cancela saves pendientes internamente)
    await _persistenceService.discardSession();
    await _timerController.clearPrefs();

    state = TrainingState();
    Logger().d('Sesión descartada correctamente');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PERSISTENCIA - Delegado a SessionPersistenceService
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda el estado con debounce para evitar saves excesivos
  void _saveState() {
    _persistenceService.saveWithDebounce();
    _timerController.saveToPrefs();
  }

  /// Fuerza el save si hay uno pendiente (llamar antes de operaciones críticas)
  Future<void> flushPendingSave() async {
    await _persistenceService.flushPendingSave();
  }

  Future<void> clearStorage() async {
    await _persistenceService.clearActiveSession();
    await _timerController.clearPrefs();
  }

  Future<void> restoreFromStorage() async {
    final data = await _persistenceService.restoreSession();
    if (data != null) {
      state = TrainingState(
        activeRutina: data.activeRutina,
        exercises: data.exercises,
        targets: data.targets,
        startTime: data.startTime ?? DateTime.now(),
        defaultRestSeconds: data.defaultRestSeconds,
        isRestActive: false,
        history: data.history,
        showAdvancedOptions: false,
      );

      // Restaurar timer desde SharedPreferences
      await _timerController.loadFromPrefs();
      state = state.copyWith(
        restTimer: _timerController.state,
        isRestActive: _timerController.state.isActive,
      );
    }
  }
}

final trainingSessionProvider = StateNotifierProvider<TrainingSessionNotifier, TrainingState>((ref) {
  final repo = ref.watch(trainingRepositoryProvider);
  return TrainingSessionNotifier(ref, repo);
});

/// Resultado del guardado de sesión para feedback visual
class SessionSaveResult {
  final bool success;
  final int completedSets;
  final int totalSets;
  final int durationMinutes;

  const SessionSaveResult({
    required this.success,
    required this.completedSets,
    required this.totalSets,
    required this.durationMinutes,
  });

  double get completionRate => totalSets > 0 ? completedSets / totalSets : 0;
  bool get isComplete => completedSets == totalSets;
}

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
