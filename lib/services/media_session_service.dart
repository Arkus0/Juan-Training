import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import 'haptics_controller.dart';
import 'media_control_service.dart';

/// Servicio que gestiona la MediaSession propia de la app.
///
/// IMPORTANTE: Este servicio SOLO activa el Media Player del sistema
/// cuando detecta música REAL reproduciéndose (Spotify, etc).
/// NO se activa con los beeps del timer.
///
/// Comportamiento:
/// - Escucha cambios en la reproducción de música externa
/// - Solo muestra controles si hay música activa
/// - Se desactiva automáticamente cuando la música se detiene
/// - Respeta el setting mediaControlsEnabled
///
/// Arquitectura:
/// ```
/// MediaControlService (detecta Spotify)
///         │
///         ▼
/// MediaSessionManagerService (decide si mostrar)
///         │
///         ▼
/// MediaSessionService (Android) → Notification MediaStyle
/// ```
///
/// USO:
/// ```dart
/// // Al iniciar entrenamiento - solo conecta el listener
/// MediaSessionManagerService.instance.startMonitoring(
///   trainingName: 'Push Day',
///   enabled: settings.mediaControlsEnabled,
/// );
///
/// // Al terminar entrenamiento - limpia todo
/// MediaSessionManagerService.instance.stopMonitoring();
/// ```
class MediaSessionManagerService {
  static final MediaSessionManagerService instance =
      MediaSessionManagerService._();
  MediaSessionManagerService._();

  final _logger = Logger();

  // Platform channels
  static const _channel = MethodChannel('com.juantraining/media_session');
  static const _eventsChannel =
      MethodChannel('com.juantraining/media_session_events');

  // Estado
  bool _isSessionActive = false;
  bool get isSessionActive => _isSessionActive;

  bool _isMonitoring = false;
  bool _isEnabled = true;
  String? _trainingName;

  // Callbacks para eventos de media buttons
  VoidCallback? onPlayPause;
  VoidCallback? onNext;
  VoidCallback? onPrevious;

  // Stream de eventos
  final _eventController = StreamController<MediaSessionEvent>.broadcast();
  Stream<MediaSessionEvent> get eventStream => _eventController.stream;

  // ════════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ════════════════════════════════════════════════════════════════════════════

  /// Inicializa el servicio y registra handlers de eventos
  void initialize() {
    if (!Platform.isAndroid) return;

    // Registrar handler para eventos desde Android
    _eventsChannel.setMethodCallHandler(_handleMediaEvent);
    _logger.i('MediaSessionManagerService inicializado');
  }

  Future<dynamic> _handleMediaEvent(MethodCall call) async {
    _logger.d('Media event recibido: ${call.method}');

    switch (call.method) {
      case 'onMediaPlayPause':
        final isPlaying = call.arguments?['isPlaying'] as bool? ?? false;
        _eventController.add(MediaSessionEvent.playPause(isPlaying: isPlaying));
        onPlayPause?.call();
        // Haptic feedback
        HapticsController.instance.onMediaCommand();
        break;

      case 'onMediaNext':
        _eventController.add(const MediaSessionEvent.next());
        onNext?.call();
        HapticsController.instance.onMediaCommand();
        break;

      case 'onMediaPrevious':
        _eventController.add(const MediaSessionEvent.previous());
        onPrevious?.call();
        HapticsController.instance.onMediaCommand();
        break;
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CONTROL DE MONITOREO
  // ════════════════════════════════════════════════════════════════════════════

  /// Inicia el monitoreo de música externa.
  /// Solo mostrará controles de media cuando detecte música real reproduciéndose.
  ///
  /// [enabled]: Si es false, no mostrará controles aunque haya música
  void startMonitoring({String? trainingName, bool enabled = true}) {
    if (!Platform.isAndroid) return;
    if (_isMonitoring) return;

    _isMonitoring = true;
    _isEnabled = enabled;
    _trainingName = trainingName;

    _logger.i('Iniciando monitoreo de media (enabled: $enabled)');

    // Conectar listener para detectar música
    _connectMediaListener();

    // Verificar si ya hay música reproduciéndose
    _checkCurrentMediaState();
  }

  /// Detiene el monitoreo y la MediaSession
  Future<void> stopMonitoring() async {
    if (!Platform.isAndroid) return;

    _isMonitoring = false;
    _isEnabled = false;
    _trainingName = null;

    // Desconectar listener
    _mediaSubscription?.cancel();
    _mediaSubscription = null;

    // Detener MediaSession si estaba activa
    await _stopSession();

    _logger.i('Monitoreo de media detenido');
  }

  /// Actualiza si los controles están habilitados (desde settings)
  void setEnabled({required bool enabled}) {
    _isEnabled = enabled;
    if (!enabled && _isSessionActive) {
      _stopSession();
    } else if (enabled && _isMonitoring) {
      _checkCurrentMediaState();
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CONTROL INTERNO DE SESIÓN
  // ════════════════════════════════════════════════════════════════════════════

  /// Inicia la MediaSession (interno - solo cuando hay música)
  Future<bool> _startSession() async {
    if (!Platform.isAndroid) return false;
    if (_isSessionActive) return true;
    if (!_isEnabled) return false;

    try {
      await _channel.invokeMethod('startMediaSession', {
        'trainingName': _trainingName ?? 'Entrenamiento',
      });

      _isSessionActive = true;
      _logger.i('MediaSession activada (música detectada)');

      return true;
    } catch (e) {
      _logger.e('Error iniciando MediaSession', error: e);
      return false;
    }
  }

  /// Detiene la MediaSession (interno)
  Future<void> _stopSession() async {
    if (!Platform.isAndroid) return;
    if (!_isSessionActive) return;

    try {
      await _channel.invokeMethod('stopMediaSession');
      _isSessionActive = false;
      _logger.i('MediaSession desactivada');
    } catch (e) {
      _logger.e('Error deteniendo MediaSession', error: e);
    }
  }

  // Métodos legacy para compatibilidad
  Future<bool> startSession({String? trainingName}) async {
    startMonitoring(trainingName: trainingName);
    return true;
  }

  Future<void> stopSession() => stopMonitoring();

  /// Actualiza el estado de reproducción
  ///
  /// Llamar cuando detectamos que la música cambió de estado
  /// (ej: Spotify pausó/reprodujo)
  Future<void> updatePlaybackState({required bool isPlaying}) async {
    if (!Platform.isAndroid || !_isSessionActive) return;

    try {
      await _channel.invokeMethod('updatePlaybackState', {
        'isPlaying': isPlaying,
      });
    } catch (e) {
      _logger.w('Error actualizando estado de reproducción', error: e);
    }
  }

  /// Actualiza los metadatos mostrados (título, artista)
  ///
  /// Útil para mostrar info de la canción actual de Spotify
  Future<void> updateMetadata({String? title, String? artist}) async {
    if (!Platform.isAndroid || !_isSessionActive) return;

    try {
      await _channel.invokeMethod('updateMetadata', {
        'title': title,
        'artist': artist,
      });
    } catch (e) {
      _logger.w('Error actualizando metadata', error: e);
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DETECCIÓN DE MÚSICA
  // ════════════════════════════════════════════════════════════════════════════

  /// Verifica el estado actual de música
  void _checkCurrentMediaState() {
    final session = MediaControlService.instance.currentSession;
    _handleMediaStateChange(session);
  }

  /// Conecta el listener para detectar cambios en la música
  StreamSubscription<MediaSessionInfo>? _mediaSubscription;

  void _connectMediaListener() {
    _mediaSubscription?.cancel();
    _mediaSubscription = MediaControlService.instance.sessionStream
        .listen(_handleMediaStateChange);
  }

  /// Maneja cambios en el estado de la música
  /// Activa/desactiva MediaSession según si hay música REAL
  void _handleMediaStateChange(MediaSessionInfo session) async {
    if (!_isMonitoring || !_isEnabled) return;

    // Detectar si hay música REAL reproduciéndose
    // (No beeps del timer - esos no tienen packageName de app de música)
    final hasMusicApp =
        session.packageName != null && _isMusicApp(session.packageName!);

    final isPlaying = session.playbackState == MediaPlaybackState.playing;
    final hasRealMusic = hasMusicApp && (isPlaying || session.hasMedia);

    if (hasRealMusic) {
      // Hay música real → activar MediaSession si no está activa
      if (!_isSessionActive) {
        await _startSession();
      }

      // Actualizar estado y metadata
      await updatePlaybackState(isPlaying: isPlaying);
      if (session.hasMedia) {
        await updateMetadata(
          title: session.title,
          artist: session.artist,
        );
      }
    } else {
      // No hay música real → desactivar MediaSession si está activa
      if (_isSessionActive) {
        await _stopSession();
      }
    }
  }

  /// Verifica si el packageName es de una app de música conocida
  bool _isMusicApp(String packageName) {
    // Lista de apps de música comunes
    const musicApps = [
      'com.spotify',
      'com.google.android.apps.youtube.music',
      'com.apple.android.music',
      'com.amazon.mp3',
      'com.pandora.android',
      'com.soundcloud.android',
      'deezer.android.app',
      'com.tidal',
      'com.qobuz.music',
      'com.gaana',
      'com.jiosaavn.saavn',
      // Agregar más según sea necesario
    ];

    return musicApps
        .any((app) => packageName.toLowerCase().contains(app.toLowerCase()));
  }

  // Métodos legacy para compatibilidad
  void connectToMediaControlService() {
    _connectMediaListener();
  }

  void disconnectFromMediaControlService() {
    _mediaSubscription?.cancel();
    _mediaSubscription = null;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // CLEANUP
  // ════════════════════════════════════════════════════════════════════════════

  void dispose() {
    disconnectFromMediaControlService();
    _eventController.close();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EVENTOS
// ════════════════════════════════════════════════════════════════════════════

/// Evento de MediaSession (desde controles del sistema)
sealed class MediaSessionEvent {
  const MediaSessionEvent();

  const factory MediaSessionEvent.playPause({required bool isPlaying}) =
      MediaSessionPlayPause;
  const factory MediaSessionEvent.next() = MediaSessionNext;
  const factory MediaSessionEvent.previous() = MediaSessionPrevious;
}

class MediaSessionPlayPause extends MediaSessionEvent {
  final bool isPlaying;
  const MediaSessionPlayPause({required this.isPlaying});
}

class MediaSessionNext extends MediaSessionEvent {
  const MediaSessionNext();
}

class MediaSessionPrevious extends MediaSessionEvent {
  const MediaSessionPrevious();
}
