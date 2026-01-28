import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/voice_input_provider.dart';
import '../../utils/design_system.dart';

/// FAB flotante sutil para control por voz durante entrenamiento
///
/// Diseño UX:
/// - Pequeño y discreto en esquina inferior izquierda
/// - Se expande al pulsar para mostrar comandos
/// - Transcripción en tiempo real en tooltip flotante
/// - Comandos soportados: "Hecho", "Siguiente", "Peso X kilos"
class VoiceTrainingFab extends ConsumerStatefulWidget {
  final Function(VoiceTrainingCommand) onCommand;
  final bool enabled;

  const VoiceTrainingFab({
    super.key,
    required this.onCommand,
    this.enabled = true,
  });

  @override
  ConsumerState<VoiceTrainingFab> createState() => _VoiceTrainingFabState();
}

class _VoiceTrainingFabState extends ConsumerState<VoiceTrainingFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _showTranscript = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (!widget.enabled) return;

    final notifier = ref.read(voiceInputProvider.notifier);
    final currentState = ref.read(voiceInputProvider);

    if (currentState.isListening) {
      // Parar y procesar
      await notifier.stopListening();
      // Obtener el transcript del estado actualizado
      final updatedState = ref.read(voiceInputProvider);
      final transcript = updatedState.transcript;

      setState(() => _showTranscript = false);
      _pulseController.stop();
      _pulseController.reset();

      // Parsear comando de entrenamiento
      if (transcript.isNotEmpty) {
        final command = _parseTrainingCommand(transcript);
        if (command != null) {
          widget.onCommand(command);
        }
      }
      // Limpiar después de procesar
      notifier.clearResults();
    } else {
      // Empezar a escuchar
      setState(() => _showTranscript = true);
      _pulseController.repeat(reverse: true);
      await notifier.startListening();
    }
  }

  VoiceTrainingCommand? _parseTrainingCommand(String transcript) {
    final normalized = transcript.toLowerCase().trim();

    // Comando: "Hecho" / "Listo" / "Serie completada"
    if (RegExp(
            r'^(hecho|listo|completado|terminado|serie\s+(?:hecha|completada))',)
        .hasMatch(normalized)) {
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
      return const VoiceTrainingCommand(
        type: VoiceCommandType.markDone,
      );
    }

    // Comando: "Siguiente" / "Next" / "Próxima serie"
    if (RegExp(r'^(siguiente|next|proxim|adelante)').hasMatch(normalized)) {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
      return const VoiceTrainingCommand(
        type: VoiceCommandType.nextSet,
      );
    }

    // Comando: "Descanso" / "Timer" / "Descansar X segundos"
    final restMatch = RegExp(r'(?:descanso|timer|descansar)\s*(?:de\s*)?(\d+)?')
        .firstMatch(normalized);
    if (restMatch != null) {
      final seconds = restMatch.group(1);
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
      return VoiceTrainingCommand(
        type: VoiceCommandType.startRest,
        value: seconds != null ? int.tryParse(seconds)?.toDouble() : null,
      );
    }

    // Comando: "Peso X kilos" / "X kilos" / "X kg"
    final weightMatch = RegExp(r'(?:peso\s*)?(\d+(?:[.,]\d+)?)\s*(?:kilos?|kg)')
        .firstMatch(normalized);
    if (weightMatch != null) {
      final weightStr = weightMatch.group(1)!.replaceAll(',', '.');
      final weight = double.tryParse(weightStr);
      if (weight != null) {
        try {
          HapticFeedback.selectionClick();
        } catch (_) {}
        return VoiceTrainingCommand(
          type: VoiceCommandType.setWeight,
          value: weight,
        );
      }
    }

    // Comando: "X repeticiones" / "X reps"
    final repsMatch =
        RegExp(r'(\d+)\s*(?:reps?|repeticiones?)').firstMatch(normalized);
    if (repsMatch != null) {
      final reps = int.tryParse(repsMatch.group(1)!);
      if (reps != null) {
        try {
          HapticFeedback.selectionClick();
        } catch (_) {}
        return VoiceTrainingCommand(
          type: VoiceCommandType.setReps,
          value: reps.toDouble(),
        );
      }
    }

    // Comando: "RPE X" / "Esfuerzo X"
    final rpeMatch =
        RegExp(r'(?:rpe|esfuerzo)\s*(\d+(?:[.,]\d+)?)').firstMatch(normalized);
    if (rpeMatch != null) {
      final rpeStr = rpeMatch.group(1)!.replaceAll(',', '.');
      final rpe = double.tryParse(rpeStr);
      if (rpe != null && rpe >= 1 && rpe <= 10) {
        try {
          HapticFeedback.selectionClick();
        } catch (_) {}
        return VoiceTrainingCommand(
          type: VoiceCommandType.setRpe,
          value: rpe,
        );
      }
    }

    // Comando: "Nota: texto" / "Anotar: texto" / "Apuntar: texto"
    final noteMatch = RegExp(r'^(?:nota|anotar|apuntar|apunta|anota)[:\s]+(.+)',
            caseSensitive: false,)
        .firstMatch(normalized);
    if (noteMatch != null) {
      final noteText = noteMatch.group(1)!.trim();
      if (noteText.isNotEmpty) {
        try {
          HapticFeedback.selectionClick();
        } catch (_) {}
        return VoiceTrainingCommand(
          type: VoiceCommandType.addNote,
          note: noteText,
        );
      }
    }

    // No reconocido
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceInputProvider);
    final isListening = voiceState.isListening;

    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Transcripción flotante
        if (_showTranscript &&
            (isListening || voiceState.partialTranscript.isNotEmpty))
          Positioned(
            bottom: 80,
            left: 16,
            right: 80,
            child: _buildTranscriptBubble(voiceState),
          ),

        // FAB
        Positioned(
          bottom: 16,
          left: 16,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale =
                  isListening ? 1.0 + (_pulseController.value * 0.15) : 1.0;
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: FloatingActionButton.small(
              heroTag: 'voice_training_fab',
              onPressed: _onTap,
              backgroundColor:
                  isListening ? Colors.red[600] : AppColors.bgElevated,
              foregroundColor: Colors.white,
              elevation: isListening ? 8 : 4,
              child: Icon(
                isListening ? Icons.mic : Icons.mic_none,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTranscriptBubble(VoiceInputState voiceState) {
    final text = voiceState.partialTranscript.isNotEmpty
        ? voiceState.partialTranscript
        : 'Di: "Hecho", "50 kilos", "10 reps"...';

    return AnimatedOpacity(
      opacity: voiceState.isListening ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgElevated.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: voiceState.isListening
                ? AppColors.error.withValues(alpha: 0.5)
                : AppColors.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (voiceState.isListening) ...[
              const _PulsingDot(size: 10),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: voiceState.partialTranscript.isEmpty
                      ? Colors.white38
                      : Colors.white70,
                  fontStyle: voiceState.partialTranscript.isEmpty
                      ? FontStyle.italic
                      : FontStyle.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
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
      duration: const Duration(milliseconds: 600),
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
            color: Colors.red[500]!
                .withValues(alpha: 0.5 + _controller.value * 0.5),
          ),
        );
      },
    );
  }
}

/// Comando de entrenamiento parseado desde voz
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

/// Tipos de comandos de voz para entrenamiento
enum VoiceCommandType {
  markDone, // Marcar serie como completada
  nextSet, // Ir a siguiente serie
  setWeight, // Establecer peso (value = kg)
  setReps, // Establecer reps (value = número)
  setRpe, // Establecer RPE (value = 1-10)
  startRest, // Iniciar descanso (value = segundos opcionales)
  addNote, // Añadir nota (note = texto)
}
