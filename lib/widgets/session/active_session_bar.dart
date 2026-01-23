import '../../utils/design_system.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/training_provider.dart';
import '../../screens/training_session_screen.dart';

class ActiveSessionBar extends ConsumerWidget {
  const ActiveSessionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainingState = ref.watch(trainingSessionProvider);

    // Si no hay sesión activa con startTime, no mostramos nada
    if (trainingState.startTime == null) return const SizedBox.shrink();

    final rutinaName = trainingState.activeRutina?.nombre ?? 'Entrenamiento Libre';
    final ejerciciosCount = trainingState.exercises.length;

    final duration = DateTime.now().difference(trainingState.startTime!);
    final minutes = duration.inMinutes;


    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.live,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        // 🎯 NEON IRON: Usar colores del sistema
        border: Border.all(color: AppColors.liveGlow),
      ),
      child: Row(
        children: [
          const Icon(Icons.fitness_center, color: Colors.white),
          const SizedBox(width: 12),
          // Tappable area to re-open the session screen
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingSessionScreen()));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ENTRENAMIENTO EN CURSO',
                    style: TextStyle(
                      color: Colors.redAccent[100],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$rutinaName • $ejerciciosCount Ejercicios • ${minutes}m',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Quick actions: rest timer (circular) and finish (trash icon)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trainingState.restTimer.isActive) ...[
                // Embedded timer bubble that replicates FloatingTimer actions (tap, long-press, pulse)
                _EmbeddedTimerBubble(
                  timerState: trainingState.restTimer,
                  onPause: () => ref.read(trainingSessionProvider.notifier).pauseRest(),
                  onResume: () => ref.read(trainingSessionProvider.notifier).resumeRest(),
                  onStop: () => ref.read(trainingSessionProvider.notifier).stopRest(),
                ),
                const SizedBox(width: 8),
              ],

              // Finish button (now trash)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.bgElevated,
                      title: const Text('DESCARTAR SESIÓN', style: TextStyle(color: Colors.white)),
                      content: const Text('¿Estás seguro de que quieres descartar la sesión actual?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCELAR')),
                        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('DESCARTAR')),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await ref.read(trainingSessionProvider.notifier).finishSession();
                  }
                },
              ),
            ],
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
                    color: isPaused ? AppColors.warning! : (isCritical ? AppColors.neonPrimary! : AppColors.border!),
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
                  valueColor: AlwaysStoppedAnimation(isPaused ? AppColors.warning! : (isCritical ? AppColors.neonPrimary! : Colors.white)),
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
                    Icon(
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