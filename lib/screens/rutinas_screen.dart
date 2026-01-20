import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rutina.dart';
import 'create_edit_routine_screen.dart';
import '../providers/training_provider.dart';

class RutinasScreen extends ConsumerWidget {
  const RutinasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rutinasAsync = ref.watch(rutinasStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MIS RUTINAS'),
      ),
      body: rutinasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (rutinas) {
          if (rutinas.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 24),
                  Text(
                    'NO HAY RUTINAS',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¡CREA TU LEGADO AHORA!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.redAccent[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: rutinas.length,
            padding: const EdgeInsets.all(16.0),
            itemBuilder: (context, index) {
              final rutina = rutinas[index];
              final totalExercises = rutina.dias.fold(0, (sum, day) => sum + day.ejercicios.length);

              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // Navigate to Edit screen
                     Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CreateEditRoutineScreen(rutina: rutina),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                rutina.nombre.toUpperCase(),
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.edit, color: Colors.redAccent[700]),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.calendar_view_week, size: 18, color: Colors.grey[400]),
                            const SizedBox(width: 6),
                            Text(
                              '${rutina.dias.length} DÍAS',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.fitness_center, size: 18, color: Colors.grey[400]),
                            const SizedBox(width: 6),
                            Text(
                              '$totalExercises EJERCICIOS',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateEditRoutineScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('NUEVA RUTINA'),
      ),
    );
  }
}
