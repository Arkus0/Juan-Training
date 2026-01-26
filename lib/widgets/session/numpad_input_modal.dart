import '../../utils/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================================
/// NUMPAD INPUT MODAL — Intensidad Roja (Underground Gym)
/// ============================================================================
///
/// Modal fullscreen para entrada de valores KG/REPS.
/// Diseñado para uso en gimnasio: botones GIGANTES, contexto claro.
///
/// PRINCIPIOS:
/// - Touch targets ≥72dp (dedos sudados, guantes)
/// - Contexto siempre visible (ejercicio, serie)
/// - Valor anterior como referencia
/// - Auto-cierre tras confirmación
/// - Botón CONFIRMAR rojo Ferrari, gigante, único CTA
/// - Borde rojo en inputs activos
/// ============================================================================

/// Colores específicos para el modal — Aggressive Red
class _ModalColors {
  static const activeAccent = AppColors.bloodRed;  // #C41E3A
  static const activeSet = AppColors.bloodRed;     // Alias for compatibility
  static const textPrimary = AppColors.textPrimary; // #EAEAEA
  static const textSecondary = AppColors.textSecondary;
  static const textDisabled = AppColors.textDisabled;
  static const bgCard = AppColors.bgElevated;       // #1C1C1C
  static const bgInput = AppColors.bgInteractive;   // #252525
  static const confirmButton = AppColors.bloodRed;  // #C41E3A
  static const borderFocus = AppColors.bloodRed;    // Para inputs en foco
}

class NumpadInputModal extends StatefulWidget {
  final String exerciseName;
  final int setNumber;
  final int totalSets;
  final String fieldLabel; // "KG" o "REPS"
  final double? previousValue;
  final double? currentValue;
  final bool isInteger;
  final ValueChanged<double> onConfirm;
  /// Callback para plate calculator
  /// Parámetros: (pesoActual, callbackParaActualizar, callbackParaAplicarYCerrar)
  final Function(double, Function(double), Function(double))? onOpenPlateCalc;

  const NumpadInputModal({
    super.key,
    required this.exerciseName,
    required this.setNumber,
    required this.totalSets,
    required this.fieldLabel,
    this.previousValue,
    this.currentValue,
    required this.isInteger,
    required this.onConfirm,
    this.onOpenPlateCalc,
  });

  /// Método estático para mostrar el modal fácilmente
  static Future<double?> show({
    required BuildContext context,
    required String exerciseName,
    required int setNumber,
    required int totalSets,
    required String fieldLabel,
    double? previousValue,
    double? currentValue,
    bool isInteger = false,
    Function(double, Function(double), Function(double))? onOpenPlateCalc,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: false,
      builder: (ctx) => NumpadInputModal(
        exerciseName: exerciseName,
        setNumber: setNumber,
        totalSets: totalSets,
        fieldLabel: fieldLabel,
        previousValue: previousValue,
        currentValue: currentValue,
        isInteger: isInteger,
        onConfirm: (val) => Navigator.of(ctx).pop(val),
        onOpenPlateCalc: onOpenPlateCalc,
      ),
    );
  }

  @override
  State<NumpadInputModal> createState() => _NumpadInputModalState();
}

class _NumpadInputModalState extends State<NumpadInputModal> {
  late String _displayValue;
  bool _showLimitWarning = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // LÍMITES DUROS — Prevención de valores absurdos
  // ═══════════════════════════════════════════════════════════════════════════
  // Estos límites previenen errores de usuario (ej: 2000 kg por accidente)
  // y protegen la integridad de los datos.
  // 🎯 FIX #3: Permitir pesos negativos para máquinas asistidas (ej: -50kg)
  // ═══════════════════════════════════════════════════════════════════════════
  static const double _maxWeight = 999.9; // kg - Eddie Hall deadlifted 500kg
  static const double _minWeight = -200.0; // kg - máquinas asistidas
  static const int _maxReps = 999; // reps - más que suficiente para cualquier set

  @override
  void initState() {
    super.initState();
    // 🎯 FIX #3: Inicializar con valor actual incluyendo 0 y negativos
    if (widget.currentValue != null && widget.currentValue != 0) {
      _displayValue = widget.isInteger
          ? widget.currentValue!.toInt().toString()
          : _formatNumber(widget.currentValue!);
    } else {
      _displayValue = '';
    }
  }

  String _formatNumber(double value) {
    // Quitar .0 si es entero
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  /// Verifica si el valor está dentro de los límites permitidos
  /// 🎯 FIX #3: Ahora soporta pesos negativos para KG (máquinas asistidas)
  bool _isWithinLimits(String valueStr) {
    final value = double.tryParse(valueStr);
    if (value == null) return true; // Strings inválidos se manejan en _canConfirm

    if (widget.isInteger) {
      // REPS: 0 a _maxReps (no negativos)
      return value >= 0 && value <= _maxReps;
    } else {
      // KG: _minWeight a _maxWeight (permite negativos para asistidas)
      return value >= _minWeight && value <= _maxWeight;
    }
  }

  void _onDigit(String digit) {
    setState(() {
      // Limitar longitud
      if (_displayValue.length >= 6) return;

      // Validar punto decimal
      if (digit == '.') {
        if (_displayValue.contains('.')) return;
        if (widget.isInteger) return;
        if (_displayValue.isEmpty) {
          _displayValue = '0.';
          HapticFeedback.selectionClick();
          return;
        }
      }

      // Construir nuevo valor y validar límites
      final newValue = _displayValue + digit;
      if (!_isWithinLimits(newValue)) {
        // Valor excede límite - feedback de error
        HapticFeedback.heavyImpact();
        _showLimitWarning = true;
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showLimitWarning = false);
        });
        return;
      }

      HapticFeedback.selectionClick();
      _displayValue = newValue;
      _showLimitWarning = false;
    });
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();
    if (_displayValue.isNotEmpty) {
      setState(() {
        _displayValue = _displayValue.substring(0, _displayValue.length - 1);
      });
    }
  }

  void _onClear() {
    HapticFeedback.lightImpact();
    setState(() {
      _displayValue = '';
    });
  }

  /// 🎯 FIX #3: Cambia el signo del valor (positivo ↔ negativo)
  /// Solo disponible para KG, no para REPS
  void _onToggleSign() {
    if (widget.isInteger) return; // REPS no puede ser negativo

    HapticFeedback.selectionClick();
    setState(() {
      if (_displayValue.isEmpty) {
        _displayValue = '-';
      } else if (_displayValue == '-') {
        _displayValue = '';
      } else if (_displayValue.startsWith('-')) {
        _displayValue = _displayValue.substring(1);
      } else {
        _displayValue = '-$_displayValue';
      }
    });
  }

  void _onConfirm() {
    final value = double.tryParse(_displayValue);
    // 🎯 FIX #3: Permitir 0 y negativos para KG, solo >= 0 para REPS
    final isValid = value != null && (widget.isInteger ? value >= 0 : true);
    if (isValid) {
      HapticFeedback.mediumImpact();
      widget.onConfirm(value!);
    }
  }

  void _onUsePrevious() {
    // 🎯 FIX #3: Permitir usar valores anteriores incluyendo 0 y negativos
    if (widget.previousValue != null) {
      HapticFeedback.selectionClick();
      setState(() {
        _displayValue = widget.isInteger
            ? widget.previousValue!.toInt().toString()
            : _formatNumber(widget.previousValue!);
      });
    }
  }

  void _openPlateCalculator() {
    if (widget.onOpenPlateCalc == null) return;
    HapticFeedback.selectionClick();
    final currentWeight = double.tryParse(_displayValue) ?? 0.0;
    widget.onOpenPlateCalc!(
      currentWeight,
      // Callback para solo actualizar el display (sin cerrar)
      (newWeight) {
        setState(() {
          _displayValue = _formatNumber(newWeight);
        });
      },
      // 🆕 Callback para aplicar directamente y cerrar el numpad
      (newWeight) {
        // Aplicar y cerrar
        widget.onConfirm(newWeight);
      },
    );
  }

  bool get _canConfirm {
    final value = double.tryParse(_displayValue);
    if (value == null) return false;
    // 🎯 FIX #3: Permitir 0 y negativos para KG, solo >= 0 para REPS
    // Para KG: cualquier valor dentro de límites está permitido
    // Para REPS: solo >= 0 (no tiene sentido reps negativas)
    if (widget.isInteger) {
      return value >= 0;
    }
    return true; // KG permite cualquier valor (incluyendo 0 y negativos)
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      height: screenHeight * 0.80, // Expandido al 80% para botones más grandes
      decoration: const BoxDecoration(
        color: _ModalColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle bar para drag (visual)
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header con contexto - COMPACTO
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: Column(
                children: [
                  // Nombre del ejercicio - MUY sutil
                  Text(
                    widget.exerciseName.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _ModalColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Serie actual - Rojo para foco
                  Text(
                    'SERIE ${widget.setNumber} DE ${widget.totalSets}',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _ModalColors.activeSet,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // 🎯 FIX #3: Valor anterior (si existe) - ahora muestra 0 y negativos
                  if (widget.previousValue != null) ...[
                    const SizedBox(height: 8),
                    Tooltip(
                      message: 'Toca para usar el valor de tu sesión anterior',
                      child: GestureDetector(
                        onTap: _onUsePrevious,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _ModalColors.bgInput,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              // Borde más visible si el input está vacío
                              color: _displayValue.isEmpty
                                  ? _ModalColors.activeSet.withValues(alpha:0.5)
                                  : AppColors.border,
                              width: _displayValue.isEmpty ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history,
                                size: 14,
                                color: _displayValue.isEmpty
                                    ? _ModalColors.activeSet
                                    : _ModalColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Anterior: ${_formatNumber(widget.previousValue!)} ${widget.fieldLabel}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _displayValue.isEmpty
                                      ? _ModalColors.textPrimary
                                      : _ModalColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _ModalColors.activeSet.withValues(alpha:0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'USAR',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: _ModalColors.activeSet,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Botón plate calculator (solo para KG)
                  if (widget.fieldLabel == 'KG' && widget.onOpenPlateCalc != null) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => _openPlateCalculator(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _ModalColors.bgInput,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.fitness_center,
                              size: 14,
                              color: _ModalColors.activeSet,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Calcular discos',
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _ModalColors.activeSet,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Display del valor actual - GRANDE pero compacto
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _displayValue.isEmpty ? '0' : _displayValue,
                          style: GoogleFonts.montserrat(
                            fontSize: 56, // Reducido
                            fontWeight: FontWeight.w900,
                            color: _displayValue.isEmpty
                                ? _ModalColors.textDisabled
                                : _ModalColors.textPrimary,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.fieldLabel,
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            color: _ModalColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    // Advertencia de límite alcanzado
                    if (_showLimitWarning)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          widget.isInteger
                              ? 'Máximo: $_maxReps reps'
                              : 'Máximo: ${_maxWeight.toStringAsFixed(1)} kg',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Numpad - Botones que se ajustan al espacio disponible
            // 🎯 FIX #3: Añadido botón ± para pesos negativos (máquinas asistidas)
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Expanded(child: _buildNumpadRow(['1', '2', '3'])),
                    const SizedBox(height: 8),
                    Expanded(child: _buildNumpadRow(['4', '5', '6'])),
                    const SizedBox(height: 8),
                    Expanded(child: _buildNumpadRow(['7', '8', '9'])),
                    const SizedBox(height: 8),
                    // Última fila: ± (solo para KG), punto decimal, 0, backspace
                    Expanded(child: _buildNumpadRow(['±', '.', '0', '←'])),
                  ],
                ),
              ),
            ),

            // Botones de acción - CONFIRMAR prominente pero compacto
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottomPadding),
              child: Row(
                children: [
                  // Botón limpiar - Sutil
                  if (_displayValue.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: SizedBox(
                        height: 56,
                        child: TextButton(
                          onPressed: _onClear,
                          style: TextButton.styleFrom(
                            foregroundColor: _ModalColors.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          child: Text(
                            'LIMPIAR',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Botón confirmar - ÚNICO CTA
                  Expanded(
                    child: SizedBox(
                      height: 64,
                      child: ElevatedButton(
                        onPressed: _canConfirm ? _onConfirm : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _ModalColors.confirmButton,
                          disabledBackgroundColor: AppColors.bgPressed,
                          foregroundColor: AppColors.textOnAccent,
                          disabledForegroundColor: AppColors.textDisabled,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 24,
                              color: _canConfirm ? AppColors.textOnAccent : AppColors.textDisabled,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'CONFIRMAR',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadRow(List<String> buttons) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: buttons.map((btn) => _buildNumpadButton(btn)).toList(),
    );
  }

  Widget _buildNumpadButton(String label) {
    final isBackspace = label == '←';
    final isDecimal = label == '.';
    final isToggleSign = label == '±';
    // 🎯 FIX #3: ± deshabilitado para REPS (solo válido para KG)
    final isDisabled = (isDecimal && widget.isInteger) || (isToggleSign && widget.isInteger);

    // Determinar la acción del botón
    VoidCallback? onTap;
    if (!isDisabled) {
      if (isBackspace) {
        onTap = _onBackspace;
      } else if (isToggleSign) {
        onTap = _onToggleSign;
      } else {
        onTap = () => _onDigit(label);
      }
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4), // Reducido para 4 botones
        child: Material(
          color: isDisabled ? AppColors.bgElevated : _ModalColors.bgInput,
          borderRadius: BorderRadius.circular(16), // Ligeramente más pequeño
          child: InkWell(
            onTap: onTap,
            onLongPress: isBackspace ? _onClear : null,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: isBackspace
                  ? const Icon(
                      Icons.backspace_outlined,
                      color: _ModalColors.textPrimary,
                      size: 28, // Ligeramente más pequeño
                    )
                  : Text(
                      label,
                      style: GoogleFonts.montserrat(
                        fontSize: 28, // Ligeramente más pequeño para 4 botones
                        fontWeight: FontWeight.w700,
                        color: isDisabled
                            ? _ModalColors.textDisabled
                            : _ModalColors.textPrimary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
