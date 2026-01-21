import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/serie_log.dart';
import '../../screens/plate_calculator_dialog.dart';

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
      if (_weightController.text.isNotEmpty && double.tryParse(_weightController.text) == widget.log.peso) {
         // Identical
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
                GestureDetector(
                  onTap: () {
                    if (widget.prevLog != null) {
                      HapticFeedback.selectionClick();
                      _weightController.text = widget.prevLog!.peso.toString();
                      _repsController.text = widget.prevLog!.reps.toString();
                      widget.onWeightChanged(_weightController.text);
                      widget.onRepsChanged(_repsController.text);
                    }
                  },
                  child: SizedBox(
                    width: 50,
                    child: Center(
                      child: Text(
                        widget.prevLog != null
                            ? 'Prev:\n${widget.prevLog!.peso}x${widget.prevLog!.reps}'
                            : '-',
                        style: TextStyle(color: Colors.grey[600], fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
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
                      onChanged: (val) {
                        if (val == true) {
                          HapticFeedback.mediumImpact();
                        }
                        widget.onCompleted(val);
                      },
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
                       Tag(text: 'RPE ${widget.log.rpe}', color: Colors.orange),
                     if (widget.log.isFailure)
                       const Tag(text: 'FAIL', color: Colors.red),
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

class Tag extends StatelessWidget {
  final String text;
  final Color color;
  const Tag({super.key, required this.text, required this.color});

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
