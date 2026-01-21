import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/models/dia.dart';
import 'package:juan_training/models/ejercicio_en_rutina.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/models/rutina.dart';
import 'package:juan_training/providers/create_routine_provider.dart';
import 'package:juan_training/repositories/i_training_repository.dart';
import 'package:uuid/uuid.dart';

/// Mock implementation of ITrainingRepository for testing
class MockTrainingRepository implements ITrainingRepository {
  final List<Rutina> savedRutinas = [];

  @override
  Future<void> saveRutina(Rutina rutina) async {
    savedRutinas.add(rutina);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockTrainingRepository mockRepository;

  setUp(() {
    mockRepository = MockTrainingRepository();
  });

  group('CreateRoutineNotifier - addExerciseToDay', () {
    test('should add exercise to specified day', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      final libExercise = LibraryExercise(
        id: 1,
        name: 'Push Up',
        muscleGroup: 'Chest',
        equipment: 'Bodyweight',
        muscles: ['Pectoralis Major'],
        secondaryMuscles: ['Triceps'],
      );

      notifier.addExerciseToDay(0, libExercise);

      expect(notifier.state.dias[0].ejercicios.length, 1);
      expect(notifier.state.dias[0].ejercicios[0].nombre, 'Push Up');
      expect(notifier.state.dias[0].ejercicios[0].musculosPrincipales, ['Pectoralis Major']);
    });

    test('should add exercise with local image path initially', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      final libExercise = LibraryExercise(
        id: 1,
        name: 'Push Up',
        muscleGroup: 'Chest',
        equipment: 'Bodyweight',
        muscles: ['Pectoralis Major'],
        secondaryMuscles: [],
        localImagePath: '/path/to/image.jpg',
      );

      notifier.addExerciseToDay(0, libExercise);

      // Image path is initially set (async validation happens later)
      expect(notifier.state.dias[0].ejercicios[0].localImagePath, '/path/to/image.jpg');
    });

    test('should handle adding multiple exercises to same day', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      final exercise1 = LibraryExercise(
        id: 1,
        name: 'Push Up',
        muscleGroup: 'Chest',
        equipment: 'Bodyweight',
        muscles: [],
        secondaryMuscles: [],
      );
      
      final exercise2 = LibraryExercise(
        id: 2,
        name: 'Pull Up',
        muscleGroup: 'Back',
        equipment: 'Bar',
        muscles: [],
        secondaryMuscles: [],
      );

      notifier.addExerciseToDay(0, exercise1);
      notifier.addExerciseToDay(0, exercise2);

      expect(notifier.state.dias[0].ejercicios.length, 2);
      expect(notifier.state.dias[0].ejercicios[0].nombre, 'Push Up');
      expect(notifier.state.dias[0].ejercicios[1].nombre, 'Pull Up');
    });
  });

  group('CreateRoutineNotifier - createSuperset', () {
    test('should create superset with new ID for two non-superset exercises', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      // Add two exercises
      final ex1 = LibraryExercise(id: 1, name: 'Ex1', muscleGroup: 'Chest', equipment: 'Barbell', muscles: [], secondaryMuscles: []);
      final ex2 = LibraryExercise(id: 2, name: 'Ex2', muscleGroup: 'Back', equipment: 'Barbell', muscles: [], secondaryMuscles: []);
      
      notifier.addExerciseToDay(0, ex1);
      notifier.addExerciseToDay(0, ex2);

      // Verify no superset IDs initially
      expect(notifier.state.dias[0].ejercicios[0].supersetId, isNull);
      expect(notifier.state.dias[0].ejercicios[1].supersetId, isNull);

      // Create superset
      notifier.createSuperset(0, 0, 1);

      // Both should have the same superset ID
      final supersetId1 = notifier.state.dias[0].ejercicios[0].supersetId;
      final supersetId2 = notifier.state.dias[0].ejercicios[1].supersetId;
      
      expect(supersetId1, isNotNull);
      expect(supersetId2, isNotNull);
      expect(supersetId1, equals(supersetId2));
    });

    test('should add exercise to existing superset when one already has ID', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      final ex1 = LibraryExercise(id: 1, name: 'Ex1', muscleGroup: 'Chest', equipment: 'Barbell', muscles: [], secondaryMuscles: []);
      final ex2 = LibraryExercise(id: 2, name: 'Ex2', muscleGroup: 'Back', equipment: 'Barbell', muscles: [], secondaryMuscles: []);
      final ex3 = LibraryExercise(id: 3, name: 'Ex3', muscleGroup: 'Legs', equipment: 'Barbell', muscles: [], secondaryMuscles: []);
      
      notifier.addExerciseToDay(0, ex1);
      notifier.addExerciseToDay(0, ex2);
      notifier.addExerciseToDay(0, ex3);

      // Create first superset
      notifier.createSuperset(0, 0, 1);
      final firstSupersetId = notifier.state.dias[0].ejercicios[0].supersetId!;

      // Add third exercise to the superset
      notifier.createSuperset(0, 0, 2);

      // All three should have the same ID
      expect(notifier.state.dias[0].ejercicios[0].supersetId, equals(firstSupersetId));
      expect(notifier.state.dias[0].ejercicios[1].supersetId, equals(firstSupersetId));
      expect(notifier.state.dias[0].ejercicios[2].supersetId, equals(firstSupersetId));
    });

    test('should merge two different supersets when linking exercises from each', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      // Add 4 exercises
      for (int i = 1; i <= 4; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i, 
          name: 'Ex$i', 
          muscleGroup: 'Chest', 
          equipment: 'Barbell',
          muscles: [],
          secondaryMuscles: [],
        ));
      }

      // Create two separate supersets
      notifier.createSuperset(0, 0, 1); // Superset A: exercises 0,1
      notifier.createSuperset(0, 2, 3); // Superset B: exercises 2,3

      final supersetA = notifier.state.dias[0].ejercicios[0].supersetId!;
      final supersetB = notifier.state.dias[0].ejercicios[2].supersetId!;

      expect(supersetA, isNot(equals(supersetB)));

      // Merge the supersets by linking exercise from A with exercise from B
      notifier.createSuperset(0, 0, 2);

      // All four should now have the same ID (merged into A)
      final mergedId = notifier.state.dias[0].ejercicios[0].supersetId!;
      expect(notifier.state.dias[0].ejercicios[0].supersetId, equals(mergedId));
      expect(notifier.state.dias[0].ejercicios[1].supersetId, equals(mergedId));
      expect(notifier.state.dias[0].ejercicios[2].supersetId, equals(mergedId));
      expect(notifier.state.dias[0].ejercicios[3].supersetId, equals(mergedId));
    });
  });

  group('CreateRoutineNotifier - removeFromSuperset', () {
    test('should remove exercise from superset', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      // Add 3 exercises and create superset
      for (int i = 1; i <= 3; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i, 
          name: 'Ex$i', 
          muscleGroup: 'Chest', 
          equipment: 'Barbell',
          muscles: [],
          secondaryMuscles: [],
        ));
      }
      
      notifier.createSuperset(0, 0, 1);
      notifier.createSuperset(0, 1, 2);

      final supersetId = notifier.state.dias[0].ejercicios[0].supersetId!;

      // Remove middle exercise from superset
      notifier.removeFromSuperset(0, 1);

      // First and third should still have superset ID
      expect(notifier.state.dias[0].ejercicios[0].supersetId, equals(supersetId));
      expect(notifier.state.dias[0].ejercicios[2].supersetId, equals(supersetId));
      // Middle should not
      expect(notifier.state.dias[0].ejercicios[1].supersetId, isNull);
    });

    test('should clean up superset when only one exercise remains', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      // Add 2 exercises and create superset
      notifier.addExerciseToDay(0, LibraryExercise(
        id: 1, 
        name: 'Ex1', 
        muscleGroup: 'Chest', 
        equipment: 'Barbell',
        muscles: [],
        secondaryMuscles: [],
      ));
      notifier.addExerciseToDay(0, LibraryExercise(
        id: 2, 
        name: 'Ex2', 
        muscleGroup: 'Back', 
        equipment: 'Barbell',
        muscles: [],
        secondaryMuscles: [],
      ));
      
      notifier.createSuperset(0, 0, 1);

      // Remove one from superset
      notifier.removeFromSuperset(0, 0);

      // Both should now have null superset ID (no single-exercise supersets)
      expect(notifier.state.dias[0].ejercicios[0].supersetId, isNull);
      expect(notifier.state.dias[0].ejercicios[1].supersetId, isNull);
    });
  });

  group('CreateRoutineNotifier - reorderVisualExercises', () {
    test('should reorder single exercises', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      // Add 3 exercises
      for (int i = 1; i <= 3; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i, 
          name: 'Ex$i', 
          muscleGroup: 'Chest', 
          equipment: 'Barbell',
          muscles: [],
          secondaryMuscles: [],
        ));
      }

      // Reorder: move first exercise to last position
      notifier.reorderVisualExercises(0, 0, 2);

      expect(notifier.state.dias[0].ejercicios[0].nombre, 'Ex2');
      expect(notifier.state.dias[0].ejercicios[1].nombre, 'Ex3');
      expect(notifier.state.dias[0].ejercicios[2].nombre, 'Ex1');
    });

    test('should move superset group as a unit', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      // Add 4 exercises: Ex1, Ex2 (superset), Ex3, Ex4
      for (int i = 1; i <= 4; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i, 
          name: 'Ex$i', 
          muscleGroup: 'Chest', 
          equipment: 'Barbell',
          muscles: [],
          secondaryMuscles: [],
        ));
      }
      
      // Create superset with Ex2 and Ex3
      notifier.createSuperset(0, 1, 2);

      // Before reorder: Ex1, Ex2, Ex3 (superset), Ex4
      // Visual groups: [Ex1], [Ex2, Ex3], [Ex4]
      
      // Move superset group to end: oldVisualIndex=1, newVisualIndex=2
      notifier.reorderVisualExercises(0, 1, 2);

      // After: Ex1, Ex4, Ex2, Ex3
      expect(notifier.state.dias[0].ejercicios[0].nombre, 'Ex1');
      expect(notifier.state.dias[0].ejercicios[1].nombre, 'Ex4');
      expect(notifier.state.dias[0].ejercicios[2].nombre, 'Ex2');
      expect(notifier.state.dias[0].ejercicios[3].nombre, 'Ex3');

      // Superset should still be intact
      final supersetId = notifier.state.dias[0].ejercicios[2].supersetId;
      expect(notifier.state.dias[0].ejercicios[3].supersetId, equals(supersetId));
    });

    test('should preserve superset contiguity when reordering around superset', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      // Add 5 exercises
      for (int i = 1; i <= 5; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i, 
          name: 'Ex$i', 
          muscleGroup: 'Chest', 
          equipment: 'Barbell',
          muscles: [],
          secondaryMuscles: [],
        ));
      }
      
      // Create superset with Ex2, Ex3, Ex4
      notifier.createSuperset(0, 1, 2);
      notifier.createSuperset(0, 2, 3);

      // Before: Ex1, Ex2, Ex3, Ex4 (superset), Ex5
      // Visual groups: [Ex1], [Ex2, Ex3, Ex4], [Ex5]
      
      // Move first exercise to end
      notifier.reorderVisualExercises(0, 0, 2);

      // After: Ex2, Ex3, Ex4, Ex5, Ex1
      expect(notifier.state.dias[0].ejercicios[0].nombre, 'Ex2');
      expect(notifier.state.dias[0].ejercicios[1].nombre, 'Ex3');
      expect(notifier.state.dias[0].ejercicios[2].nombre, 'Ex4');
      expect(notifier.state.dias[0].ejercicios[3].nombre, 'Ex5');
      expect(notifier.state.dias[0].ejercicios[4].nombre, 'Ex1');

      // Superset should remain contiguous
      final supersetId = notifier.state.dias[0].ejercicios[0].supersetId;
      expect(notifier.state.dias[0].ejercicios[1].supersetId, equals(supersetId));
      expect(notifier.state.dias[0].ejercicios[2].supersetId, equals(supersetId));
    });
  });

  group('CreateRoutineNotifier - duplicateDay', () {
    test('should duplicate day with all exercises', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      // Add exercises to first day
      notifier.addExerciseToDay(0, LibraryExercise(
        id: 1, 
        name: 'Ex1', 
        muscleGroup: 'Chest', 
        equipment: 'Barbell',
        muscles: [],
        secondaryMuscles: [],
      ));
      notifier.addExerciseToDay(0, LibraryExercise(
        id: 2, 
        name: 'Ex2', 
        muscleGroup: 'Back', 
        equipment: 'Barbell',
        muscles: [],
        secondaryMuscles: [],
      ));

      notifier.duplicateDay(0);

      expect(notifier.state.dias.length, 2);
      expect(notifier.state.dias[1].nombre, 'Día 1 (Copia)');
      expect(notifier.state.dias[1].ejercicios.length, 2);
      expect(notifier.state.dias[1].ejercicios[0].nombre, 'Ex1');
      expect(notifier.state.dias[1].ejercicios[1].nombre, 'Ex2');
    });

    test('should preserve superset mapping when duplicating day', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      // Add exercises and create superset
      for (int i = 1; i <= 3; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i, 
          name: 'Ex$i', 
          muscleGroup: 'Chest', 
          equipment: 'Barbell',
          muscles: [],
          secondaryMuscles: [],
        ));
      }
      
      // Create superset with first two exercises
      notifier.createSuperset(0, 0, 1);
      
      final originalSupersetId = notifier.state.dias[0].ejercicios[0].supersetId!;

      // Duplicate day
      notifier.duplicateDay(0);

      // Verify duplicated day has superset with different ID but same structure
      final duplicatedEx1SupersetId = notifier.state.dias[1].ejercicios[0].supersetId;
      final duplicatedEx2SupersetId = notifier.state.dias[1].ejercicios[1].supersetId;
      final duplicatedEx3SupersetId = notifier.state.dias[1].ejercicios[2].supersetId;

      // First two should have same new superset ID
      expect(duplicatedEx1SupersetId, isNotNull);
      expect(duplicatedEx2SupersetId, isNotNull);
      expect(duplicatedEx1SupersetId, equals(duplicatedEx2SupersetId));
      
      // Third should not have superset ID
      expect(duplicatedEx3SupersetId, isNull);
      
      // New superset ID should be different from original
      expect(duplicatedEx1SupersetId, isNot(equals(originalSupersetId)));
    });

    test('should create new instance IDs when duplicating', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      notifier.addExerciseToDay(0, LibraryExercise(
        id: 1, 
        name: 'Ex1', 
        muscleGroup: 'Chest', 
        equipment: 'Barbell',
        muscles: [],
        secondaryMuscles: [],
      ));

      final originalInstanceId = notifier.state.dias[0].ejercicios[0].instanceId;

      notifier.duplicateDay(0);

      final duplicatedInstanceId = notifier.state.dias[1].ejercicios[0].instanceId;

      expect(duplicatedInstanceId, isNot(equals(originalInstanceId)));
    });
  });

  group('CreateRoutineNotifier - removeExercise', () {
    test('should remove exercise and clean up orphaned superset', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      // Add 2 exercises and create superset
      notifier.addExerciseToDay(0, LibraryExercise(
        id: 1, 
        name: 'Ex1', 
        muscleGroup: 'Chest', 
        equipment: 'Barbell',
        muscles: [],
        secondaryMuscles: [],
      ));
      notifier.addExerciseToDay(0, LibraryExercise(
        id: 2, 
        name: 'Ex2', 
        muscleGroup: 'Back', 
        equipment: 'Barbell',
        muscles: [],
        secondaryMuscles: [],
      ));
      
      notifier.createSuperset(0, 0, 1);

      // Remove one exercise
      notifier.removeExercise(0, 0);

      // Only one exercise left, and it should not have superset ID
      expect(notifier.state.dias[0].ejercicios.length, 1);
      expect(notifier.state.dias[0].ejercicios[0].nombre, 'Ex2');
      expect(notifier.state.dias[0].ejercicios[0].supersetId, isNull);
    });

    test('should remove exercise without affecting larger superset', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      // Add 3 exercises and create superset
      for (int i = 1; i <= 3; i++) {
        notifier.addExerciseToDay(0, LibraryExercise(
          id: i, 
          name: 'Ex$i', 
          muscleGroup: 'Chest', 
          equipment: 'Barbell',
          muscles: [],
          secondaryMuscles: [],
        ));
      }
      
      notifier.createSuperset(0, 0, 1);
      notifier.createSuperset(0, 1, 2);

      final supersetId = notifier.state.dias[0].ejercicios[0].supersetId!;

      // Remove middle exercise
      notifier.removeExercise(0, 1);

      // Two exercises left, both should still have superset ID
      expect(notifier.state.dias[0].ejercicios.length, 2);
      expect(notifier.state.dias[0].ejercicios[0].supersetId, equals(supersetId));
      expect(notifier.state.dias[0].ejercicios[1].supersetId, equals(supersetId));
    });
  });

  group('CreateRoutineNotifier - insertExercise', () {
    test('should insert exercise at specified index', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      // Add 2 exercises
      notifier.addExerciseToDay(0, LibraryExercise(
        id: 1, 
        name: 'Ex1', 
        muscleGroup: 'Chest', 
        equipment: 'Barbell',
        muscles: [],
        secondaryMuscles: [],
      ));
      notifier.addExerciseToDay(0, LibraryExercise(
        id: 2, 
        name: 'Ex2', 
        muscleGroup: 'Back', 
        equipment: 'Barbell',
        muscles: [],
        secondaryMuscles: [],
      ));

      // Insert new exercise in the middle
      final newEx = EjercicioEnRutina(
        id: '3',
        nombre: 'Inserted',
        musculosPrincipales: [],
        musculosSecundarios: [],
        equipo: 'Barbell',
      );

      notifier.insertExercise(0, 1, newEx);

      expect(notifier.state.dias[0].ejercicios.length, 3);
      expect(notifier.state.dias[0].ejercicios[0].nombre, 'Ex1');
      expect(notifier.state.dias[0].ejercicios[1].nombre, 'Inserted');
      expect(notifier.state.dias[0].ejercicios[2].nombre, 'Ex2');
    });
  });

  group('CreateRoutineNotifier - updateExercise', () {
    test('should update exercise properties', () {
      final notifier = CreateRoutineNotifier(mockRepository, null);
      
      notifier.addExerciseToDay(0, LibraryExercise(
        id: 1, 
        name: 'Ex1', 
        muscleGroup: 'Chest', 
        equipment: 'Barbell',
        muscles: [],
        secondaryMuscles: [],
      ));

      final exercise = notifier.state.dias[0].ejercicios[0];
      final updated = exercise.copyWith(
        series: 5,
        repsRange: '5-8',
        notas: 'Test notes',
      );

      notifier.updateExercise(0, 0, updated);

      final result = notifier.state.dias[0].ejercicios[0];
      expect(result.series, 5);
      expect(result.repsRange, '5-8');
      expect(result.notas, 'Test notes');
    });
  });
}
