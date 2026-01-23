import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:juan_training/models/rutina.dart';
import 'package:juan_training/models/dia.dart';
import 'package:juan_training/models/ejercicio_en_rutina.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/repositories/i_training_repository.dart';
import 'package:juan_training/services/exercise_library_service.dart';
import 'training_provider.dart';


// Provider family to initialize with existing routine or null
final createRoutineProvider =
    StateNotifierProvider.family<CreateRoutineNotifier, Rutina, Rutina?>(
  (ref, existingRutina) {
    final repository = ref.watch(trainingRepositoryProvider);
    return CreateRoutineNotifier(repository, existingRutina);
  },
);

// ⚡ OPTIMIZACIÓN: Provider separado para el estado de UI (expandedDayIndex)
// Esto evita que cambiar qué día está expandido cause rebuild de toda la rutina
// Solo los widgets que observen este provider se reconstruirán
final routineExpandedDayProvider = StateProvider.family<int, String?>((ref, rutinaId) => 0);

class CreateRoutineNotifier extends StateNotifier<Rutina> {
  final ITrainingRepository _repository;

  CreateRoutineNotifier(this._repository, Rutina? existingRutina)
      : super(existingRutina?.copyWith() ?? _createEmptyRoutine()) {
    if (existingRutina == null) {
      addDay();
    }
  }

  // ⚠️ DEPRECADO: Usa routineExpandedDayProvider en su lugar
  // UI state: control which day (index) is expanded in the UI.
  // Default: first day open (0). Use -1 to represent all collapsed.
  // Mantenido para backward compatibility con código existente
  int _expandedDayIndex = 0;
  int get expandedDayIndex => _expandedDayIndex;

  /// ⚠️ DEPRECADO: Usa routineExpandedDayProvider.notifier.state = -1
  /// Cierra todos los días (usa -1 como indicador)
  /// ⚡ OPTIMIZACIÓN: Ya no muta el state de la rutina para cambios de UI
  void collapseAllDays() {
    _expandedDayIndex = -1;
    // No trigger state mutation - UI should use routineExpandedDayProvider
  }

  /// ⚠️ DEPRECADO: Usa routineExpandedDayProvider.notifier.state = index
  /// Abre un día específico
  /// ⚡ OPTIMIZACIÓN: Ya no muta el state de la rutina para cambios de UI
  void setExpandedDay(int index) {
    _expandedDayIndex = index;
    // No trigger state mutation - UI should use routineExpandedDayProvider
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

    // Adjust expanded index if necessary
    if (_expandedDayIndex >= newDias.length) {
      // Removed last or out of range -> collapse
      _expandedDayIndex = -1;
    } else if (_expandedDayIndex > index) {
      // Shift left one position
      _expandedDayIndex -= 1;
    } else if (_expandedDayIndex == index) {
      // Removed the expanded day -> collapse
      _expandedDayIndex = -1;
    }

    state = state.copyWith(dias: newDias);
  }

  void duplicateDay(int dayIndex) {
    final originalDay = state.dias[dayIndex];
    const uuid = Uuid();

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

    // Preserve an identifier for the currently expanded day (if any)
    final String? expandedDayId = (_expandedDayIndex >= 0 && _expandedDayIndex < state.dias.length)
        ? state.dias[_expandedDayIndex].id
        : null;

    final newDias = [...state.dias];
    final item = newDias.removeAt(oldIndex);
    newDias.insert(newIndex, item);

    // Remap the expanded index to the new list; if not found, collapse
    if (expandedDayId == null) {
      _expandedDayIndex = -1;
    } else {
      _expandedDayIndex = newDias.indexWhere((d) => d.id == expandedDayId);
    }

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

  /// Añade múltiples ejercicios a un día desde importación OCR
  /// Cada ejercicio se añade con sus series/reps parseados
  void addExercisesFromOcr(
    int dayIndex,
    List<LibraryExercise> exercises,
    List<int> seriesList,
    List<String> repsRangeList,
  ) {
    if (exercises.isEmpty) return;
    if (dayIndex >= state.dias.length) return;

    final day = state.dias[dayIndex];
    final newExercises = <EjercicioEnRutina>[];

    for (var i = 0; i < exercises.length; i++) {
      final libExercise = exercises[i];
      final series = i < seriesList.length ? seriesList[i] : 3;
      final repsRange = i < repsRangeList.length ? repsRangeList[i] : '8-12';

      newExercises.add(EjercicioEnRutina(
        id: libExercise.id.toString(),
        nombre: libExercise.name,
        descripcion: libExercise.description,
        musculosPrincipales: libExercise.muscles,
        musculosSecundarios: libExercise.secondaryMuscles,
        equipo: libExercise.equipment,
        localImagePath: libExercise.localImagePath,
        series: series,
        repsRange: repsRange,
      ));
    }

    final updatedDay = day.copyWith(
      ejercicios: [...day.ejercicios, ...newExercises],
    );

    final newDias = [...state.dias];
    newDias[dayIndex] = updatedDay;
    state = state.copyWith(dias: newDias);
  }

  void addExerciseToDay(
    int dayIndex, 
    LibraryExercise libExercise, {
    int? defaultSeries,
    String? defaultRepsRange,
  }) {
    // Add exercise immediately without blocking on filesystem I/O
    // Image path validation happens asynchronously
    final newExercise = EjercicioEnRutina(
      id: libExercise.id.toString(),
      nombre: libExercise.name,
      descripcion: libExercise.description,
      musculosPrincipales: libExercise.muscles,
      musculosSecundarios: libExercise.secondaryMuscles,
      equipo: libExercise.equipment,
      localImagePath: libExercise.localImagePath,
      // 🆕 SmartDefaults: usar valores del historial si están disponibles
      series: defaultSeries ?? 3,
      repsRange: defaultRepsRange ?? '8-12',
    );

    final day = state.dias[dayIndex];
    final updatedDay = day.copyWith(
      ejercicios: [...day.ejercicios, newExercise],
    );

    final newDias = [...state.dias];
    newDias[dayIndex] = updatedDay;
    state = state.copyWith(dias: newDias);

    // Asynchronously validate and update the image path if needed
    if (libExercise.localImagePath != null) {
      _validateImagePathAsync(dayIndex, day.ejercicios.length, libExercise.localImagePath!);
    }
  }

  /// Validates image path asynchronously and updates exercise if path is invalid
  Future<void> _validateImagePathAsync(int dayIndex, int exerciseIndex, String imagePath) async {
    try {
      final file = File(imagePath);
      final exists = await file.exists();
      if (!exists) {
        _clearImagePath(dayIndex, exerciseIndex);
        return;
      }
      
      final length = await file.length();
      if (length == 0) {
        _clearImagePath(dayIndex, exerciseIndex);
      }
    } catch (e) {
      // On any error, clear the image path
      _clearImagePath(dayIndex, exerciseIndex);
    }
  }

  void _clearImagePath(int dayIndex, int exerciseIndex) {
    // Check if state still has this day and exercise at this index
    if (dayIndex >= state.dias.length) return;
    final day = state.dias[dayIndex];
    if (exerciseIndex >= day.ejercicios.length) return;

    final exercise = day.ejercicios[exerciseIndex];
    if (exercise.localImagePath == null) return; // Already cleared

    final updatedExercise = exercise.copyWith(localImagePath: null);
    final newEjercicios = [...day.ejercicios];
    newEjercicios[exerciseIndex] = updatedExercise;

    final updatedDay = day.copyWith(ejercicios: newEjercicios);
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

  /// 🆕 Duplica un ejercicio justo después del original
  void duplicateExercise(int dayIndex, int exerciseIndex) {
    final day = state.dias[dayIndex];
    if (exerciseIndex >= day.ejercicios.length) return;

    final original = day.ejercicios[exerciseIndex];
    
    // Crear copia con nuevo instanceId y sin supersetId
    final duplicate = original.copyWith(
      instanceId: const Uuid().v4(),
      supersetId: null, // No mantener la superserie
    );

    final newEjercicios = [...day.ejercicios];
    newEjercicios.insert(exerciseIndex + 1, duplicate);

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
      if (indexA == indexB) return; // Cannot create superset with self

      final exA = day.ejercicios[indexA];
      final exB = day.ejercicios[indexB];

      final newEjercicios = [...day.ejercicios];
      final uuid = const Uuid().v4();

      // Determine the superset ID to use
      String idToUse = uuid;
      if (exA.supersetId != null) {
          idToUse = exA.supersetId!;
      } else if (exB.supersetId != null) {
          idToUse = exB.supersetId!;
      }

      // If both have different IDs, merge all B's group into A's group
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
          // Standard case: assign the superset ID to both exercises
          newEjercicios[indexA] = exA.copyWith(supersetId: idToUse);
          newEjercicios[indexB] = exB.copyWith(supersetId: idToUse);
      }

      // Make exercises with the same supersetId contiguous
      // Collect all exercises with this superset ID
      final supersetExercises = <EjercicioEnRutina>[];
      final otherExercises = <EjercicioEnRutina>[];
      
      for (final ex in newEjercicios) {
        if (ex.supersetId == idToUse) {
          supersetExercises.add(ex);
        } else {
          otherExercises.add(ex);
        }
      }

      // Find the position to insert the superset block
      // Use the minimum index of the two exercises as the insertion point
      final minIndex = indexA < indexB ? indexA : indexB;
      
      // Rebuild the exercise list with superset exercises contiguous
      final reorderedExercises = <EjercicioEnRutina>[];
      int insertedCount = 0;
      for (int i = 0; i < newEjercicios.length; i++) {
        if (i == minIndex) {
          // Insert all superset exercises here
          reorderedExercises.addAll(supersetExercises);
          insertedCount = supersetExercises.length;
        }
        
        // Add the original exercise if it's not part of the superset
        if (newEjercicios[i].supersetId != idToUse) {
          reorderedExercises.add(newEjercicios[i]);
        }
      }
      
      // If we haven't inserted yet (minIndex >= length), append at end
      if (insertedCount == 0) {
        reorderedExercises.addAll(supersetExercises);
      }

      final updatedDay = day.copyWith(ejercicios: reorderedExercises);
      final newDias = [...state.dias];
      newDias[dayIndex] = updatedDay;
      state = state.copyWith(dias: newDias);
  }

  /// Move a whole superset block (by supersetId) to a new insertion index in the flat list
  void moveSuperset(int dayIndex, String supersetId, int insertionIndex) {
    final day = state.dias[dayIndex];
    final original = [...day.ejercicios];

    final block = original.where((e) => e.supersetId == supersetId).toList();
    if (block.isEmpty) return;

    // Remove block
    final remaining = original.where((e) => e.supersetId != supersetId).toList();

    // Clamp insertionIndex
    if (insertionIndex < 0) insertionIndex = 0;
    if (insertionIndex > remaining.length) insertionIndex = remaining.length;

    // Insert block at insertionIndex preserving block order
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

  /// Replaces an exercise with an alternative, preserving series, reps, rest, notes, and superset.
  /// Searches the library for the alternative by name (fuzzy match).
  void replaceExercise(int dayIndex, int exerciseIndex, String alternativaNombre) {
    if (dayIndex >= state.dias.length) return;
    final day = state.dias[dayIndex];
    if (exerciseIndex >= day.ejercicios.length) return;

    final oldExercise = day.ejercicios[exerciseIndex];

    // Search library for the alternative
    final library = ExerciseLibraryService.instance.exercises;
    LibraryExercise? newLibExercise;

    // Try exact match first
    for (final libEx in library) {
      if (libEx.name.toLowerCase() == alternativaNombre.toLowerCase()) {
        newLibExercise = libEx;
        break;
      }
    }

    // If no exact match, try fuzzy/partial match
    if (newLibExercise == null) {
      final lowerAlt = alternativaNombre.toLowerCase();
      for (final libEx in library) {
        if (libEx.name.toLowerCase().contains(lowerAlt) ||
            lowerAlt.contains(libEx.name.toLowerCase())) {
          newLibExercise = libEx;
          break;
        }
      }
    }

    // Create replacement exercise preserving routine-specific data
    final EjercicioEnRutina replacement;
    if (newLibExercise != null) {
      replacement = EjercicioEnRutina(
        id: newLibExercise.id.toString(),
        nombre: newLibExercise.name,
        descripcion: newLibExercise.description,
        musculosPrincipales: newLibExercise.muscles,
        musculosSecundarios: newLibExercise.secondaryMuscles,
        equipo: newLibExercise.equipment,
        localImagePath: newLibExercise.localImagePath,
        // Preserve routine-specific data from old exercise
        series: oldExercise.series,
        repsRange: oldExercise.repsRange,
        descansoSugerido: oldExercise.descansoSugerido,
        notas: oldExercise.notas,
        supersetId: oldExercise.supersetId, // Keep superset membership
      );
    } else {
      // Fallback: Just update the name if not found in library
      replacement = oldExercise.copyWith(
        nombre: alternativaNombre,
      );
    }

    final newEjercicios = [...day.ejercicios];
    newEjercicios[exerciseIndex] = replacement;

    final updatedDay = day.copyWith(ejercicios: newEjercicios);
    final newDias = [...state.dias];
    newDias[dayIndex] = updatedDay;
    state = state.copyWith(dias: newDias);
  }

  final _logger = Logger();

  Future<String?> saveRoutine() async {
    if (state.nombre.trim().isEmpty) {
      return 'Dale un nombre a tu rutina.';
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
