import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/training_provider.dart';
import '../providers/focus_manager_provider.dart';
import '../providers/session_progress_provider.dart';
import '../providers/voice_input_provider.dart';
import '../widgets/session/exercise_card.dart';
import '../widgets/session/rest_timer_bar.dart';
import '../widgets/session/session_progress_bar.dart';
import '../widgets/session/music_launcher_bar.dart';
import '../widgets/voice/voice_training_button.dart';

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
      _lastKnownIncompleteSet = ref.read(trainingSessionProvider).nextIncompleteSet;
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

      // Stop any active rest timer
      ref.read(trainingSessionProvider.notifier).stopRest();
      ref.read(sessionProgressProvider.notifier).reset();

      await ref.read(trainingSessionProvider.notifier).finishSession();
      navigator.pop();
      return;
    }

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
          '¿TERMINAR SESIÓN?',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w900,
            color: Colors.white,
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
                color: Colors.redAccent[700],
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
    final exercisesLength = ref.watch(trainingSessionProvider.select((s) => s.exercises.length));

    // Timer state (nuevo estado avanzado)
    final restTimerState = ref.watch(trainingSessionProvider.select((s) => s.restTimer));
    final showTimerBar = ref.watch(trainingSessionProvider.select((s) => s.showTimerBar));

    // Progress state
    final progress = ref.watch(sessionProgressProvider);

    // Voice available
    final voiceAvailable = ref.watch(voiceAvailableProvider);

    final notifier = ref.read(trainingSessionProvider.notifier);

    // 🎯 UX CRÍTICO: Auto-scroll al siguiente ejercicio cuando se completa una serie
    final currentIncompleteSet = ref.watch(trainingSessionProvider.select((s) => s.nextIncompleteSet));
    if (_lastKnownIncompleteSet != null && 
        currentIncompleteSet != null &&
        currentIncompleteSet.exerciseIndex != _lastKnownIncompleteSet!.exerciseIndex) {
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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 20),
        ),
        actions: [
          // Botón de voz en AppBar (al lado de terminar)
          voiceAvailable.when(
            data: (available) => available 
                ? VoiceTrainingButton(
                    enabled: true,
                    onCommand: (command) => _handleVoiceCommand(command, notifier),
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
      body: Stack(
        children: [
          Column(
            children: [
              // Barra de progreso de sesión (no invasiva, top)
              const SessionProgressBar(),

              // Music launcher (Spotify quick open) 🎧
              const MusicLauncherBar(),

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
              const Icon(Icons.note_add, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nota: $note',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue[700],
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
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '¡Serie completada!',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[700],
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
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.grey[800],
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
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.grey[800],
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
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.grey[800],
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
