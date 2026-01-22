import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import '../../models/ejercicio.dart';
import '../../models/serie_log.dart';
import '../../providers/training_provider.dart';
import '../../services/alternativas_service.dart';
import '../../widgets/common/alternativas_dialog.dart';
import 'session_set_row.dart';
import 'advanced_options_modal.dart';

class ExerciseCardContainer extends ConsumerStatefulWidget {
  final int exerciseIndex;

  const ExerciseCardContainer({
    super.key,
    required this.exerciseIndex,
  });

  @override
  ConsumerState<ExerciseCardContainer> createState() => _ExerciseCardContainerState();
}

class _ExerciseCardContainerState extends ConsumerState<ExerciseCardContainer> {
  void _showNotesDialog(BuildContext context, String exerciseName) async {
    final repo = ref.read(trainingRepositoryProvider);
    final String currentNote = await repo.getNote(exerciseName);

    if (!context.mounted) return;

    final controller = TextEditingController(text: currentNote);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('NOTAS: ${exerciseName.toUpperCase()}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Escribe notas importantes para este ejercicio (ej. altura del asiento, agarre...)',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.red)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () async {
              await repo.saveNote(exerciseName, controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('GUARDAR', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showExerciseOptions(BuildContext context, Ejercicio exercise) {
    final hasAlternativas = AlternativasService.instance.hasAlternativas(exercise.nombre);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        final historyLogs = ref.read(trainingSessionProvider).history[exercise.nombre];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(exercise.nombre.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.history, color: Colors.white),
                  title: const Text('Ver Historial'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showHistoryDialog(context, exercise.nombre, historyLogs);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.swap_horiz,
                    color: hasAlternativas ? Colors.redAccent[700] : Colors.grey[600],
                  ),
                  title: Text(
                    'Ver Alternativas',
                    style: TextStyle(
                      color: hasAlternativas ? Colors.white : Colors.white38,
                    ),
                  ),
                  subtitle: Text(
                    hasAlternativas ? 'Ejercicios similares disponibles' : 'Sin alternativas registradas',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showAlternativasDialog(
                      context: context,
                      ejercicioNombre: exercise.nombre,
                      onReplace: (alternativa) {
                        Vibrate.feedback(FeedbackType.selection);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Alternativa: $alternativa (edita la rutina para cambiar permanentemente)',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: Colors.grey[800],
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.note_alt_outlined, color: Colors.white),
                  title: const Text('Notas del Ejercicio'),
                  onTap: () {
                     Navigator.pop(sheetContext);
                     _showNotesDialog(context, exercise.nombre);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showHistoryDialog(BuildContext context, String name, List<SerieLog>? logs) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('HISTORIAL: $name', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: logs == null || logs.isEmpty
            ? const Text('No hay datos previos.', style: TextStyle(color: Colors.white70))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ÚLTIMA SESIÓN:', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...logs.map((l) => Text('• ${l.peso}kg x ${l.reps}', style: const TextStyle(color: Colors.white))),
                ],
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CERRAR')),
        ],
      ),
    );
  }

  void _showAdvancedOptions(BuildContext context, int setIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: AdvancedOptionsModal(exerciseIndex: widget.exerciseIndex, setIndex: setIndex),
        );
      },
    );
  }

  void _triggerCompletionFeedback(SerieLog current, SerieLog? previous) async {
    // Basic completion feedback
    // if (await Vibrate.canVibrate) {
    //   Vibrate.vibrate();
    // }

    // Check for "PR" or better performance
    if (previous != null) {
      bool improved = false;
      if (current.peso > previous.peso) improved = true;
      if (current.peso == previous.peso && current.reps > previous.reps) improved = true;

      if (improved) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Text('¡HAS SUPERADO LA SESIÓN ANTERIOR! 🔥', style: TextStyle(fontWeight: FontWeight.bold)),
               backgroundColor: Colors.red[900],
               behavior: SnackBarBehavior.floating,
             ),
           );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ⚡ Bolt Optimization: Only rebuild this specific card when this exercise changes
    final exercise = ref.watch(trainingSessionProvider.select((s) => s.exercises[widget.exerciseIndex]));
    final historyLogs = ref.watch(trainingSessionProvider.select((s) => s.history[exercise.nombre]));
    final showAdvanced = ref.watch(trainingSessionProvider.select((s) => s.showAdvancedOptions));
    final isRestActive = ref.watch(trainingSessionProvider.select((s) => s.isRestActive));

    final notifier = ref.read(trainingSessionProvider.notifier);

    return ExerciseCard(
      exerciseIndex: widget.exerciseIndex,
      exercise: exercise,
      historyLogs: historyLogs,
      showAdvanced: showAdvanced,
      onShowOptions: () => _showExerciseOptions(context, exercise),
      onUpdateWeight: (setIndex, val) => notifier.updateLog(widget.exerciseIndex, setIndex, peso: double.tryParse(val)),
      onUpdateReps: (setIndex, val) => notifier.updateLog(widget.exerciseIndex, setIndex, reps: int.tryParse(val)),
      onUpdateCompleted: (setIndex, val) {
        notifier.updateLog(widget.exerciseIndex, setIndex, completed: val);
        if (val == true) {
             final log = exercise.logs[setIndex];
             final prevLog = (historyLogs != null && setIndex < historyLogs.length) ? historyLogs[setIndex] : null;
             _triggerCompletionFeedback(log, prevLog);
             // Auto-advance rest
             if (!isRestActive) notifier.startRestForExercise(widget.exerciseIndex);
        }
      },
      onPlateCalc: (setIndex, val) => notifier.updateLog(widget.exerciseIndex, setIndex, peso: val),
      onSetLongPress: (setIndex) => _showAdvancedOptions(context, setIndex),
    );
  }
}

class ExerciseCard extends StatelessWidget {
  final int exerciseIndex;
  final Ejercicio exercise;
  final List<SerieLog>? historyLogs;
  final bool showAdvanced;
  final VoidCallback onShowOptions;
  final Function(int, String) onUpdateWeight;
  final Function(int, String) onUpdateReps;
  final Function(int, bool?) onUpdateCompleted;
  final Function(int, double) onPlateCalc;
  final Function(int) onSetLongPress;

  const ExerciseCard({
    super.key,
    required this.exerciseIndex,
    required this.exercise,
    required this.historyLogs,
    required this.showAdvanced,
    required this.onShowOptions,
    required this.onUpdateWeight,
    required this.onUpdateReps,
    required this.onUpdateCompleted,
    required this.onPlateCalc,
    required this.onSetLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                        exercise.nombre.toUpperCase(),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.redAccent[700],
                          shadows: [
                            Shadow(color: Colors.red[900]!.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                                           ),
                       if (historyLogs != null && historyLogs!.isNotEmpty)
                         Text(
                           'LAST: ${historyLogs!.last.peso}KG x ${historyLogs!.last.reps}',
                           style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold),
                         ),
                     ],
                   ),
                 ),
                 IconButton(
                   icon: const Icon(Icons.more_horiz),
                   onPressed: onShowOptions,
                 )
               ],
             ),

            const SizedBox(height: 16),

            // Header Row
            const Row(
              children: [
                SizedBox(width: 30, child: Center(child: Text('#', style: TextStyle(color: Colors.grey)))),
                SizedBox(width: 50, child: Center(child: Text('PREV', style: TextStyle(color: Colors.grey, fontSize: 10)))),
                Expanded(child: Center(child: Text('KG', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text('REPS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))),
                SizedBox(width: 40, child: Center(child: Icon(Icons.check, size: 16, color: Colors.grey))),
              ],
            ),
            const SizedBox(height: 8),

            ...List.generate(exercise.logs.length, (setIndex) {
              final log = exercise.logs[setIndex];
              final prevLog = (historyLogs != null && setIndex < historyLogs!.length) ? historyLogs![setIndex] : null;

              return SessionSetRow(
                key: ValueKey('ex${exerciseIndex}_set$setIndex'),
                index: setIndex,
                log: log,
                prevLog: prevLog,
                onWeightChanged: (val) => onUpdateWeight(setIndex, val),
                onRepsChanged: (val) => onUpdateReps(setIndex, val),
                onCompleted: (val) => onUpdateCompleted(setIndex, val),
                onPlateCalc: (val) => onPlateCalc(setIndex, val),
                onLongPress: () => onSetLongPress(setIndex),
                showAdvanced: showAdvanced,
              );
            }),
          ],
        ),
      ),
    );
  }
}
