import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/rutina.dart';
import 'create_edit_routine_screen.dart';

class RutinasScreen extends StatelessWidget {
  const RutinasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the already opened box
    final rutinasBox = Hive.box<Rutina>('rutinas');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Rutinas'),
        centerTitle: false,
      ),
      body: ValueListenableBuilder(
        valueListenable: rutinasBox.listenable(),
        builder: (context, Box<Rutina> box, _) {
          if (box.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.fitness_center, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay rutinas creadas.\n¡Empieza hoy!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Convert values to list to sort
          final rutinas = box.values.toList();
          // Sort by date descending (newest first)
          rutinas.sort((a, b) => b.creada.compareTo(a.creada));

          return ListView.builder(
            itemCount: rutinas.length,
            padding: const EdgeInsets.all(16.0),
            itemBuilder: (context, index) {
              final rutina = rutinas[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 12.0),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    // Navigate to Edit screen for details/editing
                     Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CreateEditRoutineScreen(rutina: rutina),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                rutina.nombre,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.format_list_bulleted, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              '${rutina.ejercicios.length} ejercicios',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(rutina.creada),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
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
        label: const Text('Nueva Rutina'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
