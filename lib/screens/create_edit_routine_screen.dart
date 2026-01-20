import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
      // Start with one empty exercise for convenience
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
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

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
        peso: double.tryParse(c.pesoController.text.replaceAll(',', '.')) ?? 0.0,
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
      // Ensure we use the same ID as key
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

  void _deleteRoutine() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Rutina'),
        content: const Text('¿Estás seguro de que quieres eliminar esta rutina? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.rutina != null) {
      final box = Hive.box<Rutina>('rutinas');
      await box.delete(widget.rutina!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap outside
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.rutina != null ? 'Editar Rutina' : 'Crear Rutina'),
          actions: [
            if (widget.rutina != null)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _deleteRoutine,
                tooltip: 'Eliminar',
              ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveRoutine,
              tooltip: 'Guardar',
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
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Rutina',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), // Extra padding for FAB/Button
                  itemCount: _exerciseControllers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return _ExerciseFormCard(
                      index: index,
                      controller: _exerciseControllers[index],
                      onRemove: () => _removeExercise(index),
                      isLast: index == _exerciseControllers.length - 1,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addExercise(),
          icon: const Icon(Icons.add),
          label: const Text('Ejercicio'),
        ),
      ),
    );
  }
}

class _ExerciseFormCard extends StatelessWidget {
  final int index;
  final _ExerciseControllers controller;
  final VoidCallback onRemove;
  final bool isLast;

  const _ExerciseFormCard({
    required this.index,
    required this.controller,
    required this.onRemove,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Ejercicio ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onRemove,
                  tooltip: 'Quitar ejercicio',
                ),
              ],
            ),
            TextFormField(
              controller: controller.nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre del Ejercicio',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (value) => value == null || value.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller.seriesController,
                    decoration: const InputDecoration(
                      labelText: 'Series',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Requerido';
                      if (int.tryParse(value) == null) return 'Número';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller.repsController,
                    decoration: const InputDecoration(
                      labelText: 'Reps',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Requerido';
                      if (int.tryParse(value) == null) return 'Número';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller.pesoController,
                    decoration: const InputDecoration(
                      labelText: 'Peso (kg)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller.notesController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
                alignLabelWithHint: true,
              ),
              maxLines: 2,
              minLines: 1,
              textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
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
    pesoController = TextEditingController(text: ejercicio?.peso == 0.0 ? '' : ejercicio?.peso.toString());
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
