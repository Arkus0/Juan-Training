import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:logger/logger.dart';
import '../models/rutina.dart';
import '../models/dia.dart';
import '../models/ejercicio_en_rutina.dart';
import '../models/library_exercise.dart';
import '../repositories/i_training_repository.dart';
import 'training_provider.dart';


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
    // Validate local image path to avoid runtime exceptions when the file is missing/corrupt
    String? validLocalPath;
    try {
      if (libExercise.localImagePath != null) {
        final f = File(libExercise.localImagePath!);
        if (f.existsSync() && f.lengthSync() > 0) {
          validLocalPath = libExercise.localImagePath;
        }
      }
    } catch (e) {
      // If any filesystem error occurs, ignore the path and proceed without image
      validLocalPath = null;
    }

    final newExercise = EjercicioEnRutina(
      id: libExercise.id.toString(),
      nombre: libExercise.name,
      descripcion: libExercise.description,
      musculosPrincipales: libExercise.muscles,
      musculosSecundarios: libExercise.secondaryMuscles,
      equipo: libExercise.equipment,
      localImagePath: validLocalPath,
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

  // Helper to get visual groups
  // Returns list of lists. Each inner list is a "visual item" (can contain 1 or more exercises).
  List<List<EjercicioEnRutina>> _getVisualGroups(List<EjercicioEnRutina> exercises) {
    if (exercises.isEmpty) return [];

    final groups = <List<EjercicioEnRutina>>[];
    final processedInstanceIds = <String>{};
    final exerciseOrder = {for (var i = 0; i < exercises.length; i++) exercises[i].instanceId: i};

    for (final ex in exercises) {
      if (processedInstanceIds.contains(ex.instanceId)) {
        continue;
      }

      if (ex.supersetId != null) {
        final group = exercises.where((e) => e.supersetId == ex.supersetId).toList();
        // Sort the group by their original order to maintain stability
        group.sort((a, b) => exerciseOrder[a.instanceId]!.compareTo(exerciseOrder[b.instanceId]!));
        groups.add(group);
        for (final groupEx in group) {
          processedInstanceIds.add(groupEx.instanceId);
        }
      } else {
        groups.add([ex]);
        processedInstanceIds.add(ex.instanceId);
      }
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

      List<EjercicioEnRutina> _collectGroup(List<EjercicioEnRutina> list, int index) {
        final target = list[index];
        if (target.supersetId == null) return [target];
        return list.where((e) => e.supersetId == target.supersetId).toList();
      }

      final original = [...day.ejercicios];
      final sourceGroup = _collectGroup(original, indexA);
      final targetGroup = _collectGroup(original, indexB);

      final sourceIds = sourceGroup.map((e) => e.instanceId).toSet();
      final targetIds = targetGroup.map((e) => e.instanceId).toSet();
      final blockIds = {...sourceIds, ...targetIds};

      // Decide which supersetId to keep/assign
      String idToUse = const Uuid().v4();
      final sourceId = sourceGroup.first.supersetId;
      final targetId = targetGroup.first.supersetId;
      if (targetId != null) {
        idToUse = targetId;
      } else if (sourceId != null) {
        idToUse = sourceId;
      }

      // Build remaining list while finding insertion point (before the first target member)
      final remaining = <EjercicioEnRutina>[];
      int insertionIndex = 0;
      for (int i = 0; i < original.length; i++) {
        final ex = original[i];
        if (blockIds.contains(ex.instanceId)) {
          if (targetIds.contains(ex.instanceId)) {
            insertionIndex = remaining.length; // place block where target started
          }
          continue;
        }
        remaining.add(ex);
      }

      // Normalize the block: target group first, then source group, all with the same supersetId
      final block = [
        ...targetGroup.map((e) => e.copyWith(supersetId: idToUse)),
        ...sourceGroup.map((e) => e.copyWith(supersetId: idToUse)),
      ];

      final newEjercicios = [...remaining]..insertAll(insertionIndex, block);

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
