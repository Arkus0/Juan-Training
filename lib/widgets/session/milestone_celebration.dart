/// ============================================================================
/// SISTEMA DE MICRO-CELEBRACIONES — Dark Tech Performance
/// ============================================================================
///
/// Implementa feedback visceral pero CONTENIDO para hitos de progreso.
///
/// PRINCIPIOS:
/// - Celebraciones BREVES, no exageradas
/// - Oro cálido para logros (sutil, no brillante)
/// - Haptic feedback progresivo
/// - Auto-cierre rápido (no interrumpir flujo)
///
/// Hitos:
/// - 25%: Vibración ligera + toast sutil
/// - 50%: Vibración media + toast motivador
/// - 75%: Vibración fuerte + toast de ánimo
/// - 100%: Vibración + celebración contenida (2s máx)
/// ============================================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/design_system.dart';

/// Controlador de celebraciones de hitos
class MilestoneCelebrationController {
  // Tracks which milestones have been shown to avoid repeats
  final Set<int> _shownMilestones = {};

  /// Verifica si un hito debe mostrarse y lo marca como mostrado
  bool shouldShowMilestone(int percentage) {
    final milestones = [25, 50, 75, 100];
    final milestone = milestones.firstWhere(
      (m) => percentage >= m && !_shownMilestones.contains(m),
      orElse: () => -1,
    );

    if (milestone != -1) {
      _shownMilestones.add(milestone);
      return true;
    }
    return false;
  }

  /// Obtiene el hito alcanzado
  int? getMilestoneReached(int percentage) {
    if (percentage >= 100 && !_shownMilestones.contains(100)) return 100;
    if (percentage >= 75 && !_shownMilestones.contains(75)) return 75;
    if (percentage >= 50 && !_shownMilestones.contains(50)) return 50;
    if (percentage >= 25 && !_shownMilestones.contains(25)) return 25;
    return null;
  }

  /// Resetea los hitos mostrados (para nueva sesión)
  void reset() {
    _shownMilestones.clear();
  }
}

/// Muestra una micro-celebración para un hito
void showMilestoneCelebration(BuildContext context, int milestone) {
  // Haptic feedback escalado según importancia
  switch (milestone) {
    case 25:
      HapticFeedback.lightImpact();
      _showMicroToast(context, '¡25% completado!', Icons.fitness_center);
      break;
    case 50:
      HapticFeedback.mediumImpact();
      _showMicroToast(context, '¡Mitad del camino! 💪', Icons.trending_up);
      break;
    case 75:
      HapticFeedback.heavyImpact();
      _showMicroToast(
          context, '¡Ya casi lo tienes! 🔥', Icons.local_fire_department,);
      break;
    case 100:
      HapticFeedback.vibrate();
      _showCompletionCelebration(context);
      break;
  }
}

/// Toast no invasivo (aparece arriba, desaparece rápido)
void _showMicroToast(BuildContext context, String message, IconData icon) {
  final overlay = Overlay.of(context);

  final overlayEntry = OverlayEntry(
    builder: (context) => _MicroToast(
      message: message,
      icon: icon,
    ),
  );

  overlay.insert(overlayEntry);

  // Remover después de 1.5 segundos
  Future.delayed(const Duration(milliseconds: 1500), () {
    overlayEntry.remove();
  });
}

/// Celebración completa al terminar sesión
void _showCompletionCelebration(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => const _CompletionCelebrationDialog(),
  );

  // Auto-cerrar después de 2 segundos
  Future.delayed(const Duration(milliseconds: 2000), () {
    if (!context.mounted) return;
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  });
}

/// Widget de micro-toast
class _MicroToast extends StatefulWidget {
  final String message;
  final IconData icon;

  const _MicroToast({
    required this.message,
    required this.icon,
  });

  @override
  State<_MicroToast> createState() => _MicroToastState();
}

class _MicroToastState extends State<_MicroToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    // Fade out después de 1 segundo
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 100,
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                // Verde apagado para completado, sutil
                color: AppColors.completedGreen.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppRadius.round),
                boxShadow: AppShadows.elevated,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    color: AppColors.textOnAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.message,
                    style: AppTypography.button.copyWith(
                      color: AppColors.textOnAccent,
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

/// Diálogo de celebración al completar sesión
class _CompletionCelebrationDialog extends StatefulWidget {
  const _CompletionCelebrationDialog();

  @override
  State<_CompletionCelebrationDialog> createState() =>
      _CompletionCelebrationDialogState();
}

class _CompletionCelebrationDialogState
    extends State<_CompletionCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              // Oro cálido sutil para celebración final
              border: Border.all(
                color: AppColors.goldAccent.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: AppShadows.glow(AppColors.goldAccent),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono animado - Oro para logro
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.goldSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    size: 64,
                    color: AppColors.goldAccent,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  '¡SESIÓN COMPLETADA!',
                  style: AppTypography.hero.copyWith(
                    fontSize: 22,
                    color: AppColors.goldAccent,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'Gran trabajo 💪',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget para mostrar PR (Personal Record) - ORO SUTIL
class PRCelebration extends StatelessWidget {
  final String exerciseName;
  final String improvement;

  const PRCelebration({
    super.key,
    required this.exerciseName,
    required this.improvement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        // Oro sutil, no brillante
        color: AppColors.goldSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.goldAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            color: AppColors.goldAccent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '¡NUEVO PR!',
                style: AppTypography.badge.copyWith(
                  color: AppColors.goldAccent,
                ),
              ),
              Text(
                improvement,
                style: AppTypography.meta.copyWith(
                  color: AppColors.goldDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
