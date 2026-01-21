import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juan_training/providers/create_routine_provider.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/models/rutina.dart';
import 'package:juan_training/repositories/i_training_repository.dart';

// Mock repository for testing
class MockTrainingRepository implements ITrainingRepository {
  @override
  Future<void> saveRutina(Rutina rutina) async {
    // Mock implementation - just return success
  }

  @override
  Future<List<Rutina>> getRutinas() async {
    return [];
  }

  @override
  Future<void> deleteRutina(String id) async {
    // Mock implementation
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Helper function to create a fake LibraryExercise for testing
LibraryExercise createFakeExercise(int id, String name) {
  return LibraryExercise(
    id: id,
    name: name,
    muscleGroup: 'Test Muscle',
    equipment: 'Test Equipment',
    description: 'Test description for $name',
    muscles: ['Muscle 1', 'Muscle 2'],
    secondaryMuscles: ['Secondary 1'],
  );
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

  group('CreateRoutineNotifier - Basic Operations', () {
    test('should create empty routine with one day by default', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final state = container.read(createRoutineProvider(null));

      expect(state.nombre, isEmpty);
      expect(state.dias.length, 1);
      expect(state.dias[0].ejercicios, isEmpty);
    });

    test('should update routine name', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      notifier.updateName('My Routine');

      final state = container.read(createRoutineProvider(null));
      expect(state.nombre, 'My Routine');
    });

    test('should add a new day', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      notifier.addDay();

      final state = container.read(createRoutineProvider(null));
      expect(state.dias.length, 2);
      expect(state.dias[1].nombre, 'Día 2');
    });

    test('should remove a day', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      notifier.addDay();
      notifier.removeDay(0);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias.length, 1);
    });
  });

  group('CreateRoutineNotifier - Exercise Operations', () {
    test('should add exercise to day', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise = createFakeExercise(1, 'Bench Press');

      notifier.addExerciseToDay(0, exercise);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias[0].ejercicios.length, 1);
      expect(state.dias[0].ejercicios[0].nombre, 'Bench Press');
      expect(state.dias[0].ejercicios[0].id, '1');
    });

    test('should add exercise with non-blocking image path verification', () async {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise = createFakeExercise(1, 'Squat');
      exercise.localImagePath = '/nonexistent/path.jpg';

      notifier.addExerciseToDay(0, exercise);

      // Exercise should be added immediately
      final state = container.read(createRoutineProvider(null));
      expect(state.dias[0].ejercicios.length, 1);
      expect(state.dias[0].ejercicios[0].nombre, 'Squat');

      // Wait for async verification to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Path should still be there (async update may clear it if file doesn't exist)
      // But the exercise should be present
      final finalState = container.read(createRoutineProvider(null));
      expect(finalState.dias[0].ejercicios.length, 1);
    });

    test('should remove exercise from day', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise1 = createFakeExercise(1, 'Bench Press');
      final exercise2 = createFakeExercise(2, 'Squat');

      notifier.addExerciseToDay(0, exercise1);
      notifier.addExerciseToDay(0, exercise2);
      notifier.removeExercise(0, 0);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias[0].ejercicios.length, 1);
      expect(state.dias[0].ejercicios[0].nombre, 'Squat');
    });

    test('should update exercise', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise = createFakeExercise(1, 'Bench Press');

      notifier.addExerciseToDay(0, exercise);

      final state = container.read(createRoutineProvider(null));
      final updatedExercise = state.dias[0].ejercicios[0].copyWith(
        series: 5,
        repsRange: '10-15',
      );

      notifier.updateExercise(0, 0, updatedExercise);

      final finalState = container.read(createRoutineProvider(null));
      expect(finalState.dias[0].ejercicios[0].series, 5);
      expect(finalState.dias[0].ejercicios[0].repsRange, '10-15');
    });
  });

  group('CreateRoutineNotifier - Superset Operations', () {
    test('should create superset between two exercises', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise1 = createFakeExercise(1, 'Bench Press');
      final exercise2 = createFakeExercise(2, 'Flies');

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

    test('should add exercise to existing superset', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise1 = createFakeExercise(1, 'Exercise 1');
      final exercise2 = createFakeExercise(2, 'Exercise 2');
      final exercise3 = createFakeExercise(3, 'Exercise 3');

      notifier.addExerciseToDay(0, exercise1);
      notifier.addExerciseToDay(0, exercise2);
      notifier.addExerciseToDay(0, exercise3);

      // Create superset between 1 and 2
      notifier.createSuperset(0, 0, 1);
      final stateAfterFirst = container.read(createRoutineProvider(null));
      final supersetId = stateAfterFirst.dias[0].ejercicios[0].supersetId;

      // Add exercise 3 to the superset
      notifier.createSuperset(0, 0, 2);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias[0].ejercicios[0].supersetId, equals(supersetId));
      expect(state.dias[0].ejercicios[1].supersetId, equals(supersetId));
      expect(state.dias[0].ejercicios[2].supersetId, equals(supersetId));
    });

    test('should remove exercise from superset', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise1 = createFakeExercise(1, 'Exercise 1');
      final exercise2 = createFakeExercise(2, 'Exercise 2');
      final exercise3 = createFakeExercise(3, 'Exercise 3');

      notifier.addExerciseToDay(0, exercise1);
      notifier.addExerciseToDay(0, exercise2);
      notifier.addExerciseToDay(0, exercise3);

      // Create superset between all three
      notifier.createSuperset(0, 0, 1);
      notifier.createSuperset(0, 0, 2);

      // Remove exercise 1 from superset
      notifier.removeFromSuperset(0, 0);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias[0].ejercicios[0].supersetId, isNull);
      expect(state.dias[0].ejercicios[1].supersetId, isNotNull);
      expect(state.dias[0].ejercicios[2].supersetId, isNotNull);
      expect(state.dias[0].ejercicios[1].supersetId,
          equals(state.dias[0].ejercicios[2].supersetId));
    });

    test('should clean up orphaned superset when only one exercise remains', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise1 = createFakeExercise(1, 'Exercise 1');
      final exercise2 = createFakeExercise(2, 'Exercise 2');

      notifier.addExerciseToDay(0, exercise1);
      notifier.addExerciseToDay(0, exercise2);

      // Create superset
      notifier.createSuperset(0, 0, 1);

      // Remove one from superset
      notifier.removeFromSuperset(0, 0);

      final state = container.read(createRoutineProvider(null));
      // Both should have null supersetId now
      expect(state.dias[0].ejercicios[0].supersetId, isNull);
      expect(state.dias[0].ejercicios[1].supersetId, isNull);
    });

    test('should clean up superset when deleting exercise leaves only one', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise1 = createFakeExercise(1, 'Exercise 1');
      final exercise2 = createFakeExercise(2, 'Exercise 2');

      notifier.addExerciseToDay(0, exercise1);
      notifier.addExerciseToDay(0, exercise2);

      // Create superset
      notifier.createSuperset(0, 0, 1);

      // Delete one exercise
      notifier.removeExercise(0, 0);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias[0].ejercicios.length, 1);
      expect(state.dias[0].ejercicios[0].supersetId, isNull);
    });
  });

  group('CreateRoutineNotifier - Reordering', () {
    test('should reorder visual exercises (single exercises)', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise1 = createFakeExercise(1, 'Exercise 1');
      final exercise2 = createFakeExercise(2, 'Exercise 2');
      final exercise3 = createFakeExercise(3, 'Exercise 3');

      notifier.addExerciseToDay(0, exercise1);
      notifier.addExerciseToDay(0, exercise2);
      notifier.addExerciseToDay(0, exercise3);

      // Move first exercise to last position
      notifier.reorderVisualExercises(0, 0, 2);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias[0].ejercicios[0].nombre, 'Exercise 2');
      expect(state.dias[0].ejercicios[1].nombre, 'Exercise 3');
      expect(state.dias[0].ejercicios[2].nombre, 'Exercise 1');
    });

    test('should reorder visual groups with supersets as units', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise1 = createFakeExercise(1, 'Exercise 1');
      final exercise2 = createFakeExercise(2, 'Exercise 2');
      final exercise3 = createFakeExercise(3, 'Exercise 3');
      final exercise4 = createFakeExercise(4, 'Exercise 4');

      notifier.addExerciseToDay(0, exercise1);
      notifier.addExerciseToDay(0, exercise2);
      notifier.addExerciseToDay(0, exercise3);
      notifier.addExerciseToDay(0, exercise4);

      // Create superset between 1 and 2
      notifier.createSuperset(0, 0, 1);

      // Now we have: [Superset(1,2), 3, 4]
      // Move superset to the end
      notifier.reorderVisualExercises(0, 0, 2);

      final state = container.read(createRoutineProvider(null));
      // Should be: [3, 4, Superset(1,2)]
      expect(state.dias[0].ejercicios[0].nombre, 'Exercise 3');
      expect(state.dias[0].ejercicios[1].nombre, 'Exercise 4');
      expect(state.dias[0].ejercicios[2].nombre, 'Exercise 1');
      expect(state.dias[0].ejercicios[3].nombre, 'Exercise 2');

      // Verify superset is still intact
      expect(state.dias[0].ejercicios[2].supersetId,
          equals(state.dias[0].ejercicios[3].supersetId));
    });

    test('should keep superset contiguous when reordering', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise1 = createFakeExercise(1, 'Exercise 1');
      final exercise2 = createFakeExercise(2, 'Exercise 2');
      final exercise3 = createFakeExercise(3, 'Exercise 3');

      notifier.addExerciseToDay(0, exercise1);
      notifier.addExerciseToDay(0, exercise2);
      notifier.addExerciseToDay(0, exercise3);

      // Create superset between 1 and 3 (non-contiguous initially)
      notifier.createSuperset(0, 0, 2);

      final state = container.read(createRoutineProvider(null));
      // After createSuperset, they should be made contiguous
      final supersetId = state.dias[0].ejercicios[0].supersetId;

      // Find all exercises with this supersetId
      final supersetIndices = <int>[];
      for (int i = 0; i < state.dias[0].ejercicios.length; i++) {
        if (state.dias[0].ejercicios[i].supersetId == supersetId) {
          supersetIndices.add(i);
        }
      }

      // They should be contiguous
      for (int i = 1; i < supersetIndices.length; i++) {
        expect(supersetIndices[i], equals(supersetIndices[i - 1] + 1));
      }
    });
  });

  group('CreateRoutineNotifier - Day Duplication', () {
    test('should duplicate day preserving exercises', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise1 = createFakeExercise(1, 'Exercise 1');
      final exercise2 = createFakeExercise(2, 'Exercise 2');

      notifier.updateDayName(0, 'Leg Day');
      notifier.addExerciseToDay(0, exercise1);
      notifier.addExerciseToDay(0, exercise2);

      notifier.duplicateDay(0);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias.length, 2);
      expect(state.dias[1].nombre, 'Leg Day (Copia)');
      expect(state.dias[1].ejercicios.length, 2);
      expect(state.dias[1].ejercicios[0].nombre, 'Exercise 1');
      expect(state.dias[1].ejercicios[1].nombre, 'Exercise 2');
    });

    test('should duplicate day preserving superset mapping with new IDs', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise1 = createFakeExercise(1, 'Exercise 1');
      final exercise2 = createFakeExercise(2, 'Exercise 2');
      final exercise3 = createFakeExercise(3, 'Exercise 3');

      notifier.addExerciseToDay(0, exercise1);
      notifier.addExerciseToDay(0, exercise2);
      notifier.addExerciseToDay(0, exercise3);

      // Create superset between 1 and 2
      notifier.createSuperset(0, 0, 1);

      final stateBeforeDup = container.read(createRoutineProvider(null));
      final originalSupersetId = stateBeforeDup.dias[0].ejercicios[0].supersetId;

      notifier.duplicateDay(0);

      final state = container.read(createRoutineProvider(null));
      expect(state.dias.length, 2);

      // Check that superset in original day is unchanged
      expect(state.dias[0].ejercicios[0].supersetId, equals(originalSupersetId));
      expect(state.dias[0].ejercicios[1].supersetId, equals(originalSupersetId));

      // Check that duplicated day has a different superset ID
      final duplicatedSupersetId = state.dias[1].ejercicios[0].supersetId;
      expect(duplicatedSupersetId, isNotNull);
      expect(duplicatedSupersetId, isNot(equals(originalSupersetId)));

      // Check that superset relationship is preserved in duplicated day
      expect(state.dias[1].ejercicios[1].supersetId, equals(duplicatedSupersetId));
      expect(state.dias[1].ejercicios[2].supersetId, isNull);

      // Check that instance IDs are different
      expect(state.dias[0].ejercicios[0].instanceId,
          isNot(equals(state.dias[1].ejercicios[0].instanceId)));
    });
  });

  group('CreateRoutineNotifier - Validation', () {
    test('should return error when saving routine with empty name', () async {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise = createFakeExercise(1, 'Exercise 1');
      notifier.addExerciseToDay(0, exercise);

      final error = await notifier.saveRoutine();
      expect(error, isNotNull);
      expect(error, contains('nombre'));
    });

    test('should return error when saving routine with no exercises', () async {
      final notifier = container.read(createRoutineProvider(null).notifier);
      notifier.updateName('Test Routine');

      final error = await notifier.saveRoutine();
      expect(error, isNotNull);
      expect(error, contains('ejercicios'));
    });

    test('should save successfully with valid routine', () async {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final exercise = createFakeExercise(1, 'Exercise 1');

      notifier.updateName('Test Routine');
      notifier.addExerciseToDay(0, exercise);

      final error = await notifier.saveRoutine();
      expect(error, isNull);
    });
  });
}
