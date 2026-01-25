import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';

import 'haptics_controller.dart';
import 'media_control_service.dart';
import 'media_session_service.dart';
import 'timer_audio_service.dart';
import 'timer_platform_service.dart';
import 'timer_notification_service.dart';

/// Gestor centralizado del ciclo de vida de la aplicación.
///
/// Responsabilidades:
/// - Detectar cuando la app pasa a background/foreground
/// - Limpiar recursos cuando la app es destruida
/// - Detener servicios en background para permitir que Android mate el proceso
/// - Reiniciar servicios cuando la app vuelve a foreground
///
/// CRÍTICO para evitar que la app quede "colgada" y requiera forzar detención.
class AppLifecycleManager with WidgetsBindingObserver {
  static final AppLifecycleManager instance = AppLifecycleManager._();
  AppLifecycleManager._();

  final _logger = Logger();

  bool _isInitialized = false;
  bool _isInBackground = false;
  bool _isDisposed = false;

  // Channel para comunicar con Android
  static const _channel = MethodChannel('com.juantraining/app_lifecycle');

  /// Estado actual del lifecycle
  AppLifecycleState _currentState = AppLifecycleState.resumed;
  AppLifecycleState get currentState => _currentState;
  bool get isInBackground => _isInBackground;

  /// Inicializa el gestor de lifecycle.
  /// Llamar desde main() DESPUÉS de inicializar los servicios.
  void initialize() {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    _isDisposed = false;

    _logger.i('AppLifecycleManager inicializado');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _currentState = state;
    _logger.d('AppLifecycleState cambió a: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _handleResumed();
        break;

      case AppLifecycleState.paused:
        _handlePaused();
        break;

      case AppLifecycleState.detached:
        _handleDetached();
        break;

      case AppLifecycleState.inactive:
        // Transición - no hacer nada
        break;

      case AppLifecycleState.hidden:
        // Similar a paused en algunos casos
        break;
    }
  }

  /// App volvió a primer plano
  void _handleResumed() {
    if (!_isInBackground) return;

    _isInBackground = false;
    _logger.i('App volvió a foreground');

    // Reiniciar servicios que se pausaron
    _restoreServices();
  }

  /// App pasó a background
  void _handlePaused() {
    _isInBackground = true;
    _logger.i('App pasó a background');

    // Pausar servicios no críticos para permitir cleanup
    _pauseNonCriticalServices();
  }

  /// App está siendo destruida
  void _handleDetached() {
    _logger.i('App está siendo destruida - limpiando recursos');
    disposeAll();
  }

  /// Pausa servicios no críticos cuando la app va a background.
  /// El timer de descanso sigue en el foreground service de Android.
  void _pauseNonCriticalServices() {
    try {
      // Detener el polling de MediaControlService
      // El timer de descanso sigue activo via foreground service
      MediaControlService.instance.dispose();

      _logger.d('Servicios no críticos pausados');
    } catch (e) {
      _logger.e('Error pausando servicios', error: e);
    }
  }

  /// Restaura servicios cuando la app vuelve a foreground.
  void _restoreServices() {
    try {
      // Reiniciar polling de media
      MediaControlService.instance.initialize();

      _logger.d('Servicios restaurados');
    } catch (e) {
      _logger.e('Error restaurando servicios', error: e);
    }
  }

  /// Limpia TODOS los recursos. Llamar cuando la app cierra.
  Future<void> disposeAll() async {
    if (_isDisposed) return;
    _isDisposed = true;

    _logger.i('Disposing all services...');

    try {
      // 1. Detener el timer de descanso si está activo
      await _stopTimerService();

      // 2. Detener MediaSession
      await MediaSessionManagerService.instance.stopMonitoring();
      MediaSessionManagerService.instance.dispose();

      // 3. Detener polling de media (permanente)
      MediaControlService.instance.disposeCompletely();

      // 4. Limpiar audio player
      await TimerAudioService.instance.dispose();

      // 5. Limpiar haptics controller
      HapticsController.instance.dispose();

      // 6. Limpiar timer platform service
      TimerPlatformService.instance.dispose();

      // 7. Detener notificaciones del timer
      await TimerNotificationService.instance.stopTimerNotification();

      _logger.i('All services disposed successfully');
    } catch (e) {
      _logger.e('Error disposing services', error: e);
    }

    // Remover este observer
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
    }
  }

  /// Detiene el foreground service del timer en Android
  Future<void> _stopTimerService() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('stopAllServices');
    } catch (e) {
      // El channel puede no existir si no se configuró
      _logger.w('Could not stop timer service via channel', error: e);

      // Intentar via TimerPlatformService
      try {
        await TimerPlatformService.instance.stop();
      } catch (_) {}
    }
  }

  /// Método auxiliar para forzar cierre limpio desde UI
  Future<void> forceCleanShutdown() async {
    _logger.i('Force clean shutdown requested');
    await disposeAll();

    // En Android, también notificar al sistema
    if (Platform.isAndroid) {
      try {
        await SystemNavigator.pop();
      } catch (e) {
        _logger.e('Error calling SystemNavigator.pop', error: e);
      }
    }
  }
}
