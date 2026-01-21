import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:reorderables/reorderables.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import '../models/rutina.dart';
import '../models/library_exercise.dart';
import '../providers/create_routine_provider.dart';
import 'create_routine/widgets/dia_expansion_tile.dart';
import 'create_routine/widgets/biblioteca_bottom_sheet.dart';
import 'package:logger/logger.dart';

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
        Vibrate.feedback(FeedbackType.error);
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

      // Vibrate
      Vibrate.vibrateWithPauses([
        const Duration(milliseconds: 50),
        const Duration(milliseconds: 200),
      ]); // Simulate heavy impact

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
      Vibrate.feedback(FeedbackType.error);
      final logger = Logger();
      logger.e('Unexpected error in _saveRoutine', error: e, stackTrace: s);
      return;
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
          Vibrate.feedback(FeedbackType.light);
          // Close the bottom sheet first
          Navigator.pop(bottomSheetContext);
          // Then show SnackBar on the main scaffold
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Has añadido ${ex.name} 💪',
                style: GoogleFonts.montserrat(color: Colors.white),
              ),
              backgroundColor: Colors.red[900],
            ),
          );
        },
      ),
    );
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
              ReorderableColumn(
                key: ValueKey(routineState.dias.length),
                onReorder: notifier.reorderDays,
                draggingWidgetOpacity: 0.8,
                children: routineState.dias.asMap().entries.map((entry) {
                  final index = entry.key;
                  final dia = entry.value;

                  return Container(
                    key: Key(dia.id),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: DiaExpansionTile(
                      dayIndex: index,
                      dia: dia,
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
                      onRemoveDay: () => notifier.removeDay(index),
                      onDuplicateDay: () => notifier.duplicateDay(index),
                      onCreateSuperset: (idxA, idxB) =>
                          notifier.createSuperset(index, idxA, idxB),
                      onRemoveFromSuperset: (exIdx) =>
                          notifier.removeFromSuperset(index, exIdx),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 24),

            // FAB Add Day (Inline or actual FAB? Requirements: "Floating big red FAB... Below list: big red FAB")
            // "Below list: big red FAB 'AÑADIR DÍA'"
            Center(
              child: FloatingActionButton.extended(
                heroTag: 'add_day_fab',
                onPressed: () {
                  notifier.addDay();
                  Vibrate.feedback(FeedbackType.light);
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
