import '../../utils/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/analysis_models.dart';
import '../../providers/analysis_provider.dart';

/// Spider/Radar chart showing muscle volume balance
class SymmetryRadar extends ConsumerWidget {
  const SymmetryRadar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symmetryAsync = ref.watch(symmetryDataProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.radar,
                  color: Colors.purple,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'RADAR DE SIMETRÍA',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              // Imbalance warning
              symmetryAsync.when(
                data: (data) {
                  if (data.hasImbalance) {
                    return Tooltip(
                      message: data.imbalanceWarnings.join('\n'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha:0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Desequilibrio',
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'Volumen últimos 30 días',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),

          const SizedBox(height: 16),

          // Radar Chart
          symmetryAsync.when(
            data: (data) => _buildRadarChart(data),
            loading: () => _buildLoading(),
            error: (_, __) => _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarChart(SymmetryData data) {
    if (data.volumes.isEmpty) {
      return _buildEmptyState();
    }

    // Prepare data for radar chart
    const muscleGroups = kMuscleGroups;
    final values = muscleGroups.map((m) {
      return data.getNormalized(m);
    }).toList();

    // Check if all values are 0
    final hasData = values.any((v) => v > 0);
    if (!hasData) {
      return _buildEmptyState();
    }

    return SizedBox(
      height: 250,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              dataEntries: values.map((v) => RadarEntry(value: v * 100)).toList(),
              fillColor: Colors.redAccent.withValues(alpha:0.3),
              borderColor: Colors.redAccent,
              borderWidth: 2,
              entryRadius: 3,
            ),
          ],
          radarShape: RadarShape.polygon,
          radarBorderData: const BorderSide(color: Colors.transparent),
          tickCount: 4,
          ticksTextStyle: const TextStyle(
            color: Colors.transparent,
            fontSize: 10,
          ),
          tickBorderData: const BorderSide(
            color: AppColors.bgDeep,
            width: 1,
          ),
          gridBorderData: const BorderSide(
            color: AppColors.bgDeep,
            width: 1,
          ),
          titleTextStyle: GoogleFonts.montserrat(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          getTitle: (index, angle) {
            final muscle = muscleGroups[index];
            final volume = data.volumes[muscle];
            final volumeStr = volume != null
                ? '\n${(volume.totalVolume / 1000).toStringAsFixed(1)}t'
                : '';
            return RadarChartTitle(
              text: '$muscle$volumeStr',
              angle: 0,
            );
          },
          titlePositionPercentageOffset: 0.15,
          radarBackgroundColor: Colors.transparent,
        ),
        swapAnimationDuration: const Duration(milliseconds: 400),
        swapAnimationCurve: Curves.easeInOutCubic,
      ),
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      height: 250,
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.redAccent.withValues(alpha:0.5),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.radar,
            color: AppColors.border,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin datos de entrenamiento',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Entrena para ver tu equilibrio muscular',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: AppColors.border,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact version for dashboard
class SymmetryRadarCompact extends ConsumerWidget {
  const SymmetryRadarCompact({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symmetryAsync = ref.watch(symmetryDataProvider);

    return symmetryAsync.when(
      data: (data) {
        if (data.volumes.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Mini radar
              SizedBox(
                width: 80,
                height: 80,
                child: RadarChart(
                  RadarChartData(
                    dataSets: [
                      RadarDataSet(
                        dataEntries: kMuscleGroups
                            .map((m) => RadarEntry(value: data.getNormalized(m) * 100))
                            .toList(),
                        fillColor: Colors.redAccent.withValues(alpha:0.3),
                        borderColor: Colors.redAccent,
                        borderWidth: 1.5,
                        entryRadius: 2,
                      ),
                    ],
                    radarShape: RadarShape.polygon,
                    radarBorderData: const BorderSide(color: Colors.transparent),
                    tickCount: 2,
                    ticksTextStyle: const TextStyle(color: Colors.transparent),
                    tickBorderData: const BorderSide(
                      color: AppColors.bgDeep,
                      width: 0.5,
                    ),
                    gridBorderData: const BorderSide(
                      color: AppColors.bgDeep,
                      width: 0.5,
                    ),
                    getTitle: (_, __) => const RadarChartTitle(text: ''),
                    radarBackgroundColor: Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simetría',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (data.hasImbalance)
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              data.imbalanceWarnings.first,
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: Colors.amber,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Equilibrado',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                  ],
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
