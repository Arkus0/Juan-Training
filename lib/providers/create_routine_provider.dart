import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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
    final day = state.dias[dayIndex];
    final newEjercicios = [...day.ejercicios]..removeAt(exerciseIndex);
    final updatedDay = day.copyWith(ejercicios: newEjercicios);

    final newDias = [...state.dias];
    newDias[dayIndex] = updatedDay;
    state = state.copyWith(dias: newDias);
  }

  void reorderExercises(int dayIndex, int oldIndex, int newIndex) {
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
