import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/voice_action.dart';
import '../../providers/voice_input_provider.dart' as vip;
import '../../utils/design_system.dart';
import 'voice_training_fab.dart' show VoiceTrainingCommand, VoiceCommandType;

// Re-exportar los tipos del FAB para compatibilidad
export 'voice_training_fab.dart' show VoiceTrainingCommand, VoiceCommandType;

/// Contexto de la serie activa para mostrar en el overlay
class VoiceTrainingContext {
  final String exerciseName;
  final int currentSet;
  final int totalSets;
  final double? currentWeight;
  final int? currentReps;
  final double? currentRpe;

  const VoiceTrainingContext({
    required this.exerciseName,
    required this.currentSet,
    required this.totalSets,
    this.currentWeight,
    this.currentReps,
    this.currentRpe,
  });
}

/// Botón de voz compacto para usar en AppBar durante entrenamiento
///
/// Diseño UX - PUSH TO TALK:
/// - IconButton que cabe en el AppBar junto a otros botones
/// - Muestra overlay modal con transcripción y CONTEXTO al escuchar
/// - Indica claramente qué serie/campo se va a modificar
class VoiceTrainingButton extends ConsumerStatefulWidget {
  final Function(VoiceTrainingCommand) onCommand;
  final bool enabled;
  final VoiceTrainingContext? context; // Contexto de la serie activa

  const VoiceTrainingButton({
    super.key,
    required this.onCommand,
    this.enabled = true,
    this.context,
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
        context: widget.context, // Pasar contexto de la serie activa
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _onTap() async {
    if (!widget.enabled) return;

    final notifier = ref.read(vip.voiceInputProvider.notifier);
    final currentState = ref.read(vip.voiceInputProvider);

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
    final notifier = ref.read(vip.voiceInputProvider.notifier);

    _removeOverlay();
    _pulseController.stop();
    _pulseController.reset();

    await notifier.stopListening();

    // Obtener el transcript del estado actualizado
    final updatedState = ref.read(vip.voiceInputProvider);
    final transcript = updatedState.transcript;

    // Parsear comando de entrenamiento
    if (transcript.isNotEmpty) {
      final command = _parseTrainingCommand(transcript);
      if (command != null) {
        // Registrar acción para undo
        notifier.recordAction(vip.VoiceAction(
          description: _getActionDescription(command),
        ),);
        widget.onCommand(command);
      } else {
        // No se entendió el comando - mostrar feedback
        _showNotUnderstoodSnackbar(transcript);
      }
    } else if (updatedState.notUnderstood) {
      // No se captó nada
      _showNotUnderstoodSnackbar(null);
    }
    // Limpiar después de procesar
    notifier.clearResults();
  }

  String _getActionDescription(VoiceTrainingCommand command) {
    switch (command.type) {
      case VoiceCommandType.setWeight:
        return 'Peso: ${command.value?.toStringAsFixed(1)} kg';
      case VoiceCommandType.setReps:
        return 'Reps: ${command.value?.toInt()}';
      case VoiceCommandType.setRpe:
        return 'RPE: ${command.value?.toStringAsFixed(1)}';
      case VoiceCommandType.addNote:
        return 'Nota añadida';
      case VoiceCommandType.markDone:
        return 'Serie completada';
      case VoiceCommandType.nextSet:
        return 'Siguiente serie';
      case VoiceCommandType.startRest:
        return 'Descanso iniciado';
    }
  }

  void _showNotUnderstoodSnackbar(String? transcript) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                transcript != null
                    ? 'No entendido: "$transcript"'
                    : 'No se detectó voz',
                style: GoogleFonts.montserrat(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'REINTENTAR',
          textColor: Colors.orange,
          onPressed: _onTap,
        ),
      ),
    );
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

    final voiceState = ref.watch(vip.voiceInputProvider);
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

/// Overlay modal que muestra la transcripción y CONTEXTO mientras escucha
/// Diseño UX: Muestra claramente qué serie/campo se va a modificar
class _ListeningOverlay extends ConsumerWidget {
  final VoidCallback onDismiss;
  final VoiceTrainingContext? context;

  const _ListeningOverlay({
    required this.onDismiss,
    this.context,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(vip.voiceInputProvider);
    final text = voiceState.partialTranscript.isNotEmpty
        ? voiceState.partialTranscript
        : 'Di: "80 kilos", "10 reps", "RPE 8", "hecho"...';

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onDismiss,
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
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
                        'ESCUCHANDO...',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // CONTEXTO: Qué serie se va a modificar
                  if (this.context != null) ...[
                    _buildContextIndicator(this.context!),
                    const SizedBox(height: 16),
                  ],

                  // Transcripción en tiempo real
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgDeep,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
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
                        if (voiceState.partialTranscript.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const _PulsingDot(color: Colors.green, size: 6),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Comandos disponibles
                  _buildAvailableCommands(),

                  const SizedBox(height: 12),
                  // Hint para cerrar
                  Text(
                    'Toca en cualquier lugar para detener',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
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

  /// Indicador de contexto: muestra qué serie se va a modificar
  Widget _buildContextIndicator(VoiceTrainingContext ctx) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neonCyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.edit_note,
                size: 16,
                color: AppColors.neonCyan.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Text(
                'MODIFICANDO:',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neonCyan,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ctx.exerciseName,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Serie ${ctx.currentSet} de ${ctx.totalSets}',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          // Campos actuales
          Row(
            children: [
              _FieldChip(
                label: 'Peso',
                value: ctx.currentWeight != null
                    ? '${ctx.currentWeight!.toStringAsFixed(1)} kg'
                    : '--',
                isSet: ctx.currentWeight != null,
              ),
              const SizedBox(width: 8),
              _FieldChip(
                label: 'Reps',
                value: ctx.currentReps?.toString() ?? '--',
                isSet: ctx.currentReps != null,
              ),
              const SizedBox(width: 8),
              _FieldChip(
                label: 'RPE',
                value: ctx.currentRpe?.toStringAsFixed(1) ?? '--',
                isSet: ctx.currentRpe != null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Lista de comandos disponibles
  Widget _buildAvailableCommands() {
    return const Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        _CommandHint(label: '80 kilos', icon: Icons.scale),
        _CommandHint(label: '10 reps', icon: Icons.tag),
        _CommandHint(label: 'RPE 8', icon: Icons.speed),
        _CommandHint(label: 'Hecho', icon: Icons.check),
        _CommandHint(label: 'Nota: ...', icon: Icons.note),
      ],
    );
  }
}

/// Chip para mostrar el estado de un campo
class _FieldChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isSet;

  const _FieldChip({
    required this.label,
    required this.value,
    required this.isSet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isSet
            ? AppColors.success.withValues(alpha: 0.2)
            : AppColors.bgDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSet
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: Colors.white54,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isSet ? AppColors.success : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hint de comando disponible
class _CommandHint extends StatelessWidget {
  final String label;
  final IconData icon;

  const _CommandHint({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white38),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}

/// Punto pulsante para indicadores
class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingDot({required this.color, this.size = 8});

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
            color: widget.color.withValues(alpha: 0.5 + _controller.value * 0.5),
            shape: BoxShape.circle,
          ),
        );
      },
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


