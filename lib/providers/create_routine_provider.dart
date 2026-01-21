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
    // Add exercise immediately without blocking I/O
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

    // Schedule async validation of local image path (non-blocking)
    if (libExercise.localImagePath != null) {
      final exerciseIndex = day.ejercicios.length; // Index of newly added exercise
      _updateExerciseLocalImagePath(
          dayIndex, exerciseIndex, libExercise.localImagePath!);
    }
  }

  /// Asynchronously validates and updates exercise local image path.
  /// Runs in a microtask to avoid blocking the UI thread.
  void _updateExerciseLocalImagePath(
      int dayIndex, int exerciseIndex, String imagePath) {
    Future.microtask(() async {
      String? validPath;
      try {
        final file = File(imagePath);
        // Async file checks
        if (await file.exists()) {
          final length = await file.length();
          if (length > 0) {
            validPath = imagePath;
          }
        }
      } catch (e) {
        // If any error occurs, clear the path
        validPath = null;
      }

      // Update state if path changed and notifier still mounted
      // StateNotifier is disposed when the provider is disposed
      try {
        final currentDay = state.dias[dayIndex];
        if (exerciseIndex < currentDay.ejercicios.length) {
          final currentExercise = currentDay.ejercicios[exerciseIndex];
          // Only update if the path is different from what we validated
          if (currentExercise.localImagePath != validPath) {
            final updatedExercise =
                currentExercise.copyWith(localImagePath: validPath);
            updateExercise(dayIndex, exerciseIndex, updatedExercise);
          }
        }
      } catch (e) {
        // Notifier may have been disposed, ignore
      }
    });
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

  /// Computes visual groups from a list of exercises.
  /// A visual group is either:
  /// - A single exercise without a supersetId, or
  /// - A contiguous block of exercises sharing the same supersetId.
  /// Returns a list of groups, where each group is a list of exercises.
  List<List<EjercicioEnRutina>> _computeVisualGroups(
      List<EjercicioEnRutina> exercises) {
    if (exercises.isEmpty) return [];

    final groups = <List<EjercicioEnRutina>>[];
    int i = 0;

    while (i < exercises.length) {
      final current = exercises[i];

      if (current.supersetId == null) {
        // Single exercise without superset
        groups.add([current]);
        i++;
      } else {
        // Start of a superset group - collect all contiguous exercises with same ID
        final supersetId = current.supersetId!;
        final group = <EjercicioEnRutina>[];

        while (i < exercises.length &&
            exercises[i].supersetId == supersetId) {
          group.add(exercises[i]);
          i++;
        }

        groups.add(group);
      }
    }

    return groups;
  }

  /// Reorders visual items (which might be single exercises or superset blocks)
  void reorderVisualExercises(int dayIndex, int oldVisualIndex, int newVisualIndex) {
    final day = state.dias[dayIndex];
    final visualGroups = _computeVisualGroups(day.ejercicios);

    if (oldVisualIndex < 0 || oldVisualIndex >= visualGroups.length) return;
    if (newVisualIndex < 0 || newVisualIndex >= visualGroups.length) return;

    // Adjust newVisualIndex for standard reordering logic
    if (oldVisualIndex < newVisualIndex) {
      newVisualIndex -= 1;
    }

    // Remove the group from the visual groups list
    final movedGroups = [...visualGroups];
    final groupToMove = movedGroups.removeAt(oldVisualIndex);
    movedGroups.insert(newVisualIndex, groupToMove);

    // Flatten back to a single list of exercises
    final newEjercicios =
        movedGroups.expand((group) => group).toList();

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

  /// Creates a superset between two exercises at the given indices.
  /// If the exercises are not adjacent, they will be made adjacent.
  /// Ensures superset members are contiguous.
  void createSuperset(int dayIndex, int indexA, int indexB) {
    if (indexA < 0 || indexB < 0) return;
    final day = state.dias[dayIndex];
    if (indexA >= day.ejercicios.length || indexB >= day.ejercicios.length)
      return;
    if (indexA == indexB) return;

    final exA = day.ejercicios[indexA];
    final exB = day.ejercicios[indexB];
    final newEjercicios = [...day.ejercicios];

    // Determine superset ID to use
    String supersetId;
    if (exA.supersetId != null && exB.supersetId != null) {
      if (exA.supersetId == exB.supersetId) {
        // Already in same superset, nothing to do
        return;
      }
      // Merge two different supersets: use exA's ID, update all of exB's group
      supersetId = exA.supersetId!;
      final oldIdB = exB.supersetId!;
      for (int i = 0; i < newEjercicios.length; i++) {
        if (newEjercicios[i].supersetId == oldIdB) {
          newEjercicios[i] =
              newEjercicios[i].copyWith(supersetId: supersetId);
        }
      }
    } else if (exA.supersetId != null) {
      // Add exB to exA's superset
      supersetId = exA.supersetId!;
      newEjercicios[indexB] = exB.copyWith(supersetId: supersetId);
    } else if (exB.supersetId != null) {
      // Add exA to exB's superset
      supersetId = exB.supersetId!;
      newEjercicios[indexA] = exA.copyWith(supersetId: supersetId);
    } else {
      // Neither has a superset, create new one
      supersetId = const Uuid().v4();
      newEjercicios[indexA] = exA.copyWith(supersetId: supersetId);
      newEjercicios[indexB] = exB.copyWith(supersetId: supersetId);
    }

    // Ensure contiguity: move all exercises with this supersetId together
    final supersetExercises = <EjercicioEnRutina>[];
    final otherExercises = <EjercicioEnRutina>[];

    for (final ex in newEjercicios) {
      if (ex.supersetId == supersetId) {
        supersetExercises.add(ex);
      } else {
        otherExercises.add(ex);
      }
    }

    // Insert superset group at the position of the first occurrence
    // Find how many "other" exercises come before the first superset exercise
    int insertPosition = 0;
    for (int i = 0; i < newEjercicios.length; i++) {
      if (newEjercicios[i].supersetId == supersetId) {
        break;
      }
      insertPosition++;
    }

    final reordered = <EjercicioEnRutina>[];
    reordered.addAll(otherExercises.sublist(0, insertPosition.clamp(0, otherExercises.length)));
    reordered.addAll(supersetExercises);
    reordered.addAll(otherExercises.sublist(insertPosition.clamp(0, otherExercises.length)));

    final updatedDay = day.copyWith(ejercicios: reordered);
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

      // Check remaining members and clean up orphan if only one remains
      int? orphanIndex;
      int count = 0;
      for (int i = 0; i < newEjercicios.length; i++) {
        if (newEjercicios[i].supersetId == oldSupersetId) {
          count++;
          orphanIndex = i;
        }
      }

      if (count == 1 && orphanIndex != null) {
        // Only one exercise left with this superset ID, clean it up
        newEjercicios[orphanIndex] = newEjercicios[orphanIndex].copyWith(supersetId: null);
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
