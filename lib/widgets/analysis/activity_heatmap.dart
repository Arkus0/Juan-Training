import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/analysis_models.dart';
import '../../providers/analysis_provider.dart';

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
    final startOfYear = DateTime(now.year, 1, 1);
    final weekOfYear = ((now.difference(startOfYear).inDays) / 7).floor();

    // Calculate scroll position (each week column is ~14 pixels + 2 gap)
    final cellSize = 14.0;
    final gap = 2.0;
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
            color: Colors.grey[400],
            letterSpacing: 1.2,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: Colors.grey[600], size: 20),
              onPressed: () {
                HapticFeedback.selectionClick();
                ref.read(selectedYearProvider.notifier).state = year - 1;
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
              icon: Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
              onPressed: year < DateTime.now().year
                  ? () {
                      HapticFeedback.selectionClick();
                      ref.read(selectedYearProvider.notifier).state = year + 1;
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

    // Month labels
    const monthLabels = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
                        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

    // Calculate all weeks of the year
    final startOfYear = DateTime(year, 1, 1);
    final endOfYear = DateTime(year, 12, 31);
    final totalDays = endOfYear.difference(startOfYear).inDays + 1;
    final weeks = (totalDays / 7).ceil() + 1;

    return SizedBox(
      height: (cellSize + gap) * rows + 24, // +24 for month labels
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month labels
            SizedBox(
              height: 16,
              child: Row(
                children: List.generate(12, (month) {
                  // Calculate position of first week of month
                  final firstOfMonth = DateTime(year, month + 1, 1);
                  final weekOfMonth = ((firstOfMonth.difference(startOfYear).inDays) / 7).floor();
                  return Padding(
                    padding: EdgeInsets.only(left: weekOfMonth > 0 ? (cellSize + gap) * 4 : 0),
                    child: SizedBox(
                      width: (cellSize + gap) * 4,
                      child: Text(
                        monthLabels[month],
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                }).take(1).toList() + [
                  // Simplified: just show months evenly spaced
                  ...List.generate(12, (month) {
                    return SizedBox(
                      width: (cellSize + gap) * (weeks / 12).floor(),
                      child: Text(
                        monthLabels[month],
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Grid
            SizedBox(
              height: (cellSize + gap) * rows,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(weeks, (weekIndex) {
                  return Padding(
                    padding: const EdgeInsets.only(right: gap),
                    child: Column(
                      children: List.generate(rows, (dayOfWeek) {
                        // Calculate date for this cell
                        final firstDayOfYear = startOfYear;
                        final firstDayWeekday = firstDayOfYear.weekday; // 1=Mon, 7=Sun

                        // Adjust to start on Monday
                        final daysOffset = (weekIndex * 7) + dayOfWeek - (firstDayWeekday - 1);
                        final cellDate = firstDayOfYear.add(Duration(days: daysOffset));

                        // Skip if outside year
                        if (cellDate.year != year) {
                          return SizedBox(
                            width: cellSize,
                            height: cellSize + gap,
                            child: const SizedBox.shrink(),
                          );
                        }

                        // Get activity for this date
                        final normalizedDate = DateTime(cellDate.year, cellDate.month, cellDate.day);
                        final dayActivity = activity[normalizedDate];
                        final intensity = dayActivity?.intensityLevel ?? 0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: gap),
                          child: _HeatmapCell(
                            date: cellDate,
                            intensity: intensity,
                            activity: dayActivity,
                            size: cellSize,
                            onTap: widget.onDayTap,
                          ),
                        );
                      }),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
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
            color: Colors.grey[600],
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
            color: Colors.grey[600],
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
            color: Colors.grey[600],
          ),
        ),
      ],
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
    final isToday = date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;

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
                ? Border.all(color: Colors.white.withOpacity(0.5), width: 1)
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
