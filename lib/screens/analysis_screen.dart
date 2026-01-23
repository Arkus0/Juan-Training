import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/design_system.dart';
import '../models/sesion.dart';
import '../providers/training_provider.dart';
import '../providers/analysis_provider.dart';
import '../widgets/analysis/activity_heatmap.dart';
import '../widgets/analysis/streak_counter.dart';
import '../widgets/analysis/calendar_view.dart';
import '../widgets/analysis/session_list_view.dart';
import '../widgets/analysis/recovery_monitor.dart';
import '../widgets/analysis/symmetry_radar.dart';
import '../widgets/analysis/hall_of_fame.dart';
import '../widgets/analysis/strength_trend.dart';

/// Centro de Comando Anabólico - Analysis Screen
/// Replaces HistoryScreen with advanced analytics
class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(analysisTabIndexProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(sesionesHistoryStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgDeep,
        elevation: 0,
        title: Text(
          'ANÁLISIS',
          style: AppTypography.sectionTitle.copyWith(
            letterSpacing: 2,
          ),
        ),
        actions: [
          // Export menu (preserved from HistoryScreen)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: const Color(0xFF1E1E1E),
            onSelected: (value) {
              if (value == 'export_all') {
                final sessions = sessionsAsync.valueOrNull ?? [];
                _exportAllSessions(context, sessions);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'export_all',
                child: Row(
                  children: [
                    const Icon(Icons.file_download, size: 20, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      'Exportar Todo',
                      style: GoogleFonts.montserrat(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.neonPrimary,
          indicatorWeight: 3,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textTertiary,
          labelStyle: AppTypography.labelEmphasis,
          unselectedLabelStyle: AppTypography.label,
          onTap: (_) => HapticFeedback.selectionClick(),
          tabs: const [
            Tab(text: 'HISTORIAL'),
            Tab(text: 'ESTADÍSTICAS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BitacoraTab(),
          _LaboratorioTab(),
        ],
      ),
    );
  }

  void _exportAllSessions(BuildContext context, List<Sesion> sessions) {
    if (sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay sesiones para exportar',
            style: GoogleFonts.montserrat(),
          ),
          backgroundColor: Colors.grey[800],
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    exportAllSessions(context, sessions);
  }
}

/// BITÁCORA Tab - Discipline & Consistency
class _BitacoraTab extends ConsumerWidget {
  const _BitacoraTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(bitacoraViewModeProvider);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Streak Counter
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: const StreakCounter(),
          ),
        ),

        // Activity Heatmap
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: ActivityHeatmap(
              onDayTap: (date) {
                ref.read(selectedCalendarDateProvider.notifier).state = date;
                ref.read(bitacoraViewModeProvider.notifier).state = BitacoraViewMode.calendar;
              },
            ),
          ),
        ),

        // View Mode Selector
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ViewModeSelector(
              currentMode: viewMode,
              onModeChanged: (mode) {
                HapticFeedback.selectionClick();
                ref.read(bitacoraViewModeProvider.notifier).state = mode;
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 16),
        ),

        // Content based on view mode
        if (viewMode == BitacoraViewMode.calendar)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: AnalysisCalendarView(),
            ),
          )
        else
          const SessionListView(),

        // Bottom padding
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }
}

/// LABORATORIO Tab - Science & Analytics
class _LaboratorioTab extends ConsumerWidget {
  const _LaboratorioTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Recovery Monitor
        const RecoveryMonitor(),

        const SizedBox(height: 20),

        // Symmetry Radar
        const SymmetryRadar(),

        const SizedBox(height: 20),

        // Hall of Fame (PRs)
        const HallOfFame(),

        const SizedBox(height: 20),

        // Strength Trend
        const StrengthTrend(),

        // Bottom padding for nav bar
        const SizedBox(height: 100),
      ],
    );
  }
}

/// View mode selector (Calendar vs List)
class _ViewModeSelector extends StatelessWidget {
  final BitacoraViewMode currentMode;
  final ValueChanged<BitacoraViewMode> onModeChanged;

  const _ViewModeSelector({
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildOption(
            icon: Icons.calendar_month,
            label: 'Calendario',
            isSelected: currentMode == BitacoraViewMode.calendar,
            onTap: () => onModeChanged(BitacoraViewMode.calendar),
          ),
          _buildOption(
            icon: Icons.list_alt,
            label: 'Lista',
            isSelected: currentMode == BitacoraViewMode.list,
            onTap: () => onModeChanged(BitacoraViewMode.list),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.neonPrimarySubtle : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: isSelected
                ? Border.all(color: AppColors.neonPrimary.withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.neonPrimary : AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: isSelected
                    ? AppTypography.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )
                    : AppTypography.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
