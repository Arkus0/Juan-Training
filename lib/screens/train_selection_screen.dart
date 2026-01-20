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
        title: const Text('SELECCIONAR ENTRENO'),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Rutina>('rutinas').listenable(),
        builder: (context, Box<Rutina> box, _) {
          if (box.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 80, color: Colors.redAccent[700]),
                  const SizedBox(height: 24),
                  Text(
                    'SIN RUTINAS',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ve a Rutinas y crea tu plan de batalla.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final rutinas = box.values.toList();
          rutinas.sort((a, b) => b.creada.compareTo(a.creada));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rutinas.length,
            itemBuilder: (context, index) {
              final rutina = rutinas[index];
              return Card(
                child: InkWell(
                  onTap: () {
                    if (rutina.dias.isEmpty) return;

                    if (rutina.dias.length == 1) {
                      ref
                          .read(trainingSessionProvider.notifier)
                          .startSession(rutina, rutina.dias.first.ejercicios);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrainingSessionScreen(),
                        ),
                      );
                    } else {
                      showDialog(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: Text('ELIGE DÍA',
                              style: TextStyle(
                                  color: Colors.red[900],
                                  fontWeight: FontWeight.w900)),
                          backgroundColor: Colors.grey[900],
                          children: rutina.dias.map((d) {
                            return SimpleDialogOption(
                              padding: const EdgeInsets.all(16),
                              child: Text(d.nombre,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                              onPressed: () {
                                Navigator.pop(context);
                                ref
                                    .read(trainingSessionProvider.notifier)
                                    .startSession(rutina, d.ejercicios);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const TrainingSessionScreen(),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rutina.nombre.toUpperCase(),
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red[900],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'START',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${rutina.dias.length} DÍAS',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.redAccent[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // List days instead of exercises
                        if (rutina.dias.isNotEmpty)
                          Text(
                            rutina.dias.take(3).map((d) => d.nombre).join(' • ').toUpperCase(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                            maxLines: 2,
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
