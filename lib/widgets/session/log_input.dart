import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget de input optimizado para logging de series en gym
///
/// Características:
/// - Teclado numérico compacto (no tapa UI)
/// - Ghost values tocables (tap para copiar valor anterior)
/// - Swipe vertical para +1/-1 rápido
/// - Auto-focus suave con vibración
/// - Diseño oscuro adaptado al tema gym
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

  /// Ancho mínimo del input
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
    this.minWidth = 70,
    this.onEditingComplete,
    this.textInputAction = TextInputAction.next,
  });

  @override
  State<LogInput> createState() => _LogInputState();
}

class _LogInputState extends State<LogInput> with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  // Para swipe gesture
  double _dragAccumulator = 0;
  static const double _swipeThreshold = 30.0; // Pixels para triggear cambio

  // Animación para feedback visual de swipe
  late AnimationController _feedbackController;
  late Animation<double> _scaleAnimation;

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

    // Animación de feedback
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _feedbackController, curve: Curves.easeOut),
    );

    // Auto-focus inicial si es necesario
    if (widget.shouldFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(LogInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Sync controller con valor externo
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(offset: widget.value.length);
    }

    // Auto-focus cuando shouldFocus cambia a true
    if (widget.shouldFocus && !oldWidget.shouldFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _feedbackController.dispose();
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
    final canVibrate = await Vibrate.canVibrate;
    if (canVibrate) {
      Vibrate.feedback(FeedbackType.selection);
    }
  }

  Future<void> _triggerMediumVibration() async {
    final canVibrate = await Vibrate.canVibrate;
    if (canVibrate) {
      Vibrate.feedback(FeedbackType.light);
    }
  }

  void _handleGhostTap() {
    if (widget.ghostValue == null || widget.ghostValue!.isEmpty) return;

    _controller.text = widget.ghostValue!;
    widget.onChanged(widget.ghostValue!);
    widget.onGhostTap?.call();
    _triggerLightVibration();

    // Feedback visual
    _feedbackController.forward().then((_) => _feedbackController.reverse());
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    _dragAccumulator -= details.delta.dy; // Negativo porque swipe up = incremento

    if (_dragAccumulator.abs() >= _swipeThreshold) {
      final currentValue = _parseCurrentValue();
      final increment = _dragAccumulator > 0 ? widget.swipeIncrement : -widget.swipeIncrement;
      final newValue = (currentValue + increment).clamp(0.0, 9999.0);

      // Formatear el nuevo valor
      final formatted = widget.isInteger
          ? newValue.round().toString()
          : newValue.toStringAsFixed(newValue.truncateToDouble() == newValue ? 0 : 1);

      _controller.text = formatted;
      widget.onChanged(formatted);
      _triggerMediumVibration();

      // Reset accumulator
      _dragAccumulator = 0;

      // Feedback visual
      _feedbackController.forward().then((_) => _feedbackController.reverse());
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

  @override
  Widget build(BuildContext context) {
    final hasGhost = widget.ghostValue != null && widget.ghostValue!.isNotEmpty;
    final isEmpty = _controller.text.isEmpty;

    return GestureDetector(
      // Swipe vertical para +1/-1
      onVerticalDragUpdate: _handleVerticalDrag,
      onVerticalDragEnd: _handleDragEnd,
      // Tap en ghost para copiar
      onDoubleTap: hasGhost ? _handleGhostTap : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
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
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  filled: true,
                  fillColor: _focusNode.hasFocus ? Colors.grey[900] : Colors.black,
                  // Ghost value como hint
                  hintText: hasGhost ? widget.ghostValue : null,
                  hintStyle: GoogleFonts.montserrat(
                    color: widget.isSuggestion
                        ? Colors.green[600]?.withValues(alpha: 0.6)
                        : Colors.white30,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  // Suffix si existe
                  suffixText: widget.suffix,
                  suffixStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  // Borders
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[800]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[800]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.redAccent[700]!, width: 2),
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

              // Indicador de swipe (pequeñas flechas)
              if (_focusNode.hasFocus)
                Positioned(
                  right: 2,
                  top: 2,
                  bottom: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(Icons.keyboard_arrow_up, size: 10, color: Colors.grey[700]),
                      Icon(Icons.keyboard_arrow_down, size: 10, color: Colors.grey[700]),
                    ],
                  ),
                ),

              // Indicador de ghost tap (doble tap)
              if (hasGhost && isEmpty)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: widget.isSuggestion
                          ? Colors.green[900]?.withValues(alpha: 0.5)
                          : Colors.grey[800]?.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '2x',
                      style: TextStyle(
                        fontSize: 7,
                        color: widget.isSuggestion ? Colors.green[400] : Colors.grey[500],
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
      color: isAccent ? Colors.redAccent[700] : Colors.grey[800],
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 18, color: Colors.white),
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
      color: Colors.grey[900],
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
      color: isAccent ? Colors.redAccent[700] : Colors.grey[800],
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
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
