import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:juan_training/models/rutina.dart';
import 'package:juan_training/models/dia.dart';
import 'package:juan_training/models/ejercicio_en_rutina.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/repositories/i_training_repository.dart';
import 'package:juan_training/providers/training_provider.dart';


// Provider family to initialize with existing routine or null
final createRoutineProvider =
    StateNotifierProvider.family<CreateRoutineNotifier, Rutina, Rutina?>(
  (ref, existingRutina) {
    final repository = ref.watch(trainingRepositoryProvider);
    return CreateRoutineNotifier(repository, existingRutina);
  },
);

class CreateRoutineNotifier extends StateNotifier<Rutina> {
  final ITrainingRepository _repository;

  CreateRoutineNotifier(this._repository, Rutina? existingRutina)
      : super(existingRutina?.copyWith() ?? _createEmptyRoutine()) {
    if (existingRutina == null) {
      addDay();
    }
  }

  static Rutina _createEmptyRoutine() {
    return Rutina(
      id: const Uuid().v4(),
      nombre: '',
      dias: [],
      creada: DateTime.now(),
    );
  }

  // --- Actions ---

  void updateName(String name) {
    state = state.copyWith(nombre: name);
  }

  void addDay() {
    final newDia = Dia(
      nombre: 'Día ${state.dias.length + 1}',
      ejercicios: [],
    );
    state = state.copyWith(dias: [...state.dias, newDia]);
  }

  void removeDay(int index) {
    final newDias = [...state.dias]..removeAt(index);
    state = state.copyWith(dias: newDias);
  }

  void duplicateDay(int dayIndex) {
    final originalDay = state.dias[dayIndex];
    final uuid = const Uuid();

    // Map to track oldSupersetId -> newSupersetId for this duplication
    final supersetMap = <String, String>{};

    final newExercises = originalDay.ejercicios.map((ex) {
      String? newSupersetId;
      if (ex.supersetId != null) {
        if (supersetMap.containsKey(ex.supersetId)) {
          newSupersetId = supersetMap[ex.supersetId];
        } else {
          newSupersetId = uuid.v4();
          supersetMap[ex.supersetId!] = newSupersetId;
        }
      }

      return ex.copyWith(
        instanceId: uuid.v4(),
        supersetId: newSupersetId, // Null if original was null, new ID if original had ID
      );
    }).toList();

    final newDia = originalDay.copyWith(
      id: uuid.v4(),
      nombre: '${originalDay.nombre} (Copia)',
      ejercicios: newExercises,
    );

    final newDias = [...state.dias, newDia];
    state = state.copyWith(dias: newDias);
  }

  void reorderDays(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final newDias = [...state.dias];
    final item = newDias.removeAt(oldIndex);
    newDias.insert(newIndex, item);
    state = state.copyWith(dias: newDias);
  }

  void updateDayName(int index, String newName) {
    final newDias = [...state.dias];
    newDias[index] = newDias[index].copyWith(nombre: newName);
    state = state.copyWith(dias: newDias);
  }

  void updateDayProgression(int index, String type) {
    final newDias = [...state.dias];
    newDias[index] = newDias[index].copyWith(progressionType: type);
    state = state.copyWith(dias: newDias);
  }

  void addExerciseToDay(int dayIndex, LibraryExercise libExercise) {
    // Add exercise quickly with unvalidated path, then schedule async validation
    // to avoid blocking the UI thread with file I/O
    final newExercise = EjercicioEnRutina(
      id: libExercise.id.toString(),
      nombre: libExercise.name,
      descripcion: libExercise.description,
      musculosPrincipales: libExercise.muscles,
      musculosSecundarios: libExercise.secondaryMuscles,
      equipo: libExercise.equipment,
      localImagePath: libExercise.localImagePath,
    );

    final day = state.dias[dayIndex];
    final updatedDay = day.copyWith(
      ejercicios: [...day.ejercicios, newExercise],
    );

    final newDias = [...state.dias];
    newDias[dayIndex] = updatedDay;
    state = state.copyWith(dias: newDias);

    // Schedule microtask to validate image path asynchronously
    if (libExercise.localImagePath != null) {
      Future.microtask(() {
        _updateExerciseLocalImagePath(
          dayIndex,
          day.ejercicios.length, // Index of the newly added exercise
          libExercise.localImagePath!,
        );
      });
    }
  }

  /// Private helper to validate and update local image path asynchronously
  void _updateExerciseLocalImagePath(
      int dayIndex, int exerciseIndex, String localImagePath) {
    try {
      // Validate that the file exists and has content
      final f = File(localImagePath);
      if (!f.existsSync() || f.lengthSync() == 0) {
        // File is invalid, clear the path
        final day = state.dias[dayIndex];
        if (exerciseIndex < day.ejercicios.length) {
          final exercise = day.ejercicios[exerciseIndex];
          if (exercise.localImagePath == localImagePath) {
            updateExercise(
              dayIndex,
              exerciseIndex,
              exercise.copyWith(localImagePath: null),
            );
          }
        }
      }
    } catch (e) {
      // If any filesystem error occurs, clear the path
      final day = state.dias[dayIndex];
      if (exerciseIndex < day.ejercicios.length) {
        final exercise = day.ejercicios[exerciseIndex];
        if (exercise.localImagePath == localImagePath) {
          updateExercise(
            dayIndex,
            exerciseIndex,
            exercise.copyWith(localImagePath: null),
          );
        }
      }
    }
  }

  void removeExercise(int dayIndex, int exerciseIndex) {
    // Before removing, check if it was part of a superset
    // If we remove an item from a superset of 2, the remaining one should lose its supersetId

    // Actually, removeFromSuperset logic handles logic for "breaking" the link.
    // But here we are DELETING the exercise entirely.

    final day = state.dias[dayIndex];
    final exToRemove = day.ejercicios[exerciseIndex];
    final oldSupersetId = exToRemove.supersetId;

    final newEjercicios = [...day.ejercicios]..removeAt(exerciseIndex);

    // Check if we need to clean up the superset
    if (oldSupersetId != null) {
        // Count remaining exercises with this supersetId
        final remainingInSuperset = newEjercicios.where((e) => e.supersetId == oldSupersetId).toList();
        if (remainingInSuperset.length == 1) {
             // Only 1 left, so it's no longer a superset
             final indexToFix = newEjercicios.indexOf(remainingInSuperset.first);
             if (indexToFix != -1) {
                 newEjercicios[indexToFix] = newEjercicios[indexToFix].copyWith(supersetId: null);
             }
        }
    }

    final updatedDay = day.copyWith(ejercicios: newEjercicios);
    final newDias = [...state.dias];
    newDias[dayIndex] = updatedDay;
    state = state.copyWith(dias: newDias);
  }

  void insertExercise(int dayIndex, int index, EjercicioEnRutina ex) {
    final day = state.dias[dayIndex];
    final newEjercicios = [...day.ejercicios];

    // Safety check for index
    if (index < 0) index = 0;
    if (index > newEjercicios.length) index = newEjercicios.length;

    newEjercicios.insert(index, ex);

    final updatedDay = day.copyWith(ejercicios: newEjercicios);
    final newDias = [...state.dias];
    newDias[dayIndex] = updatedDay;
    state = state.copyWith(dias: newDias);
  }

  /// Helper to compute visual groups for reordering
  /// Returns list of lists where each inner list is a contiguous group of exercises
  /// that share the same supersetId, or a single exercise without a supersetId.
  /// This ensures that supersets are kept together as a unit during reordering.
  List<List<EjercicioEnRutina>> _computeVisualGroups(List<EjercicioEnRutina> exercises) {
    if (exercises.isEmpty) return [];

    final groups = <List<EjercicioEnRutina>>[];
    var currentGroup = <EjercicioEnRutina>[exercises[0]];

    for (int i = 1; i < exercises.length; i++) {
      final current = exercises[i];
      final previous = currentGroup.last;

      // Check if current exercise should be grouped with previous
      if (current.supersetId != null &&
          previous.supersetId != null &&
          current.supersetId == previous.supersetId) {
        // Same superset, add to current group
        currentGroup.add(current);
      } else {
        // Different group, finalize current group and start new one
        groups.add(currentGroup);
        currentGroup = [current];
      }
    }

    // Add the last group
    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }

    return groups;
  }

  /// Reorders visual items (which might be single exercises or superset blocks)
  void reorderVisualExercises(int dayIndex, int oldVisualIndex, int newVisualIndex) {
    final day = state.dias[dayIndex];
    final visualGroups = _computeVisualGroups(day.ejercicios);

    if (oldVisualIndex < newVisualIndex) {
      newVisualIndex -= 1;
    }

    // Get the block of exercises to move
    final exercisesToMove = visualGroups[oldVisualIndex];

    // Remove them from the flat list
    final idsToMove = exercisesToMove.map((e) => e.instanceId).toSet();
    final remainingExercises = day.ejercicios.where((e) => !idsToMove.contains(e.instanceId)).toList();

    // Reconstruct visual groups from remaining exercises to match indices
    final remainingVisualGroups = _computeVisualGroups(remainingExercises);

    // Find insertion index in flat list
    int flatInsertionIndex = 0;
    for (int i = 0; i < newVisualIndex; i++) {
      if (i < remainingVisualGroups.length) {
        flatInsertionIndex += remainingVisualGroups[i].length;
      }
    }

    // Insert
    final newEjercicios = [...remainingExercises];
    newEjercicios.insertAll(flatInsertionIndex, exercisesToMove);

    final updatedDay = day.copyWith(ejercicios: newEjercicios);
    final newDias = [...state.dias];
    newDias[dayIndex] = updatedDay;
    state = state.copyWith(dias: newDias);
  }

  void reorderExercises(int dayIndex, int oldIndex, int newIndex) {
     // Deprecated or fallback for simple reorders if needed.
     // But UI should use reorderVisualExercises now.
     // Keeping this logic just in case, or forwarding it?
     // Since UI will change to use reorderVisualExercises, we might not use this.
     // But let's keep it as is for compatibility or direct flat reorders.
    final day = state.dias[dayIndex];
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final newEjercicios = [...day.ejercicios];
    final item = newEjercicios.removeAt(oldIndex);
    newEjercicios.insert(newIndex, item);

    final updatedDay = day.copyWith(ejercicios: newEjercicios);
    final newDias = [...state.dias];
    newDias[dayIndex] = updatedDay;
    state = state.copyWith(dias: newDias);
  }

  void updateExercise(
      int dayIndex, int exerciseIndex, EjercicioEnRutina updated) {
    final day = state.dias[dayIndex];
    final newEjercicios = [...day.ejercicios];
    newEjercicios[exerciseIndex] = updated;
    final updatedDay = day.copyWith(ejercicios: newEjercicios);

    final newDias = [...state.dias];
    newDias[dayIndex] = updatedDay;
    state = state.copyWith(dias: newDias);
  }

  // --- Superset Actions ---

  /// Creates a superset between two exercises, ensuring they become contiguous
  /// and share the same supersetId (deterministic UUID).
  void createSuperset(int dayIndex, int indexA, int indexB) {
    if (indexA < 0 || indexB < 0) return;
    final day = state.dias[dayIndex];
    if (indexA >= day.ejercicios.length || indexB >= day.ejercicios.length) return;

    final exA = day.ejercicios[indexA];
    final exB = day.ejercicios[indexB];

    var newEjercicios = [...day.ejercicios];
    
    // Determine superset ID to use
    String supersetId;
    if (exA.supersetId != null && exB.supersetId != null) {
      // Both already have superset IDs
      if (exA.supersetId == exB.supersetId) {
        // Already in the same superset, nothing to do
        return;
      } else {
        // Merge both supersets into one (use A's ID)
        final idA = exA.supersetId!;
        final idB = exB.supersetId!;
        for (int i = 0; i < newEjercicios.length; i++) {
          if (newEjercicios[i].supersetId == idB) {
            newEjercicios[i] = newEjercicios[i].copyWith(supersetId: idA);
          }
        }
        supersetId = idA;
      }
    } else if (exA.supersetId != null) {
      // Only A has a superset ID, add B to it
      supersetId = exA.supersetId!;
      newEjercicios[indexB] = exB.copyWith(supersetId: supersetId);
    } else if (exB.supersetId != null) {
      // Only B has a superset ID, add A to it
      supersetId = exB.supersetId!;
      newEjercicios[indexA] = exA.copyWith(supersetId: supersetId);
    } else {
      // Neither has a superset ID, create a new one
      supersetId = const Uuid().v4();
      newEjercicios[indexA] = exA.copyWith(supersetId: supersetId);
      newEjercicios[indexB] = exB.copyWith(supersetId: supersetId);
    }

    // Ensure exercises with same supersetId are contiguous
    // Group all exercises by supersetId and non-superset exercises
    final exercisesWithSupersetId = <EjercicioEnRutina>[];
    final otherExercises = <EjercicioEnRutina>[];
    
    for (final ex in newEjercicios) {
      if (ex.supersetId == supersetId) {
        exercisesWithSupersetId.add(ex);
      } else {
        otherExercises.add(ex);
      }
    }

    // Find the minimum index where any of the superset exercises currently are
    int minIndex = newEjercicios.length;
    for (final ex in exercisesWithSupersetId) {
      final idx = newEjercicios.indexOf(ex);
      if (idx != -1 && idx < minIndex) {
        minIndex = idx;
      }
    }

    // Rebuild the exercise list with superset exercises contiguous
    final result = <EjercicioEnRutina>[];
    int insertedSuperset = 0;
    
    for (int i = 0; i < newEjercicios.length; i++) {
      if (i == minIndex && insertedSuperset == 0) {
        // Insert all superset exercises here
        result.addAll(exercisesWithSupersetId);
        insertedSuperset = 1;
      }
      
      if (!exercisesWithSupersetId.contains(newEjercicios[i])) {
        result.add(newEjercicios[i]);
      }
    }

    final updatedDay = day.copyWith(ejercicios: result);
    final newDias = [...state.dias];
    newDias[dayIndex] = updatedDay;
    state = state.copyWith(dias: newDias);
  }

  void removeFromSuperset(int dayIndex, int exerciseIndex) {
      final day = state.dias[dayIndex];
      final ex = day.ejercicios[exerciseIndex];
      final oldSupersetId = ex.supersetId;

      if (oldSupersetId == null) return;

      final newEjercicios = [...day.ejercicios];

      // Remove ID from this exercise
      newEjercicios[exerciseIndex] = ex.copyWith(supersetId: null);

      // Check remaining members
      final remaining = newEjercicios.where((e) => e.supersetId == oldSupersetId).toList();
      if (remaining.length == 1) {
          // Clean up the orphan
          final orphanIndex = newEjercicios.indexOf(remaining.first);
           if (orphanIndex != -1) {
               newEjercicios[orphanIndex] = newEjercicios[orphanIndex].copyWith(supersetId: null);
           }
      }

      final updatedDay = day.copyWith(ejercicios: newEjercicios);
      final newDias = [...state.dias];
      newDias[dayIndex] = updatedDay;
      state = state.copyWith(dias: newDias);
  }

  final _logger = Logger();

  Future<String?> saveRoutine() async {
    if (state.nombre.trim().isEmpty) {
      return 'Ponle nombre a tu legado.';
    }
    if (state.dias.isEmpty) {
      return 'Añade al menos un día.';
    }
    bool hasExercise = false;
    for (var d in state.dias) {
      if (d.ejercicios.isNotEmpty) {
        hasExercise = true;
        break;
      }
    }
    if (!hasExercise) {
      return 'Una rutina vacía es debilidad. Añade ejercicios.';
    }

    // Basic sanity checks to avoid DB constraint errors
    try {
      final dayIds = state.dias.map((d) => d.id).toList();
      if (dayIds.length != dayIds.toSet().length) {
        return 'IDs de días duplicados. Reinicia y prueba de nuevo.';
      }

      final allInstanceIds = state.dias.expand((d) => d.ejercicios.map((e) => e.instanceId)).toList();
      if (allInstanceIds.isEmpty) return 'Añade al menos un ejercicio antes de guardar.';
      if (allInstanceIds.length != allInstanceIds.toSet().length) {
        return 'IDs de ejercicios duplicados. Intenta reiniciar la app.';
      }
      if (allInstanceIds.any((id) => id.trim().isEmpty)) {
        return 'Encontrado ID de ejercicio vacío. Revisa los ejercicios.';
      }

      await _repository.saveRutina(state);
      return null;
    } catch (e, s) {
      _logger.e('Error guardando rutina', error: e, stackTrace: s);
      return 'Error al guardar rutina: ${e.toString()}';
    }
  }
}
