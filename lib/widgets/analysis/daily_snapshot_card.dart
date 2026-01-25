import '../../utils/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/analysis_models.dart';
import '../../providers/analysis_provider.dart';

/// Shows summary of training for selected date
class DailySnapshotCard extends ConsumerWidget {
  const DailySnapshotCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(dailySnapshotProvider);
    final selectedDate = ref.watch(selectedCalendarDateProvider);

    if (selectedDate == null) {
      return const SizedBox.shrink();
    }

    return snapshotAsync.when(
      data: (snapshot) {
        if (snapshot == null) {
          return _buildNoTraining(selectedDate);
        }
        return _buildSnapshot(context, snapshot);
      },
      loading: () => _buildLoading(),
      error: (_, __) => _buildNoTraining(selectedDate),
    );
  }

  Widget _buildSnapshot(BuildContext context, DailySnapshot snapshot) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E1E1E),
            Color(0xFF1A1A1A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha:0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM', 'es_ES').format(snapshot.date).toUpperCase(),
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                        letterSpacing: 1,
                      ),
                    ),
                    if (snapshot.dayName != null)
                      Text(
                        snapshot.dayName!,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _buildStat(
                icon: Icons.monitor_weight_outlined,
                value: snapshot.formattedVolume,
                label: 'VOLUMEN',
              ),
              const SizedBox(width: 16),
              _buildStat(
                icon: Icons.timer_outlined,
                value: snapshot.formattedDuration,
                label: 'DURACIÓN',
              ),
              const SizedBox(width: 16),
              _buildStat(
                icon: Icons.check_circle_outline,
                value: '${snapshot.setsCompleted}',
                label: 'SERIES',
              ),
            ],
          ),

          // Best set highlight
          if (snapshot.bestSet != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amber.withValues(alpha:0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MEJOR SET',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          snapshot.bestSet!.formatted,
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
            ),
          ],

          // Exercise list
          if (snapshot.exerciseNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: snapshot.exerciseNames.take(5).map((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    name,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (snapshot.exerciseNames.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${snapshot.exerciseNames.length - 5} más',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.textTertiary, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTraining(DateTime date) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDeep),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_busy,
            color: AppColors.textTertiary,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            'Sin entrenamiento',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          Text(
            DateFormat('d MMM yyyy', 'es_ES').format(date),
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
    return Container(
      height: 100,
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
