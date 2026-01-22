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

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TrainingSessionScreen()),
        );
      },
      child: Container(
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
            Expanded(
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
