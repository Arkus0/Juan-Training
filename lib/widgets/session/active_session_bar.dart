import '../../utils/design_system.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/training_provider.dart';
import 'package:juan_training/models/rest_timer_state.dart';
import '../../screens/training_session_screen.dart';

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

    // 🎯 AGGRESSIVE RED: Barra fina y minimal, no clutter
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkRed,  // #8B0000 - rojo oscuro sutil
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bloodRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Icono minimal pulsante
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bloodRed,
              boxShadow: [
                BoxShadow(
                  color: AppColors.bloodRedGlow,
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          
          // Info compacta - tappable para ir a sesión
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingSessionScreen()));
              },
              child: Text(
                '$rutinaName • ${minutes}m',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Timer embebido si está activo
          if (trainingState.restTimer.isActive) ...[
            _EmbeddedTimerBubble(
              timerState: trainingState.restTimer,
              onPause: () => ref.read(trainingSessionProvider.notifier).pauseRest(),
              onResume: () => ref.read(trainingSessionProvider.notifier).resumeRest(),
              onStop: () => ref.read(trainingSessionProvider.notifier).stopRest(),
            ),
            const SizedBox(width: 8),
          ],

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
            child: const Icon(Icons.close, color: AppColors.textTertiary, size: 16),
          ),
        ],
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