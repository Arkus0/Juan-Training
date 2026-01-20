import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timer_count_down/timer_count_down.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/training_provider.dart';
import '../models/ejercicio.dart';
import '../models/serie_log.dart';

class TrainingSessionScreen extends ConsumerStatefulWidget {
  const TrainingSessionScreen({super.key});

  @override
  ConsumerState<TrainingSessionScreen> createState() => _TrainingSessionScreenState();
}

class _TrainingSessionScreenState extends ConsumerState<TrainingSessionScreen> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
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
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trainingSessionProvider);
    final notifier = ref.read(trainingSessionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          (state.activeRutina?.nombre ?? 'Entrenando').toUpperCase(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 20),
        ),
        actions: [
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
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 120), // Space for timer
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exercise.nombre.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.redAccent[700],
                shadows: [
                  Shadow(color: Colors.red[900]!.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'META: ${exercise.series} X ${exercise.reps} @ ${exercise.peso}KG',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[400],
                fontWeight: FontWeight.bold,
              ),
            ),
            if (exercise.notas != null && exercise.notas!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                    border: Border(left: BorderSide(color: Colors.red[900]!, width: 2)),
                  ),
                  child: Text(
                    exercise.notas!,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: FixedColumnWidth(30),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
                3: FixedColumnWidth(40),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    Center(child: Text('#', style: TextStyle(color: Colors.redAccent[700], fontWeight: FontWeight.bold))),
                    Center(child: Text('KG', style: TextStyle(color: Colors.redAccent[700], fontWeight: FontWeight.bold))),
                    Center(child: Text('REPS', style: TextStyle(color: Colors.redAccent[700], fontWeight: FontWeight.bold))),
                    const Icon(Icons.check_circle_outline, size: 18, color: Colors.grey),
                  ]
                ),
                const TableRow(children: [SizedBox(height: 8), SizedBox(height: 8), SizedBox(height: 8), SizedBox(height: 8)]), // Spacer
                ...List.generate(exercise.logs.length, (setIndex) {
                  final log = exercise.logs[setIndex];
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.grey[800],
                          child: Text('${setIndex + 1}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: _AggressiveTextField(
                          controller: _controllers['${exerciseIndex}_${setIndex}_weight']!,
                          onChanged: (val) {
                            final peso = double.tryParse(val);
                            if (peso != null) notifier.updateLog(exerciseIndex, setIndex, peso: peso);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: _AggressiveTextField(
                          controller: _controllers['${exerciseIndex}_${setIndex}_reps']!,
                          onChanged: (val) {
                            final reps = int.tryParse(val);
                            if (reps != null) notifier.updateLog(exerciseIndex, setIndex, reps: reps);
                          },
                          isInteger: true,
                        ),
                      ),
                      Transform.scale(
                        scale: 1.3,
                        child: Checkbox(
                          value: log.completed,
                          activeColor: Colors.redAccent[700],
                          onChanged: (val) {
                            notifier.updateLog(exerciseIndex, setIndex, completed: val);
                          },
                          side: const BorderSide(color: Colors.grey, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
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
    if (state.isRestActive) {
      return Container(
        color: Colors.black.withOpacity(0.95), // Dark overlay feeling
        height: 250, // Large area for timer
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Countdown(
                seconds: state.defaultRestSeconds,
                build: (BuildContext context, double time) {
                  return _AggressiveTimerDisplay(seconds: time);
                },
                interval: const Duration(milliseconds: 100),
                onFinished: () {
                  _notifyTimerFinished();
                  notifier.stopRest();
                },
              ),
            ),
            ElevatedButton(
              onPressed: () => notifier.stopRest(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red[900],
                minimumSize: const Size(200, 50),
              ),
              child: const Text('¡A LA CARGA! (SALTAR)'),
            )
          ],
        ),
      );
    }

    // Default rest selector
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.redAccent[700]!, width: 2)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('DESCANSO', style: Theme.of(context).textTheme.labelSmall),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.grey),
                      onPressed: () {
                        if (state.defaultRestSeconds > 10) {
                          notifier.setRestDuration(state.defaultRestSeconds - 10);
                        }
                      },
                    ),
                    Text(
                      '${state.defaultRestSeconds}s',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle, color: Colors.redAccent[700]),
                      onPressed: () {
                        notifier.setRestDuration(state.defaultRestSeconds + 10);
                      },
                    ),
                  ],
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () => notifier.startRest(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent[700],
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('DESCANSAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _notifyTimerFinished() async {
    Vibrate.vibrate();
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/beep.mp3'));
    } catch (_) {}

    if (mounted) {
       // Optional: Flash screen or big dialog could go here
    }
  }
}

class _AggressiveTextField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool isInteger;

  const _AggressiveTextField({
    required this.controller,
    required this.onChanged,
    this.isInteger = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        filled: true,
        fillColor: Colors.black,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent[700]!, width: 2),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _AggressiveTimerDisplay extends StatefulWidget {
  final double seconds;

  const _AggressiveTimerDisplay({required this.seconds});

  @override
  State<_AggressiveTimerDisplay> createState() => _AggressiveTimerDisplayState();
}

class _AggressiveTimerDisplayState extends State<_AggressiveTimerDisplay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_AggressiveTimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seconds <= 10 && widget.seconds > 0) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int seconds = widget.seconds.ceil();
    final bool isCritical = seconds <= 10;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isCritical ? _scaleAnimation.value : 1.0,
          child: Text(
            '$seconds',
            style: GoogleFonts.montserrat(
              fontSize: 120,
              fontWeight: FontWeight.w900,
              color: isCritical ? Colors.redAccent[700] : Colors.white,
              shadows: [
                Shadow(
                  color: (isCritical ? Colors.red : Colors.red[900])!.withOpacity(0.8),
                  blurRadius: isCritical ? 20 : 10,
                  offset: const Offset(0, 0),
                )
              ],
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
