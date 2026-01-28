import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../models/analysis_models.dart';
import '../../providers/analysis_provider.dart';
import '../../utils/design_system.dart';

/// Horizontal list showing muscle group recovery status
class RecoveryMonitor extends ConsumerWidget {
  const RecoveryMonitor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recoveryAsync = ref.watch(muscleRecoveryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.battery_charging_full,
                  color: Colors.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'MONITOR DE RECUPERACIÓN',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Recovery cards
        recoveryAsync.when(
          data: (recoveries) {
            if (recoveries.isEmpty) {
              return _buildEmptyState();
            }
            return _buildRecoveryList(recoveries);
          },
          loading: () => _buildLoading(),
          error: (_, __) => _buildEmptyState(),
        ),
      ],
    );
  }

  Widget _buildRecoveryList(List<MuscleRecovery> recoveries) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: recoveries.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 8,
              right: index == recoveries.length - 1 ? 0 : 0,
            ),
            child: _RecoveryCard(recovery: recoveries[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDeep),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.fitness_center,
            color: AppColors.border,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Entrena para ver tu recuperación',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  final MuscleRecovery recovery;

  const _RecoveryCard({required this.recovery});

  @override
  Widget build(BuildContext context) {
    final status = recovery.status;

    // Calculate recovery percentage (inverted - 0-2 days = low, 5+ days = full)
    double recoveryPercent;
    if (recovery.daysSinceTraining >= 5) {
      recoveryPercent = 1.0;
    } else if (recovery.daysSinceTraining <= 0) {
      recoveryPercent = 0.0;
    } else {
      recoveryPercent = recovery.daysSinceTraining / 5.0;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showRecoveryDetail(context);
      },
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              status.color.withValues(alpha: 0.15),
              const Color(0xFF1A1A1A),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status.color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Muscle icon/name
            Row(
              children: [
                Text(
                  _getMuscleEmoji(recovery.muscleName),
                  style: const TextStyle(fontSize: 16),
                ),
                const Spacer(),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: status.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: status.color.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Muscle name
            Text(
              recovery.displayName.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const Spacer(),

            // Recovery bar
            LinearPercentIndicator(
              padding: EdgeInsets.zero,
              lineHeight: 4,
              percent: recoveryPercent,
              backgroundColor: AppColors.bgDeep,
              linearGradient: LinearGradient(
                colors: [
                  status.color.withValues(alpha: 0.7),
                  status.color,
                ],
              ),
              barRadius: const Radius.circular(2),
            ),

            const SizedBox(height: 8),

            // Days count & status
            Row(
              children: [
                Text(
                  recovery.daysSinceTraining >= 999
                      ? '--'
                      : '${recovery.daysSinceTraining}d',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: status.color,
                  ),
                ),
                const Spacer(),
                Text(
                  status.emoji,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRecoveryDetail(BuildContext context) {
    final status = recovery.status;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Muscle info
              Row(
                children: [
                  Text(
                    _getMuscleEmoji(recovery.muscleName),
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recovery.displayName,
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: status.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              status.label.toUpperCase(),
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: status.color,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Días desde último entreno',
                      recovery.daysSinceTraining >= 999
                          ? 'Nunca entrenado'
                          : '${recovery.daysSinceTraining} días',
                    ),
                    const Divider(color: Color(0xFF2A2A2A), height: 24),
                    _buildDetailRow(
                      'Estado de recuperación',
                      _getRecoveryAdvice(status),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Recommendation
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: status.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getRecommendationIcon(status),
                      color: status.color,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getRecommendation(status),
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: Colors.grey[300],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            color: AppColors.textTertiary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  String _getMuscleEmoji(String muscle) {
    switch (muscle.toLowerCase()) {
      case 'pecho':
        return '🫁';
      case 'espalda':
        return '🔙';
      case 'piernas':
        return '🦵';
      case 'hombros':
        return '🤷';
      case 'brazos':
        return '💪';
      case 'core':
        return '🎯';
      default:
        return '💪';
    }
  }

  String _getRecoveryAdvice(RecoveryStatus status) {
    switch (status) {
      case RecoveryStatus.recovering:
        return 'Necesita descanso';
      case RecoveryStatus.ready:
        return 'Listo para entrenar';
      case RecoveryStatus.fresh:
        return 'Completamente fresco';
    }
  }

  IconData _getRecommendationIcon(RecoveryStatus status) {
    switch (status) {
      case RecoveryStatus.recovering:
        return Icons.hotel;
      case RecoveryStatus.ready:
        return Icons.thumb_up;
      case RecoveryStatus.fresh:
        return Icons.flash_on;
    }
  }

  String _getRecommendation(RecoveryStatus status) {
    switch (status) {
      case RecoveryStatus.recovering:
        return 'Este músculo aún se está recuperando. Considera entrenar otro grupo muscular hoy.';
      case RecoveryStatus.ready:
        return 'Buen momento para entrenar este músculo. La recuperación está casi completa.';
      case RecoveryStatus.fresh:
        return '¡Hora de atacar! Este músculo está completamente recuperado y listo para el máximo esfuerzo.';
    }
  }
}
