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

  @override
  Widget build(BuildContext context) {
    // ⚡ Bolt Optimization: Use select to only rebuild on specific changes
    // This prevents the entire screen from rebuilding when a single text field changes
    final activeRutinaName = ref.watch(trainingSessionProvider.select((s) => s.activeRutina?.nombre));
    final showAdvanced = ref.watch(trainingSessionProvider.select((s) => s.showAdvancedOptions));
    final exercisesLength = ref.watch(trainingSessionProvider.select((s) => s.exercises.length));

    // Timer specific selectors
    final isRestActive = ref.watch(trainingSessionProvider.select((s) => s.isRestActive));
    final defaultRestSeconds = ref.watch(trainingSessionProvider.select((s) => s.defaultRestSeconds));

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
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 120), // Space for timer
              itemCount: exercisesLength,
              itemBuilder: (context, index) {
                // ⚡ Bolt Optimization: Extracted to smart widget
                return SessionExerciseCard(exerciseIndex: index);
              },
            ),
          ),
          _buildTimerPanel(context, isRestActive, defaultRestSeconds, notifier),
        ],
      ),
    );
  }

  Widget _buildTimerPanel(BuildContext context, bool isRestActive, int defaultRestSeconds, TrainingSessionNotifier notifier) {
    if (isRestActive) {
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
                seconds: defaultRestSeconds,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
                        if (defaultRestSeconds > 10) {
                          notifier.setRestDuration(defaultRestSeconds - 10);
                        }
                      },
                    ),
                    Text(
                      '${defaultRestSeconds}s',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle, color: Colors.redAccent[700]),
                      onPressed: () {
                        notifier.setRestDuration(defaultRestSeconds + 10);
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
}

class SessionExerciseCard extends ConsumerStatefulWidget {
  final int exerciseIndex;

  const SessionExerciseCard({
    super.key,
    required this.exerciseIndex,
  });

  @override
  ConsumerState<SessionExerciseCard> createState() => _SessionExerciseCardState();
}

class _SessionExerciseCardState extends ConsumerState<SessionExerciseCard> {
  @override
  Widget build(BuildContext context) {
    // ⚡ Bolt Optimization: Only rebuild this specific card when name or log count changes
    final exerciseName = ref.watch(trainingSessionProvider.select((s) => s.exercises[widget.exerciseIndex].nombre));
    final logsLength = ref.watch(trainingSessionProvider.select((s) => s.exercises[widget.exerciseIndex].logs.length));
    final historyLogs = ref.watch(trainingSessionProvider.select((s) => s.history[exerciseName]));

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
                        exerciseName.toUpperCase(),
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

            ...List.generate(logsLength, (setIndex) {
              return SessionSetRow(
                exerciseIndex: widget.exerciseIndex,
                setIndex: setIndex,
                exerciseName: exerciseName,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class SessionSetRow extends ConsumerStatefulWidget {
  final int exerciseIndex;
  final int setIndex;
  final String exerciseName;

  const SessionSetRow({
    super.key,
    required this.exerciseIndex,
    required this.setIndex,
    required this.exerciseName,
  });

  @override
  ConsumerState<SessionSetRow> createState() => _SessionSetRowState();
}

class _SessionSetRowState extends ConsumerState<SessionSetRow> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    final log = ref.read(trainingSessionProvider).exercises[widget.exerciseIndex].logs[widget.setIndex];
    _weightController = TextEditingController(text: log.peso > 0 ? log.peso.toString() : '');
    _repsController = TextEditingController(text: log.reps > 0 ? log.reps.toString() : '');
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _openPlateCalc(double currentWeight, TrainingSessionNotifier notifier) {
    showDialog(
      context: context,
      builder: (_) => PlateCalculatorDialog(
        currentWeight: currentWeight,
        onWeightSelected: (val) {
          _weightController.text = val.toString();
          notifier.updateLog(widget.exerciseIndex, widget.setIndex, peso: val);
        },
      ),
    );
  }

  void _showAdvancedOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _AdvancedOptionsModal(exerciseIndex: widget.exerciseIndex, setIndex: widget.setIndex),
        );
      },
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
           await player.play(AssetSource('sounds/success.mp3'));
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

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(trainingSessionProvider.select((s) => s.exercises[widget.exerciseIndex].logs[widget.setIndex]));
    final prevLog = ref.watch(trainingSessionProvider.select((s) {
      final historyLogs = s.history[widget.exerciseName];
      if (historyLogs != null && widget.setIndex < historyLogs.length) {
        return historyLogs[widget.setIndex];
      }
      return null;
    }));
    final showAdvanced = ref.watch(trainingSessionProvider.select((s) => s.showAdvancedOptions));
    final isRestActive = ref.watch(trainingSessionProvider.select((s) => s.isRestActive));
    final notifier = ref.read(trainingSessionProvider.notifier);

    ref.listen(trainingSessionProvider.select((s) => s.exercises[widget.exerciseIndex].logs[widget.setIndex]), (prev, next) {
        // Sync controllers if external change (e.g. plate calc or copy)
        // Check weight
        final double currentWeight = double.tryParse(_weightController.text) ?? 0.0;
        if (next.peso != currentWeight) {
           if (_weightController.text.isEmpty || double.tryParse(_weightController.text) != next.peso) {
              if (next.peso == 0.0) {
                 if (_weightController.text.isNotEmpty) _weightController.text = '';
              } else {
                 _weightController.text = next.peso.toString();
              }
           }
        }
        // Check reps
        final int currentReps = int.tryParse(_repsController.text) ?? 0;
        if (next.reps != currentReps) {
             if (_repsController.text.isEmpty || int.tryParse(_repsController.text) != next.reps) {
                if (next.reps == 0) {
                   if (_repsController.text.isNotEmpty) _repsController.text = '';
                } else {
                   _repsController.text = next.reps.toString();
                }
             }
        }
    });

    return GestureDetector(
      onLongPress: _showAdvancedOptions,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        color: log.completed ? Colors.red[900]!.withValues(alpha: 0.1) : Colors.transparent,
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
                      backgroundColor: log.completed ? Colors.redAccent[700] : Colors.grey[800],
                      child: Text('${widget.setIndex + 1}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                    ),
                  ),
                ),
                // Previous History
                SizedBox(
                  width: 50,
                  child: Center(
                    child: Text(
                      prevLog != null ? '${prevLog.peso}x${prevLog.reps}' : '-',
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
                          onChanged: (val) => notifier.updateLog(widget.exerciseIndex, widget.setIndex, peso: double.tryParse(val)),
                        ),
                        GestureDetector(
                          onTap: () => _openPlateCalc(double.tryParse(_weightController.text) ?? 0.0, notifier),
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
                      onChanged: (val) => notifier.updateLog(widget.exerciseIndex, widget.setIndex, reps: int.tryParse(val)),
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
                      value: log.completed,
                      activeColor: Colors.redAccent[700],
                      onChanged: (val) {
                        notifier.updateLog(widget.exerciseIndex, widget.setIndex, completed: val);
                        if (val == true) {
                           _triggerCompletionFeedback(log, prevLog);
                           // Auto-advance rest
                           if (!isRestActive) notifier.startRest();
                        }
                      },
                      side: const BorderSide(color: Colors.grey, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
            if (showAdvanced || (log.rpe != null || (log.notas != null && log.notas!.isNotEmpty)))
               Padding(
                 padding: const EdgeInsets.only(left: 80, right: 40, top: 4),
                 child: Row(
                   children: [
                     if (log.rpe != null)
                       _Tag(text: 'RPE ${log.rpe}', color: Colors.orange),
                     if (log.isFailure)
                       const _Tag(text: 'FAIL', color: Colors.red),
                     if (log.notas != null && log.notas!.isNotEmpty)
                       Expanded(child: Text(log.notas!, style: const TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis)),
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
