import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:juan_training/models/rutina.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/providers/create_routine_provider.dart';
import 'package:juan_training/screens/create_routine/widgets/dia_expansion_tile.dart';
import 'package:juan_training/screens/create_routine/widgets/biblioteca_bottom_sheet.dart';
import 'package:juan_training/screens/create_routine/widgets/routine_import_dialog.dart';
import 'package:juan_training/services/routine_sharing_service.dart';
import 'package:juan_training/models/ejercicio_en_rutina.dart';

class CreateEditRoutineScreen extends ConsumerStatefulWidget {
  final Rutina? rutina; // Null for Create, existing for Edit

  const CreateEditRoutineScreen({super.key, this.rutina});

  @override
  ConsumerState<CreateEditRoutineScreen> createState() => _CreateEditRoutineScreenState();
}

class _CreateEditRoutineScreenState extends ConsumerState<CreateEditRoutineScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rutina?.nombre ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveRoutine() async {
    final notifier = ref.read(createRoutineProvider(widget.rutina).notifier);

    // Attempt Save
    try {
      final error = await notifier.saveRoutine();

      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent[700],
          ),
        );
        try { HapticFeedback.vibrate(); } catch (_) {}
        return;
      }

      // Success Feedback
      if (!mounted) return;

      // Flash
      final overlay = Overlay.of(context);
      final entry = OverlayEntry(builder: (context) {
        return Container(
          color: Colors.red[900]!.withValues(alpha: 0.4),
        );
      });
      overlay.insert(entry);

      // Vibrate approximation using HapticFeedback
      try {
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 50));
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (_) {} // best-effort haptic feedback


      // SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('RUTINA FORJADA',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.white)),
          backgroundColor: Colors.red[900],
        ),
      );

      // Wait 300ms for flash then remove and pop
      final navigator = Navigator.of(context);
      await Future.delayed(const Duration(milliseconds: 300));
      entry.remove();

      if (mounted) navigator.pop();

    } catch (e, s) {
      // Unexpected error: show friendly message and log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado al guardar: ${e.toString()}', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent[700],
        ),
      );
      try { HapticFeedback.vibrate(); } catch (_) {}
      final logger = Logger();
      logger.e('Unexpected error in _saveRoutine', error: e, stackTrace: s);
      return;
    }
  }
  Future<void> _importRoutine() async {
    final notifier = ref.read(createRoutineProvider(widget.rutina).notifier);
    final dayIndex = notifier.expandedDayIndex;

    // Validation: A day must be expanded
    if (dayIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Despliega un día para importar ejercicios ahí.',
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent[700],
        ),
      );
      try { HapticFeedback.vibrate(); } catch (_) {}
      return;
    }

    final List<EjercicioEnRutina>? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RoutineImportDialog()),
    );

    if (result != null && result.isNotEmpty) {
      final currentDay = ref.read(createRoutineProvider(widget.rutina)).dias[dayIndex];
      int insertIndex = currentDay.ejercicios.length;

      for (final ex in result) {
        notifier.insertExercise(dayIndex, insertIndex++, ex);
      }

      try { HapticFeedback.heavyImpact(); } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'IMPORTADOS ${result.length} EJERCICIOS',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.white),
          ),
          backgroundColor: Colors.red[900],
        ),
      );
    }
  }

  void _addExercise(int dayIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => BibliotecaBottomSheet(
        onAdd: (LibraryExercise ex) {
          ref
              .read(createRoutineProvider(widget.rutina).notifier)
              .addExerciseToDay(dayIndex, ex);
          try { HapticFeedback.lightImpact(); } catch (_) {}
          // Snackbar is now shown inside BibliotecaBottomSheet
        },
      ),
    );
  }

  void _exportRoutine(Rutina rutina) {
    // Validate that routine has content worth exporting
    if (rutina.nombre.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ponle nombre a tu rutina antes de compartir',
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (rutina.dias.isEmpty ||
        !rutina.dias.any((d) => d.ejercicios.isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Añade ejercicios antes de compartir',
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try { HapticFeedback.selectionClick(); } catch (_) {}
    RoutineSharingService.instance.shareRoutine(rutina);
  }

  @override
  Widget build(BuildContext context) {
    final routineState = ref.watch(createRoutineProvider(widget.rutina));
    final notifier = ref.read(createRoutineProvider(widget.rutina).notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.rutina == null ? 'CREA TU RUTINA' : 'EDITAR: ${routineState.nombre.toUpperCase()}',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 22),
        ),
        backgroundColor: Colors.red[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner, color: Colors.white),
            tooltip: 'Importar Rutina (OCR)',
            onPressed: _importRoutine,
          ),
          // Export button - only show when editing an existing routine with content
          if (widget.rutina != null || routineState.dias.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'export') {
                  _exportRoutine(routineState);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 20),
                      SizedBox(width: 8),
                      Text('Compartir Rutina'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100), // Space for FAB/Button
        child: Column(
          children: [
            // Routine Name Input
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _nameController,
                style: GoogleFonts.montserrat(
                  fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nombre que motive miedo',
                  hintStyle: GoogleFonts.montserrat(color: Colors.red[900]!.withValues(alpha: 0.5)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red[900]!)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent[700]!, width: 2)),
                ),
                onChanged: (val) => notifier.updateName(val),
              ),
            ),

            // Days List (Reorderable)
            // Using ReorderableColumn to handle list of Days
            if (routineState.dias.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Text(
                    'AÑADE TU PRIMER DÍA',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white24,
                    ),
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                key: ValueKey(routineState.dias.length),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) {
                  // Detectamos el inicio del arrastre y colapsamos cualquier día abierto para evitar glitches visuales
                  Future.microtask(() {
                    final notifier = ref.read(createRoutineProvider(widget.rutina).notifier);
                    if (notifier.expandedDayIndex != -1) {
                      notifier.collapseAllDays();
                    }
                  });

                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      return Material(
                        elevation: animation.value * 8,
                        color: Colors.transparent,
                        shadowColor: Colors.red[900],
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                onReorder: notifier.reorderDays,
                itemCount: routineState.dias.length,
                itemBuilder: (context, index) {
                  final dia = routineState.dias[index];
                  return Container(
                    key: Key(dia.id),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: DiaExpansionTile(
                      dayIndex: index,
                      dia: dia,
                      // Ensure this item rebuilds when routine state changes (watch),
                      // but read the notifier to get the UI-only expanded index.
                      initiallyExpanded: ref.read(createRoutineProvider(widget.rutina).notifier).expandedDayIndex == index,
                      onExpansionChanged: (val) {
                        if (val) {
                          ref.read(createRoutineProvider(widget.rutina).notifier).setExpandedDay(index);
                        } else {
                          ref.read(createRoutineProvider(widget.rutina).notifier).collapseAllDays();
                        }
                      },
                      onUpdateName: (val) => notifier.updateDayName(index, val),
                      onUpdateProgression: (val) =>
                          notifier.updateDayProgression(index, val),
                      onAddExercise: () => _addExercise(index),
                      onReorderExercises: (oldIdx, newIdx) =>
                          notifier.reorderVisualExercises(index, oldIdx, newIdx),
                      onRemoveExercise: (exIdx) =>
                          notifier.removeExercise(index, exIdx),
                      onUndoRemove: (exIdx, ex) =>
                          notifier.insertExercise(index, exIdx, ex),
                      onUpdateExercise: (exIdx, updated) =>
                          notifier.updateExercise(index, exIdx, updated),
                      onReplaceExercise: (exIdx, alternativaNombre) =>
                          notifier.replaceExercise(index, exIdx, alternativaNombre),
                      onRemoveDay: () => notifier.removeDay(index),
                      onDuplicateDay: () => notifier.duplicateDay(index),
                      onCreateSuperset: (idxA, idxB) =>
                          notifier.createSuperset(index, idxA, idxB),
                      onMoveSuperset: (supersetId, toFlat) => notifier.moveSuperset(index, supersetId, toFlat),
                      onMoveExercise: (fromFlat, toFlat) => notifier.reorderExercises(index, fromFlat, toFlat),
                      onRemoveFromSuperset: (exIdx) =>
                          notifier.removeFromSuperset(index, exIdx),
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            // FAB Add Day (Inline or actual FAB? Requirements: "Floating big red FAB... Below list: big red FAB")
            // "Below list: big red FAB 'AÑADIR DÍA'"
            Center(
              child: FloatingActionButton.extended(
                heroTag: 'add_day_fab',
                onPressed: () {
                  notifier.addDay();
                  try { HapticFeedback.lightImpact(); } catch (_) {}
                },
                icon: const Icon(Icons.add, size: 32),
                label: Text('AÑADIR DÍA', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16)),
                backgroundColor: Colors.red[900],
                elevation: 8,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [BoxShadow(color: Colors.red[900]!.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: ElevatedButton(
          onPressed: _saveRoutine,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent[700],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shadowColor: Colors.redAccent,
            elevation: 10,
          ),
          child: Text(
            'GUARDAR RUTINA',
            style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}
