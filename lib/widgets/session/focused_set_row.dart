import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/serie_log.dart';
import '../../screens/plate_calculator_dialog.dart';
import '../../utils/design_system.dart';
import 'numpad_input_modal.dart';

typedef NullableBoolChanged = void Function({required bool? value});

/// ============================================================================
/// FOCUSED SET ROW — Intensidad Roja (Underground Gym)
/// ============================================================================
///
/// Widget de fila de serie con jerarquía visual clara:
///
/// Estados visuales:
/// - ACTIVA: Rojo profundo, prominente, touch targets grandes
/// - COMPLETADA: Verde brillante, check claro
/// - PASADA (sin completar): Muy sutil, gris
/// - FUTURA: Casi invisible
///
/// Vibe: Gym underground con luces rojas
/// ============================================================================

/// Colores de sesión — Rojo sangre + Verde check
class TrainingColors {
  // FOCO: Rojo profundo para serie activa (intensidad)
  static const activeSet = AppColors.bloodRed;
  static const activeBg = Color(0xFF1A1212); // Sutil tinte rojo

  // COMPLETADO: Verde brillante (éxito)
  static const completed = AppColors.completedGreen;
  static const completedBg = Color(0xFF121A12); // Sutil tinte verde

  // NEUTROS: Grises para todo lo demás
  static const textPrimary = AppColors.textPrimary;
  static const textSecondary = AppColors.textSecondary;
  static const textDisabled = AppColors.textDisabled;
  static const bgCard = AppColors.bgElevated;
  static const bgInput = AppColors.bgInteractive;

  // ACCIÓN: Rojo profundo para confirmar
  static const confirmButton = AppColors.bloodRed;
}

// ⚡ OPTIMIZACIÓN: Estilos pre-computados para evitar GoogleFonts en build
class _SetRowStyles {
  static final badgeLabel = GoogleFonts.montserrat(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: AppColors.textOnAccent,
  );

  static final badgeLabelDisabled = GoogleFonts.montserrat(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: TrainingColors.textDisabled,
  );

  // Serie activa: números grandes pero no exagerados
  static final valueActiveText = GoogleFonts.montserrat(
    fontSize: 24,
    fontWeight: FontWeight.w800,
  );

  static final valueNormalText = GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  // Labels muy sutiles para no competir con datos
  static final labelActiveText = GoogleFonts.montserrat(
    fontSize: 9,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );

  static final labelNormalText = GoogleFonts.montserrat(
    fontSize: 8,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );
}

// ⚡ OPTIMIZACIÓN: RowStyle constantes - JERARQUÍA VISUAL CLARA
// 🆕 Padding aumentado para mejor usabilidad con dedos sudados/fatiga
class _RowStyles {
  // COMPLETADA: Verde apagado, sutil pero satisfactoria
  static const completed = RowStyle(
    bgColor: TrainingColors.completedBg,
    borderColor: Color(0x402E8B57), // Verde @ 0.25 alpha
    textColor: TrainingColors.textSecondary,
    opacity: 0.6, // Desaturada
    padding:
        EdgeInsets.symmetric(vertical: 10, horizontal: 12), // 🆕 Más padding
  );

  // ACTIVA: Rojo prominente, LA ÚNICA que destaca
  static const active = RowStyle(
    bgColor: TrainingColors.activeBg,
    borderColor: TrainingColors.activeSet,
    textColor: TrainingColors.textPrimary,
    opacity: 1.0,
    padding:
        EdgeInsets.symmetric(vertical: 14, horizontal: 14), // 🆕 Más padding
  );

  // FUTURA: Casi invisible
  static const future = RowStyle(
    bgColor: Colors.transparent,
    borderColor: Colors.transparent,
    textColor: TrainingColors.textDisabled,
    opacity: 0.3, // Muy sutil
    padding:
        EdgeInsets.symmetric(vertical: 6, horizontal: 12), // 🆕 Más padding
  );

  // PASADA (sin completar): Sutil
  static const past = RowStyle(
    bgColor: Colors.transparent,
    borderColor: Colors.transparent,
    textColor: TrainingColors.textSecondary,
    opacity: 0.5,
    padding:
        EdgeInsets.symmetric(vertical: 8, horizontal: 12), // 🆕 Más padding
  );
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
  final NullableBoolChanged onCompleted;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete; // 🆕 Callback para eliminar serie
  final bool canDelete; // 🆕 Si se puede eliminar (>1 serie)

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
    this.onDelete,
    this.canDelete = false,
  });

  @override
  State<FocusedSetRow> createState() => _FocusedSetRowState();
}

class _FocusedSetRowState extends State<FocusedSetRow>
    with SingleTickerProviderStateMixin {
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
    final style = _getRowStyle(isCompleted, widget.isActive, widget.isFuture);

    // 🆕 Contenido base de la fila
    final Widget rowContent = GestureDetector(
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
                      color: TrainingColors.completed.withValues(
                        alpha: 0.3 * (1 - _flashAnimation.value),
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
            margin: const EdgeInsets.symmetric(
                vertical: 4,), // 🆕 Más separación entre series
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
                // 🎯 FIX #3: Muestra peso incluso si es 0 o negativo (máquinas asistidas)
                Expanded(
                  child: _TappableValueInput(
                    value: widget.log.peso,
                    label: 'KG',
                    isActive: widget.isActive,
                    isCompleted: isCompleted,
                    textColor: style.textColor,
                    allowZeroAndNegative: true, // 🎯 FIX #3
                    onTap: isCompleted ? null : () => _openWeightInput(context),
                  ),
                ),

                const SizedBox(width: 12),

                // Input REPS (táctil grande)
                // 🎯 FIX #3: Muestra reps incluso si es 0 (isométricos, holds)
                Expanded(
                  child: _TappableValueInput(
                    value: widget.log.reps.toDouble(),
                    label: 'REPS',
                    isActive: widget.isActive,
                    isCompleted: isCompleted,
                    textColor: style.textColor,
                    isInteger: true,
                    allowZeroAndNegative:
                        true, // 🎯 FIX #3: permite 0 para isométricos
                    onTap: isCompleted ? null : () => _openRepsInput(context),
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

    // 🆕 SWIPE-TO-DELETE: Solo si se puede eliminar (más de 1 serie)
    if (widget.canDelete && widget.onDelete != null) {
      return Dismissible(
        key: Key('dismissible_set_${widget.log.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) async {
          // Confirmación rápida con haptic
          HapticFeedback.mediumImpact();
          return true; // Sin diálogo - acción inmediata para gimnasio
        },
        onDismissed: (direction) {
          widget.onDelete!();
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.bloodRed.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'ELIMINAR',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.delete_outline, color: Colors.white, size: 20),
            ],
          ),
        ),
        child: rowContent,
      );
    }

    return rowContent;
  }

  // ⚡ OPTIMIZACIÓN: Usar constantes pre-definidas en lugar de crear nuevos objetos
  RowStyle _getRowStyle(bool isCompleted, bool isActive, bool isFuture) {
    if (isCompleted) return _RowStyles.completed;
    if (isActive) return _RowStyles.active;
    if (isFuture) return _RowStyles.future;
    return _RowStyles.past;
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
      onOpenPlateCalc: (currentWeight, onWeightUpdate, onApplyAndClose) {
        _showPlateCalculator(context, currentWeight, onApplyAndClose);
      },
    );

    if (result != null) {
      widget.onWeightChanged(result);
      // 🆕 Auto-completar si ambos campos tienen valor
      _checkAutoComplete(result, widget.log.reps.toDouble());
    }
  }

  /// 🆕 Muestra calculadora de placas - "APLICAR" cierra todo y aplica directamente
  void _showPlateCalculator(BuildContext context, double currentWeight,
      Function(double) onApplyAndClose,) {
    showDialog(
      context: context,
      builder: (dialogContext) => PlateCalculatorDialog(
        currentWeight: currentWeight,
        onWeightSelected: (weight) {
          Navigator.of(dialogContext).pop(); // Cerrar dialog de placas
          // 🎯 FIX: Aplicar directamente y cerrar numpad (el callback hace pop del numpad)
          onApplyAndClose(weight);
        },
      ),
    );
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
      // Capturar ID del set actual para verificar antes de completar
      final currentSetId = widget.log.id;
      // Dar un pequeño delay para que el estado se actualice
      Future.delayed(const Duration(milliseconds: 100), () {
        // Solo completar si el widget sigue montado y es el mismo set
        if (mounted && widget.log.id == currentSetId) {
          widget.onCompleted(value: true);
        }
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

/// Badge del número de serie - Jerarquía visual clara
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
    var textColor = AppColors.textOnAccent;
    var label = '${index + 1}';

    if (isWarmup) {
      bgColor = AppColors.info;
      label = 'W';
    } else if (isDropset) {
      bgColor = Colors.purple[700]!;
      label = 'D';
    } else if (isCompleted) {
      bgColor = TrainingColors.completed; // Verde apagado
    } else if (isActive) {
      bgColor = TrainingColors.activeSet; // Cyan
    } else {
      bgColor = TrainingColors.bgInput;
      textColor = TrainingColors.textDisabled;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isCompleted && !isWarmup && !isDropset
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : Text(
                label,
                // ⚡ OPTIMIZACIÓN: Usar estilo pre-computado
                style: textColor == Colors.white
                    ? _SetRowStyles.badgeLabel
                    : _SetRowStyles.badgeLabelDisabled,
              ),
      ),
    );
  }
}

/// Input táctil grande para KG/REPS - TOUCH TARGETS GRANDES
class _TappableValueInput extends StatelessWidget {
  final double? value;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final Color textColor;
  final bool isInteger;
  final VoidCallback? onTap;
  final bool allowZeroAndNegative; // 🎯 FIX #3

  const _TappableValueInput({
    this.value,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.textColor,
    this.isInteger = false,
    this.onTap,
    this.allowZeroAndNegative = false, // 🎯 FIX #3
  });

  String get _displayValue {
    if (value == null) return '—';
    // 🎯 FIX #3: Solo mostrar "—" si no permite cero/negativo Y el valor es 0
    if (!allowZeroAndNegative && value == 0) return '—';
    if (isInteger) return value!.toInt().toString();
    // Quitar .0 si es entero
    if (value == value!.truncateToDouble()) {
      return value!.toInt().toString();
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Touch target mínimo 64dp (activo 72dp) para dedos sudados
    final height = isActive ? 72.0 : 56.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isActive ? TrainingColors.bgInput : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          // Borde sutil cyan, NO rojo ni agresivo
          border: isActive
              ? Border.all(
                  color: TrainingColors.activeSet.withValues(alpha: 0.4),
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
                // ⚡ OPTIMIZACIÓN: Estilos pre-computados - valores MUY prominentes
                style: (isActive
                        ? _SetRowStyles.valueActiveText
                        : _SetRowStyles.valueNormalText)
                    .copyWith(
                  color: value == null || value == 0
                      ? TrainingColors.textDisabled
                      : textColor,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                // Labels muy sutiles para no competir con datos
                style: isActive
                    ? _SetRowStyles.labelActiveText
                    : _SetRowStyles.labelNormalText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Checkbox de completado con zona táctil grande (64dp)
class _CompletionCheckbox extends StatelessWidget {
  final bool isCompleted;
  final bool isActive;
  final NullableBoolChanged onChanged;

  const _CompletionCheckbox({
    required this.isCompleted,
    required this.isActive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onChanged(value: !isCompleted);
          },
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted
                    ? TrainingColors.completed // Verde apagado
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCompleted
                      ? TrainingColors.completed
                      : isActive
                          ? TrainingColors.activeSet // Cyan
                          : TrainingColors.textDisabled,
                  width: 2.5,
                ),
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      color: AppColors.textOnAccent,
                      size: 28,
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
