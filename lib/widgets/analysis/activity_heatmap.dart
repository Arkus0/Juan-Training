import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/analysis_models.dart';
import '../../providers/analysis_provider.dart';
import '../../utils/design_system.dart';

/// GitHub-style activity heatmap for training consistency visualization
class ActivityHeatmap extends ConsumerStatefulWidget {
  final Function(DateTime)? onDayTap;

  const ActivityHeatmap({super.key, this.onDayTap});

  @override
  ConsumerState<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends ConsumerState<ActivityHeatmap> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Scroll to current week after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentWeek();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentWeek() {
    if (!_scrollController.hasClients) return;

    final now = DateTime.now();
    final startOfYear = DateTime(now.year);
    final weekOfYear = ((now.difference(startOfYear).inDays) / 7).floor();

    // Calculate scroll position (each week column is ~14 pixels + 2 gap)
    const cellSize = 14.0;
    const gap = 2.0;
    final targetScroll = (weekOfYear - 10) * (cellSize + gap);

    _scrollController.animateTo(
      targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final year = ref.watch(selectedYearProvider);
    final activityAsync = ref.watch(yearlyActivityProvider(year));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Year selector
        _buildYearSelector(year),

        const SizedBox(height: 12),

        // Heatmap
        activityAsync.when(
          data: (activity) => _buildHeatmap(activity, year),
          loading: () => _buildLoadingHeatmap(),
          error: (e, _) => _buildErrorState(e.toString()),
        ),

        const SizedBox(height: 8),

        // Legend
        _buildLegend(),
      ],
    );
  }

  Widget _buildYearSelector(int year) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'MAPA DE ACTIVIDAD',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: AppColors.textTertiary, size: 20,),
              onPressed: () {
                HapticFeedback.selectionClick();
                ref.read(selectedYearProvider.notifier).setYear(year - 1);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            Text(
              '$year',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right,
                  color: AppColors.textTertiary, size: 20,),
              onPressed: year < DateTime.now().year
                  ? () {
                      HapticFeedback.selectionClick();
                      ref.read(selectedYearProvider.notifier).setYear(year + 1);
                    }
                  : null,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeatmap(Map<DateTime, DailyActivity> activity, int year) {
    const cellSize = 14.0;
    const gap = 2.0;
    const rows = 7; // Days of week

    // Calculate all weeks of the year
    final startOfYear = DateTime(year);
    final endOfYear = DateTime(year, 12, 31);
    final totalDays = endOfYear.difference(startOfYear).inDays + 1;
    final weeks = (totalDays / 7).ceil() + 1;

    // Pre-calculate first day weekday once (not in itemBuilder)
    final firstDayWeekday = startOfYear.weekday;

    return SizedBox(
      height: (cellSize + gap) * rows + 24, // +24 for month labels
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month labels - static row
          const _MonthLabelsRow(cellSize: cellSize, gap: gap),

          const SizedBox(height: 8),

          // ⚡ OPTIMIZACIÓN: ListView.builder horizontal para virtualizar semanas
          // Solo renderiza ~15-20 semanas visibles en pantalla vs las 52+ totales
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                decelerationRate: ScrollDecelerationRate.fast,
              ),
              // Cache extent para pre-renderizar semanas cercanas
              cacheExtent: (cellSize + gap) * 10,
              itemCount: weeks,
              itemBuilder: (context, weekIndex) {
                return RepaintBoundary(
                  child: _WeekColumn(
                    weekIndex: weekIndex,
                    year: year,
                    startOfYear: startOfYear,
                    firstDayWeekday: firstDayWeekday,
                    activity: activity,
                    cellSize: cellSize,
                    gap: gap,
                    onDayTap: widget.onDayTap,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingHeatmap() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.redAccent,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'Error cargando datos',
          style: GoogleFonts.montserrat(
            color: AppColors.textTertiary,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          'Menos',
          style: GoogleFonts.montserrat(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: 4),
        ...List.generate(5, (i) {
          return Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: kHeatmapColors[i],
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
        const SizedBox(width: 4),
        Text(
          'Más',
          style: GoogleFonts.montserrat(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

/// Fila de etiquetas de meses - Const para evitar rebuilds
class _MonthLabelsRow extends StatelessWidget {
  final double cellSize;
  final double gap;

  const _MonthLabelsRow({
    required this.cellSize,
    required this.gap,
  });

  static const _monthLabels = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  // Pre-computed style para evitar GoogleFonts en build
  static final _labelStyle = GoogleFonts.montserrat(
    fontSize: 10,
    color: AppColors.textTertiary,
  );

  @override
  Widget build(BuildContext context) {
    // Aproximación: cada mes ocupa ~4.3 semanas
    final monthWidth = (cellSize + gap) * 4.3;

    return SizedBox(
      height: 16,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 12,
        itemBuilder: (context, month) {
          return SizedBox(
            width: monthWidth,
            child: Text(_monthLabels[month], style: _labelStyle),
          );
        },
      ),
    );
  }
}

/// Columna de una semana - Extraída para optimizar rebuilds
class _WeekColumn extends StatelessWidget {
  final int weekIndex;
  final int year;
  final DateTime startOfYear;
  final int firstDayWeekday;
  final Map<DateTime, DailyActivity> activity;
  final double cellSize;
  final double gap;
  final Function(DateTime)? onDayTap;

  const _WeekColumn({
    required this.weekIndex,
    required this.year,
    required this.startOfYear,
    required this.firstDayWeekday,
    required this.activity,
    required this.cellSize,
    required this.gap,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: gap),
      child: Column(
        children: List.generate(7, (dayOfWeek) {
          // Calculate date for this cell
          final daysOffset =
              (weekIndex * 7) + dayOfWeek - (firstDayWeekday - 1);
          final cellDate = startOfYear.add(Duration(days: daysOffset));

          // Skip if outside year
          if (cellDate.year != year) {
            return SizedBox(
              width: cellSize,
              height: cellSize + gap,
            );
          }

          // Get activity for this date
          final normalizedDate =
              DateTime(cellDate.year, cellDate.month, cellDate.day);
          final dayActivity = activity[normalizedDate];
          final intensity = dayActivity?.intensityLevel ?? 0;

          return Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: _HeatmapCell(
              date: cellDate,
              intensity: intensity,
              activity: dayActivity,
              size: cellSize,
              onTap: onDayTap,
            ),
          );
        }),
      ),
    );
  }
}

/// Individual heatmap cell
class _HeatmapCell extends StatelessWidget {
  final DateTime date;
  final int intensity;
  final DailyActivity? activity;
  final double size;
  final Function(DateTime)? onTap;

  const _HeatmapCell({
    required this.date,
    required this.intensity,
    this.activity,
    required this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = kHeatmapColors[intensity.clamp(0, 4)];
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    return GestureDetector(
      onTap: () {
        if (activity != null || isToday) {
          HapticFeedback.selectionClick();
          onTap?.call(date);
        }
      },
      child: Tooltip(
        message: _buildTooltip(),
        preferBelow: false,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: isToday
                ? Border.all(color: Colors.white.withValues(alpha: 0.5))
                : null,
          ),
        ),
      ),
    );
  }

  String _buildTooltip() {
    final dateStr = '${date.day}/${date.month}/${date.year}';
    if (activity == null) {
      return '$dateStr\nSin actividad';
    }
    return '$dateStr\n${activity!.sessionsCount} sesión(es)\n${activity!.totalVolume.toStringAsFixed(0)}kg volumen';
  }
}
