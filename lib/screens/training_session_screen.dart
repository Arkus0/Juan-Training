import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timer_count_down/timer_count_down.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/training_provider.dart';
import '../models/ejercicio.dart';
import '../models/serie_log.dart';
import 'plate_calculator_dialog.dart';

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
    final navigator = Navigator.of(context);
    await ref.read(trainingSessionProvider.notifier).finishSession();
    navigator.pop();
  }

  void _showAdvancedOptions(BuildContext context, int exerciseIndex, int setIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _AdvancedOptionsModal(exerciseIndex: exerciseIndex, setIndex: setIndex),
        );
      },
    );
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
          IconButton(
            icon: Icon(state.showAdvancedOptions ? Icons.settings_input_component : Icons.settings_input_component_outlined),
            onPressed: () => notifier.toggleAdvancedOptions(!state.showAdvancedOptions),
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
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 120), // Space for timer
              itemCount: state.exercises.length,
              itemBuilder: (context, index) {
                return _buildExerciseCard(context, index, state.exercises[index], notifier, state);
              },
            ),
          ),
          _buildTimerPanel(context, state, notifier),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, int exerciseIndex, Ejercicio exercise, TrainingSessionNotifier notifier, TrainingState state) {
    final historyLogs = state.history[exercise.nombre];

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
                       if (historyLogs != null && historyLogs.isNotEmpty)
                         Text(
                           'LAST: ${historyLogs.last.peso}KG x ${historyLogs.last.reps}',
                           style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold),
                         ),
                     ],
                   ),
                 ),
                 IconButton(
                   icon: const Icon(Icons.more_horiz),
                   onPressed: () {}, // Could open exercise settings
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
              final prevLog = (historyLogs != null && setIndex < historyLogs.length) ? historyLogs[setIndex] : null;

              return SessionSetRow(
                index: setIndex,
                log: log,
                prevLog: prevLog,
                onWeightChanged: (val) => notifier.updateLog(exerciseIndex, setIndex, peso: double.tryParse(val)),
                onRepsChanged: (val) => notifier.updateLog(exerciseIndex, setIndex, reps: int.tryParse(val)),
                onCompleted: (val) {
                  notifier.updateLog(exerciseIndex, setIndex, completed: val);
                  if (val == true) {
                     _triggerCompletionFeedback(log, prevLog);
                     // Auto-advance rest
                     if (!state.isRestActive) notifier.startRest();
                  }
                },
                onPlateCalc: (val) => notifier.updateLog(exerciseIndex, setIndex, peso: val),
                onLongPress: () => _showAdvancedOptions(context, exerciseIndex, setIndex),
                showAdvanced: state.showAdvancedOptions,
              );
            }),
          ],
        ),
      ),
    );
  }

  void _triggerCompletionFeedback(SerieLog current, SerieLog? previous) async {
    // Basic completion feedback
    if (await Vibrate.canVibrate) {
      Vibrate.vibrate();
    }

    // Check for "PR" or better performance
    if (previous != null) {
      bool improved = false;
      if (current.peso > previous.peso) improved = true;
      if (current.peso == previous.peso && current.reps > previous.reps) improved = true;

      if (improved) {
        // Play success sound
        try {
           final player = AudioPlayer();
           await player.play(AssetSource('sounds/success.mp3')); // Assuming we have one, or stick to beep
        } catch (_) {}

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

  Widget _buildTimerPanel(BuildContext context, TrainingState state, TrainingSessionNotifier notifier) {
    if (state.isRestActive) {
      return Container(
        color: Colors.black.withValues(alpha: 0.95),
        height: 250,
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
  }

  void _checkDiscoveryTooltip() async {
     // Ideally check Hive box count, simplified here
     // If this is one of the first sessions, show a tooltip
     // Since we don't have easy access to Hive count here without provider,
     // we can just show a temporary snackbar hint if it's the very start of session.

     // Note: Real implementation would check Hive.box<Sesion>('sesiones').length < 3

     // For now, let's just show it briefly on entry
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
}

class SessionSetRow extends StatefulWidget {
  final int index;
  final SerieLog log;
  final SerieLog? prevLog;
  final Function(String) onWeightChanged;
  final Function(String) onRepsChanged;
  final Function(bool?) onCompleted;
  final Function(double) onPlateCalc;
  final VoidCallback onLongPress;
  final bool showAdvanced;

  const SessionSetRow({
    super.key,
    required this.index,
    required this.log,
    required this.prevLog,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onCompleted,
    required this.onPlateCalc,
    required this.onLongPress,
    required this.showAdvanced,
  });

  @override
  State<SessionSetRow> createState() => _SessionSetRowState();
}

class _SessionSetRowState extends State<SessionSetRow> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.log.peso > 0 ? widget.log.peso.toString() : '');
    _repsController = TextEditingController(text: widget.log.reps > 0 ? widget.log.reps.toString() : '');
  }

  @override
  void didUpdateWidget(SessionSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check for weight changes from external source (e.g. copy previous set)
    final double currentWeight = double.tryParse(_weightController.text) ?? 0.0;
    if (widget.log.peso != currentWeight && widget.log.peso != 0.0) {
      // Avoid resetting if difference is just parsing (e.g. "10." vs 10.0)
      // But here we generally want to update if model changed significantly
      if (_weightController.text.isNotEmpty && double.tryParse(_weightController.text) == widget.log.peso) {
         // Identical value, don't mess with text (cursor)
      } else {
         _weightController.text = widget.log.peso.toString();
      }
    }

    // Check for reps changes
    final int currentReps = int.tryParse(_repsController.text) ?? 0;
    if (widget.log.reps != currentReps && widget.log.reps != 0) {
      if (_repsController.text.isNotEmpty && int.tryParse(_repsController.text) == widget.log.reps) {
         // Identical
      } else {
         _repsController.text = widget.log.reps.toString();
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _openPlateCalc() {
    final currentVal = double.tryParse(_weightController.text) ?? 0.0;
    showDialog(
      context: context,
      builder: (_) => PlateCalculatorDialog(
        currentWeight: currentVal,
        onWeightSelected: (val) {
          _weightController.text = val.toString();
          widget.onPlateCalc(val);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: widget.log.completed ? Colors.red[900]!.withValues(alpha: 0.1) : Colors.transparent,
        child: Column(
          children: [
            Row(
              children: [
                // Set Number
                SizedBox(
                  width: 30,
                  child: Center(
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: widget.log.completed ? Colors.redAccent[700] : Colors.grey[800],
                      child: Text('${widget.index + 1}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                  ),
                ),
                // Previous History
                SizedBox(
                  width: 50,
                  child: Center(
                    child: Text(
                      widget.prevLog != null ? '${widget.prevLog!.peso}x${widget.prevLog!.reps}' : '-',
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                  ),
                ),
                // Weight Input
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        _AggressiveTextField(
                          controller: _weightController,
                          onChanged: widget.onWeightChanged,
                        ),
                        GestureDetector(
                          onTap: _openPlateCalc,
                          child: Container(
                            margin: const EdgeInsets.only(right: 2),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.calculate, size: 16, color: Colors.grey),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                // Reps Input
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _AggressiveTextField(
                      controller: _repsController,
                      onChanged: widget.onRepsChanged,
                      isInteger: true,
                    ),
                  ),
                ),
                // Checkbox
                SizedBox(
                  width: 40,
                  child: Transform.scale(
                    scale: 1.3,
                    child: Checkbox(
                      value: widget.log.completed,
                      activeColor: Colors.redAccent[700],
                      onChanged: widget.onCompleted,
                      side: const BorderSide(color: Colors.grey, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.showAdvanced || (widget.log.rpe != null || (widget.log.notas != null && widget.log.notas!.isNotEmpty)))
               Padding(
                 padding: const EdgeInsets.only(left: 80, right: 40, top: 4),
                 child: Row(
                   children: [
                     if (widget.log.rpe != null)
                       _Tag(text: 'RPE ${widget.log.rpe}', color: Colors.orange),
                     if (widget.log.isFailure)
                       const _Tag(text: 'FAIL', color: Colors.red),
                     if (widget.log.notas != null && widget.log.notas!.isNotEmpty)
                       Expanded(child: Text(widget.log.notas!, style: const TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis)),
                   ],
                 ),
               )
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }
}

class _AdvancedOptionsModal extends ConsumerStatefulWidget {
  final int exerciseIndex;
  final int setIndex;

  const _AdvancedOptionsModal({required this.exerciseIndex, required this.setIndex});

  @override
  ConsumerState<_AdvancedOptionsModal> createState() => _AdvancedOptionsModalState();
}

class _AdvancedOptionsModalState extends ConsumerState<_AdvancedOptionsModal> {
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(trainingSessionProvider);
    final log = state.exercises[widget.exerciseIndex].logs[widget.setIndex];
    _notesController = TextEditingController(text: log.notas ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trainingSessionProvider);
    final notifier = ref.read(trainingSessionProvider.notifier);
    final log = state.exercises[widget.exerciseIndex].logs[widget.setIndex];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, color: Colors.grey[700])),
          const SizedBox(height: 16),
          Text('OPCIONES PRO', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.redAccent)),
          const SizedBox(height: 16),

          // RPE Slider
          Text('RPE (Esfuerzo Percibido): ${log.rpe ?? "-"}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: (log.rpe ?? 0).toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: Colors.redAccent[700],
            onChanged: (val) {
              notifier.updateLog(widget.exerciseIndex, widget.setIndex, rpe: val == 0 ? null : val.toInt());
            },
          ),

          // Toggles
          Row(
            children: [
              FilterChip(
                label: const Text('FALLO MUSCULAR'),
                selected: log.isFailure,
                onSelected: (val) => notifier.updateLog(widget.exerciseIndex, widget.setIndex, isFailure: val),
                selectedColor: Colors.red[900],
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('DROPSET'),
                selected: log.isDropset,
                onSelected: (val) => notifier.updateLog(widget.exerciseIndex, widget.setIndex, isDropset: val),
                selectedColor: Colors.orange[900],
              ),
            ],
          ),

          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notas de la serie', prefixIcon: Icon(Icons.edit_note)),
            onChanged: (val) => notifier.updateLog(widget.exerciseIndex, widget.setIndex, notas: val),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
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
                  color: (isCritical ? Colors.red : Colors.red[900])!.withValues(alpha: 0.8),
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
