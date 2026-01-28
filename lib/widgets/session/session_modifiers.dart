import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/ejercicio_en_rutina.dart';
import '../../models/library_exercise.dart';
import '../../providers/training_provider.dart';
import '../../screens/create_routine/widgets/biblioteca_bottom_sheet.dart';
import '../../utils/design_system.dart';

/// Botón compacto para añadir una serie adicional a un ejercicio
class AddSetButton extends ConsumerWidget {
  final int exerciseIndex;

  const AddSetButton({
    super.key,
    required this.exerciseIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          ref
              .read(trainingSessionProvider.notifier)
              .addSetToExercise(exerciseIndex);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.add_circle_outline,
                      color: Colors.white, size: 18,),
                  const SizedBox(width: 8),
                  Text(
                    'Serie añadida',
                    style: AppTypography.labelEmphasis,
                  ),
                ],
              ),
              backgroundColor: AppColors.bgElevated,
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.border,
            ),
            borderRadius: BorderRadius.circular(8),
            color: AppColors.bgInteractive.withValues(alpha: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'AÑADIR SERIE',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón para añadir un nuevo ejercicio a la sesión activa
class AddExerciseButton extends ConsumerWidget {
  const AddExerciseButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddExerciseSheet(context, ref),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.techCyan.withValues(alpha: 0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.bgElevated.withValues(alpha: 0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppColors.techCyan,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  'AÑADIR EJERCICIO',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppColors.techCyan,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddExerciseSheet(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => BibliotecaBottomSheet(
          onAdd: (libExercise) {
            Navigator.pop(sheetContext);
            _showAddOptionDialog(context, ref, libExercise);
          },
        ),
      ),
    );
  }

  void _showAddOptionDialog(
      BuildContext context, WidgetRef ref, LibraryExercise exercise,) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddExerciseOptionDialog(
        exercise: exercise,
        onSessionOnly: () {
          Navigator.pop(dialogContext);
          // Añadir solo a esta sesión
          ref
              .read(trainingSessionProvider.notifier)
              .addExerciseToSession(exercise);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: Colors.white, size: 18,),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${exercise.name} añadido a esta sesión',
                      style: AppTypography.labelEmphasis,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onAddToRoutine: () async {
          Navigator.pop(dialogContext);

          // Añadir a sesión actual
          ref
              .read(trainingSessionProvider.notifier)
              .addExerciseToSession(exercise);

          // También añadir a la rutina (si hay una activa con día conocido)
          final state = ref.read(trainingSessionProvider);
          if (state.activeRutina != null && state.dayIndex != null) {
            // Usar el repositorio directamente para actualizar la rutina
            final rutina = state.activeRutina!;
            final dayIndex = state.dayIndex!;

            // Crear una copia de la rutina con el ejercicio añadido
            if (dayIndex < rutina.dias.length) {
              final newExercise = EjercicioEnRutina(
                id: exercise.id.toString(),
                nombre: exercise.name,
                descripcion: exercise.description,
                musculosPrincipales: exercise.muscles,
                musculosSecundarios: exercise.secondaryMuscles,
                equipo: exercise.equipment,
                localImagePath: exercise.localImagePath,
              );

              final updatedDay = rutina.dias[dayIndex].copyWith(
                ejercicios: [...rutina.dias[dayIndex].ejercicios, newExercise],
              );

              final newDias = [...rutina.dias];
              newDias[dayIndex] = updatedDay;
              final updatedRutina = rutina.copyWith(dias: newDias);

              await ref
                  .read(trainingRepositoryProvider)
                  .saveRutina(updatedRutina);
            }

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.library_add_check,
                          color: Colors.white, size: 18,),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${exercise.name} añadido a sesión y rutina',
                          style: AppTypography.labelEmphasis,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else {
            // No hay rutina activa, solo añadir a sesión
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 18,),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${exercise.name} añadido (sin rutina activa para guardar)',
                          style: AppTypography.labelEmphasis,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: AppColors.bgElevated,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
      ),
    );
  }
}

/// Diálogo para elegir si añadir ejercicio solo a la sesión o también a la rutina
class AddExerciseOptionDialog extends StatelessWidget {
  final LibraryExercise exercise;
  final VoidCallback onSessionOnly;
  final VoidCallback onAddToRoutine;

  const AddExerciseOptionDialog({
    super.key,
    required this.exercise,
    required this.onSessionOnly,
    required this.onAddToRoutine,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        children: [
          const Icon(
            Icons.fitness_center_rounded,
            color: AppColors.techCyan,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            exercise.name.toUpperCase(),
            style: AppTypography.sectionTitle.copyWith(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '¿Dónde quieres añadir este ejercicio?',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Opción 1: Solo esta sesión
          _OptionTile(
            icon: Icons.today_rounded,
            title: 'SOLO ESTA SESIÓN',
            subtitle: 'Ejercicio temporal, no se guardará en tu rutina',
            color: AppColors.textSecondary,
            onTap: onSessionOnly,
          ),

          const SizedBox(height: 12),

          // Opción 2: Añadir a la rutina
          _OptionTile(
            icon: Icons.library_add_rounded,
            title: 'AÑADIR A LA RUTINA',
            subtitle: 'Se guardará permanentemente en este día',
            color: AppColors.techCyan,
            onTap: onAddToRoutine,
            highlighted: true,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.only(bottom: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'CANCELAR',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool highlighted;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? color.withValues(alpha: 0.1) : AppColors.bgDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: highlighted ? color : AppColors.border,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
