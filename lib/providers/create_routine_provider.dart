import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/rutina.dart';
import '../models/dia.dart';
import '../models/ejercicio_en_rutina.dart';
import '../models/library_exercise.dart';
import '../repositories/i_training_repository.dart';
import 'training_provider.dart';
import 'package:collection/collection.dart'; // For equality checks if needed

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
      : super(existingRutina?.copyWith() ?? _createEmptyRoutine());

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

  // Helper to get visual groups
  // Returns list of lists. Each inner list is a "visual item" (can contain 1 or more exercises).
  List<List<EjercicioEnRutina>> _getVisualGroups(List<EjercicioEnRutina> exercises) {
    final groups = <List<EjercicioEnRutina>>[];
    if (exercises.isEmpty) return groups;

    List<EjercicioEnRutina> currentGroup = [];
    String? currentSupersetId;

    for (var ex in exercises) {
      if (currentGroup.isEmpty) {
        currentGroup.add(ex);
        currentSupersetId = ex.supersetId;
      } else {
        // If ex belongs to same superset as current group
        if (ex.supersetId != null && ex.supersetId == currentSupersetId) {
          currentGroup.add(ex);
        } else {
          // Finish previous group
          groups.add(currentGroup);
          // Start new group
          currentGroup = [ex];
          currentSupersetId = ex.supersetId;
        }
      }
    }
    // Add last group
    if (currentGroup.isNotEmpty) {
      groups.add(currentGroup);
    }
    return groups;
  }

  /// Reorders visual items (which might be single exercises or superset blocks)
  void reorderVisualExercises(int dayIndex, int oldVisualIndex, int newVisualIndex) {
    final day = state.dias[dayIndex];
    final visualGroups = _getVisualGroups(day.ejercicios);

    if (oldVisualIndex < newVisualIndex) {
      newVisualIndex -= 1;
    }

    // Get the block of exercises to move
    final exercisesToMove = visualGroups[oldVisualIndex];

    // Remove them from the flat list
    // Note: Since they are contiguous in the flat list (by definition of visual group logic),
    // we can find where they start.
    // However, to be safe, we just filter them out.
    // Wait, relying on instance equality is safer if instanceId is unique.
    final idsToMove = exercisesToMove.map((e) => e.instanceId).toSet();
    final remainingExercises = day.ejercicios.where((e) => !idsToMove.contains(e.instanceId)).toList();

    // Find insertion index in flat list
    // The newVisualIndex corresponds to a position in the `visualGroups` list (after removal).
    // We need to find how many flat exercises are before that visual group.

    // Reconstruct visual groups from remaining exercises to match indices
    final remainingVisualGroups = _getVisualGroups(remainingExercises);

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

  void createSuperset(int dayIndex, int indexA, int indexB) {
      if (indexA < 0 || indexB < 0) return;
      final day = state.dias[dayIndex];
      if (indexA >= day.ejercicios.length || indexB >= day.ejercicios.length) return;

      final exA = day.ejercicios[indexA];
      final exB = day.ejercicios[indexB];

      final newEjercicios = [...day.ejercicios];
      final uuid = const Uuid().v4();

      // Check if they already have supersetIds
      // Case 1: Neither has ID -> New ID for both
      // Case 2: One has ID -> Add the other to that ID
      // Case 3: Both have DIFFERENT IDs -> Merge? Or just overwrite?
      // Requirement: "Link with next". Usually implies merging blocks or extending.

      String idToUse = uuid;
      if (exA.supersetId != null) {
          idToUse = exA.supersetId!;
      } else if (exB.supersetId != null) {
          idToUse = exB.supersetId!;
      }

      // If both have different IDs, we merge all B's group into A's group
      if (exA.supersetId != null && exB.supersetId != null && exA.supersetId != exB.supersetId) {
           final idA = exA.supersetId!;
           final idB = exB.supersetId!;
           // Update all exercises with idB to have idA
           for (int i=0; i<newEjercicios.length; i++) {
               if (newEjercicios[i].supersetId == idB) {
                   newEjercicios[i] = newEjercicios[i].copyWith(supersetId: idA);
               }
           }
      } else {
          // Standard case
          newEjercicios[indexA] = exA.copyWith(supersetId: idToUse);
          newEjercicios[indexB] = exB.copyWith(supersetId: idToUse);
      }

      final updatedDay = day.copyWith(ejercicios: newEjercicios);
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

    await _repository.saveRutina(state);

    return null;
  }
}
