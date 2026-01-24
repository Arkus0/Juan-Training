import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/voice_input_provider.dart';
import '../../utils/design_system.dart';

/// Estados explícitos del botón Push To Talk
enum PttState {
  idle,       // Esperando - Gris neutro - "Pulsa para hablar"
  listening,  // Escuchando activamente - Rojo vivo - "Escuchando..."
  processing, // Procesando transcripción - Amarillo - "Procesando..."
  success,    // Éxito - Verde - "Detectado: [preview]"
  error,      // Error - Naranja - "No entendido"
}

/// Botón Push To Talk con comportamiento explícito.
///
/// PRINCIPIO: Si no pulsas, no escucha. Punto.
///
/// Comportamiento:
/// - onTapDown: Empieza a escuchar
/// - onTapUp: Para y procesa
/// - onTapCancel: Cancela sin procesar
///
/// Feedback visual por estado:
/// - IDLE: Gris, mic_none, "Pulsa para hablar"
/// - LISTENING: Rojo con glow pulsante, mic, "Escuchando..."
/// - PROCESSING: Amarillo, spinner, "Procesando..."
/// - SUCCESS: Verde, check, "Detectado"
/// - ERROR: Naranja, error, "No entendido"
class PttVoiceButton extends ConsumerStatefulWidget {
  final VoidCallback? onListeningStart;
  final Function(String transcript)? onListeningEnd;
  final VoidCallback? onCancel;
  final double size;
  final bool showLabel;
  final bool showHint;

  const PttVoiceButton({
    super.key,
    this.onListeningStart,
    this.onListeningEnd,
    this.onCancel,
    this.size = 80,
    this.showLabel = true,
    this.showHint = true,
  });

  @override
  ConsumerState<PttVoiceButton> createState() => _PttVoiceButtonState();
}

class _PttVoiceButtonState extends ConsumerState<PttVoiceButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  bool _isPressed = false;
  PttState _displayState = PttState.idle;
  String? _successPreview;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    _pulseController.repeat(reverse: true);
    _glowController.repeat(reverse: true);
  }

  void _stopAnimations() {
    _pulseController.stop();
    _pulseController.reset();
    _glowController.stop();
    _glowController.reset();
  }

  Future<void> _onTapDown(TapDownDetails details) async {
    if (_displayState == PttState.processing) return;

    setState(() {
      _isPressed = true;
      _displayState = PttState.listening;
      _successPreview = null;
    });

    _startAnimations();

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    widget.onListeningStart?.call();

    final notifier = ref.read(voiceInputProvider.notifier);
    await notifier.startListening();
  }

  Future<void> _onTapUp(TapUpDetails details) async {
    if (!_isPressed) return;

    setState(() {
      _isPressed = false;
      _displayState = PttState.processing;
    });

    _stopAnimations();

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    final notifier = ref.read(voiceInputProvider.notifier);
    final exercises = await notifier.stopListening();

    final transcript = ref.read(voiceInputProvider).transcript;
    widget.onListeningEnd?.call(transcript);

    if (exercises.isNotEmpty && exercises.any((e) => e.isValid)) {
      setState(() {
        _displayState = PttState.success;
        _successPreview = exercises.where((e) => e.isValid).map((e) => e.matchedName).join(', ');
      });

      // Volver a idle después de mostrar éxito
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _displayState = PttState.idle);
      }
    } else if (transcript.isEmpty) {
      setState(() => _displayState = PttState.idle);
    } else {
      setState(() => _displayState = PttState.error);

      // Volver a idle después de mostrar error
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _displayState = PttState.idle);
      }
    }
  }

  void _onTapCancel() {
    if (!_isPressed) return;

    setState(() {
      _isPressed = false;
      _displayState = PttState.idle;
    });

    _stopAnimations();

    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    widget.onCancel?.call();
    ref.read(voiceInputProvider.notifier).cancelListening();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceInputProvider);

    // Sincronizar con estado del provider si está procesando externamente
    if (voiceState.isProcessing && _displayState != PttState.processing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _displayState = PttState.processing);
        }
      });
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hint contextual
        if (widget.showHint && _displayState == PttState.idle) ...[
          _buildHintText(),
          const SizedBox(height: 12),
        ],

        // Botón principal
        GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pulseAnimation, _glowAnimation]),
            builder: (context, child) {
              return _buildButton();
            },
          ),
        ),

        // Label de estado
        if (widget.showLabel) ...[
          const SizedBox(height: 12),
          _buildStateLabel(),
        ],

        // Transcripción en tiempo real
        if (_displayState == PttState.listening && voiceState.partialTranscript.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildTranscriptPreview(voiceState.partialTranscript),
        ],
      ],
    );
  }

  Widget _buildHintText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, size: 16, color: Colors.white54),
          const SizedBox(width: 8),
          Text(
            'Mantén pulsado para hablar',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    final config = _getStateConfig();
    final scale = _displayState == PttState.listening ? _pulseAnimation.value : 1.0;
    final glowOpacity = _displayState == PttState.listening ? _glowAnimation.value : 0.0;

    return Transform.scale(
      scale: scale,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: config.backgroundColor,
          boxShadow: [
            // Glow para estado listening
            if (_displayState == PttState.listening)
              BoxShadow(
                color: config.glowColor.withValues(alpha: glowOpacity),
                blurRadius: 30,
                spreadRadius: 8,
              ),
            // Sombra normal
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: config.borderColor,
            width: _displayState == PttState.listening ? 3 : 2,
          ),
        ),
        child: Center(
          child: _displayState == PttState.processing
              ? SizedBox(
                  width: widget.size * 0.4,
                  height: widget.size * 0.4,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(config.iconColor),
                  ),
                )
              : Icon(
                  config.icon,
                  color: config.iconColor,
                  size: widget.size * 0.45,
                ),
        ),
      ),
    );
  }

  Widget _buildStateLabel() {
    final config = _getStateConfig();

    String labelText;
    switch (_displayState) {
      case PttState.idle:
        labelText = 'Pulsa para hablar';
      case PttState.listening:
        labelText = 'Escuchando...';
      case PttState.processing:
        labelText = 'Procesando...';
      case PttState.success:
        labelText = 'Detectado';
      case PttState.error:
        labelText = 'No entendido';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Column(
        key: ValueKey(_displayState),
        children: [
          Text(
            labelText,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: config.labelColor,
            ),
          ),
          if (_displayState == PttState.success && _successPreview != null) ...[
            const SizedBox(height: 4),
            Text(
              _successPreview!,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.white54,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTranscriptPreview(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 300),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: AppColors.error),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.white70,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  _PttStateConfig _getStateConfig() {
    switch (_displayState) {
      case PttState.idle:
        return _PttStateConfig(
          backgroundColor: AppColors.bgElevated,
          borderColor: AppColors.border,
          iconColor: Colors.white70,
          labelColor: Colors.white54,
          glowColor: Colors.transparent,
          icon: Icons.mic_none,
        );
      case PttState.listening:
        return _PttStateConfig(
          backgroundColor: AppColors.error,
          borderColor: Colors.red[400]!,
          iconColor: Colors.white,
          labelColor: AppColors.error,
          glowColor: Colors.red,
          icon: Icons.mic,
        );
      case PttState.processing:
        return _PttStateConfig(
          backgroundColor: Colors.amber[700]!,
          borderColor: Colors.amber[400]!,
          iconColor: Colors.white,
          labelColor: Colors.amber[600]!,
          glowColor: Colors.amber,
          icon: Icons.hourglass_empty,
        );
      case PttState.success:
        return _PttStateConfig(
          backgroundColor: Colors.green[600]!,
          borderColor: Colors.green[400]!,
          iconColor: Colors.white,
          labelColor: Colors.green[500]!,
          glowColor: Colors.green,
          icon: Icons.check,
        );
      case PttState.error:
        return _PttStateConfig(
          backgroundColor: Colors.orange[700]!,
          borderColor: Colors.orange[400]!,
          iconColor: Colors.white,
          labelColor: Colors.orange[500]!,
          glowColor: Colors.orange,
          icon: Icons.error_outline,
        );
    }
  }
}

class _PttStateConfig {
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color labelColor;
  final Color glowColor;
  final IconData icon;

  const _PttStateConfig({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.labelColor,
    required this.glowColor,
    required this.icon,
  });
}

/// Punto pulsante para indicador de escucha
class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingDot({
    required this.color,
    this.size = 10,
  });

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.5 + _controller.value * 0.5),
          ),
        );
      },
    );
  }
}

/// Widget compacto de PTT para usar en AppBar o espacios reducidos
class PttCompactButton extends ConsumerStatefulWidget {
  final Function(VoiceTrainingCommand)? onCommand;
  final double size;

  const PttCompactButton({
    super.key,
    this.onCommand,
    this.size = 40,
  });

  @override
  ConsumerState<PttCompactButton> createState() => _PttCompactButtonState();
}

class _PttCompactButtonState extends ConsumerState<PttCompactButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceInputProvider);
    final isListening = voiceState.isListening;

    if (isListening && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isListening && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    return GestureDetector(
      onTapDown: (_) async {
        setState(() => _isPressed = true);
        try { HapticFeedback.mediumImpact(); } catch (_) {}
        await ref.read(voiceInputProvider.notifier).startListening();
      },
      onTapUp: (_) async {
        setState(() => _isPressed = false);
        try { HapticFeedback.heavyImpact(); } catch (_) {}
        await ref.read(voiceInputProvider.notifier).stopListening();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        ref.read(voiceInputProvider.notifier).cancelListening();
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = isListening ? 1.0 + _pulseController.value * 0.1 : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isListening ? AppColors.error : AppColors.bgElevated,
                border: Border.all(
                  color: isListening ? Colors.red[400]! : AppColors.border,
                  width: isListening ? 2 : 1,
                ),
                boxShadow: isListening
                    ? [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: widget.size * 0.5,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Comando de entrenamiento por voz (para compatibilidad)
class VoiceTrainingCommand {
  final VoiceCommandType type;
  final double? value;
  final String? note;

  const VoiceTrainingCommand({
    required this.type,
    this.value,
    this.note,
  });
}

enum VoiceCommandType {
  markDone,
  nextSet,
  setWeight,
  setReps,
  setRpe,
  startRest,
  addNote,
}
