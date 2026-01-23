import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/ejercicio.dart';
import '../../models/serie_log.dart';
import '../../models/library_exercise.dart';
import '../../models/progression_engine_models.dart';
import '../../providers/training_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/focus_manager_provider.dart';
import '../../providers/progression_provider.dart';
import '../../screens/training_session_screen.dart';
import '../../services/alternativas_service.dart';
import '../../services/exercise_library_service.dart';
import '../../widgets/common/alternativas_dialog.dart';
import '../../utils/design_system.dart';
import 'session_set_row.dart';
import 'advanced_options_modal.dart';
import 'progression_preview.dart';

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
    // Convert string ID to int safely
    final int? libId = int.tryParse(exercise.libraryId);

    final hasAlternativas = libId != null && AlternativasService.instance.hasAlternativas(libId);

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
                    if (!hasAlternativas) return;

                    Navigator.pop(sheetContext);

                    // Resolve LibraryExercise object
                    final libraryExercise = ExerciseLibraryService.instance.getExerciseById(libId);

                    if (libraryExercise == null) {
                       ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: No se encontró información del ejercicio en la biblioteca')),
                      );
                      return;
                    }

                    // Get full list for service
                    final allExercises = ExerciseLibraryService.instance.exercises.cast<LibraryExercise>();

                    showAlternativasDialog(
                      context: context,
                      ejercicioOriginal: libraryExercise,
                      allExercises: allExercises,
                      onReplace: (alternativa) {
                        try { HapticFeedback.selectionClick(); } catch (_) {}

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Alternativa: ${alternativa.name} (edita la rutina para cambiar permanentemente)',
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
    // Haptic feedback example (use HapticFeedback.* instead of flutter_vibrate)
    // try { HapticFeedback.vibrate(); } catch (_) {}

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
    final exercise = ref.watch(trainingSessionProvider.select((s) => s.exercises.length > widget.exerciseIndex ? s.exercises[widget.exerciseIndex] : null));
    if (exercise == null) return const SizedBox.shrink();

    final historyLogs = ref.watch(trainingSessionProvider.select((s) => s.history[exercise.nombre]));
    final showAdvanced = ref.watch(trainingSessionProvider.select((s) => s.showAdvancedOptions));
    final isRestActive = ref.watch(trainingSessionProvider.select((s) => s.restTimer.isActive));

    // Settings
    final showSupersetIndicator = ref.watch(settingsProvider.select((s) => s.showSupersetIndicator));

    // Progression v2: Obtener decisión de progresión para este ejercicio
    final progressionDecision = ref.watch(exerciseProgressionProvider(widget.exerciseIndex));

    // Auto-focus: detectar si este ejercicio/set debe recibir focus
    // Usa el provider legacy y el nuevo FocusManager
    final focusTarget = ref.watch(timerFinishedFocusProvider);
    final focusManagerTarget = ref.watch(focusManagerProvider).currentTarget;

    // Determinar si este ejercicio debe recibir focus (de cualquiera de los dos sistemas)
    int? focusSetIndexFromManager;
    if (focusManagerTarget != null && focusManagerTarget.exerciseIndex == widget.exerciseIndex) {
      focusSetIndexFromManager = focusManagerTarget.setIndex;
    }

    final notifier = ref.read(trainingSessionProvider.notifier);

    return ExerciseCard(
      exerciseIndex: widget.exerciseIndex,
      exercise: exercise,
      historyLogs: historyLogs,
      showAdvanced: showAdvanced,
      showSupersetBadge: showSupersetIndicator && exercise.isInSuperset,
      progressionDecision: progressionDecision,
      focusSetIndex: focusSetIndexFromManager ?? (focusTarget?.exerciseIndex == widget.exerciseIndex ? focusTarget?.setIndex : null),
      onShowOptions: () => _showExerciseOptions(context, exercise),
      onUpdateWeight: (setIndex, val) => notifier.updateLog(widget.exerciseIndex, setIndex, peso: double.tryParse(val)),
      onUpdateReps: (setIndex, val) => notifier.updateLog(widget.exerciseIndex, setIndex, reps: int.tryParse(val)),
      onUpdateCompleted: (setIndex, val) {
        notifier.updateLog(widget.exerciseIndex, setIndex, completed: val);
        if (val == true) {
             final log = exercise.logs[setIndex];
             final prevLog = (historyLogs != null && setIndex < historyLogs.length) ? historyLogs[setIndex] : null;
             _triggerCompletionFeedback(log, prevLog);
             // 🎯 P1: Timer SIEMPRE auto-inicia al completar serie
             if (!isRestActive) {
               notifier.startRestForExercise(widget.exerciseIndex, setIndex: setIndex);
             }
        }
      },
      onPlateCalc: (setIndex, val) => notifier.updateLog(widget.exerciseIndex, setIndex, peso: val),
      onSetLongPress: (setIndex) => _showAdvancedOptions(context, setIndex),
      onRestTimeChange: (seconds) => _updateExerciseRestTime(seconds),
    );
  }

  void _updateExerciseRestTime(int seconds) {
    final notifier = ref.read(trainingSessionProvider.notifier);
    notifier.updateExerciseRestTime(widget.exerciseIndex, seconds);
  }
}

class ExerciseCard extends StatelessWidget {
  final int exerciseIndex;
  final Ejercicio exercise;
  final List<SerieLog>? historyLogs;
  final bool showAdvanced;
  final bool showSupersetBadge;
  final ProgressionDecision? progressionDecision; // Decisión de progresión v2
  final int? focusSetIndex; // Set que debe recibir focus (auto-focus del timer)
  final VoidCallback onShowOptions;
  final Function(int, String) onUpdateWeight;
  final Function(int, String) onUpdateReps;
  final Function(int, bool?) onUpdateCompleted;
  final Function(int, double) onPlateCalc;
  final Function(int) onSetLongPress;
  final Function(int)? onRestTimeChange;

  const ExerciseCard({
    super.key,
    required this.exerciseIndex,
    required this.exercise,
    required this.historyLogs,
    required this.showAdvanced,
    this.showSupersetBadge = false,
    this.progressionDecision,
    this.focusSetIndex,
    required this.onShowOptions,
    required this.onUpdateWeight,
    required this.onUpdateReps,
    required this.onUpdateCompleted,
    required this.onPlateCalc,
    required this.onSetLongPress,
    this.onRestTimeChange,
  });

  @override
  Widget build(BuildContext context) {
    final restSeconds = exercise.descansoSugeridoSeconds ?? 90;

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
                       Row(
                         children: [
                           Flexible(
                             child: Text(
                              exercise.nombre.toUpperCase(),
                              // 🎯 REDISEÑO: Nombre en blanco, sin sombras rojas
                              style: AppTypography.sectionTitle,
                             ),
                           ),
                           if (showSupersetBadge) ...[
                             const SizedBox(width: 8),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                               decoration: BoxDecoration(
                                 color: Colors.orange[800],
                                 borderRadius: BorderRadius.circular(4),
                               ),
                               child: Text(
                                 'SS',
                                 style: GoogleFonts.montserrat(
                                   fontSize: 10,
                                   fontWeight: FontWeight.w900,
                                   color: Colors.white,
                                 ),
                               ),
                             ),
                           ],
                         ],
                       ),
                       const SizedBox(height: 4),
                       Row(
                         children: [
                           if (historyLogs != null && historyLogs!.isNotEmpty)
                             Text(
                               'LAST: ${historyLogs!.last.peso}KG x ${historyLogs!.last.reps}',
                               style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold),
                             ),
                           // Badge de progresión v2 (compacto)
                           if (progressionDecision != null) ...[
                             const SizedBox(width: 8),
                             ProgressionBadge(decision: progressionDecision!),
                           ],
                           const Spacer(),
                           // Selector de tiempo de descanso inline
                           _RestTimeChip(
                             seconds: restSeconds,
                             onChanged: onRestTimeChange,
                           ),
                         ],
                       ),
                     ],
                   ),
                 ),
                 // 🎯 P1: Icono opciones más visible
                 Container(
                   decoration: BoxDecoration(
                     color: Colors.grey[850],
                     borderRadius: BorderRadius.circular(8),
                     border: Border.all(color: Colors.grey[700]!),
                   ),
                   child: IconButton(
                     icon: Icon(Icons.more_horiz, color: Colors.grey[400]),
                     onPressed: onShowOptions,
                     tooltip: 'Opciones del ejercicio',
                     padding: const EdgeInsets.all(8),
                     constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                   ),
                 )
               ],
             ),

            // Card de progresión v2 (si hay sugerencia)
            if (progressionDecision != null) ...[
              const SizedBox(height: 12),
              ProgressionPreviewCard(
                decision: progressionDecision!,
                compact: true,
              ),
            ],

            const SizedBox(height: 12),

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
                shouldFocus: focusSetIndex == setIndex,
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Chip compacto para mostrar y editar el tiempo de descanso por ejercicio
class _RestTimeChip extends StatelessWidget {
  final int seconds;
  final Function(int)? onChanged;

  const _RestTimeChip({
    required this.seconds,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Cambiar tiempo de descanso',
      child: Material(
        color: Colors.grey[850],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[700]!, width: 1),
        ),
        child: InkWell(
          onTap: onChanged != null ? () => _showRestTimePicker(context) : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${seconds}s',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[400],
                  ),
                ),
                if (onChanged != null) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.edit, size: 10, color: Colors.grey[600]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRestTimePicker(BuildContext context) {
    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _RestTimePickerSheet(
        initialSeconds: seconds,
        onSelected: (newSeconds) {
          onChanged?.call(newSeconds);
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Bottom sheet para seleccionar tiempo de descanso
class _RestTimePickerSheet extends StatefulWidget {
  final int initialSeconds;
  final Function(int) onSelected;

  const _RestTimePickerSheet({
    required this.initialSeconds,
    required this.onSelected,
  });

  @override
  State<_RestTimePickerSheet> createState() => _RestTimePickerSheetState();
}

class _RestTimePickerSheetState extends State<_RestTimePickerSheet> {
  late int _selectedSeconds;

  // Opciones predefinidas de tiempo
  static const List<int> _presets = [30, 45, 60, 90, 120, 150, 180, 240, 300];

  @override
  void initState() {
    super.initState();
    _selectedSeconds = widget.initialSeconds;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TIEMPO DE DESCANSO',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // Controles +/-
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 32),
                  onPressed: _selectedSeconds > 10
                      ? () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedSeconds -= 10);
                        }
                      : null,
                  color: Colors.grey,
                ),
                const SizedBox(width: 16),
                Text(
                  '${_selectedSeconds}s',
                  style: GoogleFonts.montserrat(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 32),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedSeconds += 10);
                  },
                  color: Colors.redAccent[700],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Presets
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _presets.map((preset) {
                final isSelected = preset == _selectedSeconds;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedSeconds = preset);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.redAccent[700] : Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? null
                          : Border.all(color: Colors.grey[700]!),
                    ),
                    child: Text(
                      _formatPreset(preset),
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : Colors.grey[400],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Botón confirmar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.onSelected(_selectedSeconds);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent[700],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'CONFIRMAR',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPreset(int seconds) {
    if (seconds >= 60) {
      final mins = seconds ~/ 60;
      final secs = seconds % 60;
      if (secs == 0) return '${mins}m';
      return '${mins}m ${secs}s';
    }
    return '${seconds}s';
  }
}
