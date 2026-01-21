import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import 'package:juan_training/models/dia.dart';
import 'package:juan_training/models/ejercicio_en_rutina.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/models/rutina.dart';
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

  /// Duplicates a day with all its exercises.
  /// Superset mappings are preserved: exercises that were in the same superset
  /// in the original day will be in a new superset together in the duplicated day.
  /// Each duplicated exercise gets a new instance ID and superset ID.
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
    // Create exercise immediately with the provided path
    // We'll validate asynchronously to avoid blocking the UI thread
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

    // Perform async validation of the image path without blocking UI
    // If the path is invalid, we'll update the exercise to remove it
    if (libExercise.localImagePath != null) {
      // Index of newly added exercise is the previous length (0-based indexing)
      _validateImagePathAsync(dayIndex, day.ejercicios.length, libExercise.localImagePath!);
    }
  }

  /// Validates image path asynchronously and updates exercise if path is invalid
  void _validateImagePathAsync(int dayIndex, int exerciseIndex, String imagePath) {
    // Use Future.microtask to defer filesystem check and handle errors properly
    Future.microtask(() async {
      try {
        final file = File(imagePath);
        final exists = await file.exists();
        final hasContent = exists && await file.length() > 0;
        
        if (!hasContent) {
          // Path is invalid, update exercise to remove it
          _updateExerciseImagePath(dayIndex, exerciseIndex, null);
        }
      } catch (e) {
        // If any filesystem error occurs, remove the invalid path
        // Errors are expected here for invalid paths and should be silently handled
        _updateExerciseImagePath(dayIndex, exerciseIndex, null);
      }
    });
  }

  /// Helper to update exercise image path
  void _updateExerciseImagePath(int dayIndex, int exerciseIndex, String? newPath) {
    // Ensure indices are still valid (user might have modified routine)
    if (dayIndex >= state.dias.length) return;
    
    final day = state.dias[dayIndex];
    if (exerciseIndex >= day.ejercicios.length) return;

    final exercise = day.ejercicios[exerciseIndex];
    final updatedExercise = exercise.copyWith(localImagePath: newPath);
    
    updateExercise(dayIndex, exerciseIndex, updatedExercise);
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

  // --- Helper Methods ---

  /// Groups exercises into visual items for UI rendering.
  /// Each visual item is either:
  /// - A single non-superset exercise, or
  /// - A contiguous group of exercises sharing the same superset ID
  /// 
  /// Returns a list of lists, where each inner list represents one visual item.
  /// Exercises within a superset group are kept in their original order for stability.
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
        // Group all exercises with the same superset ID
        final group = exercises.where((e) => e.supersetId == ex.supersetId).toList();
        // Sort by original order to maintain stability
        group.sort((a, b) => exerciseOrder[a.instanceId]!.compareTo(exerciseOrder[b.instanceId]!));
        groups.add(group);
        for (final groupEx in group) {
          processedInstanceIds.add(groupEx.instanceId);
        }
      } else {
        // Single exercise
        groups.add([ex]);
        processedInstanceIds.add(ex.instanceId);
      }
    }
    return groups;
  }

  /// Reorders visual exercise groups (single exercises or superset blocks).
  /// When a superset is moved, all exercises in that superset move together as a unit.
  /// This ensures supersets remain contiguous after reordering.
  void reorderVisualExercises(int dayIndex, int oldVisualIndex, int newVisualIndex) {
    final day = state.dias[dayIndex];
    final visualGroups = _getVisualGroups(day.ejercicios);

    if (oldVisualIndex < newVisualIndex) {
      newVisualIndex -= 1;
    }

    // Get the block of exercises to move
    final exercisesToMove = visualGroups[oldVisualIndex];

    // Remove them from the flat list by filtering out their instance IDs
    final idsToMove = exercisesToMove.map((e) => e.instanceId).toSet();
    final remainingExercises = day.ejercicios.where((e) => !idsToMove.contains(e.instanceId)).toList();

    // Find insertion index in the flat list based on visual group position
    final remainingVisualGroups = _getVisualGroups(remainingExercises);

    int flatInsertionIndex = 0;
    for (int i = 0; i < newVisualIndex; i++) {
      if (i < remainingVisualGroups.length) {
        flatInsertionIndex += remainingVisualGroups[i].length;
      }
    }

    // Insert the moved exercises at the calculated position
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

  /// Creates a superset by linking two exercises together.
  /// Uses deterministic ID assignment: reuses existing superset IDs when possible,
  /// or creates a new UUID when linking two non-superset exercises.
  /// Ensures contiguity by merging superset groups when linking exercises from different supersets.
  void createSuperset(int dayIndex, int indexA, int indexB) {
    if (indexA < 0 || indexB < 0) return;
    final day = state.dias[dayIndex];
    if (indexA >= day.ejercicios.length || indexB >= day.ejercicios.length) return;

    final exA = day.ejercicios[indexA];
    final exB = day.ejercicios[indexB];

    final newEjercicios = [...day.ejercicios];
    
    String idToUse;
    
    // Deterministic ID assignment logic:
    // 1. If both have different superset IDs -> merge B's group into A's group
    // 2. If A has superset ID -> add B to A's superset
    // 3. If B has superset ID -> add A to B's superset
    // 4. If neither has ID -> create new superset with new UUID
    
    if (exA.supersetId != null && exB.supersetId != null && exA.supersetId != exB.supersetId) {
      // Merge case: update all exercises with B's ID to have A's ID
      final idA = exA.supersetId!;
      final idB = exB.supersetId!;
      
      for (int i = 0; i < newEjercicios.length; i++) {
        if (newEjercicios[i].supersetId == idB) {
          newEjercicios[i] = newEjercicios[i].copyWith(supersetId: idA);
        }
      }
    } else if (exA.supersetId != null) {
      // A has ID, add B to it
      idToUse = exA.supersetId!;
      newEjercicios[indexB] = exB.copyWith(supersetId: idToUse);
    } else if (exB.supersetId != null) {
      // B has ID, add A to it
      idToUse = exB.supersetId!;
      newEjercicios[indexA] = exA.copyWith(supersetId: idToUse);
    } else {
      // Neither has ID, create new superset
      idToUse = const Uuid().v4();
      newEjercicios[indexA] = exA.copyWith(supersetId: idToUse);
      newEjercicios[indexB] = exB.copyWith(supersetId: idToUse);
    }

    final updatedDay = day.copyWith(ejercicios: newEjercicios);
    final newDias = [...state.dias];
    newDias[dayIndex] = updatedDay;
    state = state.copyWith(dias: newDias);
  }

  /// Removes an exercise from its superset.
  /// If removing the exercise leaves only one exercise in the superset,
  /// that remaining exercise is also removed from the superset (no single-exercise supersets).
  void removeFromSuperset(int dayIndex, int exerciseIndex) {
    final day = state.dias[dayIndex];
    final ex = day.ejercicios[exerciseIndex];
    final oldSupersetId = ex.supersetId;

    if (oldSupersetId == null) return;

    final newEjercicios = [...day.ejercicios];

    // Remove superset ID from this exercise
    newEjercicios[exerciseIndex] = ex.copyWith(supersetId: null);

    // Check remaining members of the superset
    final remaining = newEjercicios.where((e) => e.supersetId == oldSupersetId).toList();
    if (remaining.length == 1) {
      // Clean up the orphaned exercise (no single-exercise supersets)
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
