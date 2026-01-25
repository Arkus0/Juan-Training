import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/voice_action.dart';
import '../../utils/design_system.dart';

/// Muestra un snackbar con opción de deshacer después de una acción por voz
///
/// Principio UX: Toda acción por voz debe ser reversible.
/// El snackbar permanece 5 segundos con opción de DESHACER.
class VoiceUndoSnackbar {
  /// Muestra el snackbar de undo para una acción de voz
  static void show(
    BuildContext context, {
    required VoiceAction action,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 5),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getIconForAction(action.type),
              color: AppColors.neonCyan,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Por voz:',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                  Text(
                    action.description,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.3)),
        ),
        duration: duration,
        action: SnackBarAction(
          label: 'DESHACER',
          textColor: AppColors.warning,
          onPressed: onUndo,
        ),
      ),
    );
  }

  /// Muestra snackbar simple de éxito sin undo
  static void showSuccess(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle_outline,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: AppColors.success, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Muestra snackbar de error/no entendido
  static void showNotUnderstood(
    BuildContext context, {
    required String message,
    VoidCallback? onRetry,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        action: onRetry != null
            ? SnackBarAction(
                label: 'REINTENTAR',
                textColor: Colors.orange,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  static IconData _getIconForAction(VoiceActionType type) {
    switch (type) {
      case VoiceActionType.setWeight:
        return Icons.scale;
      case VoiceActionType.setReps:
        return Icons.tag;
      case VoiceActionType.setRpe:
        return Icons.speed;
      case VoiceActionType.addNote:
        return Icons.note;
      case VoiceActionType.markDone:
        return Icons.check_circle;
      case VoiceActionType.nextSet:
        return Icons.skip_next;
      case VoiceActionType.addExercise:
        return Icons.add_circle;
      case VoiceActionType.removeExercise:
        return Icons.remove_circle;
      default:
        // Fallback seguro (no debería llegar aquí si enum es exhaustivo)
        return Icons.help_outline;
    }
  }
}
