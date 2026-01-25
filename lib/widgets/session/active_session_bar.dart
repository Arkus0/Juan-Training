import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/training_provider.dart';
import '../../screens/training_session_screen.dart';
import '../../services/rest_timer_controller.dart';
import '../../utils/design_system.dart';

class ActiveSessionBar extends ConsumerWidget {
  const ActiveSessionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingState = ref.watch(trainingSessionProvider);

    // Si no hay sesión activa con startTime, no mostramos nada
    if (trainingState.startTime == null) return const SizedBox.shrink();

    final rutinaName = trainingState.activeRutina?.nombre ?? 'Entrenamiento Libre';

    final duration = DateTime.now().difference(trainingState.startTime!);
    final minutes = duration.inMinutes;

    // 🎯 ESTADO CRÍTICO: Barra prominente, imposible de ignorar
    // El usuario NUNCA debe pensar que perdió su sesión
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingSessionScreen()));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          // Fondo más visible
          color: AppColors.darkRed,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bloodRed.withValues(alpha: 0.6), width: 1.5),
          // Sombra sutil para elevación
          boxShadow: [
            BoxShadow(
              color: AppColors.bloodRed.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icono pulsante más grande
            Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.bloodRed,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bloodRedGlow,
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Info clara - ENTRENAMIENTO EN CURSO prominente
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Label explícito
                  const Text(
                    'ENTRENAMIENTO EN CURSO',
                    style: TextStyle(
                      color: AppColors.bloodRed,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Rutina y tiempo
                  Text(
                    '$rutinaName • ${minutes}min',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

          // Timer embebido si está activo
          if (trainingState.restTimer.isActive) ...[
            const SizedBox(width: 8),
            _EmbeddedTimerBubble(
              timerState: trainingState.restTimer,
              onPause: () => ref.read(trainingSessionProvider.notifier).pauseRest(),
              onResume: () => ref.read(trainingSessionProvider.notifier).resumeRest(),
              onStop: () => ref.read(trainingSessionProvider.notifier).stopRest(),
            ),
            const SizedBox(width: 8),
          ],

          // Flecha para indicar que es tappable (solo si no hay timer)
          if (!trainingState.restTimer.isActive)
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),

          // Botón descartar (sutil, pequeño)
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.bgElevated,
                  title: const Text('DESCARTAR SESIÓN', style: TextStyle(color: AppColors.textPrimary)),
                  content: const Text('¿Descartar sin guardar?', style: TextStyle(color: AppColors.textSecondary)),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCELAR')),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('DESCARTAR', style: TextStyle(color: AppColors.bloodRed)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(trainingSessionProvider.notifier).finishSession();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.bgInteractive.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: AppColors.textTertiary, size: 16),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// Embedded timer bubble (encajado en la barra) - replica acciones y animación del floating timer
class _EmbeddedTimerBubble extends StatefulWidget {
  final RestTimerState timerState;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  const _EmbeddedTimerBubble({
    required this.timerState,
    required this.onPause,
    required this.onResume,
    required this.onStop,
  });

  @override
  State<_EmbeddedTimerBubble> createState() => _EmbeddedTimerBubbleState();
}

class _EmbeddedTimerBubbleState extends State<_EmbeddedTimerBubble> with SingleTickerProviderStateMixin {
  Timer? _ticker;
  double _displaySeconds = 0;

  @override
  void initState() {
    super.initState();

    _displaySeconds = widget.timerState.remainingSeconds;

    if (!widget.timerState.isPaused) {
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _displaySeconds = widget.timerState.remainingSeconds;
      });
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void didUpdateWidget(covariant _EmbeddedTimerBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If paused/resumed state changed, start/stop ticker accordingly
    if (!widget.timerState.isPaused && oldWidget.timerState.isPaused) {
      _startTicker();
    } else if (widget.timerState.isPaused && !oldWidget.timerState.isPaused) {
      _stopTicker();
    }

    // Update display seconds immediately if totalSeconds or remaining changed externally
    if (widget.timerState.remainingSeconds != oldWidget.timerState.remainingSeconds) {
      setState(() {
        _displaySeconds = widget.timerState.remainingSeconds;
      });
    }
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _displaySeconds.ceil();
    final progress = widget.timerState.totalSeconds > 0 ? 1.0 - (_displaySeconds / widget.timerState.totalSeconds) : 1.0;
    final isCritical = seconds <= 10;
    final isPaused = widget.timerState.isPaused;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (isPaused) {
          widget.onResume();
        } else {
          widget.onPause();
        }
      },
      onLongPress: () {
        HapticFeedback.heavyImpact();
        widget.onStop();
      },
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
              // Background circle
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPaused ? AppColors.goldAccent : (isCritical ? AppColors.live : AppColors.bgElevated),
                  border: Border.all(
                    color: isPaused ? AppColors.warning : (isCritical ? AppColors.neonPrimary : AppColors.border),
                    width: 2,
                  ),
                ),
              ),

              // Progress indicator
              SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 3,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(isPaused ? AppColors.warning : (isCritical ? AppColors.neonPrimary : Colors.white)),
                ),
              ),

              // Countdown
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$seconds',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
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
      
    );
  }
}