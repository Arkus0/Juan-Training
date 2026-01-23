import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ejercicio.dart';
import '../../utils/design_system.dart';

/// ============================================================================
/// EXERCISE NAV RAIL — Guía lateral de navegación rápida
/// ============================================================================
///
/// Rail minimalista para saltar entre ejercicios rápidamente.
/// - Puntos indicadores por ejercicio
/// - Verde = completado, Rojo = activo, Gris = pendiente
/// - Tap para saltar al ejercicio
/// ============================================================================

class ExerciseNavRail extends StatelessWidget {
  final List<Ejercicio> exercises;
  final int currentExerciseIndex;
  final Function(int) onExerciseTap;

  const ExerciseNavRail({
    super.key,
    required this.exercises,
    required this.currentExerciseIndex,
    required this.onExerciseTap,
  });

  @override
  Widget build(BuildContext context) {
    if (exercises.length <= 3) {
      // No mostrar rail si hay pocos ejercicios
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 4,
      top: 80,
      bottom: 140,
      child: Container(
        width: 24,
        decoration: BoxDecoration(
          color: AppColors.bgElevated.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(exercises.length, (index) {
            final exercise = exercises[index];
            final isCompleted = exercise.logs.every((log) => log.completed);
            final isActive = index == currentExerciseIndex;
            final hasStarted = exercise.logs.any((log) => log.completed);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onExerciseTap(index);
                },
                child: Tooltip(
                  message: exercise.nombre,
                  preferBelow: false,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isActive ? 16 : 10,
                    height: isActive ? 16 : 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? AppColors.completedGreen
                          : isActive
                              ? AppColors.bloodRed
                              : hasStarted
                                  ? AppColors.warning.withOpacity(0.7)
                                  : AppColors.textDisabled.withOpacity(0.4),
                      border: isActive
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: AppColors.bloodRed.withOpacity(0.5),
                                blurRadius: 6,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Widget más compacto para cuando hay MUCHOS ejercicios (>8)
class ExerciseNavRailCompact extends StatelessWidget {
  final List<Ejercicio> exercises;
  final int currentExerciseIndex;
  final Function(int) onExerciseTap;

  const ExerciseNavRailCompact({
    super.key,
    required this.exercises,
    required this.currentExerciseIndex,
    required this.onExerciseTap,
  });

  @override
  Widget build(BuildContext context) {
    if (exercises.length <= 3) {
      return const SizedBox.shrink();
    }

    // Agrupar ejercicios si hay demasiados
    final showCompact = exercises.length > 8;
    final dotSize = showCompact ? 6.0 : 8.0;
    final spacing = showCompact ? 3.0 : 4.0;

    return Positioned(
      right: 2,
      top: 60,
      bottom: 120,
      child: Container(
        width: 20,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgDeep.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(exercises.length, (index) {
                    final exercise = exercises[index];
                    final isCompleted = exercise.logs.every((log) => log.completed);
                    final isActive = index == currentExerciseIndex;
                    final hasStarted = exercise.logs.any((log) => log.completed);

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onExerciseTap(index);
                      },
                      child: Tooltip(
                        message: '${index + 1}. ${exercise.nombre}',
                        preferBelow: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: spacing),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: isActive ? dotSize + 4 : dotSize,
                            height: isActive ? dotSize + 4 : dotSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted
                                  ? AppColors.completedGreen
                                  : isActive
                                      ? AppColors.bloodRed
                                      : hasStarted
                                          ? AppColors.warning.withOpacity(0.6)
                                          : AppColors.border,
                              border: isActive
                                  ? Border.all(color: Colors.white, width: 1.5)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
