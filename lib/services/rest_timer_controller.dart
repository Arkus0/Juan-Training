import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ejercicio.dart';
import 'timer_platform_service.dart';

/// Controlador de timer de descanso extraído de TrainingSessionNotifier.
///
/// Responsabilidades:
/// - Gestión del estado del timer (start/stop/pause/resume)
/// - Lógica de superseries para decidir cuándo iniciar timer
/// - Persistencia del estado del timer en SharedPreferences
/// - Comunicación con TimerPlatformService (notificación Android)
///
/// NO responsable de:
/// - Estado de ejercicios/sets
/// - Persistencia de la sesión completa
/// - Navegación o UI
class RestTimerController {
  final TimerPlatformService _platformService;
  final Logger _logger = Logger();

  StreamSubscription<TimerPlatformEvent>? _eventSubscription;
  bool _initialized = false;

  /// Callback para notificar al notifier de cambios de estado
  void Function(RestTimerState)? onStateChanged;

  /// Callback cuando el timer terminó mientras la app estaba cerrada
  void Function()? onTimerFinishedWhileAway;

  /// Estado actual del timer
  RestTimerState _state = const RestTimerState();
  RestTimerState get state => _state;

  /// Flag para indicar que el timer terminó mientras la app estaba cerrada
  bool _timerFinishedWhileAway = false;
  bool get timerFinishedWhileAway => _timerFinishedWhileAway;

  void clearTimerFinishedWhileAway() {
    _timerFinishedWhileAway = false;
  }

  RestTimerController({
    TimerPlatformService? platformService,
  }) : _platformService = platformService ?? TimerPlatformService.instance;

  /// Inicializa el controlador y configura listeners
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _platformService.initialize();
      _initialized = true;

      // Escuchar eventos del servicio de plataforma (botones de notificación)
      _eventSubscription = _platformService.eventStream.listen(_handlePlatformEvent);

      _logger.d('RestTimerController inicializado');
    } catch (e) {
      _logger.e('Error inicializando RestTimerController', error: e);
    }
  }

  /// Maneja eventos del timer de plataforma (desde notificación Android)
  void _handlePlatformEvent(TimerPlatformEvent event) {
    switch (event) {
      case TimerPlatformEvent.pause:
        _handlePauseFromPlatform();
        break;
      case TimerPlatformEvent.resume:
        _handleResumeFromPlatform();
        break;
      case TimerPlatformEvent.skip:
        stop(saveRestTime: true);
        break;
      case TimerPlatformEvent.add30:
        addTime(30);
        break;
      case TimerPlatformEvent.finished:
        stop(saveRestTime: true);
        break;
    }
  }

  void _handlePauseFromPlatform() {
    if (_state.isActive && !_state.isPaused) {
      final remaining = _state.remainingSeconds.ceil();
      _updateState(_state.copyWith(
        isPaused: true,
        totalSeconds: remaining,
        clearEndTime: true,
      ));
    }
  }

  void _handleResumeFromPlatform() {
    if (_state.isActive && _state.isPaused) {
      final endTime = DateTime.now().add(Duration(seconds: _state.totalSeconds));
      _updateState(_state.copyWith(
        isPaused: false,
        endTime: endTime,
      ));
    }
  }

  /// Verifica si el ejercicio es el último de su superset que tiene sets pendientes.
  /// Retorna true si debe iniciar el timer, false si hay más ejercicios en el superset.
  bool shouldStartTimerForSuperset({
    required int exerciseIndex,
    required int setIndex,
    required List<Ejercicio> exercises,
  }) {
    if (exerciseIndex < 0 || exerciseIndex >= exercises.length) return true;

    final exercise = exercises[exerciseIndex];

    // Si no está en superset, siempre iniciar timer
    if (!exercise.isInSuperset) return true;

    final supersetId = exercise.supersetId!;

    // Encontrar todos los ejercicios del mismo superset
    final supersetExercises = <int>[];
    for (int i = 0; i < exercises.length; i++) {
      if (exercises[i].supersetId == supersetId) {
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
    // tiene el mismo set (round) pendiente
    final nextInSuperset = supersetExercises[currentPositionInSuperset + 1];
    final nextExercise = exercises[nextInSuperset];

    if (setIndex < nextExercise.logs.length && nextExercise.logs[setIndex].completed) {
      // La ronda ya fue completada, verificar si hay más rondas
      final allRoundsComplete = supersetExercises.every((idx) {
        final ex = exercises[idx];
        return setIndex >= ex.logs.length - 1 || ex.logs[setIndex].completed;
      });
      return allRoundsComplete;
    }

    // El siguiente ejercicio del superset tiene ese set pendiente, no iniciar timer
    return false;
  }

  /// Obtiene el tiempo de descanso sugerido para un superset (del último ejercicio)
  int getSupersetRestTime({
    required int exerciseIndex,
    required List<Ejercicio> exercises,
    required int defaultRestSeconds,
  }) {
    if (exerciseIndex < 0 || exerciseIndex >= exercises.length) {
      return defaultRestSeconds;
    }

    final exercise = exercises[exerciseIndex];

    if (!exercise.isInSuperset) {
      return exercise.descansoSugeridoSeconds ?? defaultRestSeconds;
    }

    final supersetId = exercise.supersetId!;

    // Buscar el último ejercicio del superset para usar su descanso
    int? lastSupersetRestTime;
    for (int i = exercises.length - 1; i >= 0; i--) {
      if (exercises[i].supersetId == supersetId) {
        lastSupersetRestTime = exercises[i].descansoSugeridoSeconds;
        break;
      }
    }

    return lastSupersetRestTime ?? defaultRestSeconds;
  }

  /// Inicia el timer de descanso
  void start({
    required int seconds,
    int? exerciseIndex,
    int? setIndex,
  }) {
    final endTime = DateTime.now().add(Duration(seconds: seconds));

    _updateState(RestTimerState(
      isActive: true,
      isPaused: false,
      totalSeconds: seconds,
      endTime: endTime,
      lastCompletedExerciseIndex: exerciseIndex,
      lastCompletedSetIndex: setIndex,
    ));

    // Iniciar timer en servicio de plataforma (notificación Android)
    _platformService.start(
      seconds: seconds,
      exerciseIndex: exerciseIndex,
      setIndex: setIndex,
    );
  }

  /// Detiene el timer de descanso
  /// Retorna el tiempo real descansado (para analytics)
  int? stop({bool saveRestTime = true}) {
    int? actualRestTime;

    if (saveRestTime && _state.isActive) {
      final totalTime = _state.totalSeconds;
      final remainingTime = _state.remainingSeconds.ceil();
      actualRestTime = totalTime - remainingTime;

      // Solo retornar si descansó al menos un poco
      if (actualRestTime <= 0) actualRestTime = null;
    }

    _updateState(const RestTimerState(isActive: false));
    _platformService.stop();

    return actualRestTime;
  }

  /// Pausa el timer de descanso (guarda el tiempo restante)
  void pause() {
    if (!_state.isActive || _state.isPaused) return;

    final remaining = _state.remainingSeconds.ceil();
    _updateState(_state.copyWith(
      isPaused: true,
      totalSeconds: remaining,
      clearEndTime: true,
    ));

    _platformService.pause();
  }

  /// Reanuda el timer de descanso desde donde estaba pausado
  void resume() {
    if (!_state.isActive || !_state.isPaused) return;

    final endTime = DateTime.now().add(Duration(seconds: _state.totalSeconds));
    _updateState(_state.copyWith(
      isPaused: false,
      endTime: endTime,
    ));

    _platformService.resume();
  }

  /// Añade tiempo al timer actual
  void addTime(int seconds) {
    if (!_state.isActive) return;

    final newTotal = _state.totalSeconds + seconds;
    if (_state.isPaused) {
      _updateState(_state.copyWith(totalSeconds: newTotal));
    } else {
      final newEndTime = _state.endTime?.add(Duration(seconds: seconds));
      _updateState(_state.copyWith(
        totalSeconds: newTotal,
        endTime: newEndTime,
      ));
    }

    _platformService.addTime(seconds);
  }

  /// Reinicia el timer al tiempo especificado
  void restart(int seconds) {
    final endTime = DateTime.now().add(Duration(seconds: seconds));

    _updateState(_state.copyWith(
      isActive: true,
      isPaused: false,
      totalSeconds: seconds,
      endTime: endTime,
    ));

    _platformService.start(
      seconds: seconds,
      exerciseIndex: _state.lastCompletedExerciseIndex,
      setIndex: _state.lastCompletedSetIndex,
    );
  }

  // --- Persistencia en SharedPreferences ---

  Future<void> saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_state.isActive) {
        await prefs.remove('rest_timer');
        return;
      }

      final map = {
        'isActive': _state.isActive,
        'isPaused': _state.isPaused,
        'totalSeconds': _state.totalSeconds,
        'endTimeMs': _state.endTime?.millisecondsSinceEpoch,
        'lastExerciseIndex': _state.lastCompletedExerciseIndex,
        'lastSetIndex': _state.lastCompletedSetIndex,
      };

      await prefs.setString('rest_timer', json.encode(map));
    } catch (e) {
      _logger.e('Error saving rest timer to prefs', error: e);
    }
  }

  Future<void> loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('rest_timer');
      if (s == null) return;

      final Map<String, dynamic> m = json.decode(s);

      final bool isActive = m['isActive'] == true;
      final bool isPaused = m['isPaused'] == true;
      final int totalSeconds = (m['totalSeconds'] as num?)?.toInt() ?? 90;
      final int? endTimeMs = (m['endTimeMs'] as num?)?.toInt();
      final int? lastExerciseIndex = (m['lastExerciseIndex'] as num?)?.toInt();
      final int? lastSetIndex = (m['lastSetIndex'] as num?)?.toInt();

      DateTime? endTime;
      if (endTimeMs != null) endTime = DateTime.fromMillisecondsSinceEpoch(endTimeMs);

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
          _timerFinishedWhileAway = true;
          rt = const RestTimerState(isActive: false);
          onTimerFinishedWhileAway?.call();
          _logger.d('Timer había terminado mientras app cerrada - notificando');
        }

        _state = rt;
        onStateChanged?.call(_state);
      }
    } catch (e) {
      _logger.e('Error loading rest timer from prefs', error: e);
    }
  }

  Future<void> clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('rest_timer');
  }

  void _updateState(RestTimerState newState) {
    _state = newState;
    onStateChanged?.call(_state);
    saveToPrefs();
  }

  void dispose() {
    _eventSubscription?.cancel();
  }
}

/// Estado avanzado del timer de descanso.
///
/// Nota: Esta clase se mantiene aquí para preservar la API existente.
/// TrainingSessionNotifier seguirá exponiendo RestTimerState en su estado.
class RestTimerState {
  final bool isActive;
  final bool isPaused;
  final int totalSeconds;
  final DateTime? endTime;
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
    if (isPaused) return totalSeconds.toDouble();
    final remaining = endTime!.difference(DateTime.now()).inMilliseconds / 1000.0;
    return remaining > 0 ? remaining : 0;
  }

  /// Progreso del timer (0.0 a 1.0)
  double get progress {
    if (totalSeconds <= 0) return 1.0;
    return 1.0 - (remainingSeconds / totalSeconds);
  }
}
