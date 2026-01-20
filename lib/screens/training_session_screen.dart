import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timer_count_down/timer_count_down.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/training_provider.dart';
import '../models/ejercicio.dart';
import '../models/serie_log.dart';

class TrainingSessionScreen extends ConsumerStatefulWidget {
  const TrainingSessionScreen({super.key});

  @override
  ConsumerState<TrainingSessionScreen> createState() => _TrainingSessionScreenState();
}

class _TrainingSessionScreenState extends ConsumerState<TrainingSessionScreen> {
  // Controllers map: "exIndex_setIndex_type" -> TextEditingController
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current state values
    final state = ref.read(trainingSessionProvider);
    for (int i = 0; i < state.exercises.length; i++) {
      final exercise = state.exercises[i];
      for (int j = 0; j < exercise.logs.length; j++) {
        final log = exercise.logs[j];
        _controllers['${i}_${j}_weight'] = TextEditingController(text: log.peso.toString());
        _controllers['${i}_${j}_reps'] = TextEditingController(text: log.reps.toString());
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onFinishSession() async {
    final navigator = Navigator.of(context);
    await ref.read(trainingSessionProvider.notifier).finishSession();
    navigator.pop(); // Return to MainScreen (which switched to History tab)
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trainingSessionProvider);
    final notifier = ref.read(trainingSessionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.activeRutina?.nombre ?? 'Entrenando'),
        actions: [
          TextButton(
            onPressed: _onFinishSession,
            child: const Text('TERMINAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100), // Space for timer
              itemCount: state.exercises.length,
              itemBuilder: (context, index) {
                return _buildExerciseCard(context, index, state.exercises[index], notifier);
              },
            ),
          ),
          _buildTimerPanel(context, state, notifier),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, int exerciseIndex, Ejercicio exercise, TrainingSessionNotifier notifier) {
    // Target info comes from target (or we can just use the exercise info if it hasn't drifted,
    // but the exercise logs might be different).
    // The prompt says "Para cada ejercicio: series x reps objetivo".
    // We can assume exercise.series/reps/peso are the targets.

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.nombre,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              'Meta: ${exercise.series} series x ${exercise.reps} reps @ ${exercise.peso}kg',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            if (exercise.notas != null && exercise.notas!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Notas: ${exercise.notas}', style: const TextStyle(fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FixedColumnWidth(30), // #
                1: FlexColumnWidth(),    // Kg
                2: FlexColumnWidth(),    // Reps
                3: FixedColumnWidth(40), // Check
              },
              children: [
                const TableRow(
                  children: [
                    Center(child: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                    Center(child: Text('Kg', style: TextStyle(fontWeight: FontWeight.bold))),
                    Center(child: Text('Reps', style: TextStyle(fontWeight: FontWeight.bold))),
                    Icon(Icons.check, size: 16),
                  ]
                ),
                ...List.generate(exercise.logs.length, (setIndex) {
                  final log = exercise.logs[setIndex];
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: Text('${setIndex + 1}')),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: TextField(
                          controller: _controllers['${exerciseIndex}_${setIndex}_weight'],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            final peso = double.tryParse(val);
                            if (peso != null) {
                              notifier.updateLog(exerciseIndex, setIndex, peso: peso);
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: TextField(
                          controller: _controllers['${exerciseIndex}_${setIndex}_reps'],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) {
                            final reps = int.tryParse(val);
                            if (reps != null) {
                              notifier.updateLog(exerciseIndex, setIndex, reps: reps);
                            }
                          },
                        ),
                      ),
                      Checkbox(
                        value: log.completed,
                        onChanged: (val) {
                          notifier.updateLog(exerciseIndex, setIndex, completed: val);
                        },
                      ),
                    ]
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerPanel(BuildContext context, TrainingState state, TrainingSessionNotifier notifier) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: state.isRestActive
                  ? Countdown(
                      seconds: state.defaultRestSeconds,
                      build: (BuildContext context, double time) {
                        return Text(
                          'Descanso: ${time.toInt()}s',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                      interval: const Duration(milliseconds: 100),
                      onFinished: () {
                        _notifyTimerFinished();
                        notifier.stopRest();
                      },
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            if (state.defaultRestSeconds > 10) {
                              notifier.setRestDuration(state.defaultRestSeconds - 10);
                            }
                          },
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Descanso'),
                            Text(
                              '${state.defaultRestSeconds}s',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            notifier.setRestDuration(state.defaultRestSeconds + 10);
                          },
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                if (state.isRestActive) {
                  notifier.stopRest();
                } else {
                  notifier.startRest();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: state.isRestActive ? Colors.red : Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                state.isRestActive ? 'SALTAR' : 'DESCANSAR',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _notifyTimerFinished() async {
    // Vibrate
    Vibrate.vibrate();

    // Play Sound
    try {
      final player = AudioPlayer();
      // Assumes assets/sounds/beep.mp3 exists or user will add it.
      // We could also play a remote url if needed, but offline is preferred.
      await player.play(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      // Ignore audio errors if asset missing
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Descanso terminado!"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
