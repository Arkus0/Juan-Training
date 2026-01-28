import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/models/progression_engine_models.dart';
import 'package:juan_training/models/progression_type.dart';
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
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 10, completed: true,),
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 10, completed: true,),
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 10, completed: true,),
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
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 8, completed: true,),
            ],
            targetReps: 8,
            weight: 80,
          ),
          // Sesión anterior
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 14)),
            sets: [
              const SetSummary(
                  weight: 80, reps: 9, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 9, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 9, targetReps: 8, completed: true,),
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

    test('TODAS las series a max reps: sugiere subir peso (Lyle McDonald)', () {
      // LYLE McDONALD: "Once you can complete ALL sets at the top of the rep range"
      // Ya no necesita 2 sesiones de confirmación si TODAS las series están en max
      final context = ExerciseProgressionContext(
        exerciseId: 'test-1',
        exerciseName: 'Press Banca',
        state: ProgressionState.progressing,
        recentSessions: [
          // Sesión actual: 3x12 (TODAS en max reps)
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 7)),
            sets: [
              const SetSummary(
                  weight: 80, reps: 12, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 12, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 12, targetReps: 8, completed: true,),
            ],
            targetReps: 8,
            weight: 80,
          ),
          // Sesión anterior (no importa si estaba en max, ahora no necesita confirmación)
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 14)),
            sets: [
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 8, completed: true,),
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

      expect(decision.action, ProgressionAction.increaseWeight);
      expect(
          decision.suggestedWeight, 82.5,); // +2.5kg para heavy compound >60kg
      expect(decision.suggestedReps, 8); // Vuelve al mínimo
      expect(decision.isImprovement, true);
      expect(decision.reason,
          contains('Todas las series'),); // Verifica criterio Lyle
    });

    test(
        'Promedio en max pero UNA serie falla: NO subir (criterio Lyle estricto)',
        () {
      // DIFERENCIA CRÍTICA: El promedio es 12, pero Serie 3 solo hizo 11
      // Según Lyle, NO todas están en max, así que NO debe subir peso
      final context = ExerciseProgressionContext(
        exerciseId: 'test-1',
        exerciseName: 'Press Banca',
        state: ProgressionState.progressing,
        recentSessions: [
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 7)),
            sets: [
              const SetSummary(
                  weight: 80, reps: 13, targetReps: 8, completed: true,), // +1
              const SetSummary(
                  weight: 80, reps: 12, targetReps: 8, completed: true,), // max
              const SetSummary(
                  weight: 80,
                  reps: 11,
                  targetReps: 8,
                  completed: true,), // -1 (FALLA max)
            ],
            targetReps: 8,
            weight: 80,
          ),
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 14)),
            sets: [
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 8, completed: true,),
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

      // Promedio = (13+12+11)/3 = 12, PERO Serie 3 no alcanzó 12
      // Según Lyle: NO subir, consolidar
      expect(decision.action, ProgressionAction.maintain);
      expect(decision.suggestedWeight, 80); // Mismo peso
      expect(decision.suggestedReps, 12); // Mantener objetivo max
    });

    test('1 sesión a max reps: sube peso sin confirmación', () {
      final context = ExerciseProgressionContext(
        exerciseId: 'test-1',
        exerciseName: 'Press Banca',
        state: ProgressionState.confirming,
        recentSessions: [
          // Sesión actual: 3x12 (max reps)
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 7)),
            sets: [
              const SetSummary(
                  weight: 80, reps: 12, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 12, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 12, targetReps: 8, completed: true,),
            ],
            targetReps: 8,
            weight: 80,
          ),
          // Sesión anterior: solo 3x10
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 14)),
            sets: [
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 80, reps: 10, targetReps: 8, completed: true,),
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

      expect(decision.action, ProgressionAction.increaseWeight);
      expect(
          decision.suggestedWeight, 82.5,); // +2.5kg para heavy compound >60kg
      expect(decision.suggestedReps, 8); // Vuelve al mínimo
      expect(decision.reason, contains('Todas las series'));
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
              const SetSummary(
                  weight: 100, reps: 8, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 100, reps: 6, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 100, reps: 5, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 100, reps: 4, targetReps: 8, completed: true,),
            ],
            targetReps: 8,
            weight: 100,
          ),
          // Sesión anterior: buena
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 14)),
            sets: [
              const SetSummary(
                  weight: 100, reps: 8, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 100, reps: 8, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 100, reps: 8, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 100, reps: 8, targetReps: 8, completed: true,),
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

    test('2 días malos al MISMO PESO: deload 10% (Lyle/Rippetoe)', () {
      final context = ExerciseProgressionContext(
        exerciseId: 'test-1',
        exerciseName: 'Peso Muerto',
        state: ProgressionState.progressing,
        recentSessions: [
          // Segunda sesión mala AL MISMO PESO
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 7)),
            sets: [
              const SetSummary(
                  weight: 140, reps: 5, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 140, reps: 4, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 140, reps: 3, targetReps: 8, completed: true,),
            ],
            targetReps: 8,
            weight: 140,
          ),
          // Primera sesión mala AL MISMO PESO
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 14)),
            sets: [
              const SetSummary(
                  weight: 140, reps: 6, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 140, reps: 5, targetReps: 8, completed: true,),
              const SetSummary(
                  weight: 140, reps: 4, targetReps: 8, completed: true,),
            ],
            targetReps: 8,
            weight: 140,
          ),
        ],
        consecutiveSuccesses: 0,
        consecutiveFailures: 2,
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
      // NUEVO: Deload debe ser 10% (14kg), no solo 2.5kg
      expect(decision.suggestedWeight, closeTo(126, 2)); // 140 - 14 = 126
      expect(decision.reason, contains('10%'));
    });
  });

  group('ProgressionEngine - Lineal (Rippetoe/StrongLifts)', () {
    test('Sesión completa: subir peso INMEDIATAMENTE (sin confirmación)', () {
      // RIPPETOE: "Add weight to the bar every workout"
      // NO hay confirmación de 2 sesiones para novatos
      final context = ExerciseProgressionContext(
        exerciseId: 'test-lineal',
        exerciseName: 'Sentadilla',
        state: ProgressionState.progressing,
        recentSessions: [
          // Sesión actual: exitosa
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 7)),
            sets: [
              const SetSummary(
                  weight: 100, reps: 5, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 100, reps: 5, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 100, reps: 5, targetReps: 5, completed: true,),
            ],
            targetReps: 5,
            weight: 100,
          ),
          // No importa la anterior para lineal novice
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 14)),
            sets: [
              const SetSummary(
                  weight: 97.5, reps: 5, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 97.5, reps: 5, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 97.5, reps: 5, targetReps: 5, completed: true,),
            ],
            targetReps: 5,
            weight: 97.5,
          ),
        ],
        consecutiveSuccesses: 1, // Solo 1, pero lineal no necesita 2
        consecutiveFailures: 0,
        weeksAtCurrentWeight: 1,
        category: ExerciseCategory.heavyCompound,
        confirmedWeight: 100,
        repsRange: (5, 5),
      );

      final decision = engine.calculateNextSession(
        context: context,
        model: ProgressionType.lineal,
      );

      // Lineal novice: sube INMEDIATAMENTE tras éxito
      expect(decision.action, ProgressionAction.increaseWeight);
      expect(decision.suggestedWeight, 102.5); // +2.5kg
      expect(decision.isImprovement, true);
      expect(decision.reason, contains('Rippetoe'));
    });

    test('STALL: 3 fallos al MISMO peso → deload 10% (Rippetoe)', () {
      // "A stall is failing to complete work sets for THREE consecutive
      // workouts at the SAME weight" — Starting Strength p.303
      final context = ExerciseProgressionContext(
        exerciseId: 'test-stall',
        exerciseName: 'Press Banca',
        state: ProgressionState.progressing,
        recentSessions: [
          // Tercer fallo AL MISMO PESO
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 3)),
            sets: [
              const SetSummary(
                  weight: 80, reps: 4, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 80, reps: 3, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 80, reps: 3, targetReps: 5, completed: true,),
            ],
            targetReps: 5,
            weight: 80,
          ),
          // Segundo fallo AL MISMO PESO
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 5)),
            sets: [
              const SetSummary(
                  weight: 80, reps: 5, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 80, reps: 4, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 80, reps: 3, targetReps: 5, completed: true,),
            ],
            targetReps: 5,
            weight: 80,
          ),
          // Primer fallo AL MISMO PESO
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 7)),
            sets: [
              const SetSummary(
                  weight: 80, reps: 5, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 80, reps: 5, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 80, reps: 4, targetReps: 5, completed: true,),
            ],
            targetReps: 5,
            weight: 80,
          ),
        ],
        consecutiveSuccesses: 0,
        consecutiveFailures: 3,
        weeksAtCurrentWeight: 1,
        category: ExerciseCategory.heavyCompound,
        confirmedWeight: 80,
        repsRange: (5, 5),
      );

      final decision = engine.calculateNextSession(
        context: context,
        model: ProgressionType.lineal,
      );

      expect(decision.action, ProgressionAction.decreaseWeight);
      // Deload 10% de 80kg = 8kg → 72kg
      expect(decision.suggestedWeight, closeTo(72, 2));
      expect(decision.reason, contains('3 fallos'));
      expect(decision.reason, contains('10%'));
    });

    test('Fallo 1 de 3: mantener y reintentar (no deload todavía)', () {
      final context = ExerciseProgressionContext(
        exerciseId: 'test-1fallo',
        exerciseName: 'Press Militar',
        state: ProgressionState.progressing,
        recentSessions: [
          // Primer fallo
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 3)),
            sets: [
              const SetSummary(
                  weight: 50, reps: 5, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 50, reps: 4, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 50, reps: 3, targetReps: 5, completed: true,),
            ],
            targetReps: 5,
            weight: 50,
          ),
          // Sesión exitosa anterior (diferente peso)
          SessionSummary(
            date: DateTime.now().subtract(const Duration(days: 5)),
            sets: [
              const SetSummary(
                  weight: 47.5, reps: 5, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 47.5, reps: 5, targetReps: 5, completed: true,),
              const SetSummary(
                  weight: 47.5, reps: 5, targetReps: 5, completed: true,),
            ],
            targetReps: 5,
            weight: 47.5,
          ),
        ],
        consecutiveSuccesses: 0,
        consecutiveFailures: 1, // Solo 1 fallo
        weeksAtCurrentWeight: 1,
        category: ExerciseCategory.lightCompound,
        confirmedWeight: 50,
        repsRange: (5, 5),
      );

      final decision = engine.calculateNextSession(
        context: context,
        model: ProgressionType.lineal,
      );

      // Solo 1 fallo: NO deload, reintentar
      expect(decision.action, ProgressionAction.maintain);
      expect(decision.suggestedWeight, 50); // Mismo peso
      expect(
          decision.userMessage, contains('1/3'),); // Indica progreso hacia stall
    });
  });

  group('ExerciseCategory - Inferencia automática', () {
    test('Detecta compuestos pesados', () {
      expect(ExerciseCategory.inferFromName('Sentadilla'),
          ExerciseCategory.heavyCompound,);
      expect(ExerciseCategory.inferFromName('Press Banca'),
          ExerciseCategory.heavyCompound,);
      expect(ExerciseCategory.inferFromName('Peso Muerto'),
          ExerciseCategory.heavyCompound,);
      expect(ExerciseCategory.inferFromName('Bench Press'),
          ExerciseCategory.heavyCompound,);
      expect(ExerciseCategory.inferFromName('Squat'),
          ExerciseCategory.heavyCompound,);
    });

    test('Detecta compuestos ligeros', () {
      expect(ExerciseCategory.inferFromName('Remo con Barra'),
          ExerciseCategory.lightCompound,);
      expect(ExerciseCategory.inferFromName('Press Militar'),
          ExerciseCategory.lightCompound,);
      expect(ExerciseCategory.inferFromName('Dominadas'),
          ExerciseCategory.lightCompound,);
      expect(ExerciseCategory.inferFromName('Fondos'),
          ExerciseCategory.lightCompound,);
    });

    test('Detecta máquinas', () {
      expect(ExerciseCategory.inferFromName('Prensa de Piernas'),
          ExerciseCategory.machine,);
      expect(ExerciseCategory.inferFromName('Polea Alta'),
          ExerciseCategory.machine,);
      expect(ExerciseCategory.inferFromName('Cable Crossover'),
          ExerciseCategory.machine,);
    });

    test('Default: aislamiento', () {
      expect(ExerciseCategory.inferFromName('Curl de Bíceps'),
          ExerciseCategory.isolation,);
      expect(ExerciseCategory.inferFromName('Extensión de Tríceps'),
          ExerciseCategory.isolation,);
      expect(ExerciseCategory.inferFromName('Elevaciones Laterales'),
          ExerciseCategory.isolation,);
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
          const SetSummary(
              weight: 80, reps: 10, targetReps: 10, completed: true,),
          const SetSummary(
              weight: 80, reps: 10, targetReps: 10, completed: true,),
          const SetSummary(
              weight: 80, reps: 10, targetReps: 10, completed: true,),
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
          const SetSummary(
              weight: 80, reps: 10, targetReps: 10, completed: true,),
          const SetSummary(
              weight: 80, reps: 10, targetReps: 10, completed: true,),
          const SetSummary(
              weight: 80, reps: 10, targetReps: 10, completed: true,),
          const SetSummary(
              weight: 80, reps: 10, targetReps: 10, completed: true,),
          const SetSummary(
              weight: 80, reps: 8, targetReps: 10, completed: true,), // Fallo
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
          const SetSummary(
              weight: 80, reps: 10, targetReps: 10, completed: true,),
          const SetSummary(
              weight: 80, reps: 10, targetReps: 10, completed: true,),
          const SetSummary(
              weight: 80, reps: 8, targetReps: 10, completed: true,),
          const SetSummary(
              weight: 80, reps: 7, targetReps: 10, completed: true,),
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
          const SetSummary(
              weight: 80, reps: 10, targetReps: 10, completed: true,),
          const SetSummary(
              weight: 80, reps: 6, targetReps: 10, completed: true,),
          const SetSummary(
              weight: 80, reps: 5, targetReps: 10, completed: true,),
          const SetSummary(
              weight: 80, reps: 4, targetReps: 10, completed: true,),
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
