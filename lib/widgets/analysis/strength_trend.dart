import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/analysis_models.dart';
import '../../providers/analysis_provider.dart';

/// Line chart showing estimated 1RM trend over time
class StrengthTrend extends ConsumerWidget {
  const StrengthTrend({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedExercise = ref.watch(selectedTrendExerciseProvider);
    final exerciseNamesAsync = ref.watch(exerciseNamesProvider);
    final trendAsync = ref.watch(strengthTrendProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
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
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.green,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'TENDENCIA DE FUERZA',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[400],
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Exercise selector
          exerciseNamesAsync.when(
            data: (exerciseNames) {
              if (exerciseNames.isEmpty) {
                return const SizedBox.shrink();
              }
              return _buildExerciseSelector(ref, selectedExercise, exerciseNames);
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // Chart
          trendAsync.when(
            data: (dataPoints) {
              if (dataPoints.isEmpty) {
                return _buildEmptyState();
              }
              return _buildChart(dataPoints);
            },
            loading: () => _buildLoading(),
            error: (_, __) => _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseSelector(
    WidgetRef ref,
    String? selected,
    List<String> exerciseNames,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected != null && exerciseNames.contains(selected)
              ? selected
              : exerciseNames.isNotEmpty
                  ? exerciseNames.first
                  : null,
          hint: Text(
            'Selecciona ejercicio',
            style: GoogleFonts.montserrat(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[500]),
          dropdownColor: const Color(0xFF252525),
          isExpanded: true,
          items: exerciseNames.map((name) {
            return DropdownMenuItem<String>(
              value: name,
              child: Text(
                name,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              HapticFeedback.selectionClick();
              ref.read(selectedTrendExerciseProvider.notifier).state = value;
            }
          },
        ),
      ),
    );
  }

  Widget _buildChart(List<StrengthDataPoint> dataPoints) {
    // Calculate min/max for Y axis
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final point in dataPoints) {
      if (point.estimated1RM < minY) minY = point.estimated1RM;
      if (point.estimated1RM > maxY) maxY = point.estimated1RM;
    }

    // Add some padding
    final yRange = maxY - minY;
    minY = (minY - yRange * 0.1).clamp(0, double.infinity);
    maxY = maxY + yRange * 0.1;

    // Ensure minimum range
    if (maxY - minY < 10) {
      maxY = minY + 10;
    }

    // Create spots for line chart
    final spots = dataPoints.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.estimated1RM,
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawHorizontalLine: true,
                drawVerticalLine: false,
                horizontalInterval: (maxY - minY) / 4,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey[850]!,
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: (maxY - minY) / 4,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}',
                        style: GoogleFonts.montserrat(
                          color: Colors.grey[600],
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: dataPoints.length > 10
                        ? (dataPoints.length / 5).ceil().toDouble()
                        : 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= dataPoints.length) {
                        return const SizedBox.shrink();
                      }
                      final date = dataPoints[index].date;
                      return Text(
                        '${date.day}/${date.month}',
                        style: GoogleFonts.montserrat(
                          color: Colors.grey[600],
                          fontSize: 9,
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: Colors.redAccent,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.redAccent,
                        strokeWidth: 2,
                        strokeColor: const Color(0xFF1A1A1A),
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.redAccent.withOpacity(0.3),
                        Colors.redAccent.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => const Color(0xFF2A2A2A),
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.spotIndex;
                      final point = dataPoints[index];
                      final dateStr = DateFormat('d MMM', 'es_ES').format(point.date);
                      return LineTooltipItem(
                        '$dateStr\n',
                        GoogleFonts.montserrat(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                        children: [
                          TextSpan(
                            text: '1RM: ${point.estimated1RM.toStringAsFixed(1)}kg',
                            style: GoogleFonts.montserrat(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          TextSpan(
                            text: '\n${point.actualMax.toStringAsFixed(1)}kg x${point.repsAtMax}',
                            style: GoogleFonts.montserrat(
                              color: Colors.grey[500],
                              fontSize: 10,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
            ),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutCubic,
          ),
        ),

        const SizedBox(height: 12),

        // Summary stats
        _buildSummaryStats(dataPoints),
      ],
    );
  }

  Widget _buildSummaryStats(List<StrengthDataPoint> dataPoints) {
    if (dataPoints.length < 2) return const SizedBox.shrink();

    final first = dataPoints.first;
    final last = dataPoints.last;
    final change = last.estimated1RM - first.estimated1RM;
    final percentChange = (change / first.estimated1RM) * 100;
    final isPositive = change >= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isPositive ? Colors.green : Colors.red).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.trending_up : Icons.trending_down,
            color: isPositive ? Colors.green : Colors.red,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPositive
                      ? '¡Progreso detectado!'
                      : 'Revisá tu entrenamiento',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${isPositive ? '+' : ''}${change.toStringAsFixed(1)}kg (${percentChange.toStringAsFixed(1)}%) en ${dataPoints.length} sesiones',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
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
          Icon(
            Icons.show_chart,
            color: Colors.grey[700],
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'Sin datos de progreso',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Selecciona un ejercicio con historial',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      height: 200,
      child: Center(
        child: CircularProgressIndicator(
          color: Colors.redAccent.withOpacity(0.5),
          strokeWidth: 2,
        ),
      ),
    );
  }
}
