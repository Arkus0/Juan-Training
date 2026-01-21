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
  bool _isLinkDragActive = false;
  bool _dragAccepted = false;
  int? _dragSourceVisualIndex;

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

  @override
  Widget build(BuildContext context) {
    final visualGroups = _getVisualGroupIndices();

    int? _flatIndexFromVisual(int visualIndex) {
      if (visualIndex < 0 || visualIndex >= visualGroups.length) return null;
      final group = visualGroups[visualIndex];
      if (group.isEmpty) return null;
      return group.first;
    }

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
                  Column(
                    children: visualGroups.asMap().entries.map((entry) {
                      final visualIndex = entry.key;
                      final groupIndices = entry.value;
                      final isSuperset = groupIndices.length > 1 || (groupIndices.isNotEmpty && widget.dia.ejercicios[groupIndices.first].supersetId != null);

                      // Identify key for the group
                      final firstEx = widget.dia.ejercicios[groupIndices.first];
                      final Key groupKey = isSuperset
                          ? Key('superset_${firstEx.supersetId}')
                          : Key(firstEx.instanceId);

                      if (isSuperset) {
                         return DragTarget<int>(
                           key: groupKey,
                           onWillAccept: (data) => data != null && data != visualIndex,
                           onAccept: (data) {
                             final sourceFlat = _flatIndexFromVisual(data);
                             final targetFlat = _flatIndexFromVisual(visualIndex);
                             if (sourceFlat != null && targetFlat != null) {
                               _dragAccepted = true;
                               widget.onCreateSuperset(sourceFlat, targetFlat);
                             }
                             _isLinkDragActive = false;
                             setState(() {});
                           },
                           builder: (context, candidateData, rejectedData) {
                             return Container(
                               margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                               decoration: BoxDecoration(
                                 border: Border(left: BorderSide(color: candidateData.isNotEmpty ? Colors.amber : Colors.redAccent, width: 4)),
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
                                     onLink: () {},
                                     onUnlink: () => widget.onRemoveFromSuperset(idx),
                                     linkDragData: visualIndex,
                                     onLinkDragStart: () {
                                       _isLinkDragActive = true;
                                       _dragAccepted = false;
                                       _dragSourceVisualIndex = visualIndex;
                                       setState(() {});
                                     },
                                     onLinkDragEnd: () {
                                       if (!_dragAccepted && ex.supersetId != null) {
                                         widget.onRemoveFromSuperset(idx);
                                       }
                                       _isLinkDragActive = false;
                                       _dragSourceVisualIndex = null;
                                       setState(() {});
                                     },
                                     onLinkDragCancel: () {
                                       if (!_dragAccepted && ex.supersetId != null) {
                                         widget.onRemoveFromSuperset(idx);
                                       }
                                       _isLinkDragActive = false;
                                       _dragSourceVisualIndex = null;
                                       setState(() {});
                                     },
                                     disableSwipe: _isLinkDragActive,
                                   );
                                 }).toList(),
                               ),
                             );
                           },
                         );
                      } else {
                        // Single item
                        final idx = groupIndices.first;
                        final ex = widget.dia.ejercicios[idx];
                        return DragTarget<int>(
                          onWillAccept: (data) => data != null && data != visualIndex,
                          onAccept: (data) {
                            final sourceFlat = _flatIndexFromVisual(data);
                            final targetFlat = _flatIndexFromVisual(visualIndex);
                            if (sourceFlat != null && targetFlat != null) {
                              _dragAccepted = true;
                              widget.onCreateSuperset(sourceFlat, targetFlat);
                            }
                            _isLinkDragActive = false;
                            _dragSourceVisualIndex = null;
                            setState(() {});
                          },
                          builder: (context, candidateData, rejectedData) {
                            return Dismissible(
                              key: Key(ex.instanceId),
                              direction: _isLinkDragActive ? DismissDirection.none : DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: Colors.red[900],
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) {
                                final removedItem = ex;
                                widget.onRemoveExercise(idx);

                                BuildContext? dialogCtx;
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  barrierColor: Colors.black26,
                                  builder: (dialogContext) {
                                    dialogCtx = dialogContext;
                                    return Center(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          margin: const EdgeInsets.symmetric(horizontal: 40),
                                          decoration: BoxDecoration(
                                            color: Colors.red[900],
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Ejercicio eliminado',
                                                style: GoogleFonts.montserrat(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 12),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor: Colors.red[900],
                                                  minimumSize: const Size(double.infinity, 40),
                                                ),
                                                onPressed: () {
                                                  Navigator.of(dialogContext).pop();
                                                  widget.onUndoRemove(idx, removedItem);
                                                },
                                                child: Text(
                                                  'DESHACER',
                                                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );

                                // Auto-close after 1.5 seconds (only this dialog)
                                Future.delayed(const Duration(milliseconds: 1500), () {
                                  if (dialogCtx != null && Navigator.of(dialogCtx!, rootNavigator: true).canPop()) {
                                    Navigator.of(dialogCtx!, rootNavigator: true).pop();
                                  }
                                });
                              },
                              child: Container(
                                key: groupKey,
                                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                decoration: candidateData.isNotEmpty
                                    ? BoxDecoration(
                                        border: Border.all(color: Colors.amber, width: 2),
                                        borderRadius: BorderRadius.circular(8),
                                      )
                                    : null,
                                child: EjercicioCard(
                                  ejercicio: ex,
                                  onRemove: () => widget.onRemoveExercise(idx),
                                  onUpdate: (updated) => widget.onUpdateExercise(idx, updated),
                                  onLink: () {},
                                  onUnlink: null,
                                  linkDragData: visualIndex,
                                  onLinkDragStart: () {
                                    _isLinkDragActive = true;
                                    _dragAccepted = false;
                                    _dragSourceVisualIndex = visualIndex;
                                    setState(() {});
                                  },
                                  onLinkDragEnd: () {
                                    if (!_dragAccepted && ex.supersetId != null) {
                                      widget.onRemoveFromSuperset(idx);
                                    }
                                    _isLinkDragActive = false;
                                    _dragSourceVisualIndex = null;
                                    setState(() {});
                                  },
                                  onLinkDragCancel: () {
                                    if (!_dragAccepted && ex.supersetId != null) {
                                      widget.onRemoveFromSuperset(idx);
                                    }
                                    _isLinkDragActive = false;
                                    _dragSourceVisualIndex = null;
                                    setState(() {});
                                  },
                                  disableSwipe: _isLinkDragActive,
                                ),
                              ),
                            );
                          },
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
