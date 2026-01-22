import 'package:flutter/material.dart';
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

    String _formatSeconds(double secs) {
      final s = secs.ceil();
      final mm = (s ~/ 60).toString().padLeft(2, '0');
      final ss = (s % 60).toString().padLeft(2, '0');
      return '$mm:$ss';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red[900],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
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

          // Quick actions: rest timer status and pause/resume button, plus finish
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trainingState.restTimer.isActive) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    _formatSeconds(trainingState.restTimer.remainingSeconds),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    trainingState.restTimer.isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (trainingState.restTimer.isPaused) {
                      ref.read(trainingSessionProvider.notifier).resumeRest();
                    } else {
                      ref.read(trainingSessionProvider.notifier).pauseRest();
                    }
                  },
                ),
              ],

              // Finish button
              IconButton(
                icon: const Icon(Icons.stop, color: Colors.white),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.grey[900],
                      title: const Text('TERMINAR SESIÓN', style: TextStyle(color: Colors.white)),
                      content: const Text('¿Estás seguro de que quieres terminar la sesión actual?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCELAR')),
                        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('TERMINAR')),
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
