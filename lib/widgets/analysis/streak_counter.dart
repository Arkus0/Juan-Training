import '../../utils/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/analysis_models.dart';
import '../../providers/analysis_provider.dart';

/// Displays current training streak with fire emoji
class StreakCounter extends ConsumerWidget {
  const StreakCounter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakDataProvider);

    return streakAsync.when(
      data: (streak) => _buildContent(context, streak),
      loading: () => _buildLoading(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildContent(BuildContext context, StreakData streak) {
    final hasStreak = streak.currentStreak > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: hasStreak
            ? LinearGradient(
                colors: [
                  AppColors.fireRed.withValues(alpha:0.2),   // #FF3333
                  AppColors.bloodRed.withValues(alpha:0.1),  // #C41E3A
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: hasStreak ? null : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasStreak
              ? AppColors.fireRed.withValues(alpha:0.4)  // Glow rojo
              : AppColors.bgDeep,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Fire icon with glow effect
          if (hasStreak) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.fireRedGlow,  // Glow rojo intenso
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                '🔥',
                style: TextStyle(fontSize: hasStreak ? 28 : 20),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Streak info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${streak.currentStreak}',
                      style: GoogleFonts.montserrat(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: hasStreak ? AppColors.textPrimary : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      streak.currentStreak == 1 ? 'DÍA' : 'DÍAS',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: hasStreak ? AppColors.textSecondary : AppColors.textTertiary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasStreak
                      ? 'Racha actual'
                      : streak.lastTrainingDate != null
                          ? 'Sin racha activa'
                          : 'Comienza tu racha hoy',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Best streak badge
          if (streak.longestStreak > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.bgDeep,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${streak.longestStreak}',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: streak.currentStreak >= streak.longestStreak
                          ? AppColors.fireRed  // Highlight cuando iguala récord
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'RÉCORD',
                    style: GoogleFonts.montserrat(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.redAccent,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

/// Compact version for inline display
class StreakBadge extends ConsumerWidget {
  const StreakBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakDataProvider);

    return streakAsync.when(
      data: (streak) {
        if (streak.currentStreak == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.withValues(alpha:0.3),
                Colors.red.withValues(alpha:0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '${streak.currentStreak}',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
