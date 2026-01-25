import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/noise_detection_service.dart';
import '../../utils/design_system.dart';

/// Banner de sugerencia de fallback cuando hay problemas de ruido.
///
/// Muestra opciones alternativas cuando la voz no funciona bien.
class VoiceFallbackBanner extends StatelessWidget {
  final AudioQuality quality;
  final VoidCallback? onRetry;
  final VoidCallback? onSwitchToText;
  final VoidCallback? onSwitchToManual;
  final VoidCallback? onDismiss;

  const VoiceFallbackBanner({
    super.key,
    required this.quality,
    this.onRetry,
    this.onSwitchToText,
    this.onSwitchToManual,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (quality == AudioQuality.excellent || quality == AudioQuality.good) {
      return const SizedBox.shrink();
    }

    final isWarning = quality == AudioQuality.fair;
    final backgroundColor = isWarning
        ? Colors.amber.withValues(alpha: 0.15)
        : AppColors.error.withValues(alpha: 0.15);
    final borderColor = isWarning
        ? Colors.amber.withValues(alpha: 0.5)
        : AppColors.error.withValues(alpha: 0.5);
    final iconColor = isWarning ? Colors.amber : AppColors.error;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isWarning ? Icons.warning_amber : Icons.error_outline,
                color: iconColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isWarning
                      ? 'Ambiente ruidoso detectado'
                      : 'Dificultad para reconocer voz',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, size: 18),
                  color: Colors.white54,
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isWarning
                ? 'Intenta hablar más cerca del micrófono o usa otro método.'
                : 'Después de varios intentos fallidos, te recomendamos usar texto o entrada manual.',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (onRetry != null) ...[
                _FallbackButton(
                  icon: Icons.refresh,
                  label: 'Reintentar',
                  onTap: onRetry!,
                  isPrimary: isWarning,
                ),
                const SizedBox(width: 8),
              ],
              if (onSwitchToText != null) ...[
                _FallbackButton(
                  icon: Icons.keyboard,
                  label: 'Texto',
                  onTap: onSwitchToText!,
                  isPrimary: !isWarning,
                ),
                const SizedBox(width: 8),
              ],
              if (onSwitchToManual != null)
                _FallbackButton(
                  icon: Icons.touch_app,
                  label: 'Manual',
                  onTap: onSwitchToManual!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FallbackButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _FallbackButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.neonCyan.withValues(alpha: 0.2)
              : AppColors.bgDeep,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPrimary
                ? AppColors.neonCyan.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isPrimary ? AppColors.neonCyan : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isPrimary ? AppColors.neonCyan : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicador de confianza visual.
///
/// Muestra un icono/badge con el nivel de confianza de una detección.
class ConfidenceIndicator extends StatelessWidget {
  final double confidence;
  final bool showPercentage;
  final double size;

  const ConfidenceIndicator({
    super.key,
    required this.confidence,
    this.showPercentage = true,
    this.size = 24,
  });

  Color get _color {
    if (confidence >= 0.8) return AppColors.neonCyan;
    if (confidence >= 0.6) return Colors.amber;
    return AppColors.error;
  }

  IconData get _icon {
    if (confidence >= 0.8) return Icons.check_circle;
    if (confidence >= 0.6) return Icons.help;
    return Icons.error;
  }

  String get _label {
    if (confidence >= 0.8) return 'Alta';
    if (confidence >= 0.6) return 'Media';
    return 'Baja';
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Confianza: $_label (${(confidence * 100).toInt()}%)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: size * 0.6, color: _color),
            if (showPercentage) ...[
              const SizedBox(width: 4),
              Text(
                '${(confidence * 100).toInt()}%',
                style: GoogleFonts.montserrat(
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.bold,
                  color: _color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Barra de confianza horizontal.
class ConfidenceBar extends StatelessWidget {
  final double confidence;
  final double height;

  const ConfidenceBar({
    super.key,
    required this.confidence,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    if (confidence >= 0.8) {
      color = AppColors.neonCyan;
    } else if (confidence >= 0.6) {
      color = Colors.amber;
    } else {
      color = AppColors.error;
    }

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: confidence,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

/// Snackbar de undo para acciones de voz.
class VoiceUndoSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 10),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.neonCyan, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.montserrat(color: Colors.white),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'DESHACER',
          textColor: AppColors.neonCyan,
          onPressed: onUndo,
        ),
        duration: duration,
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

/// Widget de estado de escucha con indicadores claros.
class VoiceListeningStatus extends StatelessWidget {
  final bool isListening;
  final bool isProcessing;
  final bool hasError;
  final String? errorMessage;
  final String? partialTranscript;

  const VoiceListeningStatus({
    super.key,
    required this.isListening,
    this.isProcessing = false,
    this.hasError = false,
    this.errorMessage,
    this.partialTranscript,
  });

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return _buildErrorState();
    }

    if (isProcessing) {
      return _buildProcessingState();
    }

    if (isListening) {
      return _buildListeningState();
    }

    return _buildIdleState();
  }

  Widget _buildIdleState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_none, color: Colors.white54, size: 20),
          const SizedBox(width: 8),
          Text(
            'Pulsa para hablar',
            style: GoogleFonts.montserrat(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _AnimatedMicIcon(),
              const SizedBox(width: 8),
              Text(
                'Escuchando...',
                style: GoogleFonts.montserrat(
                  color: AppColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (partialTranscript != null && partialTranscript!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              partialTranscript!,
              style: GoogleFonts.montserrat(
                color: Colors.white70,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProcessingState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Procesando...',
            style: GoogleFonts.montserrat(
              color: Colors.amber,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              errorMessage ?? 'No entendido',
              style: GoogleFonts.montserrat(
                color: Colors.orange,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedMicIcon extends StatefulWidget {
  const _AnimatedMicIcon();

  @override
  State<_AnimatedMicIcon> createState() => _AnimatedMicIconState();
}

class _AnimatedMicIconState extends State<_AnimatedMicIcon>
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
          color: AppColors.error.withValues(alpha: 0.5 + _controller.value * 0.5),
          size: 20,
        );
      },
    );
  }
}

/// Límites claros del sistema de voz.
class VoiceLimitsInfo extends StatelessWidget {
  final bool compact;

  const VoiceLimitsInfo({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgDeep,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 14, color: AppColors.neonCyan),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'La voz captura: nombre, series, reps, peso',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.neonCyan, size: 18),
              const SizedBox(width: 8),
              Text(
                'Qué puede hacer la voz',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCapability(Icons.check, 'Nombre del ejercicio', true),
          _buildCapability(Icons.check, 'Series y repeticiones', true),
          _buildCapability(Icons.check, 'Peso en kg', true),
          _buildCapability(Icons.check, 'Notas simples', true),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border),
          const SizedBox(height: 8),
          _buildCapability(Icons.close, 'Detalles avanzados (editar después)', false),
          _buildCapability(Icons.close, 'Ejercicios muy específicos', false),
        ],
      ),
    );
  }

  Widget _buildCapability(IconData icon, String text, bool supported) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: supported ? AppColors.neonCyan : Colors.white38,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: supported ? Colors.white70 : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}
