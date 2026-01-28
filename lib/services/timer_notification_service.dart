import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Callback for notification actions
typedef NotificationActionCallback = void Function(String action);

/// Service for showing rest timer notifications on lock screen
///
/// Features:
/// - Persistent notification showing countdown on lock screen
/// - Pause/Resume/Skip/+30s actions from notification buttons
/// - Works when app is in background
/// - Uses Android Foreground Service for reliability
class TimerNotificationService {
  static final TimerNotificationService instance = TimerNotificationService._();
  TimerNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Platform channels for Android foreground service
  static const MethodChannel _serviceChannel =
      MethodChannel('com.juantraining/timer_service');
  static const MethodChannel _eventsChannel =
      MethodChannel('com.juantraining/timer_events');

  bool _isInitialized = false;
  Timer? _updateTimer;
  DateTime? _endTime;
  int _totalSeconds = 0;
  bool _isPaused = false;
  bool _isActive = false;

  // Callbacks for notification actions
  VoidCallback? onPausePressed;
  VoidCallback? onResumePressed;
  VoidCallback? onSkipPressed;
  VoidCallback? onAddTimePressed;

  // Notification IDs and channel
  static const int _timerNotificationId = 1001;
  static const String _channelId = 'rest_timer_channel';
  static const String _channelName = 'Temporizador de Descanso';
  static const String _channelDescription =
      'Notificaciones del temporizador de descanso';

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Set up the events channel to receive callbacks from native
    _eventsChannel.setMethodCallHandler(_handleMethodCall);

    // Android settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings (for future use)
    final darwinSettings = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'timer_category',
          actions: [
            DarwinNotificationAction.plain('pause', 'Pausar'),
            DarwinNotificationAction.plain('skip', 'Saltar'),
            DarwinNotificationAction.plain('add30', '+30s'),
          ],
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _handleBackgroundNotificationResponse,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );
    }

    _isInitialized = true;
    debugPrint('TimerNotificationService initialized');
  }

  /// Handle method calls from native (notification actions)
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('TimerNotificationService received: ${call.method}');
    switch (call.method) {
      case 'onPause':
        onPausePressed?.call();
        break;
      case 'onResume':
        onResumePressed?.call();
        break;
      case 'onSkip':
        onSkipPressed?.call();
        break;
      case 'onAdd30':
        onAddTimePressed?.call();
        break;
    }
    return null;
  }

  /// Handle notification tap response
  void _handleNotificationResponse(NotificationResponse response) {
    _processAction(response.actionId ?? response.payload);
  }

  /// Handle background notification action
  @pragma('vm:entry-point')
  static void _handleBackgroundNotificationResponse(
      NotificationResponse response,) {
    debugPrint('Background notification action: ${response.actionId}');
  }

  void _processAction(String? action) {
    if (action == null) return;

    switch (action) {
      case 'pause':
        onPausePressed?.call();
        break;
      case 'resume':
        onResumePressed?.call();
        break;
      case 'skip':
        onSkipPressed?.call();
        break;
      case 'add30':
        onAddTimePressed?.call();
        break;
    }
  }

  /// Start showing the timer notification
  Future<void> startTimerNotification({
    required int totalSeconds,
    required DateTime endTime,
    bool isPaused = false,
  }) async {
    if (!_isInitialized) await initialize();

    _totalSeconds = totalSeconds;
    _endTime = endTime;
    _isPaused = isPaused;
    _isActive = true;

    // 🎯 FIX #3: On Android, use ONLY the foreground service (not flutter_local_notifications)
    // This prevents duplicate notifications (one from Flutter, one from native)
    if (Platform.isAndroid) {
      try {
        await _serviceChannel.invokeMethod('startTimerService', {
          'totalSeconds': totalSeconds,
          'endTimeMillis': endTime.millisecondsSinceEpoch,
          'isPaused': isPaused,
        });
        debugPrint('Timer foreground service started');
      } catch (e) {
        debugPrint('Failed to start timer service: $e');
        // Fallback to Flutter notification only if native service fails
        await _showNotification();
        _startUpdateTimer(isPaused);
      }
    } else {
      // iOS: Use flutter_local_notifications
      await _showNotification();
      _startUpdateTimer(isPaused);
    }
  }

  /// Helper to start the update timer (used for iOS or as fallback)
  void _startUpdateTimer(bool isPaused) {
    _updateTimer?.cancel();
    if (!isPaused) {
      _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _showNotification();
      });
    }
  }

  /// Update the timer notification (for pause/resume/time changes)
  Future<void> updateTimerNotification({
    int? totalSeconds,
    DateTime? endTime,
    bool? isPaused,
  }) async {
    if (!_isActive) return;

    if (totalSeconds != null) _totalSeconds = totalSeconds;
    if (endTime != null) _endTime = endTime;
    if (isPaused != null) _isPaused = isPaused;

    // 🎯 FIX #3: On Android, only update the foreground service
    if (Platform.isAndroid) {
      try {
        await _serviceChannel.invokeMethod('updateTimerService', {
          'totalSeconds': _totalSeconds,
          'endTimeMillis': _endTime?.millisecondsSinceEpoch ?? 0,
          'isPaused': _isPaused,
        });
      } catch (e) {
        debugPrint('Failed to update timer service: $e');
        // Fallback: update Flutter notification
        _updateFlutterNotification();
      }
    } else {
      // iOS: Use flutter_local_notifications
      _updateFlutterNotification();
    }
  }

  /// Update Flutter notification (used for iOS or as fallback)
  void _updateFlutterNotification() {
    // Manage update timer based on pause state
    if (_isPaused) {
      _updateTimer?.cancel();
      _updateTimer = null;
    } else {
      _updateTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        _showNotification();
      });
    }
    _showNotification();
  }

  /// Stop the timer notification
  Future<void> stopTimerNotification() async {
    _updateTimer?.cancel();
    _updateTimer = null;
    _endTime = null;
    _isActive = false;

    await _notifications.cancel(id: _timerNotificationId);

    // Stop Android foreground service
    if (Platform.isAndroid) {
      try {
        await _serviceChannel.invokeMethod('stopTimerService');
        debugPrint('Timer foreground service stopped');
      } catch (e) {
        debugPrint('Failed to stop timer service: $e');
      }
    }
  }

  /// Check if timer notification is currently active
  bool get isActive => _isActive;

  /// Show/update the notification
  Future<void> _showNotification() async {
    if (_endTime == null || !_isActive) return;

    final remaining = _isPaused
        ? _totalSeconds
        : _endTime!.difference(DateTime.now()).inSeconds;

    if (remaining <= 0 && !_isPaused) {
      await stopTimerNotification();
      return;
    }

    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    final timeString = '$minutes:$seconds';

    // Progress for the notification (0-100)
    final progress = _isPaused
        ? 100
        : ((remaining / _totalSeconds) * 100).clamp(0, 100).toInt();

    // Android notification details
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: false,
      usesChronometer: !_isPaused,
      chronometerCountDown: true,
      when: _isPaused ? null : _endTime!.millisecondsSinceEpoch,
      category: AndroidNotificationCategory.stopwatch,
      visibility: NotificationVisibility.public,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      playSound: false,
      enableVibration: false,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      actions: _isPaused
          ? [
              const AndroidNotificationAction(
                'resume',
                '▶️ Reanudar',
                showsUserInterface: true,
              ),
              const AndroidNotificationAction(
                'skip',
                '⏭️ Saltar',
                showsUserInterface: true,
              ),
            ]
          : [
              const AndroidNotificationAction(
                'pause',
                '⏸️ Pausar',
                showsUserInterface: true,
              ),
              const AndroidNotificationAction(
                'add30',
                '+30s',
                showsUserInterface: true,
              ),
              const AndroidNotificationAction(
                'skip',
                '⏭️ Saltar',
                showsUserInterface: true,
              ),
            ],
      styleInformation: BigTextStyleInformation(
        _isPaused
            ? 'Timer pausado - Toca para reanudar'
            : 'Descansa y prepárate para la siguiente serie',
        contentTitle: '🏋️ Descanso: $timeString',
        summaryText: _isPaused ? 'Pausado' : 'En curso',
      ),
    );

    // iOS notification details
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
      categoryIdentifier: 'timer_category',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notifications.show(
      id: _timerNotificationId,
      title: '🏋️ Descanso: $timeString',
      body: _isPaused
          ? 'Timer pausado - Toca para continuar'
          : 'Prepárate para la siguiente serie',
      notificationDetails: details,
      payload: 'timer',
    );
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }
    return true;
  }
}
