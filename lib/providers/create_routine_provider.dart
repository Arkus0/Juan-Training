import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hive/hive.dart';
import '../models/rutina.dart';
import '../models/dia.dart';
import '../models/ejercicio_en_rutina.dart';
import '../models/library_exercise.dart';

// Provider family to initialize with existing routine or null
final createRoutineProvider = StateNotifierProvider.family<CreateRoutineNotifier, Rutina, Rutina?>(
  (ref, existingRutina) {
    return CreateRoutineNotifier(existingRutina);
  },
);

class CreateRoutineNotifier extends StateNotifier<Rutina> {
  CreateRoutineNotifier(Rutina? existingRutina)
      : super(existingRutina != null
            ? _deepCopy(existingRutina)
            : _createEmptyRoutine());

  static Rutina _createEmptyRoutine() {
    return Rutina(
      id: const Uuid().v4(),
      nombre: '',
      dias: [],
      creada: DateTime.now(),
    );
  }

  static Rutina _deepCopy(Rutina original) {
    // We create a detached copy.
    return Rutina(
      id: original.id,
      nombre: original.nombre,
      creada: original.creada,
      dias: original.dias.map((d) => _copyDia(d)).toList(),
    );
  }

  static Dia _copyDia(Dia d) {
    return Dia(
      nombre: d.nombre,
      ejercicios: d.ejercicios.map((e) => e.copyWith()).toList(),
      progressionType: d.progressionType,
      id: d.id, // Preserve Stable ID
    );
  }

  // --- Actions ---

  void updateName(String name) {
    state.nombre = name;
    state = _deepCopy(state);
  }

  void addDay() {
    final newDia = Dia(
      nombre: 'Día ${state.dias.length + 1}',
      ejercicios: [],
      id: const Uuid().v4(), // New ID
    );
    state.dias.add(newDia);
    state = _deepCopy(state);
  }

  void removeDay(int index) {
    state.dias.removeAt(index);
    state = _deepCopy(state);
  }

  void reorderDays(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = state.dias.removeAt(oldIndex);
    state.dias.insert(newIndex, item);
    state = _deepCopy(state);
  }

  void updateDayName(int index, String newName) {
    state.dias[index].nombre = newName;
    state = _deepCopy(state);
  }

  void updateDayProgression(int index, String type) {
    state.dias[index].progressionType = type;
    state = _deepCopy(state);
  }

  void addExerciseToDay(int dayIndex, LibraryExercise libExercise) {
    final exercise = EjercicioEnRutina(
      id: libExercise.id.toString(),
      nombre: libExercise.name,
      descripcion: libExercise.description,
      musculosPrincipales: libExercise.muscles,
      musculosSecundarios: libExercise.secondaryMuscles,
      equipo: libExercise.equipment,
      localImagePath: libExercise.localImagePath,
      series: 3,
      repsRange: '8-12',
      notas: null,
      instanceId: const Uuid().v4(), // New ID
    );
    state.dias[dayIndex].ejercicios.add(exercise);
    state = _deepCopy(state);
  }

  void removeExercise(int dayIndex, int exerciseIndex) {
    state.dias[dayIndex].ejercicios.removeAt(exerciseIndex);
    state = _deepCopy(state);
  }

  void reorderExercises(int dayIndex, int oldIndex, int newIndex) {
    final day = state.dias[dayIndex];
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = day.ejercicios.removeAt(oldIndex);
    day.ejercicios.insert(newIndex, item);
    state = _deepCopy(state);
  }

  void updateExercise(int dayIndex, int exerciseIndex, EjercicioEnRutina updated) {
    state.dias[dayIndex].ejercicios[exerciseIndex] = updated;
    state = _deepCopy(state);
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

    final box = Hive.box<Rutina>('rutinas');

    int? keyToUpdate;
    for (var key in box.keys) {
      final r = box.get(key);
      if (r?.id == state.id) {
        keyToUpdate = key;
        break;
      }
    }

    if (keyToUpdate != null) {
      await box.put(keyToUpdate, state);
    } else {
      await box.add(state);
    }

    return null;
  }
}
