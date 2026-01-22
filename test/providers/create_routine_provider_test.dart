import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juan_training/models/rutina.dart';
import 'package:juan_training/models/dia.dart';
import 'package:juan_training/models/ejercicio_en_rutina.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/models/sesion.dart';
import 'package:juan_training/models/ejercicio.dart';
import 'package:juan_training/models/serie_log.dart';
import 'package:juan_training/providers/create_routine_provider.dart';
import 'package:juan_training/repositories/i_training_repository.dart';

/// Mock implementation of ITrainingRepository for testing
class MockTrainingRepository implements ITrainingRepository {
  List<Rutina> _rutinas = [];
  List<Sesion> _sesiones = [];
  final Map<String, String> _notes = {};

  @override
  Stream<List<Rutina>> watchRutinas() {
    return Stream.value(_rutinas);
  }

  @override
  Future<void> saveRutina(Rutina rutina) async {
    final index = _rutinas.indexWhere((r) => r.id == rutina.id);
    if (index >= 0) {
      _rutinas[index] = rutina;
    } else {
      _rutinas.add(rutina);
    }
  }

  @override
  Future<void> deleteRutina(String id) async {
    _rutinas.removeWhere((r) => r.id == id);
  }

  @override
  Stream<List<Sesion>> watchSesionesHistory() {
    return Stream.value(_sesiones);
  }

  @override
  Future<void> saveSesion(Sesion sesion) async {
    _sesiones.add(sesion);
  }

  @override
  Future<List<Sesion>> getHistoryForExercise(String exerciseName) async {
    return _sesiones.where((s) => s.ejercicios.any((e) => e.nombre == exerciseName)).toList();
  }

  @override
  Future<void> saveActiveSession(ActiveSessionData data) async {}

  @override
  Future<ActiveSessionData?> getActiveSession() async => null;

  @override
  Stream<ActiveSessionData?> watchActiveSession() {
    return Stream.value(null);
  }

  @override
  Future<void> clearActiveSession() async {}

  @override
  Future<String> getNote(String exerciseName) async {
    return _notes[exerciseName] ?? '';
  }

  @override
  Future<void> saveNote(String exerciseName, String note) async {
    _notes[exerciseName] = note;
  }
}

void main() {
  late ProviderContainer container;
  late MockTrainingRepository mockRepository;

  setUp(() {
    mockRepository = MockTrainingRepository();
    container = ProviderContainer(
      overrides: [
        trainingRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CreateRoutineNotifier - addExerciseToDay', () {
    test('adds exercise to specified day', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final libExercise = LibraryExercise(
        id: 1,
        name: 'Push Up',
        muscleGroup: 'Chest',
        equipment: 'Bodyweight',
        description: 'A basic push up',
        muscles: ['Pectorals'],
        secondaryMuscles: ['Triceps'],
      );

      notifier.addExerciseToDay(0, libExercise);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias.length, 1);
      expect(state.dias[0].ejercicios.length, 1);
      expect(state.dias[0].ejercicios[0].nombre, 'Push Up');
      expect(state.dias[0].ejercicios[0].id, '1');
      expect(state.dias[0].ejercicios[0].musculosPrincipales, ['Pectorals']);
    });

    test('adds multiple exercises to same day', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise1 = LibraryExercise(
        id: 1,
        name: 'Push Up',
        muscleGroup: 'Chest',
        equipment: 'Bodyweight',
      );
      final exercise2 = LibraryExercise(
        id: 2,
        name: 'Squat',
        muscleGroup: 'Legs',
        equipment: 'Bodyweight',
      );

      notifier.addExerciseToDay(0, exercise1);
      notifier.addExerciseToDay(0, exercise2);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias[0].ejercicios.length, 2);
      expect(state.dias[0].ejercicios[0].nombre, 'Push Up');
      expect(state.dias[0].ejercicios[1].nombre, 'Squat');
    });

    test('generates unique instanceId for each exercise', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final libExercise = LibraryExercise(
        id: 1,
        name: 'Push Up',
        muscleGroup: 'Chest',
        equipment: 'Bodyweight',
      );

      notifier.addExerciseToDay(0, libExercise);
      notifier.addExerciseToDay(0, libExercise);

      final state = container.read(createRoutineProvider(null));
      final instanceId1 = state.dias[0].ejercicios[0].instanceId;
      final instanceId2 = state.dias[0].ejercicios[1].instanceId;
      
      expect(instanceId1, isNot(equals(instanceId2)));
      expect(instanceId1, isNotEmpty);
      expect(instanceId2, isNotEmpty);
    });
  });

  group('CreateRoutineNotifier - createSuperset', () {
    test('creates superset with unique ID for two exercises', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise1 = LibraryExercise(id: 1, name: 'Ex1', muscleGroup: 'Chest', equipment: 'None');
      final exercise2 = LibraryExercise(id: 2, name: 'Ex2', muscleGroup: 'Chest', equipment: 'None');

      notifier.addExerciseToDay(0, exercise1);
      notifier.addExerciseToDay(0, exercise2);
      notifier.createSuperset(0, 0, 1);

      final state = container.read(createRoutineProvider(null));
      final ex1 = state.dias[0].ejercicios[0];
      final ex2 = state.dias[0].ejercicios[1];
      
      expect(ex1.supersetId, isNotNull);
      expect(ex2.supersetId, isNotNull);
      expect(ex1.supersetId, equals(ex2.supersetId));
    });

    test('makes superset exercises contiguous', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      // Add 4 exercises
      for (int i = 1; i <= 4; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i,
          name: 'Exercise $i',
          muscleGroup: 'Test',
          equipment: 'None',
        ));
      }

      // Create superset with exercise at index 0 and 2 (non-contiguous)
      notifier.createSuperset(0, 0, 2);

      final state = container.read(createRoutineProvider(null));
      final exercises = state.dias[0].ejercicios;
      
      // Find exercises with superset ID
      final supersetId = exercises[0].supersetId;
      expect(supersetId, isNotNull);
      
      // Count exercises with this superset ID and verify they're contiguous
      final supersetIndices = <int>[];
      for (int i = 0; i < exercises.length; i++) {
        if (exercises[i].supersetId == supersetId) {
          supersetIndices.add(i);
        }
      }
      
      expect(supersetIndices.length, 2);
      // Verify they are contiguous (difference of 1)
      expect(supersetIndices[1] - supersetIndices[0], 1);
    });

    test('extends existing superset when adding third exercise', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      // Add 3 exercises
      for (int i = 1; i <= 3; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i,
          name: 'Exercise $i',
          muscleGroup: 'Test',
          equipment: 'None',
        ));
      }

      // Create superset with first two
      notifier.createSuperset(0, 0, 1);
      
      final stateBefore = container.read(createRoutineProvider(null));
      final supersetId = stateBefore.dias[0].ejercicios[0].supersetId;

      // Add third exercise to superset
      notifier.createSuperset(0, 1, 2);

      final stateAfter = container.read(createRoutineProvider(null));
      final exercises = stateAfter.dias[0].ejercicios;
      
      // All three should have the same original superset ID
      expect(exercises[0].supersetId, equals(supersetId));
      expect(exercises[1].supersetId, equals(supersetId));
      expect(exercises[2].supersetId, equals(supersetId));
    });
  });

  group('CreateRoutineNotifier - removeFromSuperset', () {
    test('removes exercise from superset', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      // Create superset with 2 exercises
      notifier.addExerciseToDay(0, LibraryExercise(id: 1, name: 'Ex1', muscleGroup: 'Test', equipment: 'None'));
      notifier.addExerciseToDay(0, LibraryExercise(id: 2, name: 'Ex2', muscleGroup: 'Test', equipment: 'None'));
      notifier.createSuperset(0, 0, 1);

      // Remove first exercise from superset
      notifier.removeFromSuperset(0, 0);

      final state = container.read(createRoutineProvider(null));
      final ex1 = state.dias[0].ejercicios[0];
      final ex2 = state.dias[0].ejercicios[1];
      
      expect(ex1.supersetId, isNull);
      expect(ex2.supersetId, isNull); // Should also be null since only 1 remains
    });

    test('clears supersetId from remaining exercise when only one left', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      // Create superset with 3 exercises
      for (int i = 1; i <= 3; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(id: i, name: 'Ex$i', muscleGroup: 'Test', equipment: 'None'));
      }
      notifier.createSuperset(0, 0, 1);
      notifier.createSuperset(0, 1, 2);

      final supersetId = container.read(createRoutineProvider(null)).dias[0].ejercicios[0].supersetId;

      // Remove two exercises
      notifier.removeFromSuperset(0, 0);
      notifier.removeFromSuperset(0, 0); // Index shifts after first removal

      final state = container.read(createRoutineProvider(null));
      // The remaining exercise should have no supersetId
      expect(state.dias[0].ejercicios.every((e) => e.supersetId == null), isTrue);
    });

    test('maintains superset for 2 remaining exercises when removing from 3-exercise superset', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      // Create superset with 3 exercises
      for (int i = 1; i <= 3; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(id: i, name: 'Ex$i', muscleGroup: 'Test', equipment: 'None'));
      }
      notifier.createSuperset(0, 0, 1);
      notifier.createSuperset(0, 1, 2);

      final supersetId = container.read(createRoutineProvider(null)).dias[0].ejercicios[0].supersetId;

      // Remove one exercise
      notifier.removeFromSuperset(0, 0);

      final state = container.read(createRoutineProvider(null));
      final exercises = state.dias[0].ejercicios;
      
      // Two exercises should still have the supersetId
      final withSuperset = exercises.where((e) => e.supersetId == supersetId).length;
      expect(withSuperset, 2);
    });
  });

  group('CreateRoutineNotifier - reorderVisualExercises', () {
    test('reorders single exercises correctly', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      // Add 3 exercises
      for (int i = 1; i <= 3; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i,
          name: 'Exercise $i',
          muscleGroup: 'Test',
          equipment: 'None',
        ));
      }

      final stateBefore = container.read(createRoutineProvider(null));
      final exercise1Name = stateBefore.dias[0].ejercicios[0].nombre;

      // Move first exercise to position 2 (after exercise 2 and 3)
      notifier.reorderVisualExercises(0, 0, 2);

      final stateAfter = container.read(createRoutineProvider(null));
      final exercises = stateAfter.dias[0].ejercicios;
      
      // Exercise 1 should now be at index 1 (accounting for the off-by-one in reordering)
      expect(exercises[1].nombre, exercise1Name);
    });

    test('moves superset as a unit when reordering', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      // Add 4 exercises: Ex1, Ex2 (superset), Ex3, Ex4
      for (int i = 1; i <= 4; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i,
          name: 'Exercise $i',
          muscleGroup: 'Test',
          equipment: 'None',
        ));
      }

      // Create superset with Ex1 and Ex2
      notifier.createSuperset(0, 0, 1);

      final supersetId = container.read(createRoutineProvider(null)).dias[0].ejercicios[0].supersetId;

      // Move the superset to position 2 (after Ex3 and Ex4)
      // Visual groups: [SupersetBlock(Ex1,Ex2)], [Ex3], [Ex4]
      notifier.reorderVisualExercises(0, 0, 2);

      final state = container.read(createRoutineProvider(null));
      final exercises = state.dias[0].ejercicios;
      
      // The two superset exercises should still be adjacent
      final supersetIndices = <int>[];
      for (int i = 0; i < exercises.length; i++) {
        if (exercises[i].supersetId == supersetId) {
          supersetIndices.add(i);
        }
      }
      
      expect(supersetIndices.length, 2);
      expect(supersetIndices[1] - supersetIndices[0], 1); // Contiguous
      
      // And they should be at the end (indices 2 and 3)
      expect(supersetIndices[0], 2);
      expect(supersetIndices[1], 3);
    });

    test('preserves superset integrity during complex reordering', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      // Add 6 exercises: Ex1, Ex2, Ex3 (superset), Ex4 (superset), Ex5, Ex6
      for (int i = 1; i <= 6; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i,
          name: 'Exercise $i',
          muscleGroup: 'Test',
          equipment: 'None',
        ));
      }

      // Create superset with Ex3 and Ex4
      notifier.createSuperset(0, 2, 3);

      final supersetId = container.read(createRoutineProvider(null)).dias[0].ejercicios[0].supersetId;

      // Move superset to the beginning
      // Visual indices: [Ex1], [Ex2], [Superset(Ex3,Ex4)], [Ex5], [Ex6]
      notifier.reorderVisualExercises(0, 2, 0);

      final state = container.read(createRoutineProvider(null));
      final exercises = state.dias[0].ejercicios;
      
      // Find the superset exercises
      final supersetExercises = exercises.where((e) => e.supersetId == supersetId).toList();
      expect(supersetExercises.length, 2);
      
      // They should be at indices 0 and 1
      expect(exercises[0].supersetId, equals(supersetId));
      expect(exercises[1].supersetId, equals(supersetId));
    });
  });

  group('CreateRoutineNotifier - duplicateDay', () {
    test('duplicates day with exercises', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      // Add exercises to day
      for (int i = 1; i <= 3; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i,
          name: 'Exercise $i',
          muscleGroup: 'Test',
          equipment: 'None',
        ));
      }

      notifier.duplicateDay(0);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias.length, 2);
      expect(state.dias[0].ejercicios.length, 3);
      expect(state.dias[1].ejercicios.length, 3);
      expect(state.dias[1].nombre.contains('Copia'), isTrue);
    });

    test('preserves superset mapping when duplicating day', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      // Add 3 exercises and create a superset
      for (int i = 1; i <= 3; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i,
          name: 'Exercise $i',
          muscleGroup: 'Test',
          equipment: 'None',
        ));
      }
      notifier.createSuperset(0, 0, 1);

      final originalSupersetId = container.read(createRoutineProvider(null)).dias[0].ejercicios[0].supersetId;

      notifier.duplicateDay(0);

      final state = container.read(createRoutineProvider(null));
      
      // Check original day superset is unchanged
      expect(state.dias[0].ejercicios[0].supersetId, equals(originalSupersetId));
      expect(state.dias[0].ejercicios[1].supersetId, equals(originalSupersetId));
      expect(state.dias[0].ejercicios[2].supersetId, isNull);
      
      // Check duplicated day has new superset IDs
      final newEx1 = state.dias[1].ejercicios[0];
      final newEx2 = state.dias[1].ejercicios[1];
      final newEx3 = state.dias[1].ejercicios[2];
      
      expect(newEx1.supersetId, isNotNull);
      expect(newEx2.supersetId, isNotNull);
      expect(newEx1.supersetId, equals(newEx2.supersetId));
      expect(newEx1.supersetId, isNot(equals(originalSupersetId))); // Different from original
      expect(newEx3.supersetId, isNull);
    });

    test('generates unique instanceIds when duplicating', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      notifier.addExerciseToDay(0, LibraryExercise(
        id: 1,
        name: 'Exercise 1',
        muscleGroup: 'Test',
        equipment: 'None',
      ));

      final originalInstanceId = container.read(createRoutineProvider(null)).dias[0].ejercicios[0].instanceId;

      notifier.duplicateDay(0);

      final state = container.read(createRoutineProvider(null));
      final newInstanceId = state.dias[1].ejercicios[0].instanceId;
      
      expect(newInstanceId, isNot(equals(originalInstanceId)));
      expect(newInstanceId, isNotEmpty);
    });

    test('handles multiple supersets when duplicating day', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      // Add 6 exercises
      for (int i = 1; i <= 6; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i,
          name: 'Exercise $i',
          muscleGroup: 'Test',
          equipment: 'None',
        ));
      }
      
      // Create two separate supersets
      notifier.createSuperset(0, 0, 1);
      notifier.createSuperset(0, 3, 4);

      final originalState = container.read(createRoutineProvider(null));
      final superset1Id = originalState.dias[0].ejercicios[0].supersetId;
      final superset2Id = originalState.dias[0].ejercicios[3].supersetId;

      notifier.duplicateDay(0);

      final state = container.read(createRoutineProvider(null));
      
      // Check duplicated day
      final newSuperset1Id = state.dias[1].ejercicios[0].supersetId;
      final newSuperset2Id = state.dias[1].ejercicios[3].supersetId;
      
      // New supersets should exist and be different from originals
      expect(newSuperset1Id, isNotNull);
      expect(newSuperset2Id, isNotNull);
      expect(newSuperset1Id, isNot(equals(superset1Id)));
      expect(newSuperset2Id, isNot(equals(superset2Id)));
      
      // But each new superset should be consistent within itself
      expect(state.dias[1].ejercicios[0].supersetId, equals(newSuperset1Id));
      expect(state.dias[1].ejercicios[1].supersetId, equals(newSuperset1Id));
      expect(state.dias[1].ejercicios[3].supersetId, equals(newSuperset2Id));
      expect(state.dias[1].ejercicios[4].supersetId, equals(newSuperset2Id));
    });
  });

  group('CreateRoutineNotifier - removeExercise', () {
    test('removes exercise from day', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      notifier.addExerciseToDay(0, LibraryExercise(id: 1, name: 'Ex1', muscleGroup: 'Test', equipment: 'None'));
      notifier.addExerciseToDay(0, LibraryExercise(id: 2, name: 'Ex2', muscleGroup: 'Test', equipment: 'None'));

      notifier.removeExercise(0, 0);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias[0].ejercicios.length, 1);
      expect(state.dias[0].ejercicios[0].nombre, 'Ex2');
    });

    test('cleans up superset when removing leaves only one exercise', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      
      notifier.addExerciseToDay(0, LibraryExercise(id: 1, name: 'Ex1', muscleGroup: 'Test', equipment: 'None'));
      notifier.addExerciseToDay(0, LibraryExercise(id: 2, name: 'Ex2', muscleGroup: 'Test', equipment: 'None'));
      notifier.createSuperset(0, 0, 1);

      notifier.removeExercise(0, 0);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias[0].ejercicios.length, 1);
      expect(state.dias[0].ejercicios[0].supersetId, isNull);
    });
  });
}
