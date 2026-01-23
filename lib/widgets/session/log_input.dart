import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/performance_utils.dart';
import '../../utils/design_system.dart';

// ============================================================================
// PRE-COMPUTED CONST STYLES (Avoid GoogleFonts in build methods)
// 🎯 REDISEÑO: Usar colores del sistema de diseño
// ============================================================================

class _InputStyles {
  static final inputText = GoogleFonts.montserrat(
    fontWeight: FontWeight.w800,
    fontSize: 18,
    color: AppColors.textPrimary,
  );

  // 🎯 UX MEDIO: Ghost values más visibles
  static final ghostText = GoogleFonts.montserrat(
    color: AppColors.textTertiary,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.textTertiary.withOpacity(0.3),
    decorationStyle: TextDecorationStyle.dotted,
  );

  static final ghostTextSuggestion = GoogleFonts.montserrat(
    fontWeight: FontWeight.w600,
    fontSize: 16,
  );

  static final toolbarButtonLabel = GoogleFonts.montserrat(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
}

/// Widget de input optimizado para logging de series en gym
///
/// Optimizaciones aplicadas:
/// - Estilos pre-computados (sin GoogleFonts en build)
/// - Animación condicional según PerformanceMode
/// - RepaintBoundary para aislar repaints
/// - Mínimo uso de setState
/// - FocusNode pooling
class LogInput extends StatefulWidget {
  /// Valor actual del input
  final String value;

  /// Valor ghost a mostrar como hint (ej: valor de sesión anterior)
  final String? ghostValue;

  /// Callback cuando el valor cambia
  final ValueChanged<String> onChanged;

  /// Callback cuando se toca el ghost value para copiarlo
  final VoidCallback? onGhostTap;

  /// Si es true, el input recibe focus automáticamente
  final bool shouldFocus;

  /// FocusNode externo para control de focus
  final FocusNode? focusNode;

  /// Si es true, solo permite enteros (para reps)
  final bool isInteger;

  /// Incremento para swipe (default: 1 para reps, 2.5 para peso)
  final double swipeIncrement;

  /// Si es sugerencia de progresión (muestra verde)
  final bool isSuggestion;

  /// Suffix del input (ej: "kg", "reps")
  final String? suffix;

  /// Ancho mínimo del input (88px mínimo para uso con dedos sudados)
  final double minWidth;

  /// Callback cuando se completa edición (submit)
  final VoidCallback? onEditingComplete;

  /// Acción del teclado
  final TextInputAction textInputAction;

  const LogInput({
    super.key,
    required this.value,
    this.ghostValue,
    required this.onChanged,
    this.onGhostTap,
    this.shouldFocus = false,
    this.focusNode,
    this.isInteger = false,
    this.swipeIncrement = 1.0,
    this.isSuggestion = false,
    this.suffix,
    this.minWidth = 88, // UX: Mayor tamaño para uso en gym con dedos sudados
    this.onEditingComplete,
    this.textInputAction = TextInputAction.next,
  });

  @override
  State<LogInput> createState() => _LogInputState();
}

class _LogInputState extends State<LogInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  bool _hasFocus = false;

  // Overlay toolbar entry shown when this input has focus
  OverlayEntry? _toolbarEntry;

  // Para swipe gesture
  double _dragAccumulator = 0;
  static const double _swipeThreshold = 30.0; // Pixels para triggear cambio

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }

    // Listener para tracking de focus (sin rebuild completo)
    _focusNode.addListener(_onFocusChange);

    // Auto-focus inicial si es necesario
    if (widget.shouldFocus) {
      afterFrame(() {
        if (mounted) _requestFocus();
      });
    }
  }

  void _onFocusChange() {
    if (_hasFocus != _focusNode.hasFocus) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });

      // Show or hide overlay toolbar
      if (_focusNode.hasFocus) {
        _insertToolbarOverlay();
      } else {
        _removeToolbarOverlay();
      }
    }
  }

  @override
  void didUpdateWidget(LogInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sync controller con valor externo, pero evitando sobrescribir cambios de formato
    // (p.ej. evitar que "5" se convierta inmediatamente en "5.0" mientras el usuario escribe)
    if (widget.value != oldWidget.value) {
      final currentNum = double.tryParse(_controller.text);
      final widgetNum = double.tryParse(widget.value);

      bool shouldUpdate;
      if (currentNum == null || widgetNum == null) {
        // Si no se pueden parsear, fallback a comparación de strings
        shouldUpdate = widget.value != _controller.text;
      } else {
        // Actualizar solo si el valor numérico real cambió (evita 5 == 5.0)
        shouldUpdate = widgetNum != currentNum;
      }

      if (shouldUpdate) {
        // Formateo limpio: quitar ".0" para enteros cuando sea posible
        String newText;
        if (widget.isInteger) {
          final v = widgetNum ?? double.tryParse(widget.value) ?? 0.0;
          newText = v.truncateToDouble() == v ? v.toInt().toString() : widget.value;
        } else {
          if (widgetNum != null && widgetNum.truncateToDouble() == widgetNum) {
            newText = widgetNum.toInt().toString();
          } else {
            newText = widget.value;
          }
        }

        // Mantener selección si es válida, sino poner cursor al final
        final selection = _controller.selection;
        _controller.text = newText;
        if (selection.isValid && selection.baseOffset <= newText.length && selection.extentOffset <= newText.length) {
          _controller.selection = selection;
        } else {
          _controller.selection = TextSelection.collapsed(offset: newText.length);
        }
      }
    }

    // Auto-focus cuando shouldFocus cambia a true
    if (widget.shouldFocus && !oldWidget.shouldFocus) {
      afterFrame(() {
        if (mounted) _requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _removeToolbarOverlay();
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _requestFocus() {
    _focusNode.requestFocus();
    // Seleccionar todo el texto para facilitar sobreescritura
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    _triggerLightVibration();
  }

  Future<void> _triggerLightVibration() async {
    if (PerformanceMode.instance.reduceVibrations) return;
    try { HapticFeedback.selectionClick(); } catch (_) {}
  }

  Future<void> _triggerMediumVibration() async {
    if (PerformanceMode.instance.reduceVibrations) return;
    try { HapticFeedback.lightImpact(); } catch (_) {}
  }

  void _handleGhostTap() {
    if (widget.ghostValue == null || widget.ghostValue!.isEmpty) return;

    _controller.text = widget.ghostValue!;
    widget.onChanged(widget.ghostValue!);
    widget.onGhostTap?.call();
    _triggerLightVibration();
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    _dragAccumulator -= details.delta.dy; // Negativo porque swipe up = incremento

    if (_dragAccumulator.abs() >= _swipeThreshold) {
      final currentValue = _parseCurrentValue();
      final increment =
          _dragAccumulator > 0 ? widget.swipeIncrement : -widget.swipeIncrement;
      final newValue = (currentValue + increment).clamp(0.0, 9999.0);

      // Formatear el nuevo valor
      final formatted = widget.isInteger
          ? newValue.round().toString()
          : newValue.toStringAsFixed(
              newValue.truncateToDouble() == newValue ? 0 : 1);

      _controller.text = formatted;
      widget.onChanged(formatted);
      _triggerMediumVibration();

      // Reset accumulator
      _dragAccumulator = 0;
    }
  }

  double _parseCurrentValue() {
    if (_controller.text.isEmpty) {
      // Si está vacío, usar ghost value como base si existe
      if (widget.ghostValue != null && widget.ghostValue!.isNotEmpty) {
        return double.tryParse(widget.ghostValue!) ?? 0.0;
      }
      return 0.0;
    }
    return double.tryParse(_controller.text) ?? 0.0;
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragAccumulator = 0;
  }

  // Overlay toolbar management
  void _insertToolbarOverlay() {
    if (_toolbarEntry != null) return;

    _toolbarEntry = OverlayEntry(
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        // Añadir espacio extra para el RestTimerBar (64px + SafeArea bottom padding)
        // que está siempre visible en la pantalla de entrenamiento
        final timerBarHeight = 64.0 + MediaQuery.of(context).padding.bottom;
        return Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset + timerBarHeight,
          child: Material(
            color: Colors.transparent,
            child: LogInputToolbar(
              onCopyPrevious: (widget.ghostValue != null && widget.ghostValue!.isNotEmpty) ? () {
                final val = widget.ghostValue!;
                // Sobrescribimos sin piedad
                _controller.text = val;
                // Mover cursor al final
                _controller.selection = TextSelection.fromPosition(TextPosition(offset: val.length));
                widget.onChanged(val);
                HapticFeedback.selectionClick();
              } : null,
              onDecrement: () {
                final current = _parseCurrentValue();
                final newValue = (current - widget.swipeIncrement).clamp(0.0, 9999.0);
                final formatted = widget.isInteger ? newValue.round().toString() : (newValue.truncateToDouble() == newValue ? newValue.toInt().toString() : newValue.toStringAsFixed(1));
                _controller.text = formatted;
                widget.onChanged(formatted);
              },
              onIncrement: () {
                final current = _parseCurrentValue();
                final newValue = (current + widget.swipeIncrement).clamp(0.0, 9999.0);
                final formatted = widget.isInteger ? newValue.round().toString() : (newValue.truncateToDouble() == newValue ? newValue.toInt().toString() : newValue.toStringAsFixed(1));
                _controller.text = formatted;
                widget.onChanged(formatted);
              },
              onDone: () {
                // Close keyboard and remove overlay
                FocusScope.of(context).unfocus();
                _removeToolbarOverlay();
                if (widget.onEditingComplete != null) widget.onEditingComplete!();
              },
              incrementLabel: widget.swipeIncrement % 1 == 0 ? '+${widget.swipeIncrement.toInt()}' : '+${widget.swipeIncrement}',
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_toolbarEntry!);
  }

  void _removeToolbarOverlay() {
    _toolbarEntry?.remove();
    _toolbarEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final hasGhost = widget.ghostValue != null && widget.ghostValue!.isNotEmpty;
    final isEmpty = _controller.text.isEmpty;

    // Usar RepaintBoundary para aislar repaints frecuentes
    return RepaintBoundary(
      child: GestureDetector(
        // Swipe vertical para +1/-1
        onVerticalDragUpdate: _handleVerticalDrag,
        onVerticalDragEnd: _handleDragEnd,
        // Tap en ghost para copiar
        onDoubleTap: hasGhost ? _handleGhostTap : null,
        child: Container(
          constraints: BoxConstraints(minWidth: widget.minWidth),
          child: Stack(
            children: [
              // Input principal
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: !widget.isInteger,
                  signed: false,
                ),
                textInputAction: widget.textInputAction,
                textAlign: TextAlign.center,
                style: _InputStyles.inputText,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  filled: true,
                  fillColor: _hasFocus ? AppColors.bgElevated : AppColors.bgDeep,
                  // Ghost value como hint
                  hintText: hasGhost ? widget.ghostValue : null,
                  hintStyle: widget.isSuggestion
                      ? _InputStyles.ghostTextSuggestion.copyWith(
                          color: AppColors.neonCyan?.withValues(alpha: 0.6),
                        )
                      : _InputStyles.ghostText,
                  // Suffix si existe
                  suffixText: widget.suffix,
                  suffixStyle: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  // Borders
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.bgDeep!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.bgDeep!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        BorderSide(color: AppColors.neonPrimary!, width: 2),
                  ),
                ),
                inputFormatters: [
                  // Solo números y punto decimal
                  FilteringTextInputFormatter.allow(
                    widget.isInteger ? RegExp(r'[0-9]') : RegExp(r'[0-9.]'),
                  ),
                  // Máximo un punto decimal
                  if (!widget.isInteger) _SingleDecimalFormatter(),
                ],
                onChanged: widget.onChanged,
                onEditingComplete: widget.onEditingComplete,
                onTap: () {
                  // Seleccionar todo al tocar para facilitar sobreescritura
                  if (_controller.text.isNotEmpty) {
                    _controller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _controller.text.length,
                    );
                  }
                },
              ),

              // Indicador de swipe (pequeñas flechas) - solo cuando tiene focus
              if (_hasFocus)
                Positioned(
                  right: 2,
                  top: 2,
                  bottom: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.keyboard_arrow_up,
                          size: 10, color: AppColors.border),
                      Icon(Icons.keyboard_arrow_down,
                          size: 10, color: AppColors.border),
                    ],
                  ),
                ),

              // Indicador de ghost tap (doble tap)
              if (hasGhost && isEmpty)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: widget.isSuggestion
                          ? AppColors.neonCyanSubtle?.withValues(alpha: 0.5)
                          : AppColors.bgDeep?.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '2x',
                      style: TextStyle(
                        fontSize: 7,
                        color: widget.isSuggestion
                            ? AppColors.neonCyan
                            : AppColors.textTertiary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formatter para permitir solo un punto decimal
class _SingleDecimalFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Contar puntos decimales
    final dotCount = '.'.allMatches(newValue.text).length;
    if (dotCount > 1) {
      return oldValue;
    }
    return newValue;
  }
}

/// Widget compacto de selector de incremento para teclado custom
/// (Por si queremos un teclado inline en el futuro)
class IncrementSelector extends StatelessWidget {
  final double value;
  final double increment;
  final ValueChanged<double> onChanged;
  final bool isInteger;

  const IncrementSelector({
    super.key,
    required this.value,
    required this.increment,
    required this.onChanged,
    this.isInteger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IncrementButton(
          icon: Icons.remove,
          onTap: () {
            final newValue = (value - increment).clamp(0.0, 9999.0);
            onChanged(newValue);
            HapticFeedback.selectionClick();
          },
        ),
        const SizedBox(width: 8),
        _IncrementButton(
          icon: Icons.add,
          isAccent: true,
          onTap: () {
            final newValue = value + increment;
            onChanged(newValue);
            HapticFeedback.selectionClick();
          },
        ),
      ],
    );
  }
}

class _IncrementButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isAccent;

  const _IncrementButton({
    required this.icon,
    required this.onTap,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isAccent ? AppColors.neonPrimary : AppColors.bgDeep,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Toolbar compacta que aparece sobre el teclado con acciones rápidas
class LogInputToolbar extends StatelessWidget {
  final VoidCallback? onCopyPrevious;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback onDone;
  final String incrementLabel;

  const LogInputToolbar({
    super.key,
    this.onCopyPrevious,
    this.onIncrement,
    this.onDecrement,
    required this.onDone,
    this.incrementLabel = '+/-',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: AppColors.bgElevated,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          if (onCopyPrevious != null)
            _ToolbarButton(
              label: 'PREV',
              icon: Icons.content_copy,
              onTap: onCopyPrevious!,
            ),
          const Spacer(),
          if (onDecrement != null)
            _ToolbarButton(
              label: '-',
              onTap: onDecrement!,
            ),
          const SizedBox(width: 8),
          if (onIncrement != null)
            _ToolbarButton(
              label: '+',
              isAccent: true,
              onTap: onIncrement!,
            ),
          const SizedBox(width: 16),
          _ToolbarButton(
            label: 'OK',
            isAccent: true,
            onTap: onDone,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isAccent;

  const _ToolbarButton({
    required this.label,
    this.icon,
    required this.onTap,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isAccent ? AppColors.neonPrimary : AppColors.bgDeep,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.textPrimary),
                const SizedBox(width: 4),
              ],
              Text(label, style: _InputStyles.toolbarButtonLabel),
            ],
          ),
        ),
      ),
    );
  }
}
