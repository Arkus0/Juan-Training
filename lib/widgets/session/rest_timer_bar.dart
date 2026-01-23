import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/training_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/timer_audio_service.dart';
import '../../services/timer_notification_service.dart';
import '../../utils/performance_utils.dart';
import '../../utils/design_system.dart';

/// Callback cuando el timer termina, incluye info para auto-focus
typedef TimerFinishedCallback = void Function({
  int? lastExerciseIndex,
  int? lastSetIndex,
});

// ============================================================================
// PRE-COMPUTED CONST STYLES (Avoid GoogleFonts in build methods)
// ============================================================================

class _TimerStyles {
  static final labelSmall = GoogleFonts.montserrat(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.0,
  );

  static final countdownLarge = GoogleFonts.montserrat(
    fontSize: 18,
    fontWeight: FontWeight.w900,
  );

  static final countdownNormal = GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w900,
  );

  static final buttonLabel = GoogleFonts.montserrat(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: Colors.white,
  );

  static final durationDisplay = GoogleFonts.montserrat(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    color: Colors.white,
  );

  static final stateLabel = GoogleFonts.montserrat(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  );

  static final hintLabel = GoogleFonts.montserrat(
    fontSize: 9,
    fontWeight: FontWeight.w500,
  );
}

/// Barra de timer de descanso no invasiva (estilo Hevy/Strong)
///
/// Optimizaciones:
/// - RepaintBoundary para aislar repaints del timer
/// - Ticker adaptativo (reduce frecuencia en modo performance)
/// - Widgets const donde posible
/// - Estilos pre-computados (no GoogleFonts en build)
/// - Mínimo uso de setState
class RestTimerBar extends ConsumerStatefulWidget {
  final RestTimerState timerState;
  final bool showInactiveBar; // Mostrar barra inactiva (configurable desde AppBar)
  final VoidCallback onStartRest;
  final VoidCallback onStopRest;
  final VoidCallback onPauseRest;
  final VoidCallback onResumeRest;
  final ValueChanged<int> onDurationChange;
  final ValueChanged<int> onAddTime;
  final TimerFinishedCallback onTimerFinished;
  final VoidCallback? onDiscardSession; // Nuevo: borrar sesión
  final VoidCallback? onRestartRest; // Nuevo: reiniciar descanso dentro de la sesión

  const RestTimerBar({
    super.key,
    required this.timerState,
    this.showInactiveBar = false,
    required this.onStartRest,
    required this.onStopRest,
    required this.onPauseRest,
    required this.onResumeRest,
    required this.onDurationChange,
    required this.onAddTime,
    required this.onTimerFinished,
    this.onDiscardSession,
    this.onRestartRest,
  });

  @override
  ConsumerState<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends ConsumerState<RestTimerBar>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Timer? _ticker;
  double _displaySeconds = 0;
  int _lastVibratedSecond = -1;

  // Animación para show/hide (optimizada)
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Throttler para limitar vibraciones
  final Throttler _vibrationThrottler = Throttler(
    interval: const Duration(milliseconds: 800),
  );

  // Lock screen notification service
  final TimerNotificationService _notificationService = TimerNotificationService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Duración de animación adaptativa según modo performance
    final animDuration = Duration(
      milliseconds: (250 * PerformanceMode.instance.animationScale).round(),
    );

    _animController = AnimationController(
      vsync: this,
      duration: animDuration,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    // Setup notification callbacks
    _setupNotificationCallbacks();

    if (widget.timerState.isActive) {
      _startTicker();
      _animController.forward();
      _startLockScreenNotification();
    }

    _displaySeconds = widget.timerState.remainingSeconds;
  }

  /// Setup callbacks for notification button actions
  void _setupNotificationCallbacks() {
    _notificationService.onPausePressed = () {
      if (mounted && widget.timerState.isActive && !widget.timerState.isPaused) {
        widget.onPauseRest();
      }
    };
    _notificationService.onResumePressed = () {
      if (mounted && widget.timerState.isActive && widget.timerState.isPaused) {
        widget.onResumeRest();
      }
    };
    _notificationService.onSkipPressed = () {
      if (mounted && widget.timerState.isActive) {
        widget.onStopRest();
      }
    };
    _notificationService.onAddTimePressed = () {
      if (mounted && widget.timerState.isActive) {
        widget.onAddTime(30);
      }
    };
  }

  /// Start the lock screen notification
  Future<void> _startLockScreenNotification() async {
    final settings = ref.read(settingsProvider);
    // Only show if lock screen timer is enabled in settings
    if (!settings.lockScreenTimerEnabled) return;

    if (widget.timerState.endTime != null) {
      await _notificationService.startTimerNotification(
        totalSeconds: widget.timerState.totalSeconds,
        endTime: widget.timerState.endTime!,
        isPaused: widget.timerState.isPaused,
      );
    }
  }

  /// Update the lock screen notification
  Future<void> _updateLockScreenNotification() async {
    final settings = ref.read(settingsProvider);
    if (!settings.lockScreenTimerEnabled) return;

    await _notificationService.updateTimerNotification(
      totalSeconds: widget.timerState.totalSeconds,
      endTime: widget.timerState.endTime,
      isPaused: widget.timerState.isPaused,
    );
  }

  /// Stop the lock screen notification
  Future<void> _stopLockScreenNotification() async {
    await _notificationService.stopTimerNotification();
  }

  @override
  void didUpdateWidget(RestTimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Timer se activó
    if (widget.timerState.isActive && !oldWidget.timerState.isActive) {
      _startTicker();
      _animController.forward();
      _lastVibratedSecond = -1;
      _startLockScreenNotification();
    }

    // Timer se desactivó
    if (!widget.timerState.isActive && oldWidget.timerState.isActive) {
      _stopTicker();
      _animController.reverse();
      _stopLockScreenNotification();
    }

    // Timer se pausó
    if (widget.timerState.isPaused && !oldWidget.timerState.isPaused) {
      _stopTicker();
      _updateLockScreenNotification();
    }

    // Timer se reanudó
    if (!widget.timerState.isPaused &&
        oldWidget.timerState.isPaused &&
        widget.timerState.isActive) {
      _startTicker();
      _updateLockScreenNotification();
    }

    // Timer duration changed (e.g., +30s)
    if (widget.timerState.totalSeconds != oldWidget.timerState.totalSeconds ||
        widget.timerState.endTime != oldWidget.timerState.endTime) {
      _updateLockScreenNotification();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.timerState.isActive &&
        !widget.timerState.isPaused) {
      _updateDisplay();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker();
    _animController.dispose();
    _vibrationThrottler.dispose();
    // Clear notification callbacks
    _notificationService.onPausePressed = null;
    _notificationService.onResumePressed = null;
    _notificationService.onSkipPressed = null;
    _notificationService.onAddTimePressed = null;
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    // Usar intervalo adaptativo según modo performance
    final interval = PerformanceMode.instance.timerTickInterval;
    _ticker = Timer.periodic(interval, (_) {
      if (!mounted) return;
      _updateDisplay();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _updateDisplay() {
    final remaining = widget.timerState.remainingSeconds;

    if (remaining <= 0 &&
        widget.timerState.isActive &&
        !widget.timerState.isPaused) {
      _stopTicker();
      _triggerFinalFeedback();
      widget.onTimerFinished(
        lastExerciseIndex: widget.timerState.lastCompletedExerciseIndex,
        lastSetIndex: widget.timerState.lastCompletedSetIndex,
      );
      widget.onStopRest();
      return;
    }

    // Solo hacer setState si el valor cambió significativamente
    // (para reducir rebuilds innecesarios)
    final newSeconds = remaining.ceil();
    if (newSeconds != _displaySeconds.ceil()) {
      setState(() {
        _displaySeconds = remaining;
      });

      // Vibración y sonido progresivo últimos 10 segundos
      _handleProgressiveFeedback(remaining);
    } else {
      // Actualizar internamente sin rebuild completo
      _displaySeconds = remaining;
    }
  }

  /// Vibración y sonido progresivo: suave en 10-6s, media en 5-3s, fuerte en 2-1s
  void _handleProgressiveFeedback(double remaining) {
    final secondInt = remaining.ceil();

    // Solo feedback una vez por segundo
    if (secondInt == _lastVibratedSecond || secondInt > 10 || secondInt <= 0) {
      return;
    }
    _lastVibratedSecond = secondInt;

    // Usar throttler para evitar vibraciones excesivas
    _vibrationThrottler.run(() async {
      // Leer settings
      final settings = ref.read(settingsProvider);
      final vibrationEnabled = settings.timerVibrationEnabled &&
          !PerformanceMode.instance.reduceVibrations;
      final soundEnabled = settings.timerSoundEnabled;

      // Vibración
      if (vibrationEnabled) {
        try {
          if (secondInt <= 3) {
            HapticFeedback.heavyImpact();
          } else if (secondInt <= 5) {
            HapticFeedback.mediumImpact();
          } else if (secondInt <= 10) {
            HapticFeedback.lightImpact();
          }
        } catch (_) {}
      }

      // Sonido (solo últimos 3 segundos para no ser molesto)
      if (soundEnabled && secondInt <= 3) {
        final audio = TimerAudioService.instance;
        if (secondInt == 3) {
          audio.playMediumBeep();
        } else if (secondInt == 2) {
          audio.playHighBeep();
        } else if (secondInt == 1) {
          audio.playHighBeep();
        }
      }
    });
  }

  void _triggerFinalFeedback() async {
    final settings = ref.read(settingsProvider);

    // Vibración final
    if (settings.timerVibrationEnabled &&
        !PerformanceMode.instance.reduceVibrations) {
      try {
        HapticFeedback.vibrate();
        await Future.delayed(const Duration(milliseconds: 150));
        HapticFeedback.vibrate();
      } catch (_) {}
    }

    // Sonido final
    if (settings.timerSoundEnabled) {
      TimerAudioService.instance.playFinalBeep();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si no está activo, mostrar barra de inicio compacta solo si showInactiveBar es true
    if (!widget.timerState.isActive) {
      if (!widget.showInactiveBar) {
        return const SizedBox.shrink(); // Ocultar barra inactiva
      }
      return _InactiveTimerBar(
        seconds: widget.timerState.totalSeconds,
        onDurationChange: widget.onDurationChange,
        onStartRest: widget.onStartRest,
        onDiscardSession: widget.onDiscardSession,
        onRestartRest: widget.onRestartRest,
      );
    }

    // Timer activo: barra compacta con progreso
    // Usar RepaintBoundary para aislar los repaints del timer
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: Alignment.bottomCenter,
          child: _ActiveTimerBar(
            displaySeconds: _displaySeconds,
            timerState: widget.timerState,
            onStopRest: widget.onStopRest,
            onPauseRest: widget.onPauseRest,
            onResumeRest: widget.onResumeRest,
            onAddTime: () => widget.onAddTime(30),
            onDiscardSession: widget.onDiscardSession,
            onRestartRest: widget.onRestartRest,
          ),
        ),
      ),
    );
  }
}

/// Barra inactiva: botón para iniciar descanso + ajuste de tiempo
/// Extraída como widget separado para evitar rebuilds
class _InactiveTimerBar extends StatelessWidget {
  final int seconds;
  final ValueChanged<int> onDurationChange;
  final VoidCallback onStartRest;
  final VoidCallback? onDiscardSession;
  final VoidCallback? onRestartRest;

  const _InactiveTimerBar({
    required this.seconds,
    required this.onDurationChange,
    required this.onStartRest,
    this.onDiscardSession,
    this.onRestartRest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _TimeDurationSelector(
              seconds: seconds,
              onChanged: onDurationChange,
            ),

            // Basura centrada en la barra inactiva
            Expanded(
              child: Center(
                child: (onDiscardSession != null)
                    ? Tooltip(
                        message: 'Descartar sesión',
                        child: _CircleButton(
                          icon: Icons.delete_outline,
                          size: 36,
                          color: Colors.grey[800],
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: Colors.grey[900],
                                title: const Text('DESCARTAR SESIÓN', style: TextStyle(color: Colors.white)),
                                content: const Text('¿Estás seguro de que quieres descartar la sesión actual sin guardarla?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCELAR')),
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('DESCARTAR')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              HapticFeedback.heavyImpact();
                              onDiscardSession!();
                            }
                          },
                        ),
                      )
                    : (onRestartRest != null)
                        ? Tooltip(
                            message: 'Reiniciar descanso',
                            child: _CircleButton(
                              icon: Icons.refresh,
                              size: 36,
                              color: Colors.grey[800],
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onRestartRest!();
                              },
                            ),
                          )
                        : Tooltip(
                            message: 'Descartar sesión',
                            child: _CircleButton(
                              icon: Icons.delete_outline,
                              size: 36,
                              color: Colors.grey[800],
                              onTap: null,
                            ),
                          ),
              ),
            ),

            _StartRestButton(onTap: onStartRest),
          ],
        ),
      ),
    );
  }
}

/// Barra activa: timer compacto con controles
class _ActiveTimerBar extends StatelessWidget {
  final double displaySeconds;
  final RestTimerState timerState;
  final VoidCallback onStopRest;
  final VoidCallback onPauseRest;
  final VoidCallback onResumeRest;
  final VoidCallback onAddTime;
  final VoidCallback? onDiscardSession;
  final VoidCallback? onRestartRest;

  const _ActiveTimerBar({
    required this.displaySeconds,
    required this.timerState,
    required this.onStopRest,
    required this.onPauseRest,
    required this.onResumeRest,
    required this.onAddTime,
    this.onDiscardSession,
    this.onRestartRest,
  });

  @override
  Widget build(BuildContext context) {
    final seconds = displaySeconds.ceil();
    final progress = timerState.totalSeconds > 0
        ? 1.0 - (displaySeconds / timerState.totalSeconds)
        : 1.0;
    final isCritical = seconds <= 10;
    final isPaused = timerState.isPaused;

    return Semantics(
      label:
          'Timer de descanso: $seconds segundos restantes${isPaused ? ", pausado" : ""}',
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.heavyImpact();
          onStopRest();
        },
        onTap: () {
          HapticFeedback.selectionClick();
          if (isPaused) {
            onResumeRest();
          } else {
            onPauseRest();
          }
        },
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey[900]!,
                Colors.black,
              ],
            ),
            border: Border(
              top: BorderSide(
                color: isCritical ? Colors.orange[700]! : Colors.grey[700]!,
                width: isCritical ? 2 : 1,
              ),
            ),
            // Shadows solo si no está en modo performance
            boxShadow: PerformanceMode.instance.showShadows
                ? [
                    BoxShadow(
                      color: (isCritical ? AppColors.live : AppColors.bgDeep)
                          .withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ]
                : null,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                const SizedBox(width: 12),
                // Espacio central: botón de basura en el centro de la barra
                Expanded(
                  child: Center(
                    child: (onDiscardSession != null)
                    ? Tooltip(
                        message: 'Descartar sesión',
                        child: _CircleButton(
                          icon: Icons.delete_outline,
                          size: 36,
                          color: Colors.grey[800],
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: Colors.grey[900],
                                title: const Text('DESCARTAR SESIÓN', style: TextStyle(color: Colors.white)),
                                content: const Text('¿Estás seguro de que quieres descartar la sesión actual sin guardarla?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCELAR')),
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('DESCARTAR')),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              HapticFeedback.heavyImpact();
                              onDiscardSession!();
                            }
                          },
                        ),
                      )
                    : (onRestartRest != null)
                        ? Tooltip(
                            message: 'Reiniciar descanso',
                            child: _CircleButton(
                              icon: Icons.refresh,
                              size: 36,
                              color: Colors.grey[800],
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onRestartRest!();
                              },
                            ),
                          )
                        : Tooltip(
                            message: 'Descartar sesión',
                            child: _CircleButton(
                              icon: Icons.delete_outline,
                              size: 36,
                              color: Colors.grey[800],
                              onTap: null,
                            ),
                          ),
                  ),
                ),

                const SizedBox(width: 12),
                // Progreso circular con countdown (ahora a la derecha)
                RepaintBoundary(
                  child: _CircularTimerProgress(
                    progress: progress,
                    seconds: seconds,
                    isCritical: isCritical,
                    isPaused: isPaused,
                  ),
                ),
                const SizedBox(width: 12),

                // Texto de estado (compacto) y botones
                SizedBox(
                  width: 120,
                  child: _TimerStateLabel(isPaused: isPaused),
                ),
                // Botones de control (sin basura aquí)
                _TimerControlButtons(
                  isPaused: isPaused,
                  onAddTime: onAddTime,
                  onSkip: onStopRest,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Label de estado del timer - extraído para evitar rebuilds
class _TimerStateLabel extends StatelessWidget {
  final bool isPaused;

  const _TimerStateLabel({required this.isPaused});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isPaused ? 'PAUSADO' : 'DESCANSANDO',
          style: _TimerStyles.stateLabel.copyWith(
            color: isPaused ? Colors.orange[400] : Colors.grey[500],
          ),
        ),
        Text(
          isPaused ? 'Toca para reanudar' : 'Toca para pausar',
          style: _TimerStyles.hintLabel.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// Selector de duración de descanso (modo inactivo)
class _TimeDurationSelector extends StatelessWidget {
  final int seconds;
  final ValueChanged<int> onChanged;

  const _TimeDurationSelector({
    required this.seconds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'DESCANSO',
          style: _TimerStyles.labelSmall.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(width: 8),
        _CircleButton(
          icon: Icons.remove,
          size: 28,
          onTap: seconds > 10 ? () => onChanged(seconds - 10) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('${seconds}s', style: _TimerStyles.durationDisplay),
        ),
        _CircleButton(
          icon: Icons.add,
          size: 28,
          color: Colors.orange[700],
          onTap: () => onChanged(seconds + 10),
        ),
      ],
    );
  }
}

/// Botón para iniciar descanso
class _StartRestButton extends StatelessWidget {
  final VoidCallback onTap;

  const _StartRestButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange[700],
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text('DESCANSAR', style: _TimerStyles.buttonLabel),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicador de progreso circular con countdown
/// Optimizado: usa progress simple en lugar de TweenAnimationBuilder
class _CircularTimerProgress extends StatelessWidget {
  final double progress;
  final int seconds;
  final bool isCritical;
  final bool isPaused;

  const _CircularTimerProgress({
    required this.progress,
    required this.seconds,
    required this.isCritical,
    required this.isPaused,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPaused
        ? Colors.orange[400]!
        : (isCritical ? Colors.orange[700]! : Colors.white);

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Fondo del círculo
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 3,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation(Colors.grey[800]),
          ),
          // Progreso - sin TweenAnimationBuilder para mejor rendimiento
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: 3,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          // Texto del countdown
          Text(
            '$seconds',
            style: (isCritical
                    ? _TimerStyles.countdownLarge
                    : _TimerStyles.countdownNormal)
                .copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Botones de control del timer (añadir tiempo, saltar)
class _TimerControlButtons extends StatelessWidget {
  final bool isPaused;
  final VoidCallback onAddTime;
  final VoidCallback onSkip;

  const _TimerControlButtons({
    required this.isPaused,
    required this.onAddTime,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '+30 segundos',
          child: _CircleButton(
            icon: Icons.add_alarm,
            size: 36,
            onTap: () {
              HapticFeedback.selectionClick();
              onAddTime();
            },
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Saltar descanso',
          child: _CircleButton(
            icon: Icons.skip_next_rounded,
            size: 36,
            color: Colors.orange[700],
            onTap: () {
              HapticFeedback.mediumImpact();
              onSkip();
            },
          ),
        ),

      ],
    );
  }
}

/// Botón circular reutilizable
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  final VoidCallback? onTap;

  const _CircleButton({
    required this.icon,
    required this.size,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    final buttonColor = color ?? Colors.grey[700];

    return Material(
      color: isEnabled ? buttonColor : Colors.grey[850],
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.5,
            color: isEnabled ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}
