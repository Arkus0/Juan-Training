import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/design_system.dart';

/// ============================================================================
/// QUICK ACTIONS MENU — Menú Expandible de Acciones Rápidas
/// ============================================================================
///
/// FAB expandible con acciones rápidas durante el entrenamiento:
/// - REPITE: Repetir la serie actual con mismo peso/reps
/// - Mismo objetivo: Mantener progresión actual
/// - Timer: Iniciar timer de descanso
/// - ⋮ (tres puntos): Más opciones
///
/// Diseño: Aggressive Red palette, underground gym aesthetic
/// ============================================================================

class QuickActionsMenu extends StatefulWidget {
  /// Callback cuando se presiona "REPITE"
  final VoidCallback? onRepeat;

  /// Callback cuando se presiona "Mismo objetivo"
  final VoidCallback? onMaintainGoal;

  /// Callback cuando se selecciona un tiempo de descanso
  final Function(int seconds)? onRestTimeSelected;

  /// Callback cuando se presiona tres puntos (más opciones)
  final VoidCallback? onMoreOptions;

  /// Callback cuando se pide ver el historial del ejercicio
  final VoidCallback? onHistory;

  /// Tiempo de descanso actual en segundos (para mostrar)
  final int currentRestSeconds;

  const QuickActionsMenu({
    super.key,
    this.onRepeat,
    this.onMaintainGoal,
    this.onRestTimeSelected,
    this.onMoreOptions,
    this.onHistory,
    this.currentRestSeconds = 90,
  });

  @override
  State<QuickActionsMenu> createState() => _QuickActionsMenuState();
}

class _QuickActionsMenuState extends State<QuickActionsMenu>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _handleAction(VoidCallback? action) {
    if (action != null) {
      HapticFeedback.selectionClick();
      action();
    }
    // Cerrar el menú después de la acción
    if (_isExpanded) {
      _toggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Opciones expandibles (de arriba a abajo)
        SizeTransition(
          sizeFactor: _expandAnimation,
          axisAlignment: -1,
          child: FadeTransition(
            opacity: _expandAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Timer - Selector de tiempo de descanso
                _ActionButton(
                  icon: Icons.timer_outlined,
                  label: '${widget.currentRestSeconds}s',
                  color: AppColors.restTeal,
                  bgColor: AppColors.restTeal.withValues(alpha: 0.15),
                  onTap: () => _showRestTimePicker(context),
                  compact: true,
                ),
                const SizedBox(height: 8),

                // Historial - ver historial del ejercicio
                _ActionButton(
                  icon: Icons.history,
                  label: 'HISTORIAL',
                  color: AppColors.textSecondary,
                  bgColor: AppColors.bgElevated,
                  onTap: () => _handleAction(widget.onHistory),
                  compact: true,
                ),
                const SizedBox(height: 8),

                // Mismo objetivo
                _ActionButton(
                  icon: Icons.sync_rounded,
                  label: 'OBJETIVO',
                  color: AppColors.bloodRed,
                  bgColor: AppColors.darkRedSubtle,
                  onTap: () => _handleAction(widget.onMaintainGoal),
                  compact: true,
                ),
                const SizedBox(height: 8),

                // Opciones del ejercicio (acceder a más opciones)
                _ActionButton(
                  icon: Icons.more_horiz,
                  label: 'OPCIONES',
                  color: AppColors.textSecondary,
                  bgColor: AppColors.bgElevated,
                  onTap: () => _handleAction(widget.onMoreOptions),
                  compact: true,
                ),
                const SizedBox(height: 8),

                // REPITE - acción principal (más cerca del FAB)
                _ActionButton(
                  icon: Icons.repeat_rounded,
                  label: 'REPITE',
                  color: AppColors.textOnAccent,
                  bgColor: AppColors.bloodRed,
                  onTap: () => _handleAction(widget.onRepeat),
                  compact: false,
                  isPrimary: true,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // FAB principal (toggle)
        _MainFab(
          isExpanded: _isExpanded,
          rotateAnimation: _rotateAnimation,
          onTap: _toggle,
        ),
      ],
    );
  }

  /// Muestra el picker de tiempo de descanso
  void _showRestTimePicker(BuildContext context) {
    // Cerrar el menú primero
    if (_isExpanded) {
      _toggle();
    }

    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _RestTimePickerSheet(
        initialSeconds: widget.currentRestSeconds,
        onSelected: (seconds) {
          widget.onRestTimeSelected?.call(seconds);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

/// Bottom sheet para seleccionar tiempo de descanso
class _RestTimePickerSheet extends StatefulWidget {
  final int initialSeconds;
  final Function(int) onSelected;

  const _RestTimePickerSheet({
    required this.initialSeconds,
    required this.onSelected,
  });

  @override
  State<_RestTimePickerSheet> createState() => _RestTimePickerSheetState();
}

class _RestTimePickerSheetState extends State<_RestTimePickerSheet> {
  late int _selectedSeconds;

  // Opciones predefinidas de tiempo
  static const List<int> _presets = [30, 45, 60, 90, 120, 150, 180, 240, 300];

  @override
  void initState() {
    super.initState();
    _selectedSeconds = widget.initialSeconds;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 16),

            Text(
              'TIEMPO DE DESCANSO',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.restTeal,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            // Controles +/-
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildControlButton(
                  icon: Icons.remove_circle_outline,
                  onTap: () {
                    if (_selectedSeconds > 15) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedSeconds -= 15);
                    }
                  },
                ),
                const SizedBox(width: 24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.restTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.restTeal.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _formatTime(_selectedSeconds),
                    style: GoogleFonts.montserrat(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.restTeal,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                _buildControlButton(
                  icon: Icons.add_circle_outline,
                  onTap: () {
                    if (_selectedSeconds < 600) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedSeconds += 15);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Presets
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _presets.map((seconds) {
                final isSelected = seconds == _selectedSeconds;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedSeconds = seconds);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.restTeal.withValues(alpha: 0.2)
                          : AppColors.bgInteractive,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.restTeal : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      _formatTime(seconds),
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? AppColors.restTeal
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Botón confirmar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onSelected(_selectedSeconds),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.restTeal,
                  foregroundColor: AppColors.bgDeep,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'CONFIRMAR',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
      {required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bgInteractive,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 32, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    if (seconds >= 60) {
      final mins = seconds ~/ 60;
      final secs = seconds % 60;
      if (secs == 0) return '${mins}m';
      return '${mins}:${secs.toString().padLeft(2, '0')}';
    }
    return '${seconds}s';
  }
}

/// Botón de acción individual del menú expandible
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;
  final bool compact;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
    this.compact = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(compact ? 20 : 24),
            border: Border.all(
              color: isPrimary ? color : color.withValues(alpha: 0.3),
              width: isPrimary ? 2 : 1,
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: compact ? 16 : 20,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: compact ? 10 : 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// FAB principal que abre/cierra el menú
class _MainFab extends StatelessWidget {
  final bool isExpanded;
  final Animation<double> rotateAnimation;
  final VoidCallback onTap;

  const _MainFab({
    required this.isExpanded,
    required this.rotateAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.bloodRed,
                AppColors.darkRed,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.fireRed.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.bloodRed.withValues(alpha: 0.4),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: RotationTransition(
              turns: rotateAnimation,
              child: Icon(
                isExpanded ? Icons.close : Icons.bolt_rounded,
                color: AppColors.textOnAccent,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
