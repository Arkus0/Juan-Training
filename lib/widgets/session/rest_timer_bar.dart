import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/training_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/timer_audio_service.dart';

/// Callback cuando el timer termina, incluye info para auto-focus
typedef TimerFinishedCallback = void Function({
  int? lastExerciseIndex,
  int? lastSetIndex,
});

/// Barra de timer de descanso no invasiva (estilo Hevy/Strong)
///
/// Características:
/// - Compacta (56px altura), no bloquea UI
/// - Progreso circular + countdown
/// - Pause/Resume/Skip con gestos y botones
/// - Vibración progresiva últimos 10 segundos
/// - Sonido opcional (configurable en settings)
/// - Animación fade/scale para show/hide
/// - Accesibilidad con Semantics
class RestTimerBar extends ConsumerStatefulWidget {
  final RestTimerState timerState;
  final VoidCallback onStartRest;
  final VoidCallback onStopRest;
  final VoidCallback onPauseRest;
  final VoidCallback onResumeRest;
  final ValueChanged<int> onDurationChange;
  final ValueChanged<int> onAddTime;
  final TimerFinishedCallback onTimerFinished;

  const RestTimerBar({
    super.key,
    required this.timerState,
    required this.onStartRest,
    required this.onStopRest,
    required this.onPauseRest,
    required this.onResumeRest,
    required this.onDurationChange,
    required this.onAddTime,
    required this.onTimerFinished,
  });

  @override
  ConsumerState<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends ConsumerState<RestTimerBar>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Timer? _ticker;
  double _displaySeconds = 0;
  int _lastVibratedSecond = -1;

  // Animación para show/hide
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    if (widget.timerState.isActive) {
      _startTicker();
      _animController.forward();
    }

    _displaySeconds = widget.timerState.remainingSeconds;
  }

  @override
  void didUpdateWidget(RestTimerBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Timer se activó
    if (widget.timerState.isActive && !oldWidget.timerState.isActive) {
      _startTicker();
      _animController.forward();
      _lastVibratedSecond = -1;
    }

    // Timer se desactivó
    if (!widget.timerState.isActive && oldWidget.timerState.isActive) {
      _stopTicker();
      _animController.reverse();
    }

    // Timer se pausó
    if (widget.timerState.isPaused && !oldWidget.timerState.isPaused) {
      _stopTicker();
    }

    // Timer se reanudó
    if (!widget.timerState.isPaused && oldWidget.timerState.isPaused && widget.timerState.isActive) {
      _startTicker();
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
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
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

    if (remaining <= 0 && widget.timerState.isActive && !widget.timerState.isPaused) {
      _stopTicker();
      _triggerFinalFeedback();
      widget.onTimerFinished(
        lastExerciseIndex: widget.timerState.lastCompletedExerciseIndex,
        lastSetIndex: widget.timerState.lastCompletedSetIndex,
      );
      widget.onStopRest();
      return;
    }

    setState(() {
      _displaySeconds = remaining;
    });

    // Vibración y sonido progresivo últimos 10 segundos
    _handleProgressiveFeedback(remaining);
  }

  /// Vibración y sonido progresivo: suave en 10-6s, media en 5-3s, fuerte en 2-1s
  void _handleProgressiveFeedback(double remaining) async {
    final secondInt = remaining.ceil();

    // Solo feedback una vez por segundo
    if (secondInt == _lastVibratedSecond || secondInt > 10 || secondInt <= 0) return;
    _lastVibratedSecond = secondInt;

    // Leer settings
    final settings = ref.read(settingsProvider);
    final vibrationEnabled = settings.timerVibrationEnabled;
    final soundEnabled = settings.timerSoundEnabled;

    // Vibración
    if (vibrationEnabled) {
      final canVibrate = await Vibrate.canVibrate;
      if (canVibrate) {
        if (secondInt <= 3) {
          Vibrate.feedback(FeedbackType.heavy);
        } else if (secondInt <= 5) {
          Vibrate.feedback(FeedbackType.medium);
        } else if (secondInt <= 10) {
          Vibrate.feedback(FeedbackType.light);
        }
      }
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
  }

  void _triggerFinalFeedback() async {
    final settings = ref.read(settingsProvider);

    // Vibración final
    if (settings.timerVibrationEnabled) {
      final canVibrate = await Vibrate.canVibrate;
      if (canVibrate) {
        Vibrate.feedback(FeedbackType.success);
        await Future.delayed(const Duration(milliseconds: 150));
        Vibrate.feedback(FeedbackType.success);
      }
    }

    // Sonido final
    if (settings.timerSoundEnabled) {
      TimerAudioService.instance.playFinalBeep();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si no está activo, mostrar barra de inicio compacta
    if (!widget.timerState.isActive) {
      return _buildInactiveBar(context);
    }

    // Timer activo: barra compacta con progreso
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment.bottomCenter,
        child: _buildActiveTimerBar(context),
      ),
    );
  }

  /// Barra inactiva: botón para iniciar descanso + ajuste de tiempo
  Widget _buildInactiveBar(BuildContext context) {
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
            // Ajuste de tiempo
            _TimeDurationSelector(
              seconds: widget.timerState.totalSeconds,
              onChanged: widget.onDurationChange,
            ),
            const Spacer(),
            // Botón de inicio
            _StartRestButton(onTap: widget.onStartRest),
          ],
        ),
      ),
    );
  }

  /// Barra activa: timer compacto con controles
  Widget _buildActiveTimerBar(BuildContext context) {
    final seconds = _displaySeconds.ceil();
    final progress = widget.timerState.totalSeconds > 0
        ? 1.0 - (_displaySeconds / widget.timerState.totalSeconds)
        : 1.0;
    final isCritical = seconds <= 10;
    final isPaused = widget.timerState.isPaused;

    return Semantics(
      label: 'Timer de descanso: $seconds segundos restantes${isPaused ? ", pausado" : ""}',
      child: GestureDetector(
        // Long press para saltar
        onLongPress: () {
          HapticFeedback.heavyImpact();
          widget.onStopRest();
        },
        // Tap para pausar/reanudar
        onTap: () {
          HapticFeedback.selectionClick();
          if (isPaused) {
            widget.onResumeRest();
          } else {
            widget.onPauseRest();
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
                color: isCritical ? Colors.redAccent[700]! : Colors.grey[700]!,
                width: isCritical ? 2 : 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: (isCritical ? Colors.red[900] : Colors.black)!.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                const SizedBox(width: 12),

                // Progreso circular con countdown
                _CircularTimerProgress(
                  progress: progress,
                  seconds: seconds,
                  isCritical: isCritical,
                  isPaused: isPaused,
                ),

                const SizedBox(width: 12),

                // Texto de estado
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaused ? 'PAUSADO' : 'DESCANSANDO',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPaused ? Colors.orange[400] : Colors.grey[500],
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        isPaused ? 'Toca para reanudar' : 'Toca para pausar',
                        style: GoogleFonts.montserrat(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Botones de control
                _TimerControlButtons(
                  isPaused: isPaused,
                  onAddTime: () => widget.onAddTime(30),
                  onSkip: widget.onStopRest,
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
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey[600],
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 8),
        _CircleButton(
          icon: Icons.remove,
          size: 28,
          onTap: seconds > 10 ? () => onChanged(seconds - 10) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '${seconds}s',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
        _CircleButton(
          icon: Icons.add,
          size: 28,
          color: Colors.redAccent[700],
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
      color: Colors.redAccent[700],
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
              Text(
                'DESCANSAR',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Indicador de progreso circular con countdown
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
        : (isCritical ? Colors.redAccent[700]! : Colors.white);

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
          // Progreso
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 100),
            builder: (context, value, _) {
              return CircularProgressIndicator(
                value: value.clamp(0.0, 1.0),
                strokeWidth: 3,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation(color),
              );
            },
          ),
          // Texto del countdown
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: GoogleFonts.montserrat(
              fontSize: isCritical ? 18 : 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            child: Text('$seconds'),
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
        // Añadir 30s
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
        // Saltar (skip)
        Tooltip(
          message: 'Saltar descanso',
          child: _CircleButton(
            icon: Icons.skip_next_rounded,
            size: 36,
            color: Colors.redAccent[700],
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
