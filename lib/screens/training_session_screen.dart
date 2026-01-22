import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/training_provider.dart';
import '../providers/focus_manager_provider.dart';
import '../providers/session_progress_provider.dart';
import '../widgets/session/exercise_card.dart';
import '../widgets/session/rest_timer_bar.dart';
import '../widgets/session/session_progress_bar.dart';

/// Provider para comunicar el auto-focus cuando el timer termina
/// (Mantenido para compatibilidad, ahora usa FocusManagerProvider internamente)
final timerFinishedFocusProvider = StateProvider<({int exerciseIndex, int setIndex})?>(
  (ref) => null,
);

class TrainingSessionScreen extends ConsumerStatefulWidget {
  const TrainingSessionScreen({super.key});

  @override
  ConsumerState<TrainingSessionScreen> createState() => _TrainingSessionScreenState();
}

class _TrainingSessionScreenState extends ConsumerState<TrainingSessionScreen> {
  final ScrollController _scrollController = ScrollController();

  // Per-card keys used for precise scrolling via Scrollable.ensureVisible (stable per exercise id)
  final Map<String, GlobalKey> _exerciseKeys = {}; 

  @override
  void initState() {
    super.initState();
    // Discovery Tooltip Check (First 3 sessions)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDiscoveryTooltip();
      // Inicializar el progreso de sesión
      ref.read(sessionProgressProvider.notifier).recalculate();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onFinishSession() async {
    final progress = ref.read(sessionProgressProvider);

    // Mensaje de confirmación según el progreso
    String confirmMessage = '¿Estás seguro de que quieres terminar el entrenamiento?';
    if (progress.percentage < 0.5) {
      confirmMessage += '\n\nSolo has completado ${progress.formattedPercentage} de la sesión.';
    } else if (progress.percentage < 1.0) {
      confirmMessage += '\n\nHas completado ${progress.formattedPercentage}. ¡Casi lo tienes!';
    }

    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          progress.isComplete ? '¡SESIÓN COMPLETADA!' : '¿TERMINAR SESIÓN?',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            color: progress.isComplete ? Colors.green[400] : Colors.white,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              confirmMessage,
              style: const TextStyle(color: Colors.white70),
            ),
            if (progress.isComplete) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[900]?.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[400]!.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.celebration, color: Colors.green[400]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${progress.completedSets} series completadas',
                        style: GoogleFonts.montserrat(
                          color: Colors.green[400],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'CANCELAR',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'TERMINAR',
              style: TextStyle(
                color: progress.isComplete ? Colors.green[400] : Colors.redAccent[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldFinish == true) {
      if (!mounted) return;
      final navigator = Navigator.of(context);

      // Stop any active rest timer so UI and state are consistent
      // Prevents floating timer overlay from still being active after finishing
      ref.read(trainingSessionProvider.notifier).stopRest();

      // Reset progreso
      ref.read(sessionProgressProvider.notifier).reset();

      await ref.read(trainingSessionProvider.notifier).finishSession();
      navigator.pop();
    }
  }

  void _checkDiscoveryTooltip() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.swipe, color: Colors.redAccent[400], size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Tip: Swipe arriba/abajo en inputs para +/- rápido. Doble-tap para copiar valor anterior.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.grey[900],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.redAccent[700]!),
        ),
      ),
    );
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
    final id = exercises.length > exerciseIndex ? exercises[exerciseIndex].id : null;
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
    final activeRutinaName = ref.watch(trainingSessionProvider.select((s) => s.activeRutina?.nombre));
    final showAdvanced = ref.watch(trainingSessionProvider.select((s) => s.showAdvancedOptions));
    final exercisesLength = ref.watch(trainingSessionProvider.select((s) => s.exercises.length));

    // Timer state (nuevo estado avanzado)
    final restTimerState = ref.watch(trainingSessionProvider.select((s) => s.restTimer));

    // Progress state
    final progress = ref.watch(sessionProgressProvider);

    final notifier = ref.read(trainingSessionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          (activeRutinaName ?? 'Entrenando').toUpperCase(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(showAdvanced ? Icons.settings_input_component : Icons.settings_input_component_outlined),
            onPressed: () => notifier.toggleAdvancedOptions(!showAdvanced),
            tooltip: 'Opciones Avanzadas',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _onFinishSession,
              style: TextButton.styleFrom(
                backgroundColor: progress.isComplete ? Colors.green[400] : Colors.white,
                foregroundColor: progress.isComplete ? Colors.white : Colors.red[900],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de progreso de sesión (no invasiva, top)
          const SessionProgressBar(),

          // Lista de ejercicios
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 80), // Espacio para timer compacto
              itemCount: exercisesLength,
              itemBuilder: (context, index) {
                // ⚡ Bolt Optimization: Extracted to smart widget
                final exercises = ref.read(trainingSessionProvider).exercises;
                final id = exercises.length > index ? exercises[index].id : index.toString();
                final key = _exerciseKeys.putIfAbsent(id, () => GlobalKey());
                return Container(
                  key: key,
                  child: ExerciseCardContainer(exerciseIndex: index),
                );
              },
            ),
          ),

          // Nuevo Timer Bar no invasivo
          RestTimerBar(
            timerState: restTimerState,
            onStartRest: notifier.startRest,
            onStopRest: notifier.stopRest,
            onPauseRest: notifier.pauseRest,
            onResumeRest: notifier.resumeRest,
            onDurationChange: notifier.setRestDuration,
            onAddTime: notifier.addRestTime,
            onTimerFinished: _onTimerFinished,
          ),
        ],
      ),
    );
  }
}
