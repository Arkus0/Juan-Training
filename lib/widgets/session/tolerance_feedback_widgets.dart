import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/error_tolerance_system.dart';
import '../../utils/design_system.dart';

// ════════════════════════════════════════════════════════════════════════════
// TOLERANCE FEEDBACK WIDGETS
// ════════════════════════════════════════════════════════════════════════════
//
// Widgets para mostrar feedback empático basado en ERROR_TOLERANCE_DESIGN.md:
// - Bienvenida tras días sin entrenar
// - Confirmación de datos sospechosos
// - Feedback de día difícil
//
// Filosofía: El sistema es más tolerante que un entrenador humano.
// NUNCA castigar, NUNCA perder credibilidad.
//
// ════════════════════════════════════════════════════════════════════════════

/// Banner de bienvenida después de días sin entrenar
class WelcomeBackBanner extends StatelessWidget {
  final SessionGapResult result;
  final VoidCallback onDismiss;
  final VoidCallback? onAcceptSuggestion;
  final VoidCallback? onKeepOriginal;

  const WelcomeBackBanner({
    super.key,
    required this.result,
    required this.onDismiss,
    this.onAcceptSuggestion,
    this.onKeepOriginal,
  });

  @override
  Widget build(BuildContext context) {
    final message = result.message ?? '¡De vuelta!';
    final showButtons = result.isReductionSuggested && 
                        result.originalWeight != null &&
                        result.originalWeight! > 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.waving_hand_rounded,
                  color: AppColors.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '¡BIENVENIDO DE VUELTA!',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 20),
                color: AppColors.textTertiary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (result.requiresRecalibration) ...[
            const SizedBox(height: 8),
            Text(
              'Es normal perder algo de fuerza. Lo recuperarás rápido.',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (showButtons) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onKeepOriginal?.call();
                      onDismiss();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'MANTENER ${_fmt(result.originalWeight!)}KG',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onAcceptSuggestion?.call();
                      onDismiss();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'USAR ${_fmt(result.adjustedWeight)}KG',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(double w) => w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
}

/// Diálogo de confirmación para datos sospechosos
/// Ej: "¿Quisiste decir 50kg?" cuando el usuario pone 500kg
class SuspiciousDataDialog extends StatelessWidget {
  final String exerciseName;
  final double enteredWeight;
  final double suggestedWeight;
  final VoidCallback onConfirmOriginal;
  final VoidCallback onUseSuggested;

  const SuspiciousDataDialog({
    super.key,
    required this.exerciseName,
    required this.enteredWeight,
    required this.suggestedWeight,
    required this.onConfirmOriginal,
    required this.onUseSuggested,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.help_outline_rounded,
            color: AppColors.warning,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '¿QUISISTE DECIR...?',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exerciseName,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _WeightOption(
                weight: suggestedWeight,
                label: 'SUGERIDO',
                isRecommended: true,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop();
                  onUseSuggested();
                },
              ),
              const SizedBox(width: 16),
              _WeightOption(
                weight: enteredWeight,
                label: 'ORIGINAL',
                isRecommended: false,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).pop();
                  onConfirmOriginal();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Si ${_fmt(enteredWeight)}kg es correcto, confiaremos en ti.',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _fmt(double w) => w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
}

class _WeightOption extends StatelessWidget {
  final double weight;
  final String label;
  final bool isRecommended;
  final VoidCallback onTap;

  const _WeightOption({
    required this.weight,
    required this.label,
    required this.isRecommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isRecommended 
              ? AppColors.success.withOpacity(0.15)
              : AppColors.bgInteractive,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRecommended 
                ? AppColors.success.withOpacity(0.5)
                : AppColors.border,
            width: isRecommended ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '${weight.toInt()}',
              style: GoogleFonts.montserrat(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: isRecommended ? AppColors.success : AppColors.textPrimary,
              ),
            ),
            Text(
              'KG',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isRecommended ? AppColors.success : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner de día difícil (se muestra al terminar un ejercicio con bajo rendimiento)
class DifficultDayBanner extends StatelessWidget {
  final BadDayResult result;
  final VoidCallback onDismiss;

  const DifficultDayBanner({
    super.key,
    required this.result,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textTertiary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getIcon(),
            color: _getColor(),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              result.message ?? 'Día difícil. No afecta tu progreso.',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.textTertiary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    if (result.suggestDeload) return Icons.trending_down_rounded;
    if (result.isBadDay) return Icons.sentiment_neutral_rounded;
    return Icons.check_circle_outline_rounded;
  }

  Color _getColor() {
    if (result.suggestDeload) return AppColors.warning;
    if (result.isBadDay) return AppColors.textSecondary;
    return AppColors.success;
  }
}

/// Snackbar helper para mostrar mensajes de tolerancia
void showToleranceSnackBar(BuildContext context, String message, {bool isPositive = true}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: GoogleFonts.montserrat(
          fontSize: 13,
          color: Colors.white,
        ),
      ),
      backgroundColor: isPositive ? AppColors.success : AppColors.bgElevated,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

/// Muestra el diálogo de datos sospechosos
Future<void> showSuspiciousDataDialog(
  BuildContext context, {
  required String exerciseName,
  required double enteredWeight,
  required double suggestedWeight,
  required VoidCallback onConfirmOriginal,
  required VoidCallback onUseSuggested,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => SuspiciousDataDialog(
      exerciseName: exerciseName,
      enteredWeight: enteredWeight,
      suggestedWeight: suggestedWeight,
      onConfirmOriginal: onConfirmOriginal,
      onUseSuggested: onUseSuggested,
    ),
  );
}
