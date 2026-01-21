import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juan_training/providers/create_routine_provider.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/repositories/i_training_repository.dart';
import 'package:juan_training/providers/training_provider.dart';

// Fake Repository to satisfy the dependency without external calls
class FakeTrainingRepository extends Fake implements ITrainingRepository {}

void main() {
  // Helper to create a dummy LibraryExercise
  LibraryExercise createDummyExercise(int id, String name) {
    return LibraryExercise(
      id: id,
      name: name,
      muscleGroup: 'Chest',
      equipment: 'Barbell',
      muscles: ['Pectoralis Major'],
      secondaryMuscles: ['Triceps'],
    );
  }

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        trainingRepositoryProvider.overrideWithValue(FakeTrainingRepository()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CreateRoutineNotifier Logic Tests', () {
    test('1. Test de "Duplicar Día" (Deep Copy)', () {
      // Setup
      final notifier = container.read(createRoutineProvider(null).notifier);

      // Add a day
      notifier.addDay(); // Index 0

      // Add 2 exercises to Day 1
      notifier.addExerciseToDay(0, createDummyExercise(101, 'Bench Press'));
      notifier.addExerciseToDay(0, createDummyExercise(102, 'Flyes'));

      // Get state before duplication
      var state = container.read(createRoutineProvider(null));
      expect(state.dias.length, 1);
      final day1 = state.dias[0];
      final ex1_1 = day1.ejercicios[0];
      final ex1_2 = day1.ejercicios[1];

      // Acción: Duplicate Day 0
      notifier.duplicateDay(0);

      // Verificaciones
      state = container.read(createRoutineProvider(null));
      expect(state.dias.length, 2, reason: 'Routine should have 2 days');

      final day2 = state.dias[1];

      // Nombre (o copia)
      expect(day2.nombre, contains(day1.nombre), reason: 'Day 2 name should contain Day 1 name');

      // Mismos ejercicios (contenido)
      expect(day2.ejercicios.length, 2);
      expect(day2.ejercicios[0].nombre, day1.ejercicios[0].nombre);
      expect(day2.ejercicios[1].nombre, day1.ejercicios[1].nombre);

      // CRÍTICO: IDs Diferentes
      expect(day2.id, isNot(equals(day1.id)), reason: 'Day IDs must be unique');

      // CRÍTICO: Instance IDs Diferentes
      expect(day2.ejercicios[0].instanceId, isNot(equals(ex1_1.instanceId)),
        reason: 'Exercise 1 instanceId must be unique in copy');
      expect(day2.ejercicios[1].instanceId, isNot(equals(ex1_2.instanceId)),
        reason: 'Exercise 2 instanceId must be unique in copy');
    });

    test('2. Test de Superseries (Lógica de Unión)', () {
      // Setup
      final notifier = container.read(createRoutineProvider(null).notifier);
      notifier.addDay();
      notifier.addExerciseToDay(0, createDummyExercise(201, 'Curl Biceps'));
      notifier.addExerciseToDay(0, createDummyExercise(202, 'Triceps Ext'));

      var state = container.read(createRoutineProvider(null));
      var day = state.dias[0];
      expect(day.ejercicios[0].supersetId, isNull);
      expect(day.ejercicios[1].supersetId, isNull);

      // Acción: Create Superset
      notifier.createSuperset(0, 0, 1);

      // Verificaciones
      state = container.read(createRoutineProvider(null));
      day = state.dias[0];

      final exA = day.ejercicios[0];
      final exB = day.ejercicios[1];

      expect(exA.supersetId, isNotNull, reason: 'Exercise A supersetId should not be null');
      expect(exB.supersetId, isNotNull, reason: 'Exercise B supersetId should not be null');
      expect(exA.supersetId, equals(exB.supersetId), reason: 'Superset IDs must be equal');
    });

    test('3. Test de "Duplicar Superserie" (Integridad de Referencias)', () {
      // Setup: Day with superset
      final notifier = container.read(createRoutineProvider(null).notifier);
      notifier.addDay();
      notifier.addExerciseToDay(0, createDummyExercise(301, 'Squat'));
      notifier.addExerciseToDay(0, createDummyExercise(302, 'Leg Press'));
      notifier.createSuperset(0, 0, 1);

      var state = container.read(createRoutineProvider(null));
      final day1 = state.dias[0];
      final originalSupersetId = day1.ejercicios[0].supersetId;
      expect(originalSupersetId, isNotNull);

      // Acción: Duplicate Day
      notifier.duplicateDay(0);

      // Verificaciones
      state = container.read(createRoutineProvider(null));
      final day2 = state.dias[1];
      final ex2_1 = day2.ejercicios[0];
      final ex2_2 = day2.ejercicios[1];

      // Los ejercicios del nuevo día también están en superserie
      expect(ex2_1.supersetId, isNotNull);
      expect(ex2_2.supersetId, isNotNull);
      expect(ex2_1.supersetId, equals(ex2_2.supersetId), reason: 'Copied exercises must share superset ID');

      // CRÍTICO: El supersetId de la COPIA debe ser DIFERENTE al del ORIGINAL
      expect(ex2_1.supersetId, isNot(equals(originalSupersetId)),
        reason: 'Copied superset ID must be different from original to allow independent editing');
    });

    test('4. Test de "Desvincular"', () {
      // Setup: Day with superset
      final notifier = container.read(createRoutineProvider(null).notifier);
      notifier.addDay();
      notifier.addExerciseToDay(0, createDummyExercise(401, 'Pull up'));
      notifier.addExerciseToDay(0, createDummyExercise(402, 'Row'));
      notifier.createSuperset(0, 0, 1);

      // Verify setup
      var state = container.read(createRoutineProvider(null));
      expect(state.dias[0].ejercicios[0].supersetId, isNotNull);

      // Acción: Remove from superset (exercise 0)
      notifier.removeFromSuperset(0, 0);

      // Verificación
      state = container.read(createRoutineProvider(null));
      final day = state.dias[0];
      final exA = day.ejercicios[0];
      final exB = day.ejercicios[1];

      expect(exA.supersetId, isNull, reason: 'Exercise A supersetId should be null');

      // Since only 1 remains, it should also be unlinked (logic check)
      expect(exB.supersetId, isNull, reason: 'Remaining single exercise should effectively lose superset status');
    });
  });
}
