import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/serie_log.dart';
import '../../models/progression_type.dart';
import '../../screens/plate_calculator_dialog.dart';

class SessionSetRow extends StatefulWidget {
  final int index;
  final SerieLog log;
  final SerieLog? prevLog;
  final ProgressionSuggestion? suggestion;
  final Function(String) onWeightChanged;
  final Function(String) onRepsChanged;
  final Function(bool?) onCompleted;
  final Function(double) onPlateCalc;
  final VoidCallback onLongPress;
  final bool showAdvanced;
  final bool shouldFocus; // Para auto-focus cuando timer termina

  const SessionSetRow({
    super.key,
    required this.index,
    required this.log,
    required this.prevLog,
    this.suggestion,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onCompleted,
    required this.onPlateCalc,
    required this.onLongPress,
    required this.showAdvanced,
    this.shouldFocus = false,
  });

  @override
  State<SessionSetRow> createState() => _SessionSetRowState();
}

class _SessionSetRowState extends State<SessionSetRow> {
  late TextEditingController _weightController;
  late TextEditingController _repsController;
  final FocusNode _weightFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.log.peso > 0 ? widget.log.peso.toString() : '');
    _repsController = TextEditingController(text: widget.log.reps > 0 ? widget.log.reps.toString() : '');

    // Auto-focus si es necesario en init
    if (widget.shouldFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _weightFocusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(SessionSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-focus cuando shouldFocus cambia a true
    if (widget.shouldFocus && !oldWidget.shouldFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _weightFocusNode.requestFocus();
        }
      });
    }

    // Sync weight from external source (e.g. copy previous set, plate calculator)
    if (oldWidget.log.peso != widget.log.peso) {
      final controllerValue = double.tryParse(_weightController.text) ?? 0.0;
      if (widget.log.peso != controllerValue && widget.log.peso > 0) {
        _weightController.text = widget.log.peso.toString();
      }
    }

    // Sync reps from external source
    if (oldWidget.log.reps != widget.log.reps) {
      final controllerValue = int.tryParse(_repsController.text) ?? 0;
      if (widget.log.reps != controllerValue && widget.log.reps > 0) {
        _repsController.text = widget.log.reps.toString();
      }
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _weightFocusNode.dispose();
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

  void _applySuggestion() {
    if (widget.suggestion == null) return;
    HapticFeedback.selectionClick();
    _weightController.text = widget.suggestion!.suggestedWeight.toString();
    _repsController.text = widget.suggestion!.suggestedReps.toString();
    widget.onWeightChanged(_weightController.text);
    widget.onRepsChanged(_repsController.text);
  }

  @override
  Widget build(BuildContext context) {
    // Determinar hints para mostrar en campos vacíos
    String? weightHint;
    String? repsHint;

    if (widget.suggestion != null) {
      weightHint = widget.suggestion!.suggestedWeight.toString();
      repsHint = widget.suggestion!.suggestedReps.toString();
    } else if (widget.prevLog != null) {
      weightHint = widget.prevLog!.peso.toString();
      repsHint = widget.prevLog!.reps.toString();
    }

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
                // Previous History / Suggestion Tap Area
                GestureDetector(
                  onTap: () {
                    if (widget.suggestion != null) {
                      _applySuggestion();
                    } else if (widget.prevLog != null) {
                      HapticFeedback.selectionClick();
                      _weightController.text = widget.prevLog!.peso.toString();
                      _repsController.text = widget.prevLog!.reps.toString();
                      widget.onWeightChanged(_weightController.text);
                      widget.onRepsChanged(_repsController.text);
                    }
                  },
                  child: SizedBox(
                    width: 55,
                    child: Center(
                      child: _buildPrevColumn(),
                    ),
                  ),
                ),
                // Weight Input with hint
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        _ProgressionTextField(
                          controller: _weightController,
                          focusNode: _weightFocusNode,
                          onChanged: widget.onWeightChanged,
                          hintText: weightHint,
                          isSuggestion: widget.suggestion != null,
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
                // Reps Input with hint
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _ProgressionTextField(
                      controller: _repsController,
                      onChanged: widget.onRepsChanged,
                      isInteger: true,
                      hintText: repsHint,
                      isSuggestion: widget.suggestion != null,
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
            // Advanced options / suggestion message row
            if (widget.showAdvanced ||
                widget.log.rpe != null ||
                (widget.log.notas != null && widget.log.notas!.isNotEmpty) ||
                (widget.suggestion?.message != null && widget.suggestion!.isImprovement))
               Padding(
                 padding: const EdgeInsets.only(left: 80, right: 40, top: 4),
                 child: Row(
                   children: [
                     if (widget.suggestion?.isImprovement == true)
                       Padding(
                         padding: const EdgeInsets.only(right: 4),
                         child: Tag(
                           text: widget.suggestion!.message ?? 'PROGRESO',
                           color: Colors.green,
                         ),
                       ),
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

  Widget _buildPrevColumn() {
    // Si hay sugerencia de progresión, mostrarla destacada
    if (widget.suggestion != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SUG',
            style: TextStyle(
              color: widget.suggestion!.isImprovement ? Colors.green[400] : Colors.white38,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${widget.suggestion!.suggestedWeight}x${widget.suggestion!.suggestedReps}',
            style: TextStyle(
              color: widget.suggestion!.isImprovement ? Colors.green[400] : Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    // Fallback a historial anterior
    if (widget.prevLog != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Prev',
            style: TextStyle(color: Colors.grey[600], fontSize: 8),
          ),
          Text(
            '${widget.prevLog!.peso}x${widget.prevLog!.reps}',
            style: TextStyle(color: Colors.grey[600], fontSize: 10),
          ),
        ],
      );
    }

    return Text('-', style: TextStyle(color: Colors.grey[700]));
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

/// TextField con soporte para hint de progresión/historial.
class _ProgressionTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onChanged;
  final bool isInteger;
  final String? hintText;
  final bool isSuggestion;

  const _ProgressionTextField({
    required this.controller,
    this.focusNode,
    required this.onChanged,
    this.isInteger = false,
    this.hintText,
    this.isSuggestion = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
      textAlign: TextAlign.center,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        filled: true,
        fillColor: Colors.black,
        // Hint text en gris claro (sugerencia pasada)
        hintText: hintText,
        hintStyle: TextStyle(
          color: isSuggestion ? Colors.green[700]?.withValues(alpha: 0.5) : Colors.white38,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
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
