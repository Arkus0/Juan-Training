import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/serie_log.dart';
import '../providers/training_provider.dart';
import '../providers/focus_manager_provider.dart';
import '../providers/session_progress_provider.dart';
import '../providers/voice_input_provider.dart';
import '../providers/session_tolerance_provider.dart';
import '../widgets/session/exercise_card.dart';
import '../widgets/session/rest_timer_bar.dart';
import '../widgets/session/session_progress_bar.dart';
import '../widgets/session/music_launcher_bar.dart';
import '../widgets/session/progression_preview.dart'; // ExerciseSummaryFeedback
import '../widgets/session/tolerance_feedback_widgets.dart';
import '../widgets/session/session_modifiers.dart'; // AddExerciseButton
import '../widgets/voice/voice_training_button.dart';
import '../utils/design_system.dart';

/// Provider para comunicar el auto-focus cuando el timer termina
/// (Mantenido para compatibilidad, ahora usa FocusManagerProvider internamente)
final timerFinishedFocusProvider =
    StateProvider<({int exerciseIndex, int setIndex})?>(
  (ref) => null,
);

class TrainingSessionScreen extends ConsumerStatefulWidget {
  const TrainingSessionScreen({super.key});

  @override
  ConsumerState<TrainingSessionScreen> createState() =>
      _TrainingSessionScreenState();
}

class _TrainingSessionScreenState extends ConsumerState<TrainingSessionScreen> {
  final ScrollController _scrollController = ScrollController();

  // Per-card keys used for precise scrolling via Scrollable.ensureVisible (stable per exercise id)
  final Map<String, GlobalKey> _exerciseKeys = {};

  // Track last known incomplete set for auto-scroll detection
  ({int exerciseIndex, int setIndex})? _lastKnownIncompleteSet;

  @override
  void initState() {
    super.initState();
    // Discovery Tooltip Check (First 3 sessions)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDiscoveryTooltip();
      // Inicializar el progreso de sesión
      ref.read(sessionProgressProvider.notifier).recalculate();
      // Initialize tracking
      _lastKnownIncompleteSet =
          ref.read(trainingSessionProvider).nextIncompleteSet;
      // 🎯 ERROR TOLERANCE: Evaluar gap desde última sesión
      ref.read(sessionToleranceProvider.notifier).evaluateSessionGap();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onFinishSession() async {
    final progress = ref.read(sessionProgressProvider);

    // 🎯 P1: Skip dialog si sesión 100% completada - flujo sin fricción
    if (progress.isComplete) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // Stop any active rest timer
      ref.read(trainingSessionProvider.notifier).stopRest();
      ref.read(sessionProgressProvider.notifier).reset();

      await ref.read(trainingSessionProvider.notifier).finishSession();

      // 🎯 FIX: Mostrar feedback de sesión guardada ANTES de pop
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.textOnAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                '¡Sesión guardada!',
                style: AppTypography.labelEmphasis.copyWith(color: AppColors.textOnAccent),
              ),
            ],
          ),
          backgroundColor: AppColors.completedGreen,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      navigator.pop();
      return;
    }

    // Mensaje de confirmación según el progreso
    String confirmMessage =
        '¿Estás seguro de que quieres terminar el entrenamiento?';
    if (progress.percentage < 0.5) {
      confirmMessage +=
          '\n\nSolo has completado ${progress.formattedPercentage} de la sesión.';
    } else if (progress.percentage < 1.0) {
      confirmMessage +=
          '\n\nHas completado ${progress.formattedPercentage}. ¡Casi lo tienes!';
    }

    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          '¿TERMINAR SESIÓN?',
          style: AppTypography.sectionTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              confirmMessage,
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'CANCELAR',
              style:
                  AppTypography.button.copyWith(color: AppColors.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'TERMINAR',
              style: AppTypography.button.copyWith(
                color: AppColors.neonCyan,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldFinish == true) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      // Stop any active rest timer so UI and state are consistent
      // Prevents floating timer overlay from still being active after finishing
      ref.read(trainingSessionProvider.notifier).stopRest();

      // Reset progreso
      ref.read(sessionProgressProvider.notifier).reset();

      await ref.read(trainingSessionProvider.notifier).finishSession();

      // 🎯 FIX: Mostrar feedback de sesión guardada
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.textOnAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                '¡Sesión guardada!',
                style: AppTypography.labelEmphasis.copyWith(color: AppColors.textOnAccent),
              ),
            ],
          ),
          backgroundColor: AppColors.completedGreen,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

      navigator.pop();
    }
  }

  void _checkDiscoveryTooltip() async {
    // Discovery tooltip removed by request - it was showing a swipe hint which is considered noisy.
    // Left intentionally empty so the callsite remains but it does nothing.
    return;
  }

  /// Callback cuando el timer de descanso termina
  /// Vibra y notifica para auto-focus al siguiente input
  void _onTimerFinished({int? lastExerciseIndex, int? lastSetIndex}) async {
    // La vibración ya se maneja en el TimerBar
    // Notificar para auto-focus usando el nuevo FocusManager
    final state = ref.read(trainingSessionProvider);
    final nextSet = state.nextIncompleteSet;

    if (nextSet != null) {
      // Usar el nuevo FocusManager para solicitar focus
      ref.read(focusManagerProvider.notifier).requestFocus(
            exerciseIndex: nextSet.exerciseIndex,
            setIndex: nextSet.setIndex,
            field: FocusField.weight,
            vibrate: true,
          );

      // También actualizar el provider legacy para compatibilidad
      ref.read(timerFinishedFocusProvider.notifier).state = nextSet;

      // Scroll hacia el ejercicio si es necesario
      _scrollToExercise(nextSet.exerciseIndex);

      // Limpiar después de un frame para que el widget pueda reaccionar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) {
            ref.read(timerFinishedFocusProvider.notifier).state = null;
            ref.read(focusManagerProvider.notifier).clearFocus();
          }
        });
      });
    }
  }

  /// Scroll suave hacia un ejercicio específico
  void _scrollToExercise(int exerciseIndex) async {
    // Try precise scroll using the exercise's GlobalKey and ensureVisible.
    final exercises = ref.read(trainingSessionProvider).exercises;
    final id =
        exercises.length > exerciseIndex ? exercises[exerciseIndex].id : null;
    if (id != null) {
      final key = _exerciseKeys[id];
      if (key != null && key.currentContext != null) {
        await Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: 0.1,
        );
        return;
      }
    }

    // Fallback: estimate position (legacy behavior) to keep previous UX for edge cases
    final estimatedOffset = (exerciseIndex * 220.0) + 40;
    final maxOffset = _scrollController.position.maxScrollExtent;

    _scrollController.animateTo(
      estimatedOffset.clamp(0.0, maxOffset),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ⚡ Bolt Optimization: Use select to only rebuild on specific changes
    final activeRutinaName = ref
        .watch(trainingSessionProvider.select((s) => s.activeRutina?.nombre));
    final exercisesLength =
        ref.watch(trainingSessionProvider.select((s) => s.exercises.length));

    // Timer state (nuevo estado avanzado)
    final restTimerState =
        ref.watch(trainingSessionProvider.select((s) => s.restTimer));
    final showTimerBar =
        ref.watch(trainingSessionProvider.select((s) => s.showTimerBar));

    // Progress state
    final progress = ref.watch(sessionProgressProvider);

    // Voice available
    final voiceAvailable = ref.watch(voiceAvailableProvider);

    // 🎯 FEEDBACK: Ejercicio recién completado
    final completionInfo = ref.watch(exerciseCompletionProvider);

    // 🎯 ERROR TOLERANCE: Estado de tolerancia para mostrar bienvenida
    final toleranceState = ref.watch(sessionToleranceProvider);

    // 🎯 ERROR TOLERANCE: Datos sospechosos pendientes de confirmación
    final suspiciousData = ref.watch(suspiciousDataProvider);

    final notifier = ref.read(trainingSessionProvider.notifier);

    // 🎯 ERROR TOLERANCE: Mostrar diálogo de datos sospechosos
    // FIX: Marcar inmediatamente como "mostrando" para evitar múltiples diálogos
    if (suspiciousData.hasSuspiciousData) {
      // Marcar ANTES del postFrameCallback para evitar race condition
      ref.read(suspiciousDataProvider.notifier).markDialogShowing();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showSuspiciousDataDialog(suspiciousData);
        }
      });
    }

    // 🎯 UX CRÍTICO: Auto-scroll al siguiente ejercicio cuando se completa una serie
    final currentIncompleteSet =
        ref.watch(trainingSessionProvider.select((s) => s.nextIncompleteSet));
    if (_lastKnownIncompleteSet != null &&
        currentIncompleteSet != null &&
        currentIncompleteSet.exerciseIndex !=
            _lastKnownIncompleteSet!.exerciseIndex) {
      // El ejercicio cambió - scroll suave al nuevo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToExercise(currentIncompleteSet.exerciseIndex);
        }
      });
    }
    _lastKnownIncompleteSet = currentIncompleteSet;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          (activeRutinaName ?? 'Entrenando').toUpperCase(),
          style:
              Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 20),
        ),
        actions: [
          // 🎯 NEON IRON: Control de música compacto (antes era barra completa)
          const MusicAppBarAction(),
          // Botón de voz en AppBar (al lado de terminar)
          voiceAvailable.when(
            data: (available) => available
                ? VoiceTrainingButton(
                    enabled: true,
                    onCommand: (command) =>
                        _handleVoiceCommand(command, notifier),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: Icon(showTimerBar ? Icons.timer : Icons.timer_outlined),
            onPressed: () => notifier.toggleTimerBar(!showTimerBar),
            tooltip: 'Mostrar/ocultar timer',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _onFinishSession,
              style: TextButton.styleFrom(
                // 🎯 NEON IRON: Gold celebración al completar, sutil cuando en progreso
                backgroundColor: progress.isComplete
                    ? AppColors.goldAccent
                    : AppColors.bgElevated,
                foregroundColor: progress.isComplete
                    ? AppColors.bgDeep
                    : AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  side: progress.isComplete
                      ? BorderSide.none
                      : const BorderSide(color: AppColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (progress.isComplete)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.check, size: 16),
                    ),
                  Text(
                    'TERMINAR',
                    style: AppTypography.button.copyWith(
                      color: progress.isComplete
                          ? AppColors.bgDeep
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 🎯 NEON IRON: Barra de progreso ultra-mínima (4px)
              const SessionProgressBar(),

              // Lista de ejercicios (MusicLauncherBar movido a AppBar)
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                      8, 8, 8, 80), // Espacio para timer compacto
                  itemCount: exercisesLength + 1, // +1 para el botón de añadir ejercicio
                  // ⚡ OPTIMIZACIÓN: Pre-renderizar items cercanos para scroll más suave
                  cacheExtent: 300,
                  // ⚡ OPTIMIZACIÓN: Física optimizada para listas cortas (4-8 ejercicios típicos)
                  physics: const BouncingScrollPhysics(
                    decelerationRate: ScrollDecelerationRate.fast,
                  ),
                  itemBuilder: (context, index) {
                    // 🆕 Último item: botón para añadir ejercicio
                    if (index == exercisesLength) {
                      return const AddExerciseButton();
                    }
                    
                    // ⚡ Bolt Optimization: Extracted to smart widget
                    final exercises =
                        ref.read(trainingSessionProvider).exercises;
                    final id = exercises.length > index
                        ? exercises[index].id
                        : index.toString();
                    final key =
                        _exerciseKeys.putIfAbsent(id, () => GlobalKey());
                    // ⚡ OPTIMIZACIÓN: RepaintBoundary para aislar repintura de cada card
                    return RepaintBoundary(
                      child: Container(
                        key: key,
                        child: ExerciseCardContainer(exerciseIndex: index),
                      ),
                    );
                  },
                ),
              ),

              // Nuevo Timer Bar no invasivo
              RestTimerBar(
                timerState: restTimerState,
                showInactiveBar: showTimerBar,
                onStartRest: notifier.startRest,
                onStopRest: notifier.stopRest,
                onPauseRest: notifier.pauseRest,
                onResumeRest: notifier.resumeRest,
                onDurationChange: notifier.setRestDuration,
                onAddTime: notifier.addRestTime,
                onTimerFinished: _onTimerFinished,
                onRestartRest: notifier.restartRest,
              ),
            ],
          ),

          // 🎯 FEEDBACK: Overlay de ejercicio completado
          if (completionInfo != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 100, // Encima del timer bar
              child: GestureDetector(
                onTap: () =>
                    ref.read(exerciseCompletionProvider.notifier).dismiss(),
                child: AnimatedSlide(
                  offset: Offset.zero,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: ExerciseSummaryFeedback(
                    completedSets: completionInfo.completedSets,
                    targetSets: completionInfo.targetSets,
                    totalReps: completionInfo.totalReps,
                    metTarget: completionInfo.metTarget,
                    nextSessionHint: completionInfo.nextSessionHint,
                  ),
                ),
              ),
            ),

          // 🎯 ERROR TOLERANCE: Banner de bienvenida tras días sin entrenar
          if (toleranceState.shouldShowWelcome &&
              toleranceState.sessionGapResult != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: WelcomeBackBanner(
                result: toleranceState.sessionGapResult!,
                onDismiss: () => ref
                    .read(sessionToleranceProvider.notifier)
                    .markWelcomeShown(),
              ),
            ),

        ],
      ),
    );
  }

  /// Maneja comandos de voz durante el entrenamiento
  void _handleVoiceCommand(VoiceTrainingCommand command, dynamic notifier) {
    switch (command.type) {
      case VoiceCommandType.markDone:
        // Marcar la serie actual como completada
        _markCurrentSetDone(notifier);
        break;

      case VoiceCommandType.nextSet:
        // Navegar a la siguiente serie
        _navigateToNextSet();
        break;

      case VoiceCommandType.setWeight:
        if (command.value != null) {
          _setCurrentWeight(command.value!, notifier);
        }
        break;

      case VoiceCommandType.setReps:
        if (command.value != null) {
          _setCurrentReps(command.value!.toInt(), notifier);
        }
        break;

      case VoiceCommandType.setRpe:
        if (command.value != null) {
          _setCurrentRpe(command.value!, notifier);
        }
        break;

      case VoiceCommandType.startRest:
        final duration = command.value?.toInt() ?? 90;
        notifier.setRestDuration(duration);
        notifier.startRest();
        break;

      case VoiceCommandType.addNote:
        if (command.note != null && command.note!.isNotEmpty) {
          _addNoteToCurrentSet(command.note!, notifier);
        }
        break;
    }
  }

  /// Muestra diálogo para datos sospechosos (ERROR TOLERANCE)
  void _showSuspiciousDataDialog(SuspiciousDataState data) {
    // Limpiar inmediatamente para evitar múltiples diálogos
    ref.read(suspiciousDataProvider.notifier).clear();

    showSuspiciousDataDialog(
      context,
      exerciseName: data.exerciseName!,
      enteredWeight: data.enteredWeight!,
      suggestedWeight: data.suggestedWeight!,
      onConfirmOriginal: () {
        // El usuario confirma que el peso es correcto - no hacer nada
        // El peso ya fue guardado
      },
      onUseSuggested: () {
        // El usuario acepta la sugerencia - actualizar el peso
        // 🎯 FIX: Skip tolerance check to prevent infinite validation loop
        ref.read(trainingSessionProvider.notifier).updateLog(
              data.exerciseIndex!,
              data.setIndex!,
              peso: data.suggestedWeight,
              skipToleranceCheck: true,
            );
      },
    );
  }

  void _addNoteToCurrentSet(String note, dynamic notifier) {
    final state = ref.read(trainingSessionProvider);
    final nextSet = state.nextIncompleteSet;

    if (nextSet != null) {
      // Añadir nota a la serie actual
      notifier.updateLog(
        nextSet.exerciseIndex,
        nextSet.setIndex,
        notas: note,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.note_add,
                  color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nota: $note',
                  style: AppTypography.labelEmphasis,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.info,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _markCurrentSetDone(dynamic notifier) {
    final state = ref.read(trainingSessionProvider);
    final nextSet = state.nextIncompleteSet;

    if (nextSet != null) {
      // Marcar la serie como completada (toggle done)
      notifier.toggleSetDone(nextSet.exerciseIndex, nextSet.setIndex);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                '¡Serie completada!',
                style: AppTypography.labelEmphasis,
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToNextSet() {
    final state = ref.read(trainingSessionProvider);
    final nextSet = state.nextIncompleteSet;

    if (nextSet != null) {
      _scrollToExercise(nextSet.exerciseIndex);
      ref.read(focusManagerProvider.notifier).requestFocus(
            exerciseIndex: nextSet.exerciseIndex,
            setIndex: nextSet.setIndex,
            field: FocusField.weight,
            vibrate: true,
          );
    }
  }

  void _setCurrentWeight(double weight, dynamic notifier) {
    final state = ref.read(trainingSessionProvider);
    final nextSet = state.nextIncompleteSet;

    if (nextSet != null) {
      notifier.updateWeight(nextSet.exerciseIndex, nextSet.setIndex, weight);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Peso: ${weight.toStringAsFixed(1)} kg',
            style: AppTypography.labelEmphasis,
          ),
          backgroundColor: AppColors.bgElevated,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _setCurrentReps(int reps, dynamic notifier) {
    final state = ref.read(trainingSessionProvider);
    final nextSet = state.nextIncompleteSet;

    if (nextSet != null) {
      notifier.updateReps(nextSet.exerciseIndex, nextSet.setIndex, reps);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reps: $reps',
            style: AppTypography.labelEmphasis,
          ),
          backgroundColor: AppColors.bgElevated,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _setCurrentRpe(double rpe, dynamic notifier) {
    final state = ref.read(trainingSessionProvider);
    final nextSet = state.nextIncompleteSet;

    if (nextSet != null) {
      notifier.updateRpe(nextSet.exerciseIndex, nextSet.setIndex, rpe);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'RPE: ${rpe.toStringAsFixed(1)}',
            style: AppTypography.labelEmphasis,
          ),
          backgroundColor: AppColors.bgElevated,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 🎯 QUICK ACTIONS: Repetir la serie actual (copiar peso/reps de la anterior)
  void _repeatCurrentSet(dynamic notifier) {
    final state = ref.read(trainingSessionProvider);
    final nextSet = state.nextIncompleteSet;

    if (nextSet == null) return;

    final exercise = state.exercises[nextSet.exerciseIndex];

    // Buscar la serie anterior completada para copiar datos
    SerieLog? prevLog;
    if (nextSet.setIndex > 0) {
      prevLog = exercise.logs[nextSet.setIndex - 1];
    } else {
      // Usar historial si es la primera serie
      final history = state.history[exercise.nombre];
      if (history != null && history.isNotEmpty) {
        prevLog = history.first;
      }
    }

    if (prevLog != null) {
      notifier.updateLog(
        nextSet.exerciseIndex,
        nextSet.setIndex,
        peso: prevLog.peso,
        reps: prevLog.reps,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.repeat_rounded,
                  color: AppColors.textOnAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                'REPITE: ${prevLog.peso}kg × ${prevLog.reps}',
                style: AppTypography.labelEmphasis
                    .copyWith(color: AppColors.textOnAccent),
              ),
            ],
          ),
          backgroundColor: AppColors.bloodRed,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 🎯 QUICK ACTIONS: Mantener objetivo actual (mismo peso/reps del historial)
  void _maintainCurrentGoal() {
    final state = ref.read(trainingSessionProvider);
    final nextSet = state.nextIncompleteSet;

    if (nextSet == null) return;

    final exercise = state.exercises[nextSet.exerciseIndex];
    final history = state.history[exercise.nombre];

    if (history != null && nextSet.setIndex < history.length) {
      final targetLog = history[nextSet.setIndex];

      ref.read(trainingSessionProvider.notifier).updateLog(
            nextSet.exerciseIndex,
            nextSet.setIndex,
            peso: targetLog.peso,
            reps: targetLog.reps,
          );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.sync_rounded,
                  color: AppColors.bloodRed, size: 18),
              const SizedBox(width: 8),
              Text(
                'OBJETIVO: ${targetLog.peso}kg × ${targetLog.reps}',
                style: AppTypography.labelEmphasis,
              ),
            ],
          ),
          backgroundColor: AppColors.bgElevated,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// 🎯 QUICK ACTIONS: Actualizar tiempo de descanso del ejercicio actual
  void _updateCurrentExerciseRestTime(int seconds) {
    final state = ref.read(trainingSessionProvider);
    final nextSet = state.nextIncompleteSet;

    if (nextSet == null) return;

    ref.read(trainingSessionProvider.notifier).updateExerciseRestTime(
          nextSet.exerciseIndex,
          seconds,
        );

    // También actualizar la duración del timer para la próxima vez
    ref.read(trainingSessionProvider.notifier).setRestDuration(seconds);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.timer_outlined,
                color: AppColors.restTeal, size: 18),
            const SizedBox(width: 8),
            Text(
              'Descanso: ${seconds >= 60 ? "${seconds ~/ 60}m ${seconds % 60 > 0 ? "${seconds % 60}s" : ""}" : "${seconds}s"}',
              style: AppTypography.labelEmphasis,
            ),
          ],
        ),
        backgroundColor: AppColors.bgElevated,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 🎯 QUICK ACTIONS: Mostrar opciones rápidas adicionales
  void _showQuickOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final notifier = ref.read(trainingSessionProvider.notifier);
        final state = ref.read(trainingSessionProvider);
        final nextSet = state.nextIncompleteSet;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'ACCIONES RÁPIDAS',
                  style: AppTypography.sectionTitle.copyWith(
                    color: AppColors.bloodRed,
                  ),
                ),
                const SizedBox(height: 16),

                // Saltar ejercicio
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.skip_next_rounded,
                        color: AppColors.textSecondary),
                  ),
                  title: Text('Saltar al siguiente',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text('Ir al próximo ejercicio',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _navigateToNextSet();
                  },
                ),

                // Ver historial
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.restTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.history, color: AppColors.restTeal),
                  ),
                  title: Text('Ver historial',
                      style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text('Revisar sesiones anteriores',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);

                    // Mostrar historial del ejercicio actual en un modal
                    if (nextSet == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'No hay un ejercicio seleccionado.',
                            style: AppTypography.labelEmphasis,
                          ),
                          backgroundColor: AppColors.info,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    final exercise = state.exercises[nextSet.exerciseIndex];
                    final history = state.history[exercise.nombre] ?? [];

                    showModalBottomSheet(
                      context: context,
                      backgroundColor: AppColors.bgElevated,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (ctx2) {
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Handle
                                Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.border,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Historial: ${exercise.nombre}',
                                  style: AppTypography.sectionTitle,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                if (history.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Text(
                                      'No hay historial para este ejercicio.',
                                      style: AppTypography.body
                                          .copyWith(
                                              color: AppColors.textTertiary),
                                    ),
                                  )
                                else
                                  SizedBox(
                                    height: 220,
                                    child: ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      itemCount: history.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, i) {
                                        final log = history[i];
                                        return ListTile(
                                          dense: true,
                                          title: Text(
                                            '${log.peso?.toStringAsFixed(1) ?? '-'} kg × ${log.reps ?? '-'} reps',
                                            style: AppTypography.labelEmphasis,
                                          ),
                                          subtitle: (log.notas != null &&
                                                  log.notas!.isNotEmpty)
                                              ? Text(
                                                  log.notas!,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                )
                                              : null,
                                          trailing: log.rpe != null
                                              ? Text(
                                                  'RPE ${log.rpe!.toStringAsFixed(1)}',
                                                  style: AppTypography.body
                                                      .copyWith(
                                                          color: AppColors
                                                              .textTertiary),
                                                )
                                              : null,
                                        );
                                      },
                                    ),
                                  ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
