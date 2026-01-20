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
      ),
      body: ValueListenableBuilder(
        valueListenable: rutinasBox.listenable(),
        builder: (context, Box<Rutina> box, _) {
          if (box.isEmpty) {
            return const Center(
              child: Text(
                'No hay rutinas creadas.\n¡Crea la primera!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Convert values to list to sort or display
          final rutinas = box.values.toList();
          // Optional: Sort by date descending
          rutinas.sort((a, b) => b.creada.compareTo(a.creada));

          return ListView.builder(
            itemCount: rutinas.length,
            padding: const EdgeInsets.all(16.0),
            itemBuilder: (context, index) {
              final rutina = rutinas[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12.0),
                child: ListTile(
                  title: Text(
                    rutina.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${rutina.ejercicios.length} ejercicios • ${_formatDate(rutina.creada)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to details or edit
                    // For now we might want to edit it.
                    // The prompt says: "Al pulsar FAB -> navega a CreateEditRoutineScreen".
                    // It doesn't explicitly say what happens on tapping a list item,
                    // but usually it opens details. I'll leave it as TODO or navigate to edit.
                    // Let's navigate to edit for convenience as "CreateEditRoutineScreen" implies both.
                     Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CreateEditRoutineScreen(rutina: rutina),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const CreateEditRoutineScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
