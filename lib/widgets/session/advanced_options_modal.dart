import '../../utils/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/training_provider.dart';

class AdvancedOptionsModal extends ConsumerStatefulWidget {
  final int exerciseIndex;
  final int setIndex;

  const AdvancedOptionsModal({
    super.key,
    required this.exerciseIndex,
    required this.setIndex
  });

  @override
  ConsumerState<AdvancedOptionsModal> createState() => _AdvancedOptionsModalState();
}

class _AdvancedOptionsModalState extends ConsumerState<AdvancedOptionsModal> {
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(trainingSessionProvider);
    final log = state.exercises[widget.exerciseIndex].logs[widget.setIndex];
    _notesController = TextEditingController(text: log.notas ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch specific log changes if needed, or just the whole state?
    // The original code watched 'trainingSessionProvider'.
    // "final state = ref.watch(trainingSessionProvider);"
    // This rebuilds the modal if anything changes.
    // Given the modal is ephemeral and deals with one log, it's probably fine,
    // but we can optimize if we want. For now, strict extraction.

    final state = ref.watch(trainingSessionProvider);
    final notifier = ref.read(trainingSessionProvider.notifier);
    final log = state.exercises[widget.exerciseIndex].logs[widget.setIndex];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, color: AppColors.border)),
          const SizedBox(height: 16),
          Text('OPCIONES PRO', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.goldAccent)),
          const SizedBox(height: 16),

          // RPE Slider con feedback de color
          _RpeSliderWithColorFeedback(
            rpeValue: log.rpe,
            onChanged: (val) {
              notifier.updateLog(widget.exerciseIndex, widget.setIndex, rpe: val == 0 ? null : val.toInt());
            },
          ),

          // Toggles
          Row(
            children: [
              FilterChip(
                label: const Text('FALLO MUSCULAR'),
                selected: log.isFailure,
                onSelected: (val) => notifier.updateLog(widget.exerciseIndex, widget.setIndex, isFailure: val),
                selectedColor: AppColors.techCyan,
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('DROPSET'),
                selected: log.isDropset,
                onSelected: (val) => notifier.updateLog(widget.exerciseIndex, widget.setIndex, isDropset: val),
                selectedColor: AppColors.goldAccent,
              ),
            ],
          ),

          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notas de la serie', prefixIcon: Icon(Icons.edit_note)),
            onChanged: (val) => notifier.updateLog(widget.exerciseIndex, widget.setIndex, notas: val),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Widget de slider RPE con feedback de color visual instantáneo
/// Verde (1-6): Fácil/Moderado
/// Amarillo (7-8): Difícil
/// Rojo (9-10): Máximo esfuerzo
class _RpeSliderWithColorFeedback extends StatelessWidget {
  final int? rpeValue;
  final ValueChanged<double> onChanged;

  const _RpeSliderWithColorFeedback({
    required this.rpeValue,
    required this.onChanged,
  });

  /// Obtiene el color según el valor de RPE
  Color _getRpeColor(int? rpe) {
    if (rpe == null || rpe == 0) return AppColors.textTertiary;
    if (rpe <= 6) return const Color(0xFF4CAF50); // Verde
    if (rpe <= 8) return const Color(0xFFFFB300); // Amarillo/Ámbar
    return const Color(0xFFE53935); // Rojo
  }

  /// Obtiene la descripción del RPE
  String _getRpeLabel(int? rpe) {
    if (rpe == null || rpe == 0) return '-';
    if (rpe <= 3) return 'Muy fácil';
    if (rpe <= 5) return 'Moderado';
    if (rpe <= 6) return 'Algo difícil';
    if (rpe <= 7) return 'Difícil';
    if (rpe <= 8) return 'Muy difícil';
    if (rpe == 9) return 'Casi al límite';
    return 'Máximo';
  }

  @override
  Widget build(BuildContext context) {
    final rpe = rpeValue ?? 0;
    final color = _getRpeColor(rpeValue);
    final label = _getRpeLabel(rpeValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'RPE (Esfuerzo Percibido): ',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            // Badge con el valor y color
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rpe > 0 ? '$rpe' : '-',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: color,
                    ),
                  ),
                  if (rpe > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Slider con track coloreado
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.2),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
            valueIndicatorColor: color,
            valueIndicatorTextStyle: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          child: Slider(
            value: rpe.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: rpe > 0 ? '$rpe' : null,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
