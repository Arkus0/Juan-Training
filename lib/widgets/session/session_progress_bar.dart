import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/session_progress_provider.dart';
import '../../utils/design_system.dart';

/// 🎯 NEON IRON: Barra de progreso ultra-mínima
///
/// Principios aplicados:
/// - ≤4 chunks: Solo 1 elemento visual (la barra)
/// - Sin texto: El progreso se comunica visualmente
/// - No compite: Solo 4px de altura, integrada sutilmente
/// - Color semántico: Cyan progreso → Gold completado
class SessionProgressBar extends ConsumerWidget {
  const SessionProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(sessionProgressProvider);

    // No mostrar si no hay ejercicios
    if (progress.totalSets == 0) {
      return const SizedBox.shrink();
    }

    return _MinimalProgressLine(
      percentage: progress.percentage,
      isComplete: progress.isComplete,
    );
  }
}

/// Línea de progreso ultra-mínima (4px)
class _MinimalProgressLine extends StatelessWidget {
  final double percentage;
  final bool isComplete;

  const _MinimalProgressLine({
    required this.percentage,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    // Color: Cyan durante progreso, Gold al completar
    final color = isComplete ? AppColors.goldAccent : AppColors.neonCyan;

    return SizedBox(
      height: 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Fondo sutil
              Container(
                color: AppColors.bgElevated,
              ),
              // Barra de progreso animada
              AnimatedContainer(
                duration: AppDurations.medium,
                curve: Curves.easeOutCubic,
                width: constraints.maxWidth * percentage.clamp(0.0, 1.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color,
                      color.withValues(alpha: 0.7),
                    ],
                  ),
                  boxShadow: isComplete
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// LEGACY WIDGETS - Para compatibilidad con SessionProgressBarExpanded
// ============================================================

/// Texto del porcentaje con animación
class _PercentageText extends StatelessWidget {
  final double percentage;
  final bool isComplete;

  const _PercentageText({
    required this.percentage,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    final color = isComplete ? AppColors.goldAccent :
                  percentage >= 0.75 ? AppColors.neonCyan : AppColors.textPrimary;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percentage * 100),
      duration: AppDurations.medium,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          '${value.round()}%',
          style: AppTypography.dataLarge.copyWith(color: color),
        );
      },
    );
  }
}

/// Info de series completadas
class _SetsInfo extends StatelessWidget {
  final int completed;
  final int total;

  const _SetsInfo({
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.fitness_center,
          size: 12,
          color: AppColors.textTertiary,
        ),
        const SizedBox(width: 4),
        Text(
          '$completed/$total',
          style: AppTypography.meta.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Barra de fondo con gradiente animado (para versión expandida)
class _AnimatedProgressFill extends StatelessWidget {
  final double percentage;
  final bool isComplete;

  const _AnimatedProgressFill({
    required this.percentage,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    final color = isComplete ? AppColors.goldAccent : AppColors.neonCyan;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(color: AppColors.bgElevated),
            AnimatedContainer(
              duration: AppDurations.medium,
              curve: Curves.easeOutCubic,
              width: constraints.maxWidth * percentage.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: AppDurations.medium,
                height: 3,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
                      boxShadow: isComplete
                          ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Versión expandida de la barra de progreso con detalles de superseries
/// (Usada en contextos donde se necesita info detallada)
class SessionProgressBarExpanded extends ConsumerWidget {
  const SessionProgressBarExpanded({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(sessionProgressProvider);

    if (progress.totalSets == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con porcentaje
          Row(
            children: [
              _PercentageText(
                percentage: progress.percentage,
                isComplete: progress.isComplete,
              ),
              const SizedBox(width: 8),
              Text('completado', style: AppTypography.meta),
              const Spacer(),
              _SetsInfo(
                completed: progress.completedSets,
                total: progress.totalSets,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Barra de progreso horizontal
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: SizedBox(
              height: 8,
              child: _AnimatedProgressFill(
                percentage: progress.percentage,
                isComplete: progress.isComplete,
              ),
            ),
          ),

          // Info de superseries si hay
          if (progress.supersets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'SUPERSERIES',
              style: AppTypography.labelEmphasis.copyWith(
                color: AppColors.goldAccent,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            ...progress.supersets.map((ss) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        ss.isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 12,
                        color: ss.isComplete ? AppColors.neonCyan : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ss.exerciseNames.join(' + '),
                          style: AppTypography.meta.copyWith(color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${ss.completedRounds}/${ss.totalRounds}',
                        style: AppTypography.labelEmphasis.copyWith(
                          color: ss.isComplete ? AppColors.neonCyan : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
