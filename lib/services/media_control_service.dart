import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Estado de reproducción multimedia
enum MediaPlaybackState {
  unknown,
  playing,
  paused,
  stopped,
  buffering,
}

/// Información de la sesión de media activa
class MediaSessionInfo {
  final String? packageName;
  final String? title;
  final String? artist;
  final String? album;
  final MediaPlaybackState playbackState;
  final bool isSpotify;

  const MediaSessionInfo({
    this.packageName,
    this.title,
    this.artist,
    this.album,
    this.playbackState = MediaPlaybackState.unknown,
  }) : isSpotify = packageName == 'com.spotify.music';

  bool get hasMedia => title != null || playbackState == MediaPlaybackState.playing;

  static const none = MediaSessionInfo();

  @override
  String toString() =>
      'MediaSessionInfo(package: $packageName, title: $title, artist: $artist, state: $playbackState)';
}

/// Resultado de un comando multimedia
class MediaCommandResult {
  final bool success;
  final String? error;
  final bool fallbackUsed;

  const MediaCommandResult({
    required this.success,
    this.error,
    this.fallbackUsed = false,
  });

  factory MediaCommandResult.ok() => const MediaCommandResult(success: true);

  factory MediaCommandResult.failed(String error, {bool fallbackUsed = false}) =>
      MediaCommandResult(success: false, error: error, fallbackUsed: fallbackUsed);
}

/// Servicio de control multimedia robusto.
///
/// Este servicio reemplaza el control básico de KeyEvents con:
/// 1. Información real de la sesión de media activa (título, artista)
/// 2. Estado de reproducción real (playing/paused)
/// 3. Eventos reactivos via stream (no polling)
/// 4. Fallback a abrir Spotify si el comando falla
/// 5. Soporte futuro para iOS
///
/// NOTA: Requiere implementación nativa adicional en MainActivity.kt
/// para soportar MediaSessionManager callbacks.
///
/// Uso:
/// ```dart
/// final service = MediaControlService.instance;
/// await service.initialize();
///
/// // Escuchar cambios de sesión
/// service.sessionStream.listen((session) {
///   print('Ahora reproduciendo: ${session.title}');
/// });
///
/// // Controlar reproducción
/// await service.playPause();
/// await service.next();
/// ```
class MediaControlService {
  static final MediaControlService instance = MediaControlService._();
  MediaControlService._();

  final _logger = Logger();

  // Channel para comandos
  static const _channel = MethodChannel('juan_training/music_launcher');

  // Channel para eventos (futuro: EventChannel para streaming)
  // static const _eventChannel = EventChannel('juan_training/music_events');

  // Estado
  MediaSessionInfo _currentSession = MediaSessionInfo.none;
  MediaSessionInfo get currentSession => _currentSession;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Polling timer (temporal hasta implementar MediaSession callbacks)
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 3);

  // Streams - recreatable for lifecycle management
  StreamController<MediaSessionInfo>? _sessionController;
  Stream<MediaSessionInfo> get sessionStream {
    _sessionController ??= StreamController<MediaSessionInfo>.broadcast();
    return _sessionController!.stream;
  }

  /// Inicializa el servicio
  Future<bool> initialize() async {
    // Permitir re-inicialización después de dispose
    if (_isInitialized && _pollTimer != null) return true;

    if (!Platform.isAndroid) {
      _logger.w('MediaControlService solo soporta Android actualmente');
      _isInitialized = true;
      return false;
    }

    // Recrear el stream controller si fue cerrado
    if (_sessionController == null || _sessionController!.isClosed) {
      _sessionController = StreamController<MediaSessionInfo>.broadcast();
    }

    // Verificar estado inicial
    await _checkMediaState();

    // Iniciar polling (temporal)
    // TODO: Reemplazar con EventChannel + MediaSessionManager callbacks
    _startPolling();

    _isInitialized = true;
    _logger.i('MediaControlService inicializado');
    return true;
  }

  /// Verifica si hay música reproduciéndose
  Future<bool> isMusicActive() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _channel.invokeMethod<bool>('isMusicActive');
      return result == true;
    } catch (e) {
      _logger.w('Error verificando música activa', error: e);
      return false;
    }
  }

  /// Obtiene información de la sesión de media activa
  /// NOTA: Requiere implementación nativa adicional
  Future<MediaSessionInfo> getActiveSession() async {
    if (!Platform.isAndroid) return MediaSessionInfo.none;

    try {
      // Intenta obtener info completa (requiere implementación nativa)
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getMediaSession');
      if (result != null) {
        return MediaSessionInfo(
          packageName: result['packageName'] as String?,
          title: result['title'] as String?,
          artist: result['artist'] as String?,
          album: result['album'] as String?,
          playbackState: _parsePlaybackState(result['playbackState'] as int?),
        );
      }
    } catch (e) {
      // Fallback: solo verificar si hay música activa
      final isActive = await isMusicActive();
      if (isActive) {
        return const MediaSessionInfo(
          playbackState: MediaPlaybackState.playing,
        );
      }
    }

    return MediaSessionInfo.none;
  }

  MediaPlaybackState _parsePlaybackState(int? state) {
    switch (state) {
      case 3:
        return MediaPlaybackState.playing;
      case 2:
        return MediaPlaybackState.paused;
      case 1:
        return MediaPlaybackState.stopped;
      case 6:
        return MediaPlaybackState.buffering;
      default:
        return MediaPlaybackState.unknown;
    }
  }

  // --- Comandos de control ---

  /// Envía comando play/pause
  Future<MediaCommandResult> playPause() async {
    return _sendCommand('mediaPlayPause', 'play/pause');
  }

  /// Envía comando siguiente canción
  Future<MediaCommandResult> next() async {
    return _sendCommand('mediaNext', 'siguiente');
  }

  /// Envía comando canción anterior
  Future<MediaCommandResult> previous() async {
    return _sendCommand('mediaPrevious', 'anterior');
  }

  Future<MediaCommandResult> _sendCommand(String method, String description) async {
    if (!Platform.isAndroid) {
      return MediaCommandResult.failed('No soportado en esta plataforma');
    }

    try {
      await _channel.invokeMethod(method);
      _logger.d('Comando $description enviado');

      // Pequeño delay antes de verificar estado
      await Future.delayed(const Duration(milliseconds: 200));
      await _checkMediaState();

      return MediaCommandResult.ok();
    } on PlatformException catch (e) {
      _logger.w('Error enviando comando $description', error: e);

      // Fallback: abrir Spotify
      final fallbackSuccess = await _openSpotifyFallback();
      return MediaCommandResult.failed(
        e.message ?? 'Error de plataforma',
        fallbackUsed: fallbackSuccess,
      );
    } catch (e) {
      _logger.e('Error inesperado enviando comando $description', error: e);
      return MediaCommandResult.failed('Error inesperado: $e');
    }
  }

  /// Abre la app de Spotify como fallback
  Future<bool> openSpotify() async {
    return _openSpotifyFallback();
  }

  Future<bool> _openSpotifyFallback() async {
    final Uri spotifyAppUri = Uri.parse('spotify:');
    final Uri spotifyWebUri = Uri.parse('https://open.spotify.com');

    try {
      if (await canLaunchUrl(spotifyAppUri)) {
        await launchUrl(spotifyAppUri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        await launchUrl(spotifyWebUri, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (e) {
      _logger.e('Error abriendo Spotify', error: e);
      return false;
    }
  }

  // --- Polling (temporal) ---

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _checkMediaState());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkMediaState() async {
    final newSession = await getActiveSession();

    // Solo emitir si cambió y el controller está activo
    if (_hasSessionChanged(newSession)) {
      _currentSession = newSession;
      if (_sessionController != null && !_sessionController!.isClosed) {
        _sessionController!.add(_currentSession);
      }
      _logger.d('Sesión de media actualizada: $_currentSession');
    }
  }

  bool _hasSessionChanged(MediaSessionInfo newSession) {
    return newSession.packageName != _currentSession.packageName ||
        newSession.title != _currentSession.title ||
        newSession.playbackState != _currentSession.playbackState;
  }

  /// Fuerza actualización del estado
  Future<void> refresh() async {
    await _checkMediaState();
  }

  /// Detiene el servicio temporalmente (permite re-inicialización)
  void dispose() {
    _stopPolling();
    _isInitialized = false;
    // No cerramos el StreamController para permitir re-suscripción
    // Solo lo cerramos en disposeCompletely()
  }

  /// Detiene el servicio permanentemente
  void disposeCompletely() {
    _stopPolling();
    _isInitialized = false;
    _sessionController?.close();
    _sessionController = null;
  }
}
