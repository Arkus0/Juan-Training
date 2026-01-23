import '../../utils/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// ============================================================================
/// NUMPAD INPUT MODAL — Entrada Ultra-Rápida para Gimnasio
/// ============================================================================
///
/// Modal fullscreen para entrada de valores KG/REPS.
/// Diseñado para uso en gimnasio: botones grandes, contexto claro.
///
/// Principios:
/// - Touch targets ≥56dp
/// - Contexto siempre visible (ejercicio, serie)
/// - Valor anterior como referencia
/// - Auto-cierre tras confirmación
/// ============================================================================

/// Colores específicos para el modal de entrenamiento
class _ModalColors {
  static const activeSet = Color(0xFF4CAF50);
  static const textPrimary = Color(0xFFFAFAFA);
  static const textSecondary = Color(0xFF757575);
  static const textDisabled = Color(0xFF424242);
  static const bgCard = Color(0xFF1C1C1F);
  static const bgInput = Color(0xFF252528);
  static const confirmButton = Color(0xFF4CAF50);
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
      ),
    );
  }

  @override
  State<NumpadInputModal> createState() => _NumpadInputModalState();
}

class _NumpadInputModalState extends State<NumpadInputModal> {
  late String _displayValue;

  @override
  void initState() {
    super.initState();
    // Inicializar con valor actual o vacío
    if (widget.currentValue != null && widget.currentValue! > 0) {
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

  void _onDigit(String digit) {
    HapticFeedback.selectionClick();
    setState(() {
      // Limitar longitud
      if (_displayValue.length >= 6) return;

      // Validar punto decimal
      if (digit == '.') {
        if (_displayValue.contains('.')) return;
        if (widget.isInteger) return;
        if (_displayValue.isEmpty) {
          _displayValue = '0.';
          return;
        }
      }

      _displayValue += digit;
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

  void _onConfirm() {
    final value = double.tryParse(_displayValue);
    if (value != null && value > 0) {
      HapticFeedback.mediumImpact();
      widget.onConfirm(value);
    }
  }

  void _onUsePrevious() {
    if (widget.previousValue != null && widget.previousValue! > 0) {
      HapticFeedback.selectionClick();
      setState(() {
        _displayValue = widget.isInteger
            ? widget.previousValue!.toInt().toString()
            : _formatNumber(widget.previousValue!);
      });
    }
  }

  bool get _canConfirm {
    final value = double.tryParse(_displayValue);
    return value != null && value > 0;
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: _ModalColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle bar para drag (visual, no funcional)
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header con contexto
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Column(
                children: [
                  // Nombre del ejercicio
                  Text(
                    widget.exerciseName.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _ModalColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Serie actual
                  Text(
                    'SERIE ${widget.setNumber} DE ${widget.totalSets}',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _ModalColors.activeSet,
                      letterSpacing: 1.0,
                    ),
                  ),
                  // Valor anterior (si existe)
                  if (widget.previousValue != null && widget.previousValue! > 0) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _onUsePrevious,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _ModalColors.bgInput,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.border!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history,
                              size: 16,
                              color: _ModalColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Anterior: ${_formatNumber(widget.previousValue!)} ${widget.fieldLabel}',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _ModalColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _ModalColors.activeSet.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'USAR',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _ModalColors.activeSet,
                                ),
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

            // Display del valor actual
            Expanded(
              flex: 2,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _displayValue.isEmpty ? '0' : _displayValue,
                      style: GoogleFonts.montserrat(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: _displayValue.isEmpty
                            ? _ModalColors.textDisabled
                            : _ModalColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.fieldLabel,
                      style: GoogleFonts.montserrat(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: _ModalColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Numpad
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildNumpadRow(['1', '2', '3']),
                    const SizedBox(height: 12),
                    _buildNumpadRow(['4', '5', '6']),
                    const SizedBox(height: 12),
                    _buildNumpadRow(['7', '8', '9']),
                    const SizedBox(height: 12),
                    _buildNumpadRow(['.', '0', '←']),
                  ],
                ),
              ),
            ),

            // Botones de acción
            Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + bottomPadding),
              child: Row(
                children: [
                  // Botón limpiar
                  if (_displayValue.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: SizedBox(
                        height: 64,
                        child: TextButton(
                          onPressed: _onClear,
                          style: TextButton.styleFrom(
                            foregroundColor: _ModalColors.textSecondary,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: AppColors.border!),
                            ),
                          ),
                          child: Text(
                            'LIMPIAR',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Botón confirmar
                  Expanded(
                    child: SizedBox(
                      height: 80,
                      child: ElevatedButton(
                        onPressed: _canConfirm ? _onConfirm : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _ModalColors.confirmButton,
                          disabledBackgroundColor: AppColors.bgDeep,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: AppColors.textTertiary,
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
                              size: 28,
                              color: _canConfirm ? Colors.white : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'CONFIRMAR',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
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
    final isDisabled = isDecimal && widget.isInteger;

    return SizedBox(
      width: 80,
      height: 64,
      child: Material(
        color: isDisabled ? AppColors.bgElevated : _ModalColors.bgInput,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: isDisabled
              ? null
              : (isBackspace ? _onBackspace : () => _onDigit(label)),
          onLongPress: isBackspace ? _onClear : null,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: isBackspace
                ? Icon(
                    Icons.backspace_outlined,
                    color: _ModalColors.textPrimary,
                    size: 28,
                  )
                : Text(
                    label,
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isDisabled
                          ? _ModalColors.textDisabled
                          : _ModalColors.textPrimary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
