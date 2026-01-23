import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/serie_log.dart';
import 'numpad_input_modal.dart';

/// ============================================================================
/// FOCUSED SET ROW — Fila de Serie con Estados Visuales Claros
/// ============================================================================
///
/// Widget de fila de serie diseñado para ejecución ultra-rápida.
/// 
/// Estados visuales:
/// - ACTIVA: Verde, grande, destacada (1.5x tamaño)
/// - PASADA: Desaturada, compacta (60% opacidad)
/// - FUTURA: Muy sutil, colapsada (40% opacidad)
///
/// Principios:
/// - Touch targets ≥72dp para inputs
/// - Una sola decisión por momento
/// - Auto-completado cuando KG y REPS tienen valor
/// ============================================================================

/// Colores específicos para la sesión de entrenamiento
class TrainingColors {
  // FOCO: Verde para la serie activa y completadas
  static const activeSet = Color(0xFF4CAF50);
  static const activeBg = Color(0xFF1B3D1B);
  static const completed = Color(0xFF2E7D32);
  static const completedBg = Color(0xFF1A2E1A);

  // TIMER: Naranja para descanso (urgencia sin alarma)
  static const timerActive = Color(0xFFFF9800);
  static const timerBg = Color(0xFF3D2E1A);

  // NEUTROS: Grises para todo lo demás
  static const textPrimary = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFF757575);
  static const textDisabled = Color(0xFF424242);
  static const bgCard = Color(0xFF1C1C1F);
  static const bgInput = Color(0xFF252528);

  // ACCIÓN: Verde para OK
  static const confirmButton = Color(0xFF4CAF50);
}

class FocusedSetRow extends StatefulWidget {
  final int index;
  final SerieLog log;
  final SerieLog? prevLog;
  final bool isActive;
  final bool isFuture;
  final String exerciseName;
  final int totalSets;
  final Function(double) onWeightChanged;
  final Function(int) onRepsChanged;
  final ValueChanged<bool?> onCompleted;
  final VoidCallback? onLongPress;

  const FocusedSetRow({
    super.key,
    required this.index,
    required this.log,
    this.prevLog,
    required this.isActive,
    required this.isFuture,
    required this.exerciseName,
    required this.totalSets,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onCompleted,
    this.onLongPress,
  });

  @override
  State<FocusedSetRow> createState() => _FocusedSetRowState();
}

class _FocusedSetRowState extends State<FocusedSetRow> with SingleTickerProviderStateMixin {
  /// Animación de flash verde al completar
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;
  
  /// Tracking del estado anterior para detectar completado
  bool _wasCompleted = false;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeOut),
    );
    _wasCompleted = widget.log.completed;
  }

  @override
  void didUpdateWidget(FocusedSetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Detectar si se acaba de completar la serie
    if (widget.log.completed && !_wasCompleted) {
      _flashController.forward().then((_) => _flashController.reset());
    }
    _wasCompleted = widget.log.completed;
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = widget.log.completed;

    // Colores y estilos según estado
    final RowStyle style = _getRowStyle(isCompleted, widget.isActive, widget.isFuture);

    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _flashAnimation,
        builder: (context, child) {
          return Stack(
            children: [
              child!,
              // 🆕 Flash verde overlay cuando se completa
              if (_flashAnimation.value > 0)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: TrainingColors.completed.withOpacity(
                        0.3 * (1 - _flashAnimation.value),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: style.opacity,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: style.padding,
            decoration: BoxDecoration(
              color: style.bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: style.borderColor,
                width: widget.isActive ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Número de serie
                _SetNumberBadge(
                  index: widget.index,
                  isCompleted: isCompleted,
                  isActive: widget.isActive,
                  isWarmup: widget.log.isWarmup,
                  isDropset: widget.log.isDropset,
                ),

                const SizedBox(width: 12),

                // Input KG (táctil grande)
                Expanded(
                  child: _TappableValueInput(
                    value: widget.log.peso > 0 ? widget.log.peso : null,
                    label: 'KG',
                    isActive: widget.isActive,
                    isCompleted: isCompleted,
                    textColor: style.textColor,
                    onTap: isCompleted
                        ? null
                        : () => _openWeightInput(context),
                  ),
                ),

                const SizedBox(width: 12),

                // Input REPS (táctil grande)
                Expanded(
                  child: _TappableValueInput(
                    value: widget.log.reps > 0 ? widget.log.reps.toDouble() : null,
                    label: 'REPS',
                    isActive: widget.isActive,
                    isCompleted: isCompleted,
                    textColor: style.textColor,
                    isInteger: true,
                    onTap: isCompleted
                        ? null
                        : () => _openRepsInput(context),
                  ),
                ),

                const SizedBox(width: 12),

                // Checkbox de completado
                _CompletionCheckbox(
                  isCompleted: isCompleted,
                  isActive: widget.isActive,
                  onChanged: widget.onCompleted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  RowStyle _getRowStyle(bool isCompleted, bool isActive, bool isFuture) {
    if (isCompleted) {
      return RowStyle(
        bgColor: TrainingColors.completedBg,
        borderColor: TrainingColors.completed.withValues(alpha: 0.3),
        textColor: TrainingColors.textSecondary,
        opacity: 0.7,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      );
    } else if (isActive) {
      return RowStyle(
        bgColor: TrainingColors.activeBg,
        borderColor: TrainingColors.activeSet,
        textColor: TrainingColors.textPrimary,
        opacity: 1.0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      );
    } else if (isFuture) {
      return RowStyle(
        bgColor: Colors.transparent,
        borderColor: Colors.transparent,
        textColor: TrainingColors.textDisabled,
        opacity: 0.4,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      );
    } else {
      return RowStyle(
        bgColor: Colors.transparent,
        borderColor: Colors.transparent,
        textColor: TrainingColors.textSecondary,
        opacity: 0.6,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      );
    }
  }

  void _openWeightInput(BuildContext context) async {
    final result = await NumpadInputModal.show(
      context: context,
      exerciseName: widget.exerciseName,
      setNumber: widget.index + 1,
      totalSets: widget.totalSets,
      fieldLabel: 'KG',
      previousValue: widget.prevLog?.peso.toDouble(),
      currentValue: widget.log.peso > 0 ? widget.log.peso.toDouble() : null,
      isInteger: false,
    );

    if (result != null) {
      widget.onWeightChanged(result);
      // 🆕 Auto-completar si ambos campos tienen valor
      _checkAutoComplete(result, widget.log.reps.toDouble());
    }
  }

  void _openRepsInput(BuildContext context) async {
    final result = await NumpadInputModal.show(
      context: context,
      exerciseName: widget.exerciseName,
      setNumber: widget.index + 1,
      totalSets: widget.totalSets,
      fieldLabel: 'REPS',
      previousValue: widget.prevLog?.reps.toDouble(),
      currentValue: widget.log.reps > 0 ? widget.log.reps.toDouble() : null,
      isInteger: true,
    );

    if (result != null) {
      widget.onRepsChanged(result.toInt());
      // 🆕 Auto-completar si ambos campos tienen valor
      _checkAutoComplete(widget.log.peso.toDouble(), result);
    }
  }

  /// 🆕 Verifica si se debe auto-completar la serie
  void _checkAutoComplete(double weight, double reps) {
    // Si ambos valores son > 0 y la serie no está completada
    if (weight > 0 && reps > 0 && !widget.log.completed) {
      // Dar un pequeño delay para que el estado se actualice
      Future.delayed(const Duration(milliseconds: 100), () {
        widget.onCompleted(true);
      });
    }
  }
}

/// Estilo de fila según estado
class RowStyle {
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final double opacity;
  final EdgeInsets padding;

  const RowStyle({
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.opacity,
    required this.padding,
  });
}

/// Badge del número de serie
class _SetNumberBadge extends StatelessWidget {
  final int index;
  final bool isCompleted;
  final bool isActive;
  final bool isWarmup;
  final bool isDropset;

  const _SetNumberBadge({
    required this.index,
    required this.isCompleted,
    required this.isActive,
    this.isWarmup = false,
    this.isDropset = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor = Colors.white;
    String label = '${index + 1}';

    if (isWarmup) {
      bgColor = Colors.blue[700]!;
      label = 'W';
    } else if (isDropset) {
      bgColor = Colors.purple[700]!;
      label = 'D';
    } else if (isCompleted) {
      bgColor = TrainingColors.completed;
    } else if (isActive) {
      bgColor = TrainingColors.activeSet;
    } else {
      bgColor = TrainingColors.bgInput;
      textColor = TrainingColors.textDisabled;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isCompleted && !isWarmup && !isDropset
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
      ),
    );
  }
}

/// Input táctil grande para KG/REPS
class _TappableValueInput extends StatelessWidget {
  final double? value;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final Color textColor;
  final bool isInteger;
  final VoidCallback? onTap;

  const _TappableValueInput({
    this.value,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.textColor,
    this.isInteger = false,
    this.onTap,
  });

  String get _displayValue {
    if (value == null || value == 0) return '—';
    if (isInteger) return value!.toInt().toString();
    // Quitar .0 si es entero
    if (value == value!.truncateToDouble()) {
      return value!.toInt().toString();
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Touch target mínimo 56dp (activo 64dp)
    final height = isActive ? 64.0 : 48.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isActive ? TrainingColors.bgInput : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(
                  color: TrainingColors.activeSet.withOpacity(0.5),
                  width: 1.5,
                )
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _displayValue,
                style: GoogleFonts.montserrat(
                  fontSize: isActive ? 24 : 18,
                  fontWeight: FontWeight.w800,
                  color: value == null || value == 0
                      ? TrainingColors.textDisabled
                      : textColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: isActive ? 12 : 10,
                  fontWeight: FontWeight.w600,
                  color: TrainingColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Checkbox de completado con zona táctil grande (56dp)
class _CompletionCheckbox extends StatelessWidget {
  final bool isCompleted;
  final bool isActive;
  final ValueChanged<bool?> onChanged;

  const _CompletionCheckbox({
    required this.isCompleted,
    required this.isActive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onChanged(!isCompleted);
          },
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCompleted
                    ? TrainingColors.completed
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCompleted
                      ? TrainingColors.completed
                      : isActive
                          ? TrainingColors.activeSet
                          : TrainingColors.textDisabled,
                  width: 2.5,
                ),
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 24,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
