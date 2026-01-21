import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/dia.dart';
import '../../../models/ejercicio_en_rutina.dart';
import 'ejercicio_card.dart';

class DiaExpansionTile extends StatefulWidget {
  final int dayIndex;
  final Dia dia;
  final Function(String) onUpdateName;
  final Function(String) onUpdateProgression;
  final Function() onAddExercise;
  final Function(int, int) onReorderExercises;
  final Function(int) onRemoveExercise;
  final Function(int, EjercicioEnRutina) onUndoRemove;
  final Function(int, EjercicioEnRutina) onUpdateExercise;
  final Function() onRemoveDay;
  final Function() onDuplicateDay;
  final Function(int, int) onCreateSuperset;
  final Function(int) onRemoveFromSuperset;

  const DiaExpansionTile({
    super.key,
    required this.dayIndex,
    required this.dia,
    required this.onUpdateName,
    required this.onUpdateProgression,
    required this.onAddExercise,
    required this.onReorderExercises,
    required this.onRemoveExercise,
    required this.onUndoRemove,
    required this.onUpdateExercise,
    required this.onRemoveDay,
    required this.onDuplicateDay,
    required this.onCreateSuperset,
    required this.onRemoveFromSuperset,
  });

  @override
  State<DiaExpansionTile> createState() => _DiaExpansionTileState();
}

class _DiaExpansionTileState extends State<DiaExpansionTile> {
  bool _isExpanded = true;
  late TextEditingController _nameController;
  int? _lastReorderOldIndex;
  int? _lastReorderNewIndex;

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

  List<List<int>> _getVisualGroupIndices() {
    final groups = <List<int>>[];
    if (widget.dia.ejercicios.isEmpty) return groups;

    List<int> currentGroup = [];
    String? currentSupersetId;

    for (int i = 0; i < widget.dia.ejercicios.length; i++) {
      final ex = widget.dia.ejercicios[i];
      if (currentGroup.isEmpty) {
        currentGroup.add(i);
        currentSupersetId = ex.supersetId;
      } else {
        if (ex.supersetId != null && ex.supersetId == currentSupersetId) {
           currentGroup.add(i);
        } else {
           groups.add(currentGroup);
           currentGroup = [i];
           currentSupersetId = ex.supersetId;
        }
      }
    }
    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }
    return groups;
  }

  void _handleReorder(int oldIndex, int newIndex) {
    widget.onReorderExercises(oldIndex, newIndex);
    
    // After reordering, check if user wants to create a superset
    // If they dragged a single exercise next to another single exercise, offer to link them
    _lastReorderOldIndex = oldIndex;
    _lastReorderNewIndex = newIndex;
    
    // Wait a bit to let the UI update, then show option
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      
      // Get updated groups
      final visualGroups = _getVisualGroupIndices();
      
      // Find where the moved item ended up
      final actualNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
      
      // Check if we can suggest creating a superset
      if (actualNewIndex >= 0 && actualNewIndex < visualGroups.length) {
        final currentGroup = visualGroups[actualNewIndex];
        
        // Only suggest if this is a single item
        if (currentGroup.length == 1) {
          final currentEx = widget.dia.ejercicios[currentGroup.first];
          
          // Check adjacent groups
          EjercicioEnRutina? adjacentEx;
          int adjacentIdx = -1;
          
          if (actualNewIndex > 0) {
            // Check previous group
            final prevGroup = visualGroups[actualNewIndex - 1];
            if (prevGroup.length == 1) {
              adjacentEx = widget.dia.ejercicios[prevGroup.first];
              adjacentIdx = prevGroup.first;
            }
          }
          
          if (adjacentEx == null && actualNewIndex < visualGroups.length - 1) {
            // Check next group
            final nextGroup = visualGroups[actualNewIndex + 1];
            if (nextGroup.length == 1) {
              adjacentEx = widget.dia.ejercicios[nextGroup.first];
              adjacentIdx = nextGroup.first;
            }
          }
          
          // If we found an adjacent single exercise, suggest linking
          if (adjacentEx != null && 
              currentEx.supersetId == null && 
              adjacentEx.supersetId == null) {
            _showSupersetDialog(currentGroup.first, adjacentIdx);
          }
        }
      }
    });
  }

  void _showSupersetDialog(int idxA, int idxB) {
    final exA = widget.dia.ejercicios[idxA];
    final exB = widget.dia.ejercicios[idxB];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          '¿CREAR SUPERSERIE?',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            color: Colors.red[900],
          ),
        ),
        content: Text(
          '¿Quieres vincular "${exA.nombre}" y "${exB.nombre}" en una superserie?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('NO', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
            onPressed: () {
              Navigator.pop(context);
              widget.onCreateSuperset(idxA, idxB);
            },
            child: const Text('SÍ, VINCULAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visualGroups = _getVisualGroupIndices();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.red[900]!, width: 1),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.red[900]!.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
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
                  ReorderableColumn(
                    onReorder: _handleReorder,
                    children: visualGroups.map((groupIndices) {
                      final isSuperset = groupIndices.length > 1 || (groupIndices.isNotEmpty && widget.dia.ejercicios[groupIndices.first].supersetId != null);

                      // Identify key for the group
                      final firstEx = widget.dia.ejercicios[groupIndices.first];
                      final Key groupKey = isSuperset
                          ? Key('superset_${firstEx.supersetId}')
                          : Key(firstEx.instanceId);

                      if (isSuperset) {
                         return Container(
                           key: groupKey,
                           margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                           decoration: BoxDecoration(
                             border: Border(left: BorderSide(color: Colors.redAccent, width: 4)),
                             color: Colors.grey[900]!.withValues(alpha: 0.5),
                           ),
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: groupIndices.map((idx) {
                               final ex = widget.dia.ejercicios[idx];
                               return EjercicioCard(
                                 ejercicio: ex,
                                 onRemove: () => widget.onRemoveExercise(idx),
                                 onUpdate: (updated) => widget.onUpdateExercise(idx, updated),
                                 onLink: (idx < widget.dia.ejercicios.length - 1)
                                     ? () => widget.onCreateSuperset(idx, idx + 1)
                                     : null,
                                 onUnlink: () => widget.onRemoveFromSuperset(idx),
                               );
                             }).toList(),
                           ),
                         );
                      } else {
                        // Single item
                        final idx = groupIndices.first;
                        final ex = widget.dia.ejercicios[idx];
                        return Dismissible(
                          key: Key(ex.instanceId),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red[900],
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            final removedItem = ex;
                            widget.onRemoveExercise(idx);
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                              SnackBar(
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                  'Ejercicio eliminado',
                                  style: GoogleFonts.montserrat(
                                      color: Colors.white),
                                ),
                                backgroundColor: Colors.red[900],
                                action: SnackBarAction(
                                  label: 'DESHACER',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    widget.onUndoRemove(idx, removedItem);
                                  },
                                ),
                              ),
                            );
                          },
                          child: Container(
                            key: groupKey,
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            child: EjercicioCard(
                              ejercicio: ex,
                              onRemove: () => widget.onRemoveExercise(idx),
                              onUpdate: (updated) =>
                                  widget.onUpdateExercise(idx, updated),
                              onLink: (idx < widget.dia.ejercicios.length - 1)
                                  ? () => widget.onCreateSuperset(idx, idx + 1)
                                  : null,
                              onUnlink: null, // No unlink for single item
                            ),
                          ),
                        );
                      }
                    }).toList(),
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
