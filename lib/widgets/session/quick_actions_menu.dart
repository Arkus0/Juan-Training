import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/design_system.dart';

/// ============================================================================
/// QUICK ACTIONS MENU — Grid 2x2 de Acciones Rápidas Mid-Workout
/// ============================================================================
///
/// Menú flat con 4 acciones que responden a: "¿Esto me ayuda AHORA?"
///
/// Acciones:
/// - REPITE: Copiar peso/reps de la serie anterior
/// - HECHO: Marcar la serie actual como completada
/// - DESCANSO: Ajustar tiempo de descanso (inline)
/// - NOTA: Añadir nota rápida al ejercicio
///
/// Principios:
/// - Máximo 4 acciones (grid 2x2)
/// - Sin navegación profunda
/// - Cierre automático tras acción
/// - Feedback háptico
/// ============================================================================

/// Tipos de acciones rápidas disponibles
enum QuickActionType {
  repeat,    // Copiar peso/reps de serie anterior
  markDone,  // Marcar serie actual como completada
  restTimer, // Ajustar tiempo de descanso
  quickNote, // Añadir nota rápida
}

class QuickActionsMenu extends StatefulWidget {
  /// Callback cuando se presiona "REPITE"
  final VoidCallback? onRepeat;

  /// Callback cuando se presiona "HECHO"
  final VoidCallback? onMarkDone;

  /// Callback cuando se selecciona un tiempo de descanso
  final Function(int seconds)? onRestTimeSelected;

  /// Callback cuando se añade una nota rápida
  final Function(String note)? onQuickNote;

  /// Tiempo de descanso actual en segundos (para mostrar)
  final int currentRestSeconds;

  /// Si la serie actual ya está completada (para cambiar estado de HECHO)
  final bool isCurrentSetDone;

  /// Si true, el menú se abre inicialmente expandido
  final bool startExpanded;

  /// Si false, no se muestra el FAB toggle
  final bool showToggle;

  const QuickActionsMenu({
    super.key,
    this.onRepeat,
    this.onMarkDone,
    this.onRestTimeSelected,
    this.onQuickNote,
    this.currentRestSeconds = 90,
    this.isCurrentSetDone = false,
    this.startExpanded = false,
    this.showToggle = true,
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

  // Estado para el picker de descanso inline
  bool _showRestPicker = false;
  late int _selectedRestSeconds;

  // Estado para nota rápida inline
  bool _showNotePicker = false;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _rotateAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _selectedRestSeconds = widget.currentRestSeconds;
    _isExpanded = widget.startExpanded;
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _noteController.dispose();
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
        // Reset inline pickers
        _showRestPicker = false;
        _showNotePicker = false;
      }
    });
  }

  void _handleAction(VoidCallback? action) {
    if (action != null) {
      HapticFeedback.selectionClick();
      action();
    }
  }

  void _closeMenu() {
    if (_isExpanded && widget.showToggle) {
      _toggle();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si estamos en modo modal (showToggle=false), mostrar directamente el contenido
    if (!widget.showToggle) {
      return _buildModalContent();
    }

    // Modo FAB expandible
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Contenido expandible
        SizeTransition(
          sizeFactor: _expandAnimation,
          axisAlignment: -1,
          child: FadeTransition(
            opacity: _expandAnimation,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildGridContent(),
            ),
          ),
        ),

        // FAB principal
        _MainFab(
          isExpanded: _isExpanded,
          rotateAnimation: _rotateAnimation,
          onTap: _toggle,
        ),
      ],
    );
  }

  /// Contenido para modo modal (dentro de bottom sheet)
  Widget _buildModalContent() {
    return Column(
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

        // Título
        Text(
          'ACCIONES RÁPIDAS',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: AppColors.bloodRed,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),

        // Grid de acciones o picker inline
        if (_showRestPicker)
          _buildInlineRestPicker()
        else if (_showNotePicker)
          _buildInlineNotePicker()
        else
          _buildGridContent(),

        const SizedBox(height: 8),
      ],
    );
  }

  /// Grid 2x2 de acciones
  Widget _buildGridContent() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Fila 1: REPITE + HECHO
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.repeat_rounded,
                  label: 'REPITE',
                  sublabel: 'Mismo peso/reps',
                  color: AppColors.bloodRed,
                  onTap: () {
                    _handleAction(widget.onRepeat);
                    _closeMenu();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionTile(
                  icon: widget.isCurrentSetDone
                      ? Icons.check_circle
                      : Icons.check_circle_outline,
                  label: widget.isCurrentSetDone ? 'HECHA' : 'HECHO',
                  sublabel: 'Marcar serie',
                  color: widget.isCurrentSetDone
                      ? AppColors.completedGreen
                      : AppColors.textPrimary,
                  filled: widget.isCurrentSetDone,
                  onTap: () {
                    _handleAction(widget.onMarkDone);
                    _closeMenu();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fila 2: DESCANSO + NOTA
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.timer_outlined,
                  label: _formatTime(widget.currentRestSeconds),
                  sublabel: 'Descanso',
                  color: AppColors.restTeal,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _showRestPicker = true;
                      _showNotePicker = false;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.edit_note_rounded,
                  label: 'NOTA',
                  sublabel: 'Añadir nota',
                  color: AppColors.techCyan,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _showNotePicker = true;
                      _showRestPicker = false;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Picker de descanso inline (reemplaza el grid temporalmente)
  Widget _buildInlineRestPicker() {
    const presets = [30, 60, 90, 120, 180];

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con botón volver
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                color: AppColors.textSecondary,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showRestPicker = false);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 8),
              Text(
                'TIEMPO DE DESCANSO',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.restTeal,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Display actual + controles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildRestControl(
                icon: Icons.remove,
                onTap: () {
                  if (_selectedRestSeconds > 15) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedRestSeconds -= 15);
                  }
                },
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.restTeal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.restTeal.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _formatTime(_selectedRestSeconds),
                  style: GoogleFonts.montserrat(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.restTeal,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _buildRestControl(
                icon: Icons.add,
                onTap: () {
                  if (_selectedRestSeconds < 600) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedRestSeconds += 15);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Presets compactos
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: presets.map((seconds) {
              final isSelected = seconds == _selectedRestSeconds;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedRestSeconds = seconds);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.restTeal.withValues(alpha: 0.2)
                        : AppColors.bgInteractive,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.restTeal : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    _formatTime(seconds),
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.restTeal : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Botón confirmar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                widget.onRestTimeSelected?.call(_selectedRestSeconds);
                setState(() => _showRestPicker = false);
                _closeMenu();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.restTeal,
                foregroundColor: AppColors.bgDeep,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'CONFIRMAR',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestControl({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.bgInteractive,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 24, color: AppColors.textSecondary),
        ),
      ),
    );
  }

  /// Picker de nota inline
  Widget _buildInlineNotePicker() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con botón volver
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                color: AppColors.textSecondary,
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _showNotePicker = false);
                  _noteController.clear();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 8),
              Text(
                'NOTA RÁPIDA',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.techCyan,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Campo de texto
          TextField(
            controller: _noteController,
            autofocus: true,
            maxLines: 2,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Ej: Subir peso próxima vez, ajustar agarre...',
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.bgInteractive,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.techCyan, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),

          // Sugerencias rápidas
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildQuickNoteSuggestion('🔼 Subir peso'),
              _buildQuickNoteSuggestion('⚡ Más reps'),
              _buildQuickNoteSuggestion('🎯 Mejorar técnica'),
            ],
          ),
          const SizedBox(height: 16),

          // Botón guardar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final note = _noteController.text.trim();
                if (note.isNotEmpty) {
                  HapticFeedback.mediumImpact();
                  widget.onQuickNote?.call(note);
                  _noteController.clear();
                  setState(() => _showNotePicker = false);
                  _closeMenu();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.techCyan,
                foregroundColor: AppColors.bgDeep,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'GUARDAR NOTA',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickNoteSuggestion(String text) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _noteController.text = text;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgInteractive,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    if (seconds >= 60) {
      final mins = seconds ~/ 60;
      final secs = seconds % 60;
      if (secs == 0) return '${mins}m';
      return '$mins:${secs.toString().padLeft(2, '0')}';
    }
    return '${seconds}s';
  }
}

/// Tile individual para el grid de acciones
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: filled
                ? color.withValues(alpha: 0.15)
                : AppColors.bgInteractive,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: filled ? color : AppColors.border,
              width: filled ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                sublabel,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
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
            gradient: const LinearGradient(
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
