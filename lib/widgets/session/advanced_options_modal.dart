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

          // RPE Slider
          Text('RPE (Esfuerzo Percibido): ${log.rpe ?? "-"}', style: const TextStyle(fontWeight: FontWeight.bold)),
          Slider(
            value: (log.rpe ?? 0).toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: AppColors.neonPrimary,
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
