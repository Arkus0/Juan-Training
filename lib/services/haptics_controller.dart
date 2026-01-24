import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Eventos semánticos de haptics - NO tipos de vibración
/// La lógica decide QUÉ ocurrió, el controller decide CÓMO vibrar
enum HapticEvent {
  // === Entrenamiento ===
  setCompleted,        // Serie completada
  exerciseCompleted,   // Ejercicio completo (todas las series)
  milestone50,         // 50% del entrenamiento
  milestone75,         // 75% del entrenamiento
  sessionCompleted,    // 100% del entrenamiento - celebración
  prAchieved,          // Personal Record

  // === Timer/Descanso ===
  restFinished,        // Descanso terminado
  restWarning5s,       // Quedan 5 segundos
  restWarning3s,       // Quedan 3 segundos
  timerPaused,         // Timer pausado
  timerResumed,        // Timer reanudado

  // === Input/UI ===
  focusChanged,        // Auto-focus cambió de campo
  inputSubmit,         // Valor enviado (peso/reps)
  buttonTap,           // Tap en botón crítico

  // === Voz ===
  voiceStarted,        // Empezó a escuchar
  voiceStopped,        // Dejó de escuchar
  voiceSuccess,        // Reconocimiento exitoso
  voiceError,          // Error de reconocimiento

  // === Música ===
  mediaCommand,        // Comando de media enviado

  // === Rutinas ===
  routineForged,       // ¡Rutina creada! ("Rutina forjada")
}

/// Nivel de importancia del evento - determina si se throttlea
enum _HapticPriority {
  low,      // UI menor - puede omitirse
  medium,   // Normal - throttling moderado
  high,     // Importante - throttling mínimo
  critical, // Siempre vibra (PR, session complete)
}

/// Controlador centralizado de haptics con:
/// - Verificación de lifecycle (solo vibra en resumed)
/// - Throttling inteligente por prioridad
/// - API semántica (qué ocurrió, no cómo vibrar)
/// - Singleton thread-safe
///
/// USO CORRECTO:
/// ```dart
/// // En initState de widget principal (MaterialApp)
/// HapticsController.instance.initialize();
///
/// // Desde cualquier widget/UI layer
/// HapticsController.instance.trigger(HapticEvent.setCompleted);
/// ```
///
/// USO INCORRECTO:
/// ```dart
/// // NO hacer desde providers/notifiers
/// HapticFeedback.heavyImpact(); // ❌ No controlado
/// ```
class HapticsController with WidgetsBindingObserver {
  // === Singleton ===
  static final HapticsController instance = HapticsController._();
  HapticsController._();

  // === Estado ===
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _isInitialized = false;
  bool _enabled = true;
  bool _reduceVibrations = false;

  // === Throttling ===
  final Map<HapticEvent, DateTime> _lastTriggerTime = {};
  static const _defaultThrottleMs = 200;  // ms mínimo entre vibraciones
  static const _highPriorityThrottleMs = 100;
  static const _lowPriorityThrottleMs = 500;

  // === Callbacks para UI (opcional) ===
  /// Stream de eventos disparados (para debugging/analytics)
  final _eventController = StreamController<HapticEvent>.broadcast();
  Stream<HapticEvent> get eventStream => _eventController.stream;

  // ════════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ════════════════════════════════════════════════════════════════════════════

  /// Inicializa el controller y registra observer de lifecycle
  /// Llamar desde main() o MaterialApp initState
  void initialize() {
    if (_isInitialized) return;

    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
  }

  /// Limpia recursos (llamar al cerrar app si es necesario)
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventController.close();
    _isInitialized = false;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ════════════════════════════════════════════════════════════════════════════

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
  }

  /// Verifica si la app está en primer plano
  bool get _isResumed => _lifecycleState == AppLifecycleState.resumed;

  // ════════════════════════════════════════════════════════════════════════════
  // CONFIGURACIÓN
  // ════════════════════════════════════════════════════════════════════════════

  /// Habilita/deshabilita todos los haptics
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Modo reducido (solo eventos críticos)
  void setReduceVibrations(bool reduce) {
    _reduceVibrations = reduce;
  }

  /// Sincroniza con PerformanceMode existente
  void syncWithPerformanceMode({
    required bool reduceVibrations,
    required bool performanceModeEnabled,
  }) {
    _reduceVibrations = reduceVibrations || performanceModeEnabled;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // API PRINCIPAL
  // ════════════════════════════════════════════════════════════════════════════

  /// Dispara un evento háptico si las condiciones lo permiten
  ///
  /// Retorna true si la vibración se ejecutó, false si fue bloqueada
  bool trigger(HapticEvent event) {
    // 1. Verificar habilitado
    if (!_enabled) return false;

    // 2. Verificar lifecycle - CRÍTICO
    // Android ignora haptics si la app no está en foreground
    if (!_isResumed) return false;

    // 3. Obtener prioridad
    final priority = _getPriority(event);

    // 4. Verificar modo reducido
    if (_reduceVibrations && priority != _HapticPriority.critical) {
      return false;
    }

    // 5. Verificar throttling
    if (_isThrottled(event, priority)) return false;

    // 6. Ejecutar vibración
    _executeHaptic(event);

    // 7. Actualizar timestamp
    _lastTriggerTime[event] = DateTime.now();

    // 8. Notificar observers
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }

    return true;
  }

  /// Dispara múltiples eventos (para secuencias como celebración)
  /// Los ejecuta con delay entre cada uno
  Future<void> triggerSequence(
    List<HapticEvent> events, {
    Duration delay = const Duration(milliseconds: 150),
  }) async {
    for (final event in events) {
      if (!_isResumed) break; // Cancelar si app va a background
      trigger(event);
      if (event != events.last) {
        await Future.delayed(delay);
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HELPERS SEMÁNTICOS (conveniences)
  // ════════════════════════════════════════════════════════════════════════════

  /// Feedback para completar una serie
  void onSetCompleted() => trigger(HapticEvent.setCompleted);

  /// Feedback para completar un ejercicio completo
  void onExerciseCompleted() => trigger(HapticEvent.exerciseCompleted);

  /// Feedback para PR
  void onPRAchieved() => trigger(HapticEvent.prAchieved);

  /// Feedback para fin de descanso
  void onRestFinished() => trigger(HapticEvent.restFinished);

  /// Feedback para milestone de sesión
  void onMilestone(int percentage) {
    switch (percentage) {
      case 50:
        trigger(HapticEvent.milestone50);
        break;
      case 75:
        trigger(HapticEvent.milestone75);
        break;
      case 100:
        triggerSequence([
          HapticEvent.sessionCompleted,
          HapticEvent.sessionCompleted,
          HapticEvent.sessionCompleted,
        ]);
        break;
    }
  }

  /// Feedback para voz
  void onVoiceStarted() => trigger(HapticEvent.voiceStarted);
  void onVoiceStopped() => trigger(HapticEvent.voiceStopped);

  /// Feedback para media
  void onMediaCommand() => trigger(HapticEvent.mediaCommand);

  /// Feedback para rutina creada ("Rutina forjada")
  void onRoutineForged() => trigger(HapticEvent.routineForged);

  // ════════════════════════════════════════════════════════════════════════════
  // IMPLEMENTACIÓN INTERNA
  // ════════════════════════════════════════════════════════════════════════════

  _HapticPriority _getPriority(HapticEvent event) {
    switch (event) {
      // Critical - siempre vibra
      case HapticEvent.prAchieved:
      case HapticEvent.sessionCompleted:
      case HapticEvent.routineForged:
        return _HapticPriority.critical;

      // High - importantes
      case HapticEvent.exerciseCompleted:
      case HapticEvent.restFinished:
      case HapticEvent.milestone75:
      case HapticEvent.voiceSuccess:
        return _HapticPriority.high;

      // Medium - normales
      case HapticEvent.setCompleted:
      case HapticEvent.milestone50:
      case HapticEvent.restWarning5s:
      case HapticEvent.restWarning3s:
      case HapticEvent.voiceStarted:
      case HapticEvent.voiceStopped:
      case HapticEvent.voiceError:
      case HapticEvent.inputSubmit:
      case HapticEvent.timerPaused:
      case HapticEvent.timerResumed:
      case HapticEvent.mediaCommand:
        return _HapticPriority.medium;

      // Low - UI menor
      case HapticEvent.focusChanged:
      case HapticEvent.buttonTap:
        return _HapticPriority.low;
    }
  }

  bool _isThrottled(HapticEvent event, _HapticPriority priority) {
    final lastTime = _lastTriggerTime[event];
    if (lastTime == null) return false;

    final elapsed = DateTime.now().difference(lastTime).inMilliseconds;
    final threshold = switch (priority) {
      _HapticPriority.critical => 0, // Sin throttle
      _HapticPriority.high => _highPriorityThrottleMs,
      _HapticPriority.medium => _defaultThrottleMs,
      _HapticPriority.low => _lowPriorityThrottleMs,
    };

    return elapsed < threshold;
  }

  void _executeHaptic(HapticEvent event) {
    try {
      switch (event) {
        // === Heavy Impact (celebraciones, completados importantes) ===
        case HapticEvent.prAchieved:
        case HapticEvent.sessionCompleted:
        case HapticEvent.exerciseCompleted:
        case HapticEvent.restFinished:
        case HapticEvent.voiceStopped:
        case HapticEvent.routineForged:
          HapticFeedback.heavyImpact();
          break;

        // === Medium Impact (milestones, voice) ===
        case HapticEvent.milestone50:
        case HapticEvent.milestone75:
        case HapticEvent.voiceStarted:
        case HapticEvent.voiceSuccess:
        case HapticEvent.inputSubmit:
        case HapticEvent.mediaCommand:
        case HapticEvent.timerPaused:
        case HapticEvent.timerResumed:
          HapticFeedback.mediumImpact();
          break;

        // === Light Impact (warnings) ===
        case HapticEvent.restWarning5s:
        case HapticEvent.restWarning3s:
        case HapticEvent.setCompleted:
        case HapticEvent.voiceError:
          HapticFeedback.lightImpact();
          break;

        // === Selection Click (UI menor) ===
        case HapticEvent.focusChanged:
        case HapticEvent.buttonTap:
          HapticFeedback.selectionClick();
          break;
      }
    } catch (_) {
      // Silenciar errores de haptic (dispositivo sin vibrador, etc)
    }
  }
}
