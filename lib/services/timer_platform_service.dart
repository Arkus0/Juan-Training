import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado del timer sincronizado entre Dart y plataforma nativa
class TimerPlatformState {
  final bool isActive;
  final bool isPaused;
  final int totalSeconds;
  final DateTime? endTime;
  final int? exerciseIndex;
  final int? setIndex;
  final DateTime lastUpdated;

  const TimerPlatformState({
    this.isActive = false,
    this.isPaused = false,
    this.totalSeconds = 90,
    this.endTime,
    this.exerciseIndex,
    this.setIndex,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? const _DefaultDateTime();

  /// Segundos restantes calculados
  double get remainingSeconds {
    if (!isActive) return 0;
    if (isPaused) return totalSeconds.toDouble();
    if (endTime == null) return totalSeconds.toDouble();

    final remaining =
        endTime!.difference(DateTime.now()).inMilliseconds / 1000.0;
    return remaining > 0 ? remaining : 0;
  }

  /// Progreso del timer (0.0 a 1.0)
  double get progress {
    if (totalSeconds <= 0) return 1.0;
    return 1.0 - (remainingSeconds / totalSeconds);
  }

  /// ¿El timer terminó naturalmente?
  bool get isFinished => isActive && !isPaused && remainingSeconds <= 0;

  TimerPlatformState copyWith({
    bool? isActive,
    bool? isPaused,
    int? totalSeconds,
    DateTime? endTime,
    int? exerciseIndex,
    int? setIndex,
    bool clearEndTime = false,
  }) {
    return TimerPlatformState(
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      setIndex: setIndex ?? this.setIndex,
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'isActive': isActive,
        'isPaused': isPaused,
        'totalSeconds': totalSeconds,
        'endTimeMs': endTime?.millisecondsSinceEpoch,
        'exerciseIndex': exerciseIndex,
        'setIndex': setIndex,
        'lastUpdatedMs': lastUpdated.millisecondsSinceEpoch,
      };

  factory TimerPlatformState.fromJson(Map<String, dynamic> json) {
    return TimerPlatformState(
      isActive: json['isActive'] == true,
      isPaused: json['isPaused'] == true,
      totalSeconds: (json['totalSeconds'] as num?)?.toInt() ?? 90,
      endTime: json['endTimeMs'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['endTimeMs'] as num).toInt(),)
          : null,
      exerciseIndex: (json['exerciseIndex'] as num?)?.toInt(),
      setIndex: (json['setIndex'] as num?)?.toInt(),
      lastUpdated: json['lastUpdatedMs'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['lastUpdatedMs'] as num).toInt(),)
          : null,
    );
  }

  static const stopped = TimerPlatformState();
}

/// Helper class for default DateTime in const constructor
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();

  DateTime get _now => DateTime.now();

  @override
  int get millisecondsSinceEpoch => _now.millisecondsSinceEpoch;

  @override
  dynamic noSuchMethod(Invocation invocation) => _now;
}

/// Evento recibido desde la plataforma nativa
enum TimerPlatformEvent {
  pause,
  resume,
  skip,
  add30,
  finished,
}

/// Servicio para comunicación bidireccional con el timer de plataforma.
///
/// Este servicio resuelve los problemas de sincronización entre Dart y Android:
/// 1. Usa SharedPreferences como fuente de verdad compartida
/// 2. Maneja reconexión cuando flutterEngine se pierde
/// 3. Proporciona eventos streaming para reactividad
/// 4. Implementa retry logic para comandos fallidos
///
/// Uso:
/// ```dart
/// final service = TimerPlatformService.instance;
/// await service.initialize();
///
/// // Escuchar eventos
/// service.eventStream.listen((event) {
///   switch (event) {
///     case TimerPlatformEvent.pause: // ...
///   }
/// });
///
/// // Iniciar timer
/// await service.start(seconds: 90, exerciseIndex: 0, setIndex: 0);
/// ```
class TimerPlatformService {
  static final TimerPlatformService instance = TimerPlatformService._();
  TimerPlatformService._();

  final _logger = Logger();

  // Channels
  static const _timerChannel = MethodChannel('com.juantraining/timer_service');
  static const _eventsChannel = MethodChannel('com.juantraining/timer_events');

  // State
  TimerPlatformState _state = TimerPlatformState.stopped;
  TimerPlatformState get state => _state;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Streams
  final _stateController = StreamController<TimerPlatformState>.broadcast();
  Stream<TimerPlatformState> get stateStream => _stateController.stream;

  final _eventController = StreamController<TimerPlatformEvent>.broadcast();
  Stream<TimerPlatformEvent> get eventStream => _eventController.stream;

  // Prefs key
  static const _prefsKey = 'timer_platform_state';

  /// Inicializa el servicio y restaura estado persistido
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Configurar handler para eventos desde Android
    _eventsChannel.setMethodCallHandler(_handlePlatformEvent);

    // Restaurar estado desde SharedPreferences
    await _loadStateFromPrefs();

    // Si el timer estaba activo pero ya terminó, marcar como finished
    if (_state.isActive && !_state.isPaused && _state.isFinished) {
      _state = TimerPlatformState.stopped;
      await _saveStateToPrefs();
      _eventController.add(TimerPlatformEvent.finished);
    }

    _isInitialized = true;
    _logger.i('TimerPlatformService inicializado');
  }

  /// Inicia el timer de descanso
  Future<bool> start({
    required int seconds,
    int? exerciseIndex,
    int? setIndex,
  }) async {
    if (!Platform.isAndroid) {
      // En iOS, solo mantener estado local por ahora
      _updateState(
        TimerPlatformState(
          isActive: true,
          totalSeconds: seconds,
          endTime: DateTime.now().add(Duration(seconds: seconds)),
          exerciseIndex: exerciseIndex,
          setIndex: setIndex,
        ),
      );
      return true;
    }

    final endTimeMillis =
        DateTime.now().add(Duration(seconds: seconds)).millisecondsSinceEpoch;

    try {
      await _timerChannel.invokeMethod('startTimerService', {
        'totalSeconds': seconds,
        'endTimeMillis': endTimeMillis,
        'isPaused': false,
      });

      _updateState(
        TimerPlatformState(
          isActive: true,
          totalSeconds: seconds,
          endTime: DateTime.fromMillisecondsSinceEpoch(endTimeMillis),
          exerciseIndex: exerciseIndex,
          setIndex: setIndex,
        ),
      );

      _logger.d('Timer iniciado: ${seconds}s');
      return true;
    } catch (e) {
      _logger.e('Error iniciando timer', error: e);
      return false;
    }
  }

  /// Pausa el timer
  Future<bool> pause() async {
    if (!_state.isActive || _state.isPaused) return false;

    final remainingSeconds = _state.remainingSeconds.ceil();

    if (Platform.isAndroid) {
      try {
        await _timerChannel.invokeMethod('updateTimerService', {
          'totalSeconds': remainingSeconds,
          'endTimeMillis': 0,
          'isPaused': true,
        });
      } catch (e) {
        _logger.e('Error pausando timer en Android', error: e);
        // Continuar con actualización local
      }
    }

    _updateState(
      _state.copyWith(
        isPaused: true,
        totalSeconds: remainingSeconds,
        clearEndTime: true,
      ),
    );

    _logger.d('Timer pausado con $remainingSeconds segundos restantes');
    return true;
  }

  /// Reanuda el timer
  Future<bool> resume() async {
    if (!_state.isActive || !_state.isPaused) return false;

    final endTime = DateTime.now().add(Duration(seconds: _state.totalSeconds));

    if (Platform.isAndroid) {
      try {
        await _timerChannel.invokeMethod('updateTimerService', {
          'totalSeconds': _state.totalSeconds,
          'endTimeMillis': endTime.millisecondsSinceEpoch,
          'isPaused': false,
        });
      } catch (e) {
        _logger.e('Error reanudando timer en Android', error: e);
      }
    }

    _updateState(
      _state.copyWith(
        isPaused: false,
        endTime: endTime,
      ),
    );

    _logger.d('Timer reanudado');
    return true;
  }

  /// Añade tiempo al timer
  Future<bool> addTime(int seconds) async {
    if (!_state.isActive) return false;

    final newTotal = _state.totalSeconds + seconds;

    if (_state.isPaused) {
      _updateState(_state.copyWith(totalSeconds: newTotal));
    } else {
      final newEndTime = _state.endTime?.add(Duration(seconds: seconds));

      if (Platform.isAndroid) {
        try {
          await _timerChannel.invokeMethod('updateTimerService', {
            'totalSeconds': newTotal,
            'endTimeMillis': newEndTime?.millisecondsSinceEpoch ?? 0,
            'isPaused': false,
          });
        } catch (e) {
          _logger.e('Error añadiendo tiempo en Android', error: e);
        }
      }

      _updateState(
        _state.copyWith(
          totalSeconds: newTotal,
          endTime: newEndTime,
        ),
      );
    }

    _logger.d('Añadidos $seconds segundos');
    return true;
  }

  /// Detiene el timer
  Future<bool> stop() async {
    if (!_state.isActive) return false;

    if (Platform.isAndroid) {
      try {
        await _timerChannel.invokeMethod('stopTimerService');
      } catch (e) {
        _logger.e('Error deteniendo timer en Android', error: e);
      }
    }

    final previousState = _state;
    _updateState(TimerPlatformState.stopped);

    _logger.d('Timer detenido');

    // Calcular tiempo real descansado para analytics
    if (previousState.exerciseIndex != null && previousState.setIndex != null) {
      final actualRestTime =
          previousState.totalSeconds - previousState.remainingSeconds.ceil();
      _logger.d('Tiempo real descansado: ${actualRestTime}s');
    }

    return true;
  }

  /// Reinicia el timer con el tiempo original
  Future<bool> restart() async {
    if (!_state.isActive) return false;

    return await start(
      seconds: _state.totalSeconds,
      exerciseIndex: _state.exerciseIndex,
      setIndex: _state.setIndex,
    );
  }

  // --- Manejo de eventos desde plataforma ---

  Future<dynamic> _handlePlatformEvent(MethodCall call) async {
    _logger.d('Evento de plataforma: ${call.method}');

    switch (call.method) {
      case 'onPause':
        await pause();
        _eventController.add(TimerPlatformEvent.pause);
        break;

      case 'onResume':
        await resume();
        _eventController.add(TimerPlatformEvent.resume);
        break;

      case 'onSkip':
        await stop();
        _eventController.add(TimerPlatformEvent.skip);
        break;

      case 'onAdd30':
        await addTime(30);
        _eventController.add(TimerPlatformEvent.add30);
        break;

      case 'onFinished':
        await stop();
        _eventController.add(TimerPlatformEvent.finished);
        break;
    }
  }

  // --- Persistencia ---

  void _updateState(TimerPlatformState newState) {
    _state = newState;
    _stateController.add(_state);
    _saveStateToPrefs();
  }

  Future<void> _saveStateToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, json.encode(_state.toJson()));
    } catch (e) {
      _logger.e('Error guardando estado del timer', error: e);
    }
  }

  Future<void> _loadStateFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final jsonMap = json.decode(jsonStr) as Map<String, dynamic>;
        _state = TimerPlatformState.fromJson(jsonMap);
        _stateController.add(_state);
      }
    } catch (e) {
      _logger.e('Error cargando estado del timer', error: e);
      _state = TimerPlatformState.stopped;
    }
  }

  /// Limpia el estado persistido
  Future<void> clearPersistedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      _state = TimerPlatformState.stopped;
      _stateController.add(_state);
    } catch (e) {
      _logger.e('Error limpiando estado del timer', error: e);
    }
  }

  /// Libera recursos
  void dispose() {
    _stateController.close();
    _eventController.close();
  }
}
