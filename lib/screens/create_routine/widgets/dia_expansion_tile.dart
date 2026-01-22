import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:implicitly_animated_reorderable_list/implicitly_animated_reorderable_list.dart';
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
  final Function(int, int) onMoveExercise;
  final Function(int) onRemoveExercise;
  final Function(int, EjercicioEnRutina) onUndoRemove;
  final Function(int, EjercicioEnRutina) onUpdateExercise;
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
  bool _isLinkDragActive = false;
  bool _dragAccepted = false;

  // Reorder drag state
  bool _isReorderDragActive = false;
  int? _reorderSourceFlatIndex;
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

  @override
  Widget build(BuildContext context) {
    // Helper: build insertion dropzone for any flat insertion index
    Widget buildInsertionDropZone(int insertionFlatIndex) {
      return DragTarget<Object>(
        onWillAcceptWithDetails: (details) => details.data is SupersetDragData || details.data is ReorderDragData,
        onAcceptWithDetails: (details) {
          final data = details.data;
          _dragAccepted = true;
          if (data is ReorderDragData) {
            // Move single exercise by flat indices
            widget.onMoveExercise(data.flatIndex, insertionFlatIndex);
          } else if (data is SupersetDragData) {
            // If it's a superset block, move the whole block
            if (data.supersetId != null) {
              widget.onMoveSuperset(data.supersetId!, insertionFlatIndex);
            } else {
              // single exercise without superset
              widget.onMoveExercise(data.flatIndex, insertionFlatIndex);
            }
          }
          _isLinkDragActive = false;
          _dragSourceVisualIndex = null;
          _isReorderDragActive = false;
          _reorderSourceFlatIndex = null;
          setState(() {});
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;
          final show = isHovering || _isReorderDragActive;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: show ? 12 : 8,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: show
                ? BoxDecoration(
                    color: isHovering ? Colors.redAccent[700]!.withValues(alpha: 31 / 255.0) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            child: isHovering
                ? Center(child: Container(height: 4, width: double.infinity, color: Colors.redAccent[700]))
                : null,
          );
        },
      );
    }

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
                  Column(
                    children: [
                      ImplicitlyAnimatedList<EjercicioEnRutina>(
                        items: widget.dia.ejercicios,
                        areItemsTheSame: (a, b) => a.instanceId == b.instanceId,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, animation, ex, idx) {
                          return FadeTransition(
                            opacity: animation,
                            child: SizeTransition(
                              sizeFactor: animation,
                              axisAlignment: 0.0,
                              child: Column(
                                children: [
                                  buildInsertionDropZone(idx),
                                  Builder(
                                    builder: (ctx) {
                                      final isInSuperset = ex.supersetId != null;
                                      return DragTarget<SupersetDragData>(
                                        onWillAcceptWithDetails: (details) => true,
                                        onAcceptWithDetails: (details) {
                                          final data = details.data;
                                          _dragAccepted = true;
                                          if (data.supersetId != null) {
                                            // Merge/create superset with this item
                                            widget.onCreateSuperset(data.flatIndex, idx);
                                          } else {
                                            // Treat as single item move to this position (insert before idx)
                                            widget.onMoveExercise(data.flatIndex, idx);
                                          }

                                          _isLinkDragActive = false;
                                          _dragSourceVisualIndex = null;
                                          setState(() {});
                                        },
                                        builder: (context, candidateData, rejectedData) {
                                          final hovering = candidateData.isNotEmpty;
                                          return Dismissible(
                                            key: Key(ex.instanceId),
                                            direction: isInSuperset || _isLinkDragActive || _isReorderDragActive ? DismissDirection.none : DismissDirection.endToStart,
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
                                                              color: Colors.black.withValues(alpha: 77 / 255.0),
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
                                              if (mounted) {
                                                Future.delayed(const Duration(milliseconds: 1500), () {
                                                  if (dialogCtx != null && Navigator.of(dialogCtx!, rootNavigator: true).canPop()) {
                                                    Navigator.of(dialogCtx!, rootNavigator: true).pop();
                                                  }
                                                });
                                              }
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                              decoration: hovering
                                                  ? BoxDecoration(
                                                      border: Border.all(color: Colors.redAccent[700]!, width: 3),
                                                      borderRadius: BorderRadius.circular(8),
                                                      color: Colors.redAccent[700]!.withValues(alpha: 0.12),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.redAccent[700]!.withValues(alpha: 31 / 255.0),
                                                          blurRadius: 12,
                                                          spreadRadius: 2,
                                                        )
                                                      ],
                                                    )
                                                  : (isInSuperset
                                                      ? BoxDecoration(
                                                          border: const Border(
                                                            left: BorderSide(color: Colors.redAccent, width: 4),
                                                          ),
                                                          color: Colors.grey[900]!.withValues(alpha: 0.6),
                                                        )
                                                      : null),
                                              child: EjercicioCard(
                                                ejercicio: ex,
                                                onRemove: () => widget.onRemoveExercise(idx),
                                                onUpdate: (updated) => widget.onUpdateExercise(idx, updated),
                                                onLink: () {},
                                                onUnlink: ex.supersetId != null ? () => widget.onRemoveFromSuperset(idx) : null,
                                                linkDragData: SupersetDragData(
                                                  visualIndex: -1,
                                                  flatIndex: idx,
                                                  supersetId: ex.supersetId,
                                                ),
                                                reorderDragData: ReorderDragData(flatIndex: idx),
                                                onReorderDragStart: () {
                                                  _isReorderDragActive = true;
                                                  _reorderSourceFlatIndex = idx;
                                                _dragSourceVisualIndex = idx;
                                                _dragAccepted = false;
                                                setState(() {});
                                              },
                                              onReorderDragAccepted: () {
                                                _dragAccepted = true;
                                                setState(() {});
                                              },
                                              onReorderDragEnd: () {
                                                // If reorder drag finished without acceptance -> nothing
                                                _isReorderDragActive = false;
                                                _reorderSourceFlatIndex = null;
                                                _dragSourceVisualIndex = null;
                                                setState(() {});
                                              },
                                              onReorderDragCancel: () {
                                                if (!_dragAccepted && _reorderSourceFlatIndex != null) {
                                                  // Releasing outside any target -> treat as breaking superset if it was part of one
                                                  final orig = widget.dia.ejercicios[_reorderSourceFlatIndex!];
                                                  if (orig.supersetId != null) {
                                                    widget.onRemoveFromSuperset(_reorderSourceFlatIndex!);
                                                  }
                                                }
                                                _isReorderDragActive = false;
                                                _reorderSourceFlatIndex = null;
                                                _dragSourceVisualIndex = null;
                                                  setState(() {});
                                                },
                                                onReorderDragAccepted: () {
                                                  _dragAccepted = true;
                                                  setState(() {});
                                                },
                                                onReorderDragEnd: () {
                                                  // If reorder drag finished without acceptance -> nothing
                                                  _isReorderDragActive = false;
                                                  _reorderSourceFlatIndex = null;
                                                  setState(() {});
                                                },
                                                onReorderDragCancel: () {
                                                  if (!_dragAccepted && _reorderSourceFlatIndex != null) {
                                                    // Releasing outside any target -> treat as breaking superset if it was part of one
                                                    final orig = widget.dia.ejercicios[_reorderSourceFlatIndex!];
                                                    if (orig.supersetId != null) {
                                                      widget.onRemoveFromSuperset(_reorderSourceFlatIndex!);
                                                    }
                                                  }
                                                  _isReorderDragActive = false;
                                                  _reorderSourceFlatIndex = null;
                                                  setState(() {});
                                                },
                                                onLinkDragStart: () {
                                                  _isLinkDragActive = true;
                                                  _dragAccepted = false;
                                                  _dragSourceVisualIndex = idx;
                                                  setState(() {});
                                                },
                                                onLinkDragAccepted: () {
                                                  _dragAccepted = true;
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
                                                disableSwipe: _isLinkDragActive || _isReorderDragActive,
                                              ),
                                            ),
                                          );
                                        },
                                      );  // Cierre del DragTarget aquí
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // trailing dropzone
                      buildInsertionDropZone(widget.dia.ejercicios.length),
                    ],
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