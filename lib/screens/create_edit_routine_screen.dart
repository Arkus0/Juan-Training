import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/ejercicio.dart';
import '../models/library_exercise.dart';
import '../models/rutina.dart';
import 'search_exercise_screen.dart';

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

  void _openLibrary() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchExerciseScreen()),
    );

    if (result != null && result is LibraryExercise) {
      if (_exerciseControllers.isNotEmpty) {
        final lastCtrl = _exerciseControllers.last;
        final isEmpty = lastCtrl.nameController.text.trim().isEmpty &&
            (lastCtrl.seriesController.text.trim().isEmpty || lastCtrl.seriesController.text == '0') &&
            (lastCtrl.repsController.text.trim().isEmpty || lastCtrl.repsController.text == '0');

        if (isEmpty) {
          lastCtrl.nameController.text = result.name;
          if (lastCtrl.seriesController.text.isEmpty) lastCtrl.seriesController.text = '3';
          if (lastCtrl.repsController.text.isEmpty) lastCtrl.repsController.text = '10';
          if (lastCtrl.pesoController.text.isEmpty) lastCtrl.pesoController.text = '0.0';
          return;
        }
      }

      final newExercise = Ejercicio(
        id: _uuid.v4(),
        nombre: result.name,
        series: 3,
        reps: 10,
        peso: 0.0,
        notas: '',
      );
      _addExercise(ejercicio: newExercise);
    }
  }

  void _removeExercise(int index) {
    setState(() {
      _exerciseControllers[index].dispose();
      _exerciseControllers.removeAt(index);
    });
  }

  void _saveRoutine() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_exerciseControllers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red[900], content: const Text('¡AÑADE AL MENOS UN EJERCICIO!')),
      );
      return;
    }

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
      final updatedRutina = Rutina(
        id: widget.rutina!.id,
        nombre: _nameController.text.trim(),
        ejercicios: ejercicios,
        creada: widget.rutina!.creada,
      );
      box.put(updatedRutina.id, updatedRutina);
    } else {
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
        backgroundColor: Colors.grey[900],
        title: Text('ELIMINAR RUTINA', style: Theme.of(context).textTheme.headlineSmall),
        content: const Text('¿Estás seguro? Se perderá para siempre.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent[700]),
            child: const Text('ELIMINAR', style: TextStyle(fontWeight: FontWeight.bold)),
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
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.rutina != null ? 'EDITAR ESTRATEGIA' : 'NUEVA ESTRATEGIA'),
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    labelText: 'NOMBRE DEL PLAN',
                    prefixIcon: Icon(Icons.edit, color: Colors.white),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Requerido';
                    }
                    return null;
                  },
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
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
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'library',
              onPressed: _openLibrary,
              backgroundColor: Colors.grey[800],
              icon: const Icon(Icons.library_books),
              label: const Text('BIBLIOTECA'),
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
              heroTag: 'manual',
              onPressed: () => _addExercise(),
              child: const Icon(Icons.add),
              tooltip: 'Manual',
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[900],
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'EJERCICIO ${index + 1}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.redAccent[700],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller.nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'NOMBRE DEL EJERCICIO',
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
                      labelText: 'SERIES',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) return '!';
                      if (int.tryParse(value) == null) return '#';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller.repsController,
                    decoration: const InputDecoration(
                      labelText: 'REPS',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.isEmpty) return '!';
                      if (int.tryParse(value) == null) return '#';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controller.pesoController,
                    decoration: const InputDecoration(
                      labelText: 'KG',
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
                labelText: 'NOTAS TÁCTICAS (OPCIONAL)',
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
