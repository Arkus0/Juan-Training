import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/rutina.dart';
import '../providers/training_provider.dart';
import 'training_session_screen.dart';

class TrainSelectionScreen extends ConsumerWidget {
  const TrainSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenar'),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Rutina>('rutinas').listenable(),
        builder: (context, Box<Rutina> box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text('No tienes rutinas creadas.\nVe a la pestaña Rutinas para crear una.',
                textAlign: TextAlign.center,
              ),
            );
          }

          final rutinas = box.values.toList();
          // Sort by creation date? Or just list.

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rutinas.length,
            itemBuilder: (context, index) {
              final rutina = rutinas[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    // Initialize session
                    ref.read(trainingSessionProvider.notifier).startSession(rutina);
                    // Navigate to session screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrainingSessionScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rutina.nombre,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${rutina.ejercicios.length} Ejercicios',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 8),
                        // Preview exercises (first 3)
                        if (rutina.ejercicios.isNotEmpty)
                          Text(
                            rutina.ejercicios.take(3).map((e) => e.nombre).join(', ') +
                            (rutina.ejercicios.length > 3 ? '...' : ''),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
