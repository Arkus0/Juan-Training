import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:juan_training/models/dia.dart';
import 'package:juan_training/models/ejercicio_en_rutina.dart';
import 'package:juan_training/screens/create_routine/widgets/ejercicio_card.dart';

class DiaExpansionTile extends StatefulWidget {
  final int dayIndex;
  final Dia dia;
  final Function(String) onUpdateName;
  final Function(String) onUpdateProgression;
  final Function() onAddExercise;
  final Function(int, int) onReorderExercises;
  final Function(int, int) onMoveExercise;
  final Function(int) onRemoveExercise;
  final Function(int, EjercicioEnRutina) onUndoRemove;
  final Function(int, EjercicioEnRutina) onUpdateExercise;
  final Function(int, String) onReplaceExercise;
  final Function() onRemoveDay;
  final Function() onDuplicateDay;
  final Function(int, int) onCreateSuperset;
  final Function(String, int) onMoveSuperset;
  final Function(int) onRemoveFromSuperset;

  const DiaExpansionTile({
    super.key,
    required this.dayIndex,
    required this.dia,
    required this.onUpdateName,
    required this.onUpdateProgression,
    required this.onAddExercise,
    required this.onReorderExercises,
    required this.onMoveExercise,
    required this.onRemoveExercise,
    required this.onUndoRemove,
    required this.onUpdateExercise,
    required this.onReplaceExercise,
    required this.onRemoveDay,
    required this.onDuplicateDay,
    required this.onCreateSuperset,
    required this.onMoveSuperset,
    required this.onRemoveFromSuperset,
  });

  @override
  State<DiaExpansionTile> createState() => _DiaExpansionTileState();
}

class _DiaExpansionTileState extends State<DiaExpansionTile> {
  bool _isExpanded = true;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.dia.nombre);
  }

  @override
  void didUpdateWidget(DiaExpansionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dia.nombre != widget.dia.nombre) {
      _nameController.text = widget.dia.nombre;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Computes visual groups for display. Each group is a list of flat indices
  /// that should be displayed together (supersets grouped, singles alone).
  List<List<int>> _computeVisualGroups(List<EjercicioEnRutina> exercises) {
    if (exercises.isEmpty) return [];

    final groups = <List<int>>[];
    final processedIndices = <int>{};

    for (int i = 0; i < exercises.length; i++) {
      if (processedIndices.contains(i)) continue;

      final ex = exercises[i];
      if (ex.supersetId != null) {
        // Find all exercises with same supersetId
        final group = <int>[];
        for (int j = 0; j < exercises.length; j++) {
          if (exercises[j].supersetId == ex.supersetId) {
            group.add(j);
            processedIndices.add(j);
          }
        }
        groups.add(group);
      } else {
        groups.add([i]);
        processedIndices.add(i);
      }
    }
    return groups;
  }

  void _showProOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OPCIONES PRO 💀',
                style: GoogleFonts.montserrat(
                  fontSize: 20, fontWeight: FontWeight.w900, color: Colors.red[900]),
              ),
              const SizedBox(height: 24),
              ListTile(
                title: const Text('Progresión Automática', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  widget.dia.progressionType.toUpperCase(),
                  style: TextStyle(color: Colors.redAccent[700]),
                ),
                trailing: DropdownButton<String>(
                  dropdownColor: Colors.grey[850],
                  value: ['none', 'lineal', 'double', 'percentage1RM'].contains(widget.dia.progressionType)
                      ? widget.dia.progressionType
                      : 'none',
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('Ninguna', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'lineal', child: Text('Lineal', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'double', child: Text('Doble Progresión', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'percentage1RM', child: Text('% 1RM', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      widget.onUpdateProgression(val);
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.white),
                title: const Text('DUPLICAR DÍA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDuplicateDay();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('ELIMINAR DÍA', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onRemoveDay();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {


    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.red[900]!, width: 1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.red[900]!.withValues(alpha: 77 / 255.0),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.red[900]!.withValues(alpha: 51 / 255.0),
            blurRadius: 12,
            spreadRadius: -2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            color: Colors.grey[900],
            child: Row(
              children: [
                GestureDetector(
                  onLongPress: _showProOptions,
                  child: Icon(Icons.drag_handle, color: Colors.red[900]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: GoogleFonts.montserrat(
                      fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      isDense: true,
                      hintText: 'Nombre del día',
                      hintStyle: TextStyle(color: Colors.white38),
                    ),
                    onChanged: widget.onUpdateName,
                  ),
                ),
                if (widget.dia.progressionType != 'none')
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.auto_graph, color: Colors.redAccent[700], size: 20),
                  ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          if (_isExpanded)
            Column(
              children: [
                if (widget.dia.ejercicios.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'VACÍO. AÑADE DOLOR.',
                      style: GoogleFonts.montserrat(
                        color: Colors.white38, fontStyle: FontStyle.italic),
                    ),
                  ),

                // Exercises List
                if (widget.dia.ejercicios.isNotEmpty)
                  Builder(
                    builder: (context) {
                      final visualGroups = _computeVisualGroups(widget.dia.ejercicios);
                      return ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visualGroups.length,
                        onReorder: widget.onReorderExercises,
                        buildDefaultDragHandles: false,
                        itemBuilder: (context, visualIndex) {
                          final groupIndices = visualGroups[visualIndex];
                          final isSuperset = groupIndices.length > 1 ||
                              (groupIndices.isNotEmpty &&
                               widget.dia.ejercicios[groupIndices.first].supersetId != null);

                          // Identify key for the group
                          final firstEx = widget.dia.ejercicios[groupIndices.first];
                          final Key groupKey = Key('group_${firstEx.supersetId ?? firstEx.instanceId}');

                          return ReorderableDragStartListener(
                            index: visualIndex,
                            key: groupKey,
                            child: _ExerciseGroupWidget(
                              groupIndices: groupIndices,
                              exercises: widget.dia.ejercicios,
                              isSuperset: isSuperset,
                              onRemoveExercise: widget.onRemoveExercise,
                              onUpdateExercise: widget.onUpdateExercise,
                              onReplaceExercise: widget.onReplaceExercise,
                              onCreateSuperset: widget.onCreateSuperset,
                              onRemoveFromSuperset: widget.onRemoveFromSuperset,
                              onUndoRemove: widget.onUndoRemove,
                            ),
                          );
                        },
                      );
                    },
                  ),

                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: widget.onAddExercise,
                    icon: const Icon(Icons.add, color: Colors.redAccent),
                    label: Text(
                      'AÑADIR EJERCICIO',
                      style: GoogleFonts.montserrat(
                        color: Colors.redAccent, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
        ],
      ),
    );
  }
}

/// Lightweight widget for rendering a single visual group (either a single exercise or a superset)
class _ExerciseGroupWidget extends StatelessWidget {
  final List<int> groupIndices;
  final List<EjercicioEnRutina> exercises;
  final bool isSuperset;
  final Function(int) onRemoveExercise;
  final Function(int, EjercicioEnRutina) onUpdateExercise;
  final Function(int, String) onReplaceExercise;
  final Function(int, int) onCreateSuperset;
  final Function(int) onRemoveFromSuperset;
  final Function(int, EjercicioEnRutina) onUndoRemove;

  const _ExerciseGroupWidget({
    required this.groupIndices,
    required this.exercises,
    required this.isSuperset,
    required this.onRemoveExercise,
    required this.onUpdateExercise,
    required this.onReplaceExercise,
    required this.onCreateSuperset,
    required this.onRemoveFromSuperset,
    required this.onUndoRemove,
  });

  void _showDeleteSnackbar(BuildContext context, int idx, EjercicioEnRutina removedItem) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${removedItem.nombre} eliminado',
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
        backgroundColor: Colors.red[900],
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
        action: SnackBarAction(
          label: 'DESHACER',
          textColor: Colors.white,
          onPressed: () {
            onUndoRemove(idx, removedItem);
          },
        ),
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, int idx, EjercicioEnRutina ex, {bool inSuperset = false}) {
    final card = EjercicioCard(
      key: Key('exercise_${ex.instanceId}'),
      ejercicio: ex,
      onRemove: () {
        final removedItem = ex;
        onRemoveExercise(idx);
        _showDeleteSnackbar(context, idx, removedItem);
      },
      onUpdate: (updated) => onUpdateExercise(idx, updated),
      onReplace: (alternativaNombre) => onReplaceExercise(idx, alternativaNombre),
      onLink: (idx < exercises.length - 1)
          ? () => onCreateSuperset(idx, idx + 1)
          : null,
      onUnlink: inSuperset ? () => onRemoveFromSuperset(idx) : null,
    );

    // Swipe to delete for all exercises (including superset members)
    return Dismissible(
      key: Key('dismissible_${ex.instanceId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red[900],
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        final removedItem = ex;
        onRemoveExercise(idx);
        _showDeleteSnackbar(context, idx, removedItem);
      },
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isSuperset) {
      // Render superset group with swipe-to-delete for each item
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          border: const Border(left: BorderSide(color: Colors.redAccent, width: 4)),
          color: Colors.grey[900]!.withValues(alpha: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: groupIndices.map((idx) {
            final ex = exercises[idx];
            return _buildExerciseCard(context, idx, ex, inSuperset: true);
          }).toList(),
        ),
      );
    } else {
      // Single item with dismissible behavior
      final idx = groupIndices.first;
      final ex = exercises[idx];
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: _buildExerciseCard(context, idx, ex, inSuperset: false),
      );
    }
  }
}
