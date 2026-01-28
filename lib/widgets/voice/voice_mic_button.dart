import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/voice_input_provider.dart';
import '../../utils/design_system.dart';

/// Botón de micrófono con animación de onda cuando está escuchando
///
/// Usa el tema gym oscuro con rojo primario (#B71C1C)
/// Vibra al inicio/fin de escucha
class VoiceMicButton extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  final double size;
  final bool showLabel;

  const VoiceMicButton({
    super.key,
    required this.onTap,
    this.size = 56,
    this.showLabel = true,
  });

  @override
  ConsumerState<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends ConsumerState<VoiceMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
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

    // Controlar animación según estado
    if (isListening && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isListening && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            try {
              HapticFeedback.selectionClick();
            } catch (_) {}
            widget.onTap();
          },
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final scale = isListening ? _pulseAnimation.value : 1.0;
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isListening ? AppColors.error : AppColors.live,
                boxShadow: isListening
                    ? [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Icon(
                isListening ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: widget.size * 0.5,
              ),
            ),
          ),
        ),
        if (widget.showLabel) ...[
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              isListening ? 'Escuchando...' : 'Dictar',
              key: ValueKey(isListening),
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isListening ? AppColors.neonPrimary : Colors.white70,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Indicador compacto de escucha para usar en AppBar o espacios reducidos
class VoiceListeningIndicator extends ConsumerWidget {
  final double size;

  const VoiceListeningIndicator({
    super.key,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceInputProvider);

    if (!voiceState.isListening) {
      return const SizedBox.shrink();
    }

    return _PulsingDot(size: size);
  }
}

class _PulsingDot extends StatefulWidget {
  final double size;

  const _PulsingDot({required this.size});

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
            color: Colors.red[600]!
                .withValues(alpha: 0.5 + _controller.value * 0.5),
          ),
          child: Center(
            child: Container(
              width: widget.size * 0.6,
              height: widget.size * 0.6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.neonPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Widget de transcripción en tiempo real
/// Muestra texto gris clarito mientras se transcribe
class VoiceTranscriptPreview extends ConsumerWidget {
  final EdgeInsets padding;
  final double fontSize;

  const VoiceTranscriptPreview({
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceInputProvider);
    final text = voiceState.partialTranscript.isNotEmpty
        ? voiceState.partialTranscript
        : voiceState.transcript;

    if (text.isEmpty && !voiceState.isListening) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.bgElevated.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: voiceState.isListening
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (voiceState.isListening)
            Row(
              children: [
                const _PulsingDot(size: 12),
                const SizedBox(width: 8),
                Text(
                  'Escuchando...',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neonPrimary,
                  ),
                ),
              ],
            ),
          if (voiceState.isListening) const SizedBox(height: 8),
          Text(
            text.isEmpty
                ? 'Di algo como: "Añade sentadilla 5 series de 5..."'
                : text,
            style: GoogleFonts.montserrat(
              fontSize: fontSize,
              fontWeight: text.isEmpty ? FontWeight.w400 : FontWeight.w500,
              // Gris clarito para transcripción en progreso
              color: text.isEmpty
                  ? Colors.white30
                  : (voiceState.isListening ? Colors.white54 : Colors.white),
              fontStyle: text.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}
