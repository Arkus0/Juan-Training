import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/ejercicio.dart';
import '../models/rutina.dart';

class CreateEditRoutineScreen extends StatefulWidget {
  final Rutina? rutina;

  const CreateEditRoutineScreen({super.key, this.rutina});

  @override
  State<CreateEditRoutineScreen> createState() => _CreateEditRoutineScreenState();
}

class _CreateEditRoutineScreenState extends State<CreateEditRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final List<_ExerciseControllers> _exerciseControllers = [];

  // Use a constant UUID instance
  static const _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rutina?.nombre ?? '');

    if (widget.rutina != null) {
      for (var ex in widget.rutina!.ejercicios) {
        _addExercise(ejercicio: ex);
      }
    } else {
      // Add one empty exercise by default for convenience?
      // Prompt says: "Lista dinámica de ejercicios (botón + para añadir nuevo)"
      // and "ejercicios al menos 1".
      // Let's start empty or with one. Start with one to make it obvious.
      _addExercise();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var controller in _exerciseControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addExercise({Ejercicio? ejercicio}) {
    setState(() {
      _exerciseControllers.add(_ExerciseControllers(ejercicio));
    });
  }

  void _removeExercise(int index) {
    setState(() {
      _exerciseControllers[index].dispose();
      _exerciseControllers.removeAt(index);
    });
  }

  void _saveRoutine() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_exerciseControllers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos un ejercicio')),
      );
      return;
    }

    // Create Ejercicio objects
    final List<Ejercicio> ejercicios = _exerciseControllers.map((c) {
      return Ejercicio(
        id: c.existingId ?? _uuid.v4(),
        nombre: c.nameController.text.trim(),
        series: int.parse(c.seriesController.text),
        reps: int.parse(c.repsController.text),
        peso: double.tryParse(c.pesoController.text) ?? 0.0,
        notas: c.notesController.text.trim().isEmpty ? null : c.notesController.text.trim(),
      );
    }).toList();

    final box = Hive.box<Rutina>('rutinas');

    if (widget.rutina != null) {
      // Update existing
      final updatedRutina = Rutina(
        id: widget.rutina!.id,
        nombre: _nameController.text.trim(),
        ejercicios: ejercicios,
        creada: widget.rutina!.creada, // Keep original creation date
      );
      // Since we are using HiveObject, we could call widget.rutina!.save(),
      // but we need to update the fields.
      // Ideally with Hive, we replace the object in the box using the key (id usually, or auto-increment int key).
      // Wait, Hive keys. If I used `put(id, object)`, then key is id.
      // If I used `add(object)`, key is int.
      // I should check how I save it. I haven't saved any yet.
      // I will use `box.put(rutina.id, rutina)`.

      box.put(updatedRutina.id, updatedRutina);
    } else {
      // Create new
      final newRutina = Rutina(
        id: _uuid.v4(),
        nombre: _nameController.text.trim(),
        ejercicios: ejercicios,
        creada: DateTime.now(),
      );
      box.put(newRutina.id, newRutina);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rutina != null ? 'Editar Rutina' : 'Crear Rutina'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveRoutine,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Rutina',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _exerciseControllers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return _ExerciseFormCard(
                    index: index,
                    controller: _exerciseControllers[index],
                    onRemove: () => _removeExercise(index),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _addExercise(),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir Ejercicio'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseFormCard extends StatelessWidget {
  final int index;
  final _ExerciseControllers controller;
  final VoidCallback onRemove;

  const _ExerciseFormCard({
    required this.index,
    required this.controller,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ejercicio ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onRemove,
                ),
              ],
            ),
            TextFormField(
              controller: controller.nameController,
              decoration: const InputDecoration(labelText: 'Nombre del Ejercicio'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller.seriesController,
                    decoration: const InputDecoration(labelText: 'Series'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Req';
                      if (int.tryParse(value) == null) return 'Num';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller.repsController,
                    decoration: const InputDecoration(labelText: 'Reps'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Req';
                      if (int.tryParse(value) == null) return 'Num';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller.pesoController,
                    decoration: const InputDecoration(labelText: 'Peso (kg)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    // Peso es opcional, default 0
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: controller.notesController,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              maxLines: 2,
              minLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class to manage controllers for each exercise
class _ExerciseControllers {
  final String? existingId;
  late TextEditingController nameController;
  late TextEditingController seriesController;
  late TextEditingController repsController;
  late TextEditingController pesoController;
  late TextEditingController notesController;

  _ExerciseControllers(Ejercicio? ejercicio) : existingId = ejercicio?.id {
    nameController = TextEditingController(text: ejercicio?.nombre ?? '');
    seriesController = TextEditingController(text: ejercicio?.series.toString() ?? '');
    repsController = TextEditingController(text: ejercicio?.reps.toString() ?? '');
    pesoController = TextEditingController(text: ejercicio?.peso.toString() ?? '');
    notesController = TextEditingController(text: ejercicio?.notas ?? '');
  }

  void dispose() {
    nameController.dispose();
    seriesController.dispose();
    repsController.dispose();
    pesoController.dispose();
    notesController.dispose();
  }
}
