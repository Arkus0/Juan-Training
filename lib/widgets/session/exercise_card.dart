import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/ejercicio.dart';
import '../../models/library_exercise.dart';
import '../../models/progression_engine_models.dart';
import '../../models/serie_log.dart';
import '../../providers/focus_manager_provider.dart';
import '../../providers/progression_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/training_provider.dart';
import '../../screens/training_session_screen.dart';
import '../../services/alternativas_service.dart';
import '../../services/exercise_library_service.dart';
import '../../utils/design_system.dart';
import '../../widgets/common/alternativas_dialog.dart';
import 'advanced_options_modal.dart';
import 'focused_set_row.dart';
import 'progression_preview.dart'; // ConsequenceMessage, EmpatheticBanner, etc.
import 'quick_actions_menu.dart'; // QuickActionsMenu for the FAB-style actions
import 'session_modifiers.dart'; // AddSetButton
import 'session_set_row.dart';

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
  // 🆕 Estado de colapso local - null significa auto (colapsa al completar)
  bool? _manualCollapsedState;

  /// Determina si el ejercicio está colapsado
  bool _isCollapsed(bool allSetsCompleted) {
    // Si el usuario ha tocado manualmente, usar ese estado
    if (_manualCollapsedState != null) {
      return _manualCollapsedState!;
    }
    // Auto-colapsar cuando todas las series están completadas
    return allSetsCompleted;
  }

  void _toggleCollapse() {
    final exercise = ref.read(trainingSessionProvider).exercises[widget.exerciseIndex];
    final allCompleted = exercise.logs.every((log) => log.completed);
    
    setState(() {
      // Toggle basado en el estado actual
      final currentCollapsed = _isCollapsed(allCompleted);
      _manualCollapsedState = !currentCollapsed;
    });
  }

  void _showNotesDialog(BuildContext context, String exerciseName) async {
    final repo = ref.read(trainingRepositoryProvider);
    final currentNote = await repo.getNote(exerciseName);

    if (!context.mounted) return;

    final controller = TextEditingController(text: currentNote);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        title: Text('NOTAS: ${exerciseName.toUpperCase()}', style: AppTypography.sectionTitle),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Escribe notas importantes para este ejercicio (ej. altura del asiento, agarre...)',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.techCyan)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              await repo.saveNote(exerciseName, controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('GUARDAR', style: TextStyle(color: AppColors.techCyan, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showExerciseOptions(BuildContext context, Ejercicio exercise) {
    // Convert string ID to int safely
    final libId = int.tryParse(exercise.libraryId);

    final hasAlternativas = libId != null && AlternativasService.instance.hasAlternativas(libId);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        final historyLogs = ref.read(trainingSessionProvider).history[exercise.nombre];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(exercise.nombre.toUpperCase(), style: AppTypography.sectionTitle),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.history, color: AppColors.textSecondary),
                  title: const Text('Ver Historial', style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showHistoryDialog(context, exercise.nombre, historyLogs);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.swap_horiz,
                    color: hasAlternativas ? AppColors.techCyan : AppColors.textDisabled,
                  ),
                  title: Text(
                    'Ver Alternativas',
                    style: TextStyle(
                      color: hasAlternativas ? AppColors.textPrimary : AppColors.textDisabled,
                    ),
                  ),
                  subtitle: Text(
                    hasAlternativas ? 'Ejercicios similares disponibles' : 'Sin alternativas registradas',
                    style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
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
                  leading: const Icon(Icons.note_alt_outlined, color: AppColors.textSecondary),
                  title: const Text('Notas del Ejercicio', style: TextStyle(color: AppColors.textPrimary)),
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
        backgroundColor: AppColors.bgElevated,
        title: Text('HISTORIAL: $name', style: AppTypography.sectionTitle),
        content: logs == null || logs.isEmpty
            ? const Text('No hay datos previos.', style: TextStyle(color: AppColors.textSecondary))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ÚLTIMA SESIÓN:', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...logs.map((l) => Text('• ${l.peso}kg x ${l.reps}', style: const TextStyle(color: AppColors.textPrimary))),
                ],
              ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CERRAR', style: TextStyle(color: AppColors.techCyan))),
        ],
      ),
    );
  }

  void _showAdvancedOptions(BuildContext context, int setIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
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
    // Check for "PR" or better performance
    if (previous != null) {
      var improved = false;
      if (current.peso > previous.peso) improved = true;
      if (current.peso == previous.peso && current.reps > previous.reps) improved = true;

      if (improved) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('¡HAS SUPERADO LA SESIÓN ANTERIOR! 🔥', 
                 style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textOnAccent),),
               backgroundColor: AppColors.goldAccent, // Oro para PR
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
    final useFocusedInputMode = ref.watch(settingsProvider.select((s) => s.useFocusedInputMode));

    // Progression v2: Obtener decisión de progresión para este ejercicio
    final progressionDecision = ref.watch(exerciseProgressionProvider(widget.exerciseIndex));
    
    // Empathetic feedback: mensajes de apoyo para días difíciles
    final empatheticBannerMessage = ref.watch(exerciseEmpatheticBannerProvider(widget.exerciseIndex));

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

    // 🆕 Calcular estado de colapso
    final allSetsCompleted = exercise.logs.every((log) => log.completed);
    final isCollapsed = _isCollapsed(allSetsCompleted);

    return ExerciseCard(
      exerciseIndex: widget.exerciseIndex,
      exercise: exercise,
      historyLogs: historyLogs,
      showAdvanced: showAdvanced,
      showSupersetBadge: showSupersetIndicator && exercise.isInSuperset,
      progressionDecision: progressionDecision,
      empatheticBannerMessage: empatheticBannerMessage,
      focusSetIndex: focusSetIndexFromManager ?? (focusTarget?.exerciseIndex == widget.exerciseIndex ? focusTarget?.setIndex : null),
      useFocusedInputMode: useFocusedInputMode,
      isCollapsed: isCollapsed,
      onToggleCollapse: _toggleCollapse,
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
      onUpdateWeightDirect: (setIndex, val) => notifier.updateLog(widget.exerciseIndex, setIndex, peso: val),
      onUpdateRepsDirect: (setIndex, val) => notifier.updateLog(widget.exerciseIndex, setIndex, reps: val),
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
  final String? empatheticBannerMessage; // Mensaje empático para días difíciles
  final int? focusSetIndex; // Set que debe recibir focus (auto-focus del timer)
  final bool useFocusedInputMode; // Usar el nuevo modo de entrada con modal
  final bool isCollapsed; // 🆕 Estado colapsado
  final VoidCallback? onToggleCollapse; // 🆕 Callback para toggle
  final VoidCallback onShowOptions;
  final Function(int, String) onUpdateWeight;
  final Function(int, String) onUpdateReps;
  final Function(int, bool?) onUpdateCompleted;
  final Function(int, double) onPlateCalc;
  final Function(int) onSetLongPress;
  final Function(int)? onRestTimeChange;
  final Function(int, double)? onUpdateWeightDirect; // Para FocusedSetRow
  final Function(int, int)? onUpdateRepsDirect; // Para FocusedSetRow

  const ExerciseCard({
    super.key,
    required this.exerciseIndex,
    required this.exercise,
    required this.historyLogs,
    required this.showAdvanced,
    this.showSupersetBadge = false,
    this.progressionDecision,
    this.empatheticBannerMessage,
    this.focusSetIndex,
    this.useFocusedInputMode = true,
    this.isCollapsed = false,
    this.onToggleCollapse,
    required this.onShowOptions,
    required this.onUpdateWeight,
    required this.onUpdateReps,
    required this.onUpdateCompleted,
    required this.onPlateCalc,
    required this.onSetLongPress,
    this.onRestTimeChange,
    this.onUpdateWeightDirect,
    this.onUpdateRepsDirect,
  });

  @override
  Widget build(BuildContext context) {
    final restSeconds = exercise.descansoSugeridoSeconds ?? 90;
    
    // 🆕 Calcular si todas las series están completadas
    final allSetsCompleted = exercise.logs.every((log) => log.completed);
    final completedSets = exercise.logs.where((log) => log.completed).length;
    final totalSets = exercise.logs.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // 🆕 Color diferente si está colapsado/completado
      color: isCollapsed 
          ? (allSetsCompleted ? const Color(0xFF1A2A1A) : AppColors.bgElevated)
          : null,
      child: InkWell(
        // 🆕 Tap en header para colapsar/expandir
        onTap: isCollapsed ? onToggleCollapse : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(isCollapsed ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header siempre visible
                Row(
                  crossAxisAlignment: isCollapsed ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onToggleCollapse,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          crossAxisAlignment: isCollapsed ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                          children: [
                            // 🆕 Icono de expansión/colapso
                            AnimatedRotation(
                              turns: isCollapsed ? -0.25 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.expand_more,
                                size: 20,
                                color: allSetsCompleted 
                                    ? AppColors.completedGreen 
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                exercise.nombre.toUpperCase(),
                                style: AppTypography.sectionTitle.copyWith(
                                  fontSize: isCollapsed ? 18 : 19,
                                  fontWeight: isCollapsed ? FontWeight.w600 : FontWeight.w700,
                                  color: allSetsCompleted 
                                      ? AppColors.completedGreen 
                                      : AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            // 🆕 Check si completado
                            if (allSetsCompleted) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.check_circle,
                                size: 18,
                                color: AppColors.completedGreen,
                              ),
                            ],
                            // Badge contador cuando colapsado
                            if (isCollapsed && !allSetsCompleted) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.bloodRed.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.bloodRed),
                                ),
                                child: Text(
                                  '$completedSets/$totalSets',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.bloodRed,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Botón único de rayito que abre ambas funcionalidades
                    if (!isCollapsed)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.bgInteractive,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.flash_on, color: AppColors.bloodRed),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: AppColors.bgElevated,
                              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                              builder: (sheetContext) {
                                return SafeArea(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: QuickActionsMenu(
                                      currentRestSeconds: restSeconds,
                                      startExpanded: true,
                                      showToggle: false,
                                      onRepeat: () {
                                        Navigator.pop(sheetContext);
                                        // TODO: implementar repetición de set
                                      },
                                      onMaintainGoal: () {
                                        Navigator.pop(sheetContext);
                                        // Reutilizar lógica existente: mantener objetivo (si aplica)
                                      },
                                      onRestTimeSelected: (s) {
                                        Navigator.pop(sheetContext);
                                        if (onRestTimeChange != null) onRestTimeChange!(s);
                                      },
                                      onHistory: () {
                                        Navigator.pop(sheetContext);
                                        onShowOptions();
                                      },
                                      onMoreOptions: () {
                                        Navigator.pop(sheetContext);
                                        onShowOptions();
                                      },
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          tooltip: 'Acciones y opciones',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        ),
                      ),
                  ],
                ),

              // 🆕 Contenido colapsable con animación
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _buildExpandedContent(restSeconds),
                crossFadeState: isCollapsed 
                    ? CrossFadeState.showFirst 
                    : CrossFadeState.showSecond,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Contenido expandido del ejercicio (series, etc.)
  Widget _buildExpandedContent(int restSeconds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Badge superset si aplica
        if (showSupersetBadge) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'SUPERSET',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],

        // Fila horizontal: Botón objetivo y mensaje de dificultad
        Row(
          children: [
            // Evitar duplicado: si la sugerencia de progresión indica "maintain",
            // ya se muestra el mensaje "Mismo objetivo hoy" en la tarjeta de progresión.
            if (progressionDecision == null || progressionDecision!.action != ProgressionAction.maintain)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgInteractive,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Mismo objetivo hoy', style: TextStyle(fontSize: 13)),
                onPressed: () {}, // TODO: lógica real
              ),

            if (empatheticBannerMessage != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    empatheticBannerMessage!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
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

        // Header Row - solo mostrar si NO es modo focalizado
        if (!useFocusedInputMode)
          const Row(
            children: [
              SizedBox(width: 30, child: Center(child: Text('#', style: TextStyle(color: AppColors.textTertiary)))),
              SizedBox(width: 50, child: Center(child: Text('PREV', style: TextStyle(color: AppColors.textTertiary, fontSize: 10)))),
              Expanded(child: Center(child: Text('KG', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)))),
              Expanded(child: Center(child: Text('REPS', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)))),
              SizedBox(width: 40, child: Center(child: Icon(Icons.check, size: 16, color: AppColors.textTertiary))),
            ],
          ),
        if (!useFocusedInputMode)
          const SizedBox(height: 8),

        // 🎯 REDISEÑO: Usar FocusedSetRow en modo focalizado
        ...List.generate(exercise.logs.length, (setIndex) {
          final log = exercise.logs[setIndex];
          final prevLog = (historyLogs != null && setIndex < historyLogs!.length) ? historyLogs![setIndex] : null;

          // Determinar si esta serie es la activa (primera incompleta)
          final isFirstIncomplete = exercise.logs
              .take(setIndex)
              .every((l) => l.completed);
          final isActive = !log.completed && isFirstIncomplete;
          final isFuture = !log.completed && !isActive;

          if (useFocusedInputMode) {
            return FocusedSetRow(
              key: ValueKey('ex${exerciseIndex}_focused_set$setIndex'),
              index: setIndex,
              log: log,
              prevLog: prevLog,
              isActive: isActive,
              isFuture: isFuture,
              exerciseName: exercise.nombre,
              totalSets: exercise.logs.length,
              onWeightChanged: (val) => onUpdateWeightDirect?.call(setIndex, val),
              onRepsChanged: (val) => onUpdateRepsDirect?.call(setIndex, val),
              onCompleted: (val) => onUpdateCompleted(setIndex, val),
              onLongPress: () => onSetLongPress(setIndex),
            );
          }

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
        
        // 🆕 Botón para añadir series adicionales
        AddSetButton(exerciseIndex: exerciseIndex),
      ],
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
                  color: AppColors.neonPrimary,
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
                      color: isSelected ? AppColors.neonPrimary : Colors.grey[800],
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
                  backgroundColor: AppColors.neonPrimary,
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

/// Tile individual para acciones rápidas
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
