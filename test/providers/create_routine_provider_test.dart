import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juan_training/providers/create_routine_provider.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/models/ejercicio_en_rutina.dart';
import 'package:juan_training/repositories/i_training_repository.dart';
import 'package:juan_training/models/rutina.dart';

// Fake LibraryExercise for testing
LibraryExercise createFakeLibraryExercise({
  required int id,
  required String name,
  String? localImagePath,
}) {
  return LibraryExercise(
    id: id,
    name: name,
    muscleGroup: 'Test Group',
    equipment: 'Test Equipment',
    description: 'Test description',
    muscles: ['Test Muscle'],
    secondaryMuscles: ['Secondary Muscle'],
    localImagePath: localImagePath,
  );
}

// Mock repository that does nothing
class MockTrainingRepository implements ITrainingRepository {
  @override
  Future<void> saveRutina(Rutina rutina) async {
    // Mock implementation
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ProviderContainer container;
  late MockTrainingRepository mockRepository;

  setUp(() {
    mockRepository = MockTrainingRepository();
    container = ProviderContainer(
      overrides: [
        // Override the training repository provider to use our mock
        trainingRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CreateRoutineNotifier', () {
    test('addExerciseToDay adds exercise quickly without blocking', () {
      final notifier = container.read(createRoutineProvider(null).notifier);
      final libExercise = createFakeLibraryExercise(
        id: 1,
        name: 'Push Up',
        localImagePath: '/fake/path.jpg',
      );

      // Add exercise should be quick (no blocking I/O)
      notifier.addExerciseToDay(0, libExercise);

      // Verify exercise was added immediately
      final state = container.read(createRoutineProvider(null));
      expect(state.dias[0].ejercicios.length, 1);
      expect(state.dias[0].ejercicios[0].nombre, 'Push Up');
      // Image path is set immediately (validation happens async)
      expect(state.dias[0].ejercicios[0].localImagePath, '/fake/path.jpg');
    });

    test('createSuperset assigns same supersetId to two exercises', () {
      final notifier = container.read(createRoutineProvider(null).notifier);

      // Add two exercises
      final ex1 = createFakeLibraryExercise(id: 1, name: 'Exercise 1');
      final ex2 = createFakeLibraryExercise(id: 2, name: 'Exercise 2');
      notifier.addExerciseToDay(0, ex1);
      notifier.addExerciseToDay(0, ex2);

      // Create superset
      notifier.createSuperset(0, 0, 1);

      // Verify both exercises have the same supersetId
      final state = container.read(createRoutineProvider(null));
      final exercises = state.dias[0].ejercicios;
      expect(exercises[0].supersetId, isNotNull);
      expect(exercises[1].supersetId, isNotNull);
      expect(exercises[0].supersetId, equals(exercises[1].supersetId));
    });

    test('createSuperset ensures exercises are contiguous', () {
      final notifier = container.read(createRoutineProvider(null).notifier);

      // Add three exercises
      final ex1 = createFakeLibraryExercise(id: 1, name: 'Exercise 1');
      final ex2 = createFakeLibraryExercise(id: 2, name: 'Exercise 2');
      final ex3 = createFakeLibraryExercise(id: 3, name: 'Exercise 3');
      notifier.addExerciseToDay(0, ex1);
      notifier.addExerciseToDay(0, ex2);
      notifier.addExerciseToDay(0, ex3);

      // Create superset between exercises at index 0 and 2 (non-adjacent)
      notifier.createSuperset(0, 0, 2);

      // Verify exercises with same supersetId are now contiguous
      final state = container.read(createRoutineProvider(null));
      final exercises = state.dias[0].ejercicios;
      
      // Find exercises with supersetId
      final supersetExercises = exercises.where((e) => e.supersetId != null).toList();
      expect(supersetExercises.length, 2);
      
      // Find their indices in the list
      final indices = supersetExercises.map((e) => exercises.indexOf(e)).toList();
      indices.sort();
      
      // Verify they are adjacent
      expect(indices[1] - indices[0], equals(1), reason: 'Superset exercises should be contiguous');
    });

    test('removeFromSuperset removes supersetId and cleans up orphans', () {
      final notifier = container.read(createRoutineProvider(null).notifier);

      // Add two exercises and create superset
      final ex1 = createFakeLibraryExercise(id: 1, name: 'Exercise 1');
      final ex2 = createFakeLibraryExercise(id: 2, name: 'Exercise 2');
      notifier.addExerciseToDay(0, ex1);
      notifier.addExerciseToDay(0, ex2);
      notifier.createSuperset(0, 0, 1);

      // Remove one exercise from superset
      notifier.removeFromSuperset(0, 0);

      // Verify both exercises no longer have supersetId (cleanup)
      final state = container.read(createRoutineProvider(null));
      final exercises = state.dias[0].ejercicios;
      expect(exercises[0].supersetId, isNull);
      expect(exercises[1].supersetId, isNull, 
        reason: 'Single remaining exercise should have supersetId removed');
    });

    test('removeFromSuperset with 3+ exercises keeps remaining superset', () {
      final notifier = container.read(createRoutineProvider(null).notifier);

      // Add three exercises
      final ex1 = createFakeLibraryExercise(id: 1, name: 'Exercise 1');
      final ex2 = createFakeLibraryExercise(id: 2, name: 'Exercise 2');
      final ex3 = createFakeLibraryExercise(id: 3, name: 'Exercise 3');
      notifier.addExerciseToDay(0, ex1);
      notifier.addExerciseToDay(0, ex2);
      notifier.addExerciseToDay(0, ex3);

      // Create superset for all three
      notifier.createSuperset(0, 0, 1);
      notifier.createSuperset(0, 1, 2);

      // Remove one exercise from superset
      notifier.removeFromSuperset(0, 0);

      // Verify remaining two still have supersetId
      final state = container.read(createRoutineProvider(null));
      final exercises = state.dias[0].ejercicios;
      expect(exercises[0].supersetId, isNull);
      expect(exercises[1].supersetId, isNotNull);
      expect(exercises[2].supersetId, isNotNull);
      expect(exercises[1].supersetId, equals(exercises[2].supersetId));
    });

    test('reorderVisualExercises moves entire superset as a unit', () {
      final notifier = container.read(createRoutineProvider(null).notifier);

      // Add four exercises: two in a superset, two individual
      final ex1 = createFakeLibraryExercise(id: 1, name: 'Exercise 1');
      final ex2 = createFakeLibraryExercise(id: 2, name: 'Exercise 2');
      final ex3 = createFakeLibraryExercise(id: 3, name: 'Exercise 3');
      final ex4 = createFakeLibraryExercise(id: 4, name: 'Exercise 4');
      
      notifier.addExerciseToDay(0, ex1);
      notifier.addExerciseToDay(0, ex2);
      notifier.addExerciseToDay(0, ex3);
      notifier.addExerciseToDay(0, ex4);

      // Create superset for exercises 1 and 2
      notifier.createSuperset(0, 0, 1);

      var state = container.read(createRoutineProvider(null));
      var exercises = state.dias[0].ejercicios;
      
      // Find the superset group (should be exercises 1 and 2)
      final supersetId = exercises[0].supersetId!;
      
      // Visual groups should be: [superset(1,2)], [3], [4]
      // Move the superset from position 0 to position 2 (after exercises 3 and 4)
      notifier.reorderVisualExercises(0, 0, 2);

      state = container.read(createRoutineProvider(null));
      exercises = state.dias[0].ejercicios;

      // Verify order: should now be [3], [4], [superset(1,2)]
      expect(exercises.length, 4);
      expect(exercises[0].nombre, 'Exercise 3');
      expect(exercises[1].nombre, 'Exercise 4');
      
      // Last two should be the superset (in original order)
      expect(exercises[2].supersetId, equals(supersetId));
      expect(exercises[3].supersetId, equals(supersetId));
      expect(exercises[2].nombre, 'Exercise 1');
      expect(exercises[3].nombre, 'Exercise 2');
    });

    test('duplicateDay preserves superset mapping with new UUIDs', () {
      final notifier = container.read(createRoutineProvider(null).notifier);

      // Add exercises and create superset
      final ex1 = createFakeLibraryExercise(id: 1, name: 'Exercise 1');
      final ex2 = createFakeLibraryExercise(id: 2, name: 'Exercise 2');
      final ex3 = createFakeLibraryExercise(id: 3, name: 'Exercise 3');
      
      notifier.addExerciseToDay(0, ex1);
      notifier.addExerciseToDay(0, ex2);
      notifier.addExerciseToDay(0, ex3);
      notifier.createSuperset(0, 0, 1);

      var state = container.read(createRoutineProvider(null));
      final originalSupersetId = state.dias[0].ejercicios[0].supersetId!;
      final originalInstanceIds = state.dias[0].ejercicios.map((e) => e.instanceId).toList();

      // Duplicate day
      notifier.duplicateDay(0);

      state = container.read(createRoutineProvider(null));
      expect(state.dias.length, 2);

      final originalDay = state.dias[0];
      final duplicatedDay = state.dias[1];

      // Verify duplicated day has same structure
      expect(duplicatedDay.ejercicios.length, 3);
      expect(duplicatedDay.ejercicios[0].nombre, 'Exercise 1');
      expect(duplicatedDay.ejercicios[1].nombre, 'Exercise 2');
      expect(duplicatedDay.ejercicios[2].nombre, 'Exercise 3');

      // Verify superset mapping is preserved
      expect(duplicatedDay.ejercicios[0].supersetId, isNotNull);
      expect(duplicatedDay.ejercicios[1].supersetId, isNotNull);
      expect(duplicatedDay.ejercicios[2].supersetId, isNull);
      expect(
        duplicatedDay.ejercicios[0].supersetId,
        equals(duplicatedDay.ejercicios[1].supersetId),
        reason: 'Duplicated superset should have matching IDs',
      );

      // Verify new UUIDs are different from original
      expect(
        duplicatedDay.ejercicios[0].supersetId,
        isNot(equals(originalSupersetId)),
        reason: 'Duplicated superset should have new UUID',
      );
      expect(
        duplicatedDay.ejercicios[0].instanceId,
        isNot(equals(originalInstanceIds[0])),
        reason: 'Duplicated exercise should have new instanceId',
      );
      expect(
        duplicatedDay.ejercicios[1].instanceId,
        isNot(equals(originalInstanceIds[1])),
        reason: 'Duplicated exercise should have new instanceId',
      );
    });

    test('_computeVisualGroups correctly groups contiguous superset exercises', () {
      final notifier = container.read(createRoutineProvider(null).notifier);

      // Add multiple exercises with different superset configurations
      final ex1 = createFakeLibraryExercise(id: 1, name: 'Solo 1');
      final ex2 = createFakeLibraryExercise(id: 2, name: 'Superset A-1');
      final ex3 = createFakeLibraryExercise(id: 3, name: 'Superset A-2');
      final ex4 = createFakeLibraryExercise(id: 4, name: 'Solo 2');
      final ex5 = createFakeLibraryExercise(id: 5, name: 'Superset B-1');
      final ex6 = createFakeLibraryExercise(id: 6, name: 'Superset B-2');

      notifier.addExerciseToDay(0, ex1); // Solo
      notifier.addExerciseToDay(0, ex2);
      notifier.addExerciseToDay(0, ex3);
      notifier.createSuperset(0, 1, 2); // Create superset A
      notifier.addExerciseToDay(0, ex4); // Solo
      notifier.addExerciseToDay(0, ex5);
      notifier.addExerciseToDay(0, ex6);
      notifier.createSuperset(0, 4, 5); // Create superset B

      // Should have visual groups: [Solo 1], [Superset A], [Solo 2], [Superset B]
      // That's 4 visual items total
      final state = container.read(createRoutineProvider(null));
      
      // We can't directly test _computeVisualGroups as it's private,
      // but we can verify the behavior through reorderVisualExercises
      // Moving visual item 0 (Solo 1) to position 3 should put it at the end
      notifier.reorderVisualExercises(0, 0, 3);
      
      final newState = container.read(createRoutineProvider(null));
      final exercises = newState.dias[0].ejercicios;
      
      // After reorder, Solo 1 should be at the end
      expect(exercises[exercises.length - 1].nombre, 'Solo 1');
      expect(exercises[exercises.length - 1].supersetId, isNull);
    });

    test('removeExercise cleans up superset when only one remains', () {
      final notifier = container.read(createRoutineProvider(null).notifier);

      // Add two exercises and create superset
      final ex1 = createFakeLibraryExercise(id: 1, name: 'Exercise 1');
      final ex2 = createFakeLibraryExercise(id: 2, name: 'Exercise 2');
      notifier.addExerciseToDay(0, ex1);
      notifier.addExerciseToDay(0, ex2);
      notifier.createSuperset(0, 0, 1);

      // Remove one exercise entirely
      notifier.removeExercise(0, 0);

      // Verify remaining exercise has no supersetId
      final state = container.read(createRoutineProvider(null));
      expect(state.dias[0].ejercicios.length, 1);
      expect(state.dias[0].ejercicios[0].supersetId, isNull);
      expect(state.dias[0].ejercicios[0].nombre, 'Exercise 2');
    });
  });
}
