import '../../utils/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/voice_input_provider.dart';
import 'voice_training_fab.dart' show VoiceTrainingCommand, VoiceCommandType;

// Re-exportar los tipos del FAB para compatibilidad
export 'voice_training_fab.dart' show VoiceTrainingCommand, VoiceCommandType;

/// Botón de voz compacto para usar en AppBar durante entrenamiento
/// 
/// Diseño UX:
/// - IconButton que cabe en el AppBar junto a otros botones
/// - Muestra overlay modal con transcripción al escuchar
/// - Mismo parsing de comandos que VoiceTrainingFab
class VoiceTrainingButton extends ConsumerStatefulWidget {
  final Function(VoiceTrainingCommand) onCommand;
  final bool enabled;

  const VoiceTrainingButton({
    super.key,
    required this.onCommand,
    this.enabled = true,
  });

  @override
  ConsumerState<VoiceTrainingButton> createState() => _VoiceTrainingButtonState();
}

class _VoiceTrainingButtonState extends ConsumerState<VoiceTrainingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  OverlayEntry? _overlayEntry;

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
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showListeningOverlay() {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => _ListeningOverlay(
        onDismiss: _onStopListening,
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _onTap() async {
    if (!widget.enabled) return;

    final notifier = ref.read(voiceInputProvider.notifier);
    final currentState = ref.read(voiceInputProvider);

    if (currentState.isListening) {
      await _onStopListening();
    } else {
      // Empezar a escuchar
      _pulseController.repeat(reverse: true);
      _showListeningOverlay();
      await notifier.startListening();
    }
  }

  Future<void> _onStopListening() async {
    final notifier = ref.read(voiceInputProvider.notifier);
    
    _removeOverlay();
    _pulseController.stop();
    _pulseController.reset();
    
    await notifier.stopListening();
    
    // Obtener el transcript del estado actualizado
    final updatedState = ref.read(voiceInputProvider);
    final transcript = updatedState.transcript;

    // Parsear comando de entrenamiento
    if (transcript.isNotEmpty) {
      final command = _parseTrainingCommand(transcript);
      if (command != null) {
        widget.onCommand(command);
      }
    }
    // Limpiar después de procesar
    notifier.clearResults();
  }

  VoiceTrainingCommand? _parseTrainingCommand(String transcript) {
    final normalized = transcript.toLowerCase().trim();

    // Comando: "Hecho" / "Listo" / "Serie completada"
    if (RegExp(r'^(hecho|listo|completado|terminado|serie\s+(?:hecha|completada))').hasMatch(normalized)) {
      try { HapticFeedback.heavyImpact(); } catch (_) {}
      return const VoiceTrainingCommand(type: VoiceCommandType.markDone);
    }

    // Comando: "Siguiente" / "Next" / "Próxima serie"
    if (RegExp(r'^(siguiente|next|proxim|adelante)').hasMatch(normalized)) {
      try { HapticFeedback.mediumImpact(); } catch (_) {}
      return const VoiceTrainingCommand(type: VoiceCommandType.nextSet);
    }

    // Comando: "Descanso" / "Timer" / "Descansar X segundos"
    final restMatch = RegExp(r'(?:descanso|timer|descansar)\s*(?:de\s*)?(\d+)?').firstMatch(normalized);
    if (restMatch != null) {
      final seconds = restMatch.group(1);
      try { HapticFeedback.lightImpact(); } catch (_) {}
      return VoiceTrainingCommand(
        type: VoiceCommandType.startRest,
        value: seconds != null ? int.tryParse(seconds)?.toDouble() : null,
      );
    }

    // Comando: "Peso X kilos" / "X kilos" / "X kg"
    final weightMatch = RegExp(r'(?:peso\s*)?(\d+(?:[.,]\d+)?)\s*(?:kilos?|kg)').firstMatch(normalized);
    if (weightMatch != null) {
      final weightStr = weightMatch.group(1)!.replaceAll(',', '.');
      final weight = double.tryParse(weightStr);
      if (weight != null) {
        try { HapticFeedback.selectionClick(); } catch (_) {}
        return VoiceTrainingCommand(type: VoiceCommandType.setWeight, value: weight);
      }
    }

    // Comando: "X repeticiones" / "X reps"
    final repsMatch = RegExp(r'(\d+)\s*(?:reps?|repeticiones?)').firstMatch(normalized);
    if (repsMatch != null) {
      final reps = int.tryParse(repsMatch.group(1)!);
      if (reps != null) {
        try { HapticFeedback.selectionClick(); } catch (_) {}
        return VoiceTrainingCommand(type: VoiceCommandType.setReps, value: reps.toDouble());
      }
    }

    // Comando: "RPE X" / "Esfuerzo X"
    final rpeMatch = RegExp(r'(?:rpe|esfuerzo)\s*(\d+(?:[.,]\d+)?)').firstMatch(normalized);
    if (rpeMatch != null) {
      final rpeStr = rpeMatch.group(1)!.replaceAll(',', '.');
      final rpe = double.tryParse(rpeStr);
      if (rpe != null && rpe >= 1 && rpe <= 10) {
        try { HapticFeedback.selectionClick(); } catch (_) {}
        return VoiceTrainingCommand(type: VoiceCommandType.setRpe, value: rpe);
      }
    }

    // Comando: "Nota: texto" / "Anotar: texto" / "Apuntar: texto"
    final noteMatch = RegExp(r'^(?:nota|anotar|apuntar|apunta|anota)[:\s]+(.+)', caseSensitive: false).firstMatch(normalized);
    if (noteMatch != null) {
      final noteText = noteMatch.group(1)!.trim();
      if (noteText.isNotEmpty) {
        try { HapticFeedback.selectionClick(); } catch (_) {}
        return VoiceTrainingCommand(type: VoiceCommandType.addNote, note: noteText);
      }
    }

    // No reconocido
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }

    final voiceState = ref.watch(voiceInputProvider);
    final isListening = voiceState.isListening;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: isListening ? BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.3 + _pulseController.value * 0.3),
                blurRadius: 8 + _pulseController.value * 4,
                spreadRadius: _pulseController.value * 2,
              ),
            ],
          ) : null,
          child: IconButton(
            onPressed: _onTap,
            icon: Icon(
              isListening ? Icons.mic : Icons.mic_none,
              color: isListening ? AppColors.neonPrimary : Colors.white70,
            ),
            tooltip: isListening ? 'Escuchando...' : 'Dictar series (ej: 80kg, 10 reps)',
            style: IconButton.styleFrom(
              backgroundColor: isListening 
                  ? AppColors.live.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
        );
      },
    );
  }
}

/// Overlay modal que muestra la transcripción mientras escucha
class _ListeningOverlay extends ConsumerWidget {
  final VoidCallback onDismiss;

  const _ListeningOverlay({required this.onDismiss});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceInputProvider);
    final text = voiceState.partialTranscript.isNotEmpty
        ? voiceState.partialTranscript
        : 'Di: "Hecho", "50 kilos", "10 reps"...';

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onDismiss,
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: Colors.black.withValues(alpha: 0.3),
            alignment: Alignment.topCenter,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
              left: 16,
              right: 16,
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.live.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Indicador de escucha
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _PulsingMicIcon(),
                      const SizedBox(width: 12),
                      Text(
                        'Escuchando...',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Transcripción
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      text,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: voiceState.partialTranscript.isEmpty 
                            ? Colors.white38 
                            : Colors.white,
                        fontStyle: voiceState.partialTranscript.isEmpty 
                            ? FontStyle.italic 
                            : FontStyle.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Hint para cerrar
                  const Text(
                    'Toca en cualquier lugar para detener',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingMicIcon extends StatefulWidget {
  const _PulsingMicIcon();

  @override
  State<_PulsingMicIcon> createState() => _PulsingMicIconState();
}

class _PulsingMicIconState extends State<_PulsingMicIcon>
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
        return Icon(
          Icons.mic,
          size: 28,
          color: AppColors.neonPrimary.withValues(alpha: 0.6 + _controller.value * 0.4),
        );
      },
    );
  }
}
