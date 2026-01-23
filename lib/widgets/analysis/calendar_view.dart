import '../../utils/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../providers/analysis_provider.dart';
import 'daily_snapshot_card.dart';

/// TableCalendar wrapper with training day markers
class AnalysisCalendarView extends ConsumerStatefulWidget {
  const AnalysisCalendarView({super.key});

  @override
  ConsumerState<AnalysisCalendarView> createState() => _AnalysisCalendarViewState();
}

class _AnalysisCalendarViewState extends ConsumerState<AnalysisCalendarView> {
  late DateTime _focusedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedCalendarDateProvider);
    final trainingDatesAsync = ref.watch(trainingDatesProvider);

    return Column(
      children: [
        // Calendar
        trainingDatesAsync.when(
          data: (trainingDates) => _buildCalendar(trainingDates, selectedDate),
          loading: () => _buildCalendarLoading(),
          error: (_, __) => _buildCalendar({}, selectedDate),
        ),

        // Daily snapshot when date selected
        if (selectedDate != null) ...[
          const SizedBox(height: 16),
          const DailySnapshotCard(),
        ],
      ],
    );
  }

  Widget _buildCalendar(Set<DateTime> trainingDates, DateTime? selectedDate) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDeep),
      ),
      child: TableCalendar(
        firstDay: DateTime(2020),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(selectedDate, day),
        onDaySelected: (selectedDay, focusedDay) {
          HapticFeedback.selectionClick();
          ref.read(selectedCalendarDateProvider.notifier).state = selectedDay;
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
          // Update year provider for heatmap sync
          ref.read(selectedYearProvider.notifier).state = focusedDay.year;
        },
        // Spanish locale
        locale: 'es_ES',
        startingDayOfWeek: StartingDayOfWeek.monday,
        // Custom builders
        calendarBuilders: CalendarBuilders(
          // Training day marker
          markerBuilder: (context, day, events) {
            final normalizedDay = DateTime(day.year, day.month, day.day);
            if (trainingDates.contains(normalizedDay)) {
              return Positioned(
                bottom: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }
            return null;
          },
          // Default cell
          defaultBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, isSelected: false, isToday: false);
          },
          // Today cell
          todayBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, isSelected: false, isToday: true);
          },
          // Selected cell
          selectedBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, isSelected: true, isToday: isSameDay(day, DateTime.now()));
          },
          // Outside cell (other months)
          outsideBuilder: (context, day, focusedDay) {
            return Center(
              child: Text(
                '${day.day}',
                style: GoogleFonts.montserrat(
                  color: AppColors.bgDeep,
                  fontSize: 14,
                ),
              ),
            );
          },
        ),
        // Styling
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: true,
          formatButtonShowsNext: false,
          formatButtonDecoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          formatButtonTextStyle: GoogleFonts.montserrat(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
          titleTextStyle: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
          rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: GoogleFonts.montserrat(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: GoogleFonts.montserrat(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: true,
          cellMargin: const EdgeInsets.all(4),
          // Default
          defaultTextStyle: GoogleFonts.montserrat(
            color: Colors.grey[300],
            fontSize: 14,
          ),
          // Weekend
          weekendTextStyle: GoogleFonts.montserrat(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          // Today
          todayDecoration: const BoxDecoration(
            color: AppColors.bgDeep,
            shape: BoxShape.circle,
          ),
          todayTextStyle: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          // Selected
          selectedDecoration: const BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDayCell(DateTime day, {required bool isSelected, required bool isToday}) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.redAccent
            : isToday
                ? AppColors.bgDeep
                : null,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: GoogleFonts.montserrat(
            color: isSelected
                ? Colors.white
                : isToday
                    ? Colors.white
                    : Colors.grey[300],
            fontWeight: isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarLoading() {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Colors.redAccent,
          strokeWidth: 2,
        ),
      ),
    );
  }
}
