import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/models/progression_type.dart';
import 'package:juan_training/models/progression_engine_models.dart';
import 'package:juan_training/services/progression_engine.dart';

void main() {
  late ProgressionEngine engine;

  setUp(() {
    engine = ProgressionEngine.instance;
  });

  group('ProgressionEngine - Doble Progresión', () {
    test('Calibración: primeras 2 sesiones no sugieren cambios', () {
      final context = ExerciseProgressionContext(
        exerciseId: 'test-1',
        exerciseName: 'Press Banca',
        state: ProgressionState.calibrating,
        recentSessions: [
          // Solo 1 sesión
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 7)),
            sets: [
              const SetSummary(weight: 80, reps: 10, targetReps: 10, completed: true),
              const SetSummary(weight: 80, reps: 10, targetReps: 10, completed: true),
              const SetSummary(weight: 80, reps: 10, targetReps: 10, completed: true),
            ],
            targetReps: 10,
            weight: 80,
          ),
        ],
        consecutiveSuccesses: 0,
        consecutiveFailures: 0,
        weeksAtCurrentWeight: 1,
        category: ExerciseCategory.heavyCompound,
        confirmedWeight: 80,
        repsRange: (8, 12),
      );

      final decision = engine.calculateNextSession(
        context: context,
        model: ProgressionType.dobleRepsFirst,
      );

      expect(decision.action, ProgressionAction.maintain);
      expect(decision.reason, contains('Calibración'));
    });

    test('Sesión completa sin max reps: sugiere +1 rep', () {
      final context = ExerciseProgressionContext(
        exerciseId: 'test-1',
        exerciseName: 'Press Banca',
        state: ProgressionState.progressing,
        recentSessions: [
          // Sesión actual: 3x10 (completa pero no max)
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 7)),
            sets: [
              const SetSummary(weight: 80, reps: 10, targetReps: 8, completed: true),
              const SetSummary(weight: 80, reps: 10, targetReps: 8, completed: true),
              const SetSummary(weight: 80, reps: 10, targetReps: 8, completed: true),
            ],
            targetReps: 8,
            weight: 80,
          ),
          // Sesión anterior
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 14)),
            sets: [
              const SetSummary(weight: 80, reps: 9, targetReps: 8, completed: true),
              const SetSummary(weight: 80, reps: 9, targetReps: 8, completed: true),
              const SetSummary(weight: 80, reps: 9, targetReps: 8, completed: true),
            ],
            targetReps: 8,
            weight: 80,
          ),
        ],
        consecutiveSuccesses: 1,
        consecutiveFailures: 0,
        weeksAtCurrentWeight: 2,
        category: ExerciseCategory.heavyCompound,
        confirmedWeight: 80,
        repsRange: (8, 12),
      );

      final decision = engine.calculateNextSession(
        context: context,
        model: ProgressionType.dobleRepsFirst,
      );

      expect(decision.action, ProgressionAction.increaseReps);
      expect(decision.suggestedReps, 11);
      expect(decision.isImprovement, true);
    });

    test('2 sesiones a max reps: sugiere subir peso', () {
      final context = ExerciseProgressionContext(
        exerciseId: 'test-1',
        exerciseName: 'Press Banca',
        state: ProgressionState.progressing,
        recentSessions: [
          // Sesión actual: 3x12 (max reps)
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 7)),
            sets: [
              const SetSummary(weight: 80, reps: 12, targetReps: 8, completed: true),
              const SetSummary(weight: 80, reps: 12, targetReps: 8, completed: true),
              const SetSummary(weight: 80, reps: 12, targetReps: 8, completed: true),
            ],
            targetReps: 8,
            weight: 80,
          ),
          // Sesión anterior: también 3x12
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 14)),
            sets: [
              const SetSummary(weight: 80, reps: 12, targetReps: 8, completed: true),
              const SetSummary(weight: 80, reps: 12, targetReps: 8, completed: true),
              const SetSummary(weight: 80, reps: 12, targetReps: 8, completed: true),
            ],
            targetReps: 8,
            weight: 80,
          ),
        ],
        consecutiveSuccesses: 2,
        consecutiveFailures: 0,
        weeksAtCurrentWeight: 2,
        category: ExerciseCategory.heavyCompound,
        confirmedWeight: 80,
        repsRange: (8, 12),
      );

      final decision = engine.calculateNextSession(
        context: context,
        model: ProgressionType.dobleRepsFirst,
      );

      expect(decision.action, ProgressionAction.increaseWeight);
      expect(decision.suggestedWeight, 82.5); // +2.5kg para heavy compound >60kg
      expect(decision.suggestedReps, 8); // Vuelve al mínimo
      expect(decision.isImprovement, true);
    });

    test('1 sesión a max reps: espera confirmación', () {
      final context = ExerciseProgressionContext(
        exerciseId: 'test-1',
        exerciseName: 'Press Banca',
        state: ProgressionState.confirming,
        recentSessions: [
          // Sesión actual: 3x12 (max reps)
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 7)),
            sets: [
              const SetSummary(weight: 80, reps: 12, targetReps: 8, completed: true),
              const SetSummary(weight: 80, reps: 12, targetReps: 8, completed: true),
              const SetSummary(weight: 80, reps: 12, targetReps: 8, completed: true),
            ],
            targetReps: 8,
            weight: 80,
          ),
          // Sesión anterior: solo 3x10
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 14)),
            sets: [
              const SetSummary(weight: 80, reps: 10, targetReps: 8, completed: true),
              const SetSummary(weight: 80, reps: 10, targetReps: 8, completed: true),
              const SetSummary(weight: 80, reps: 10, targetReps: 8, completed: true),
            ],
            targetReps: 8,
            weight: 80,
          ),
        ],
        consecutiveSuccesses: 0, // Primera vez en max
        consecutiveFailures: 0,
        weeksAtCurrentWeight: 2,
        category: ExerciseCategory.heavyCompound,
        confirmedWeight: 80,
        repsRange: (8, 12),
      );

      final decision = engine.calculateNextSession(
        context: context,
        model: ProgressionType.dobleRepsFirst,
      );

      expect(decision.action, ProgressionAction.maintain);
      expect(decision.reason, contains('Confirmando'));
      expect(decision.suggestedWeight, 80); // No sube todavía
    });

    test('Día malo único: no castiga, mantiene', () {
      final context = ExerciseProgressionContext(
        exerciseId: 'test-1',
        exerciseName: 'Sentadilla',
        state: ProgressionState.progressing,
        recentSessions: [
          // Sesión mala: solo 2/4 sets completados
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 7)),
            sets: [
              const SetSummary(weight: 100, reps: 8, targetReps: 8, completed: true),
              const SetSummary(weight: 100, reps: 6, targetReps: 8, completed: true),
              const SetSummary(weight: 100, reps: 5, targetReps: 8, completed: true),
              const SetSummary(weight: 100, reps: 4, targetReps: 8, completed: true),
            ],
            targetReps: 8,
            weight: 100,
          ),
          // Sesión anterior: buena
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 14)),
            sets: [
              const SetSummary(weight: 100, reps: 8, targetReps: 8, completed: true),
              const SetSummary(weight: 100, reps: 8, targetReps: 8, completed: true),
              const SetSummary(weight: 100, reps: 8, targetReps: 8, completed: true),
              const SetSummary(weight: 100, reps: 8, targetReps: 8, completed: true),
            ],
            targetReps: 8,
            weight: 100,
          ),
        ],
        consecutiveSuccesses: 0,
        consecutiveFailures: 1, // Solo 1 fallo
        weeksAtCurrentWeight: 2,
        category: ExerciseCategory.heavyCompound,
        confirmedWeight: 100,
        repsRange: (8, 10),
      );

      final decision = engine.calculateNextSession(
        context: context,
        model: ProgressionType.dobleRepsFirst,
      );

      expect(decision.action, ProgressionAction.maintain);
      expect(decision.suggestedWeight, 100); // NO baja
      expect(decision.userMessage, contains('día malo'));
    });

    test('2 días malos consecutivos: sugiere bajar peso', () {
      final context = ExerciseProgressionContext(
        exerciseId: 'test-1',
        exerciseName: 'Peso Muerto',
        state: ProgressionState.progressing,
        recentSessions: [
          // Segunda sesión mala
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 7)),
            sets: [
              const SetSummary(weight: 140, reps: 5, targetReps: 8, completed: true),
              const SetSummary(weight: 140, reps: 4, targetReps: 8, completed: true),
              const SetSummary(weight: 140, reps: 3, targetReps: 8, completed: true),
            ],
            targetReps: 8,
            weight: 140,
          ),
          // Primera sesión mala
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 14)),
            sets: [
              const SetSummary(weight: 140, reps: 6, targetReps: 8, completed: true),
              const SetSummary(weight: 140, reps: 5, targetReps: 8, completed: true),
              const SetSummary(weight: 140, reps: 4, targetReps: 8, completed: true),
            ],
            targetReps: 8,
            weight: 140,
          ),
        ],
        consecutiveSuccesses: 0,
        consecutiveFailures: 2, // 2 fallos consecutivos
        weeksAtCurrentWeight: 2,
        category: ExerciseCategory.heavyCompound,
        confirmedWeight: 140,
        repsRange: (8, 10),
      );

      final decision = engine.calculateNextSession(
        context: context,
        model: ProgressionType.dobleRepsFirst,
      );

      expect(decision.action, ProgressionAction.decreaseWeight);
      expect(decision.suggestedWeight, 137.5); // -2.5kg
      expect(decision.userMessage, contains('consolidar'));
    });
  });

  group('ExerciseCategory - Inferencia automática', () {
    test('Detecta compuestos pesados', () {
      expect(ExerciseCategory.inferFromName('Sentadilla'), ExerciseCategory.heavyCompound);
      expect(ExerciseCategory.inferFromName('Press Banca'), ExerciseCategory.heavyCompound);
      expect(ExerciseCategory.inferFromName('Peso Muerto'), ExerciseCategory.heavyCompound);
      expect(ExerciseCategory.inferFromName('Bench Press'), ExerciseCategory.heavyCompound);
      expect(ExerciseCategory.inferFromName('Squat'), ExerciseCategory.heavyCompound);
    });

    test('Detecta compuestos ligeros', () {
      expect(ExerciseCategory.inferFromName('Remo con Barra'), ExerciseCategory.lightCompound);
      expect(ExerciseCategory.inferFromName('Press Militar'), ExerciseCategory.lightCompound);
      expect(ExerciseCategory.inferFromName('Dominadas'), ExerciseCategory.lightCompound);
      expect(ExerciseCategory.inferFromName('Fondos'), ExerciseCategory.lightCompound);
    });

    test('Detecta máquinas', () {
      expect(ExerciseCategory.inferFromName('Prensa de Piernas'), ExerciseCategory.machine);
      expect(ExerciseCategory.inferFromName('Polea Alta'), ExerciseCategory.machine);
      expect(ExerciseCategory.inferFromName('Cable Crossover'), ExerciseCategory.machine);
    });

    test('Default: aislamiento', () {
      expect(ExerciseCategory.inferFromName('Curl de Bíceps'), ExerciseCategory.isolation);
      expect(ExerciseCategory.inferFromName('Extensión de Tríceps'), ExerciseCategory.isolation);
      expect(ExerciseCategory.inferFromName('Elevaciones Laterales'), ExerciseCategory.isolation);
    });
  });

  group('ExerciseCategory - Incrementos inteligentes', () {
    test('Heavy compound: 2.5kg para >60kg, 1.25kg para <60kg', () {
      expect(ExerciseCategory.heavyCompound.getIncrement(100), 2.5);
      expect(ExerciseCategory.heavyCompound.getIncrement(60), 2.5);
      expect(ExerciseCategory.heavyCompound.getIncrement(50), 1.25);
    });

    test('Light compound: 2.5kg para >40kg, 1.25kg para <40kg', () {
      expect(ExerciseCategory.lightCompound.getIncrement(60), 2.5);
      expect(ExerciseCategory.lightCompound.getIncrement(40), 2.5);
      expect(ExerciseCategory.lightCompound.getIncrement(30), 1.25);
    });

    test('Isolation: siempre 1.25kg', () {
      expect(ExerciseCategory.isolation.getIncrement(10), 1.25);
      expect(ExerciseCategory.isolation.getIncrement(30), 1.25);
    });

    test('Machine: siempre 2.5kg', () {
      expect(ExerciseCategory.machine.getIncrement(50), 2.5);
    });
  });

  group('SessionResult - Evaluación de sesión', () {
    test('100% éxito = complete', () {
      final session = SessionSummary(
        date: DateTime.now(),
        sets: [
          const SetSummary(weight: 80, reps: 10, targetReps: 10, completed: true),
          const SetSummary(weight: 80, reps: 10, targetReps: 10, completed: true),
          const SetSummary(weight: 80, reps: 10, targetReps: 10, completed: true),
        ],
        targetReps: 10,
        weight: 80,
      );
      
      expect(session.evaluate(), SessionResult.complete);
      expect(session.successRate, 1.0);
    });

    test('80% éxito = acceptable', () {
      final session = SessionSummary(
        date: DateTime.now(),
        sets: [
          const SetSummary(weight: 80, reps: 10, targetReps: 10, completed: true),
          const SetSummary(weight: 80, reps: 10, targetReps: 10, completed: true),
          const SetSummary(weight: 80, reps: 10, targetReps: 10, completed: true),
          const SetSummary(weight: 80, reps: 10, targetReps: 10, completed: true),
          const SetSummary(weight: 80, reps: 8, targetReps: 10, completed: true), // Fallo
        ],
        targetReps: 10,
        weight: 80,
      );
      
      expect(session.evaluate(), SessionResult.acceptable);
    });

    test('50% éxito = partial', () {
      final session = SessionSummary(
        date: DateTime.now(),
        sets: [
          const SetSummary(weight: 80, reps: 10, targetReps: 10, completed: true),
          const SetSummary(weight: 80, reps: 10, targetReps: 10, completed: true),
          const SetSummary(weight: 80, reps: 8, targetReps: 10, completed: true),
          const SetSummary(weight: 80, reps: 7, targetReps: 10, completed: true),
        ],
        targetReps: 10,
        weight: 80,
      );
      
      expect(session.evaluate(), SessionResult.partial);
    });

    test('<50% éxito = failed', () {
      final session = SessionSummary(
        date: DateTime.now(),
        sets: [
          const SetSummary(weight: 80, reps: 10, targetReps: 10, completed: true),
          const SetSummary(weight: 80, reps: 6, targetReps: 10, completed: true),
          const SetSummary(weight: 80, reps: 5, targetReps: 10, completed: true),
          const SetSummary(weight: 80, reps: 4, targetReps: 10, completed: true),
        ],
        targetReps: 10,
        weight: 80,
      );
      
      expect(session.evaluate(), SessionResult.failed);
    });
  });

  group('ProgressionEngine - Compatibilidad legacy', () {
    test('calculateFromLegacyData funciona con datos antiguos', () {
      final decision = engine.calculateFromLegacyData(
        progressionType: ProgressionType.dobleRepsFirst,
        weightIncrement: 2.5,
        targetReps: 8,
        maxReps: 12,
        previousLogs: [
          // Simular SerieLog con datos mínimos
        ],
        setIndex: 0,
        exerciseName: 'Press Banca',
      );

      // Con logs vacíos, debería retornar null
      expect(decision, isNull);
    });
  });
}
