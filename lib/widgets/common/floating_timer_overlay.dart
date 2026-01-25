import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/training_provider.dart';
import '../../services/rest_timer_controller.dart';
import '../../utils/design_system.dart';

/// Widget flotante que muestra el timer de descanso cuando está activo
/// y el usuario está fuera de la pantalla de entrenamiento.
///
/// Se muestra como un pequeño círculo con el countdown que se puede:
/// - Tocar para pausar/reanudar
/// - Long-press para saltar
/// - Arrastrar para mover
class FloatingTimerOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const FloatingTimerOverlay({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<FloatingTimerOverlay> createState() => _FloatingTimerOverlayState();
}

class _FloatingTimerOverlayState extends ConsumerState<FloatingTimerOverlay> {
  @override
  Widget build(BuildContext context) {
    // Floating timer removed — passthrough to child only
    return widget.child;
  }
}

/// Burbuja flotante del timer
class _FloatingTimerBubble extends ConsumerStatefulWidget {
  final RestTimerState timerState;
  final Function(Offset) onPositionChange;

  const _FloatingTimerBubble({
    required this.timerState,
    required this.onPositionChange,
  });

  @override
  ConsumerState<_FloatingTimerBubble> createState() => _FloatingTimerBubbleState();
}

class _FloatingTimerBubbleState extends ConsumerState<_FloatingTimerBubble>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  double _displaySeconds = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _displaySeconds = widget.timerState.remainingSeconds;

    if (!widget.timerState.isPaused) {
      _startTicker();
    }
  }

  @override
  void didUpdateWidget(_FloatingTimerBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.timerState.isPaused && oldWidget.timerState.isPaused) {
      _startTicker();
    }

    if (widget.timerState.isPaused && !oldWidget.timerState.isPaused) {
      _stopTicker();
    }
  }

  @override
  void dispose() {
    _stopTicker();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final remaining = widget.timerState.remainingSeconds;
      setState(() {
        _displaySeconds = remaining;
      });

      // Pulsar en los últimos 10 segundos
      if (remaining <= 10 && remaining > 0) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        }
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _pulseController.stop();
    _pulseController.reset();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _displaySeconds.ceil();
    final progress = widget.timerState.totalSeconds > 0
        ? 1.0 - (_displaySeconds / widget.timerState.totalSeconds)
        : 1.0;
    final isCritical = seconds <= 10;
    final isPaused = widget.timerState.isPaused;

    final notifier = ref.read(trainingSessionProvider.notifier);

    return GestureDetector(
      onPanUpdate: (details) {
        widget.onPositionChange(details.delta);
      },
      onTap: () {
        HapticFeedback.selectionClick();
        if (isPaused) {
          notifier.resumeRest();
        } else {
          notifier.pauseRest();
        }
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        notifier.stopRest();
      },
      child: ScaleTransition(
        scale: _pulseAnimation,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPaused ? AppColors.goldAccent : (isCritical ? AppColors.live : AppColors.bgElevated),
            border: Border.all(
              color: isPaused ? AppColors.warning : (isCritical ? AppColors.neonPrimary : AppColors.border),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: (isCritical ? AppColors.live : Colors.black).withValues(alpha: 0.6),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Progreso circular
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: AppColors.bgDeep,
                  valueColor: AlwaysStoppedAnimation(
                    isPaused ? AppColors.warning : (isCritical ? AppColors.neonPrimary : Colors.white),
                  ),
                ),
              ),
              // Countdown
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$seconds',
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isPaused ? AppColors.warning : Colors.white,
                    ),
                  ),
                  if (isPaused)
                    const Icon(
                      Icons.pause,
                      size: 10,
                      color: AppColors.warning,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}