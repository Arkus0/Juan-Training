import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/serie_log.dart';
import '../../models/progression_type.dart';
import '../../screens/plate_calculator_dialog.dart';
import '../../utils/performance_utils.dart';
import 'log_input.dart';

// ============================================================================
// PRE-COMPUTED CONST STYLES (Avoid GoogleFonts in build methods)
// ============================================================================

class _SetRowStyles {
  static final setNumberText = GoogleFonts.montserrat(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: Colors.white,
  );

  static final prevLabel = GoogleFonts.montserrat(
    fontSize: 7,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static final prevValue = GoogleFonts.montserrat(
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );

  static final prevReps = GoogleFonts.montserrat(
    fontSize: 9,
    fontWeight: FontWeight.w500,
  );

  static final sugLabel = GoogleFonts.montserrat(
    fontSize: 7,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
  );

  static final sugValue = GoogleFonts.montserrat(
    fontSize: 10,
    fontWeight: FontWeight.w700,
  );

  static final sugReps = GoogleFonts.montserrat(
    fontSize: 9,
    fontWeight: FontWeight.w600,
  );

  static final tagText = GoogleFonts.montserrat(
    fontSize: 8,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  static final noteText = GoogleFonts.montserrat(
    fontSize: 9,
    fontStyle: FontStyle.italic,
  );
}

/// Widget de fila para logging de una serie individual
///
/// Optimizaciones aplicadas:
/// - Estilos pre-computados (sin GoogleFonts en build)
/// - Animación condicional según PerformanceMode
/// - RepaintBoundary para inputs
/// - Widgets const donde posible
/// - Minimizado número de setState
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
  final bool shouldFocus; // Auto-focus cuando timer termina
  final bool shouldFocusReps; // Focus específico en reps

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
    this.shouldFocusReps = false,
  });

  @override
  State<SessionSetRow> createState() => _SessionSetRowState();
}

class _SessionSetRowState extends State<SessionSetRow> {
  final FocusNode _weightFocusNode = FocusNode();
  final FocusNode _repsFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Auto-focus inicial si es necesario
    if (widget.shouldFocus) {
      afterFrame(() {
        if (mounted) _weightFocusNode.requestFocus();
      });
    } else if (widget.shouldFocusReps) {
      afterFrame(() {
        if (mounted) _repsFocusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(SessionSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-focus cuando shouldFocus cambia a true
    if (widget.shouldFocus && !oldWidget.shouldFocus) {
      afterFrame(() {
        if (mounted) {
          _weightFocusNode.requestFocus();
          _triggerFocusVibration();
        }
      });
    }

    // Auto-focus en reps
    if (widget.shouldFocusReps && !oldWidget.shouldFocusReps) {
      afterFrame(() {
        if (mounted) {
          _repsFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _weightFocusNode.dispose();
    _repsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _triggerFocusVibration() async {
    if (PerformanceMode.instance.reduceVibrations) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

  }

  void _openPlateCalc() {
    final currentVal = double.tryParse(widget.log.peso.toString()) ?? 0.0;
    showDialog(
      context: context,
      builder: (_) => PlateCalculatorDialog(
        currentWeight: currentVal,
        onWeightSelected: (val) {
          widget.onPlateCalc(val);
        },
      ),
    );
  }

  void _applySuggestionOrPrev() {
    HapticFeedback.selectionClick();
    if (widget.suggestion != null) {
      widget.onWeightChanged(widget.suggestion!.suggestedWeight.toString());
      widget.onRepsChanged(widget.suggestion!.suggestedReps.toString());
    } else if (widget.prevLog != null) {
      widget.onWeightChanged(widget.prevLog!.peso.toString());
      widget.onRepsChanged(widget.prevLog!.reps.toString());
    }
  }

  void _handleComplete(bool? value) {
    if (value == true && !PerformanceMode.instance.reduceVibrations) {
      HapticFeedback.mediumImpact();
    }
    widget.onCompleted(value);
  }

  @override
  Widget build(BuildContext context) {
    // Determinar ghost values
    String? weightGhost;
    String? repsGhost;
    bool isSuggestion = false;

    if (widget.suggestion != null) {
      weightGhost = widget.suggestion!.suggestedWeight.toString();
      repsGhost = widget.suggestion!.suggestedReps.toString();
      isSuggestion = true;
    } else if (widget.prevLog != null) {
      weightGhost = widget.prevLog!.peso.toString();
      repsGhost = widget.prevLog!.reps.toString();
    }

    // Colores según estado
    final isCompleted = widget.log.completed;
    final rowColor = isCompleted
        ? Colors.red[900]!.withValues(alpha: 0.15)
        : Colors.transparent;

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: rowColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Número de serie
                _SetNumber(
                  index: widget.index,
                  isCompleted: isCompleted,
                  isWarmup: widget.log.isWarmup,
                  isDropset: widget.log.isDropset,
                ),

                const SizedBox(width: 4),

                // Columna de valor previo/sugerencia (tocable)
                _PrevValueColumn(
                  suggestion: widget.suggestion,
                  prevLog: widget.prevLog,
                  onTap: _applySuggestionOrPrev,
                ),

                const SizedBox(width: 8),

                // Input de peso (KG) - con RepaintBoundary
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      LogInput(
                        value: widget.log.peso > 0
                            ? widget.log.peso.toString()
                            : '',
                        ghostValue: weightGhost,
                        onChanged: widget.onWeightChanged,
                        onGhostTap: () => widget.onWeightChanged(weightGhost!),
                        shouldFocus: widget.shouldFocus,
                        focusNode: _weightFocusNode,
                        isInteger: false,
                        swipeIncrement: 2.5, // 2.5kg por swipe
                        isSuggestion: isSuggestion,
                        textInputAction: TextInputAction.next,
                        onEditingComplete: () {
                          _repsFocusNode.requestFocus();
                        },
                      ),
                      // Botón calculadora de discos
                      Positioned(
                        right: 2,
                        child: GestureDetector(
                          onTap: _openPlateCalc,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.calculate_outlined,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Input de reps
                Expanded(
                  child: LogInput(
                    value:
                        widget.log.reps > 0 ? widget.log.reps.toString() : '',
                    ghostValue: repsGhost,
                    onChanged: widget.onRepsChanged,
                    onGhostTap: () => widget.onRepsChanged(repsGhost!),
                    shouldFocus: widget.shouldFocusReps,
                    focusNode: _repsFocusNode,
                    isInteger: true,
                    swipeIncrement: 1.0, // 1 rep por swipe
                    isSuggestion: isSuggestion,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: () {
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),

                const SizedBox(width: 8),

                // Checkbox de completado
                _CompletedCheckbox(
                  isCompleted: isCompleted,
                  onChanged: _handleComplete,
                ),
              ],
            ),

            // Fila de tags (RPE, Failure, notas, sugerencia)
            _TagsRow(
              log: widget.log,
              suggestion: widget.suggestion,
              showAdvanced: widget.showAdvanced,
            ),
          ],
        ),
      ),
    );
  }
}

/// Número de serie con indicadores visuales
class _SetNumber extends StatelessWidget {
  final int index;
  final bool isCompleted;
  final bool isWarmup;
  final bool isDropset;

  const _SetNumber({
    required this.index,
    required this.isCompleted,
    required this.isWarmup,
    required this.isDropset,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor = Colors.grey[800]!;
    String label = '${index + 1}';

    if (isWarmup) {
      bgColor = Colors.blue[700]!;
      label = 'W';
    } else if (isDropset) {
      bgColor = Colors.purple[700]!;
      label = 'D';
    } else if (isCompleted) {
      bgColor = Colors.redAccent[700]!;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        // Shadows solo si no está en modo performance
        boxShadow: isCompleted && PerformanceMode.instance.showShadows
            ? [
                BoxShadow(
                  color: Colors.red[900]!.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(label, style: _SetRowStyles.setNumberText),
      ),
    );
  }
}

/// Columna de valor previo/sugerencia (tocable para copiar)
class _PrevValueColumn extends StatelessWidget {
  final ProgressionSuggestion? suggestion;
  final SerieLog? prevLog;
  final VoidCallback onTap;

  const _PrevValueColumn({
    this.suggestion,
    this.prevLog,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestion != null) {
      final isImprovement = suggestion!.isImprovement;
      return Tooltip(
        message: 'Copiar sugerencia',
        child: Material(
          color: isImprovement
              ? Colors.green[900]?.withValues(alpha: 0.3)
              : Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(
              color: isImprovement
                  ? Colors.green[700]!.withValues(alpha: 0.5)
                  : Colors.grey[700]!,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SUG',
                    style: _SetRowStyles.sugLabel.copyWith(
                      color: isImprovement
                          ? Colors.green[400]
                          : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${suggestion!.suggestedWeight}',
                    style: _SetRowStyles.sugValue.copyWith(
                      color: isImprovement
                          ? Colors.green[300]
                          : Colors.grey[300],
                    ),
                  ),
                  Text(
                    'x${suggestion!.suggestedReps}',
                    style: _SetRowStyles.sugReps.copyWith(
                      color: isImprovement
                          ? Colors.green[400]
                          : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (prevLog != null) {
      return Tooltip(
        message: 'Copiar anterior',
        child: Material(
          color: Colors.grey[850],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: Colors.grey[800]!),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PREV',
                    style: _SetRowStyles.prevLabel.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${prevLog!.peso}',
                    style: _SetRowStyles.prevValue.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                  Text(
                    'x${prevLog!.reps}',
                    style: _SetRowStyles.prevReps.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 52,
      child: Center(
        child: Text(
          '-',
          style: TextStyle(color: Colors.grey[700]),
        ),
      ),
    );
  }
}

/// Checkbox de completado con estilo mejorado
class _CompletedCheckbox extends StatelessWidget {
  final bool isCompleted;
  final Function(bool?) onChanged;

  const _CompletedCheckbox({
    required this.isCompleted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Transform.scale(
        scale: 1.2,
        child: Checkbox(
          value: isCompleted,
          activeColor: Colors.redAccent[700],
          checkColor: Colors.white,
          onChanged: onChanged,
          side: BorderSide(
            color: isCompleted ? Colors.redAccent[700]! : Colors.grey[600]!,
            width: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Fila de tags (RPE, Failure, Dropset, notas, progreso)
class _TagsRow extends StatelessWidget {
  final SerieLog log;
  final ProgressionSuggestion? suggestion;
  final bool showAdvanced;

  const _TagsRow({
    required this.log,
    this.suggestion,
    required this.showAdvanced,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = showAdvanced ||
        log.rpe != null ||
        log.isFailure ||
        log.isDropset ||
        (log.notas != null && log.notas!.isNotEmpty) ||
        (suggestion?.message != null && suggestion!.isImprovement);

    if (!hasContent) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 36, right: 40, top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          if (suggestion?.isImprovement == true && suggestion?.message != null)
            _Tag(
              text: suggestion!.message!,
              color: Colors.green,
              icon: Icons.trending_up,
            ),
          if (log.rpe != null)
            _Tag(
              text: 'RPE ${log.rpe}',
              color: Colors.orange,
            ),
          if (log.isFailure)
            const _Tag(
              text: 'FALLO',
              color: Colors.red,
              icon: Icons.warning_amber_rounded,
            ),
          if (log.isDropset)
            const _Tag(
              text: 'DROP',
              color: Colors.purple,
            ),
          if (log.isWarmup)
            const _Tag(
              text: 'WARM',
              color: Colors.blue,
            ),
          if (log.notas != null && log.notas!.isNotEmpty)
            Expanded(
              child: Text(
                log.notas!,
                style: _SetRowStyles.noteText.copyWith(
                  color: Colors.grey[500],
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
        ],
      ),
    );
  }
}

/// Tag pequeño para indicadores de serie
class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const _Tag({
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: _SetRowStyles.tagText.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Tag widget exportado para uso en otros lugares (backward compatibility)
class Tag extends StatelessWidget {
  final String text;
  final Color color;

  const Tag({
    super.key,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _Tag(text: text, color: color);
  }
}
