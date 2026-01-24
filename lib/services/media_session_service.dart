import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'media_control_service.dart';
import 'haptics_controller.dart';

/// Servicio que gestiona la MediaSession propia de la app.
///
/// IMPORTANTE: Este servicio es lo que hace que aparezca el Media Player
/// del sistema Android. Sin una MediaSession activa con notificación MediaStyle,
/// Android NO muestra controles de media.
///
/// Arquitectura:
/// ```
/// Flutter UI ──> MediaSessionManagerService ──> MediaSessionService (Android)
///                        │                              │
///                        │                              ├── MediaSession (isActive=true)
///                        │                              └── Notification (MediaStyle)
///                        │
///                        └──> MediaControlService (control de Spotify)
/// ```
///
/// Ciclo de vida:
/// 1. Usuario inicia entrenamiento → startSession()
/// 2. MediaSession se activa → aparece en controles del sistema
/// 3. Usuario toca controles → onPlayPause/onNext/etc callbacks
/// 4. Callbacks → MediaControlService → KeyEvents → Spotify
/// 5. Usuario termina entrenamiento → stopSession()
///
/// USO:
/// ```dart
/// // Al iniciar entrenamiento
/// await MediaSessionManagerService.instance.startSession(
///   trainingName: 'Push Day',
/// );
///
/// // Actualizar estado según música detectada
/// MediaControlService.instance.sessionStream.listen((session) {
///   MediaSessionManagerService.instance.updatePlaybackState(
///     isPlaying: session.playbackState == MediaPlaybackState.playing,
///   );
/// });
///
/// // Al terminar entrenamiento
/// await MediaSessionManagerService.instance.stopSession();
/// ```
class MediaSessionManagerService {
  static final MediaSessionManagerService instance = MediaSessionManagerService._();
  MediaSessionManagerService._();

  final _logger = Logger();

  // Platform channels
  static const _channel = MethodChannel('com.juantraining/media_session');
  static const _eventsChannel = MethodChannel('com.juantraining/media_session_events');

  // Estado
  bool _isSessionActive = false;
  bool get isSessionActive => _isSessionActive;

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
  // CONTROL DE SESIÓN
  // ════════════════════════════════════════════════════════════════════════════

  /// Inicia la MediaSession (cuando empieza el entrenamiento)
  ///
  /// Esto hace que aparezca el Media Player del sistema con controles
  /// para controlar la música durante el entrenamiento.
  Future<bool> startSession({String? trainingName}) async {
    if (!Platform.isAndroid) return false;
    if (_isSessionActive) return true;

    try {
      await _channel.invokeMethod('startMediaSession', {
        'trainingName': trainingName ?? 'Entrenamiento',
      });

      _isSessionActive = true;
      _logger.i('MediaSession iniciada: $trainingName');

      // Sincronizar con estado actual de media
      await _syncWithCurrentMedia();

      return true;
    } catch (e) {
      _logger.e('Error iniciando MediaSession', error: e);
      return false;
    }
  }

  /// Detiene la MediaSession (cuando termina el entrenamiento)
  Future<void> stopSession() async {
    if (!Platform.isAndroid) return;
    if (!_isSessionActive) return;

    try {
      await _channel.invokeMethod('stopMediaSession');
      _isSessionActive = false;
      _logger.i('MediaSession detenida');
    } catch (e) {
      _logger.e('Error deteniendo MediaSession', error: e);
    }
  }

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
  // SINCRONIZACIÓN
  // ════════════════════════════════════════════════════════════════════════════

  /// Sincroniza con el estado actual de MediaControlService
  Future<void> _syncWithCurrentMedia() async {
    final session = MediaControlService.instance.currentSession;

    // Actualizar estado de reproducción
    await updatePlaybackState(
      isPlaying: session.playbackState == MediaPlaybackState.playing,
    );

    // Actualizar metadata si hay info disponible
    if (session.hasMedia) {
      await updateMetadata(
        title: session.title ?? 'Entrenando',
        artist: session.artist ?? 'Juan Training',
      );
    }
  }

  /// Conecta con MediaControlService para auto-sincronizar
  StreamSubscription<MediaSessionInfo>? _mediaSubscription;

  void connectToMediaControlService() {
    _mediaSubscription?.cancel();
    _mediaSubscription = MediaControlService.instance.sessionStream.listen((session) {
      if (_isSessionActive) {
        // Actualizar estado
        updatePlaybackState(
          isPlaying: session.playbackState == MediaPlaybackState.playing,
        );

        // Actualizar metadata
        if (session.hasMedia) {
          updateMetadata(
            title: session.title,
            artist: session.artist,
          );
        }
      }
    });
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

  const factory MediaSessionEvent.playPause({required bool isPlaying}) = MediaSessionPlayPause;
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
