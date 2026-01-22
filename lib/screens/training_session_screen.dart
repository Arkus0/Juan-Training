import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/training_provider.dart';
import '../widgets/session/exercise_card.dart';
import '../widgets/session/rest_timer_bar.dart';

/// Provider para comunicar el auto-focus cuando el timer termina
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

  @override
  void initState() {
    super.initState();
    // Discovery Tooltip Check (First 3 sessions)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDiscoveryTooltip();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onFinishSession() async {
    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿TERMINAR SESIÓN?'),
        content: const Text(
          '¿Estás seguro de que quieres terminar el entrenamiento? Asegúrate de haber completado tus series.',
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
                color: Theme.of(context).colorScheme.secondary,
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
      await ref.read(trainingSessionProvider.notifier).finishSession();
      navigator.pop();
    }
  }

  void _checkDiscoveryTooltip() async {
     // Ideally check Hive box count, simplified here
     await Future.delayed(const Duration(seconds: 1));
     if (!mounted) return;

     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(
         content: const Text('💡 Tip: Mantén pulsada una serie para opciones PRO (RPE, Fallo, Notas)'),
         backgroundColor: Colors.grey[900],
         behavior: SnackBarBehavior.floating,
         duration: const Duration(seconds: 4),
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.redAccent[700]!)),
       ),
     );
  }

  /// Callback cuando el timer de descanso termina
  /// Vibra y notifica para auto-focus al siguiente input
  void _onTimerFinished({int? lastExerciseIndex, int? lastSetIndex}) async {
    // La vibración ya se maneja en el TimerBar
    // Notificar para auto-focus
    final state = ref.read(trainingSessionProvider);
    final nextSet = state.nextIncompleteSet;

    if (nextSet != null) {
      // Actualizar el provider para que ExerciseCard haga focus
      ref.read(timerFinishedFocusProvider.notifier).state = nextSet;

      // Scroll hacia el ejercicio si es necesario
      _scrollToExercise(nextSet.exerciseIndex);

      // Limpiar después de un frame para que el widget pueda reaccionar
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ref.read(timerFinishedFocusProvider.notifier).state = null;
          }
        });
      });
    }
  }

  /// Scroll suave hacia un ejercicio específico
  void _scrollToExercise(int exerciseIndex) {
    // Estimar posición del card (aprox 200px por card)
    final estimatedOffset = exerciseIndex * 220.0;
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
    // This prevents the entire screen from rebuilding when a single text field changes
    final activeRutinaName = ref.watch(trainingSessionProvider.select((s) => s.activeRutina?.nombre));
    final showAdvanced = ref.watch(trainingSessionProvider.select((s) => s.showAdvancedOptions));
    final exercisesLength = ref.watch(trainingSessionProvider.select((s) => s.exercises.length));

    // Timer state (nuevo estado avanzado)
    final restTimerState = ref.watch(trainingSessionProvider.select((s) => s.restTimer));

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
                backgroundColor: Colors.white,
                foregroundColor: Colors.red[900],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(
                'TERMINAR',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 80), // Espacio reducido para timer compacto
              itemCount: exercisesLength,
              itemBuilder: (context, index) {
                // ⚡ Bolt Optimization: Extracted to smart widget
                return ExerciseCardContainer(exerciseIndex: index);
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
