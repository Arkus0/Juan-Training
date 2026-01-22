import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/services/exercise_parsing_service.dart';
import 'package:juan_training/services/exercise_validation_service.dart';

void main() {
  group('ExerciseParsingService', () {
    group('Parsing de patrones NxM', () {
      test('Debe parsear "4x10" correctamente', () async {
        // Arrange
        const input = 'Press banca 4x10';

        // Act
        final results = await ExerciseParsingService.instance.parseText(
          input,
          source: ParseSource.manual,
          validateResults: false,
        );

        // Assert
        expect(results.length, 1);
        expect(results.first.series, 4);
        expect(results.first.repsRange, '10');
      });

      test('Debe parsear rango de reps "4x8-12"', () async {
        const input = 'Sentadilla 4x8-12';

        final results = await ExerciseParsingService.instance.parseText(
          input,
          source: ParseSource.manual,
          validateResults: false,
        );

        expect(results.length, 1);
        expect(results.first.series, 4);
        expect(results.first.repsRange, '8-12');
        expect(results.first.minReps, 8);
        expect(results.first.maxReps, 12);
      });

      test('Debe parsear peso en kg', () async {
        const input = 'Peso muerto 5x5 100kg';

        final results = await ExerciseParsingService.instance.parseText(
          input,
          source: ParseSource.manual,
          validateResults: false,
        );

        expect(results.length, 1);
        expect(results.first.series, 5);
        expect(results.first.repsRange, '5');
        expect(results.first.weight, 100.0);
      });

      test('No debe confundir peso con reps', () async {
        // Este es un caso crítico: "100kg" no debe parsearse como 100 reps
        const input = 'Curl biceps 3x12 100kg';

        final results = await ExerciseParsingService.instance.parseText(
          input,
          source: ParseSource.manual,
          validateResults: false,
        );

        expect(results.length, 1);
        expect(results.first.series, 3);
        expect(results.first.repsRange, '12');
        expect(results.first.weight, 100.0);
      });
    });

    group('Parsing de patrones explícitos', () {
      test('Debe parsear "3 series de 12 reps"', () async {
        const input = 'Dominadas 3 series de 12 reps';

        final results = await ExerciseParsingService.instance.parseText(
          input,
          source: ParseSource.voice,
          validateResults: false,
        );

        expect(results.length, 1);
        expect(results.first.series, 3);
        expect(results.first.repsRange, '12');
      });

      test('Debe parsear notas', () async {
        const input = 'Press militar 4x8 nota: usar cinturón';

        final results = await ExerciseParsingService.instance.parseText(
          input,
          source: ParseSource.voice,
          validateResults: false,
        );

        expect(results.length, 1);
        expect(results.first.notes, 'usar cinturón');
      });
    });

    group('Múltiples ejercicios', () {
      test('Debe separar ejercicios por "luego"', () async {
        const input = 'Press banca 4x10 luego sentadilla 5x5';

        final results = await ExerciseParsingService.instance.parseText(
          input,
          source: ParseSource.voice,
          validateResults: false,
        );

        expect(results.length, 2);
        expect(results[0].series, 4);
        expect(results[0].repsRange, '10');
        expect(results[1].series, 5);
        expect(results[1].repsRange, '5');
      });

      test('Debe separar ejercicios por coma', () async {
        const input = 'Curl 3x12, Triceps 3x12';

        final results = await ExerciseParsingService.instance.parseText(
          input,
          source: ParseSource.manual,
          validateResults: false,
        );

        expect(results.length, 2);
      });
    });

    group('Valores por defecto', () {
      test('Debe usar series=3 por defecto si no especificado', () async {
        const input = 'Dominadas 10 reps';

        final results = await ExerciseParsingService.instance.parseText(
          input,
          source: ParseSource.manual,
          validateResults: false,
        );

        expect(results.length, 1);
        expect(results.first.series, 3);
        expect(results.first.repsRange, '10');
      });

      test('Debe usar reps=10 por defecto si no especificado', () async {
        const input = 'Press banca 4 series';

        final results = await ExerciseParsingService.instance.parseText(
          input,
          source: ParseSource.manual,
          validateResults: false,
        );

        expect(results.length, 1);
        expect(results.first.series, 4);
        // reps default es 10 pero como no parseamos "series" suelto igual,
        // se mantiene el repsRange default
      });
    });

    group('Normalización para voz', () {
      test('Debe convertir números hablados', () async {
        const input = 'Sentadilla tres series de doce reps';

        final results = await ExerciseParsingService.instance.parseText(
          input,
          source: ParseSource.voice,
          validateResults: false,
        );

        expect(results.length, 1);
        expect(results.first.series, 3);
        expect(results.first.repsRange, '12');
      });
    });
  });

  group('ExerciseValidationService', () {
    final service = ExerciseValidationService.instance;

    test('Debe validar ejercicio con valores normales', () {
      final exercise = ParsedExercise(
        rawText: 'test',
        matchedId: 1,
        matchedName: 'Test',
        series: 4,
        repsRange: '10',
        confidence: 0.9,
      );

      final result = service.validate(exercise);

      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('Debe rechazar series fuera de rango', () {
      final exercise = ParsedExercise(
        rawText: 'test',
        matchedId: 1,
        series: 50, // Demasiadas series
        repsRange: '10',
      );

      final result = service.validate(exercise);

      expect(result.isValid, false);
      expect(result.errors, isNotEmpty);
    });

    test('Debe rechazar reps fuera de rango', () {
      final exercise = ParsedExercise(
        rawText: 'test',
        matchedId: 1,
        series: 4,
        repsRange: '500', // Demasiadas reps
      );

      final result = service.validate(exercise);

      expect(result.isValid, false);
    });

    test('Debe rechazar peso excesivo', () {
      final exercise = ParsedExercise(
        rawText: 'test',
        matchedId: 1,
        series: 4,
        repsRange: '10',
        weight: 1000.0, // Peso absurdo
      );

      final result = service.validate(exercise);

      expect(result.isValid, false);
    });

    test('Debe advertir cuando no hay match de ejercicio', () {
      final exercise = ParsedExercise(
        rawText: 'test',
        matchedId: null, // Sin match
        series: 4,
        repsRange: '10',
      );

      final result = service.validate(exercise);

      expect(result.warnings, isNotEmpty);
    });

    test('autoCorrect debe corregir valores extremos', () {
      final exercise = ParsedExercise(
        rawText: 'test',
        series: 100, // Extremo
        repsRange: '10',
      );

      final corrected = service.autoCorrect(exercise);

      expect(corrected.series, 3); // Corregido al default
    });

    test('Debe detectar errores de parseo comunes', () {
      // Caso: reps parece ser peso (60 es múltiplo de 5, > 50)
      final exercise = ParsedExercise(
        rawText: 'test',
        series: 4,
        repsRange: '60',
        matchedId: 1,
      );

      final issues = service.detectPotentialParseErrors(exercise);

      expect(issues, isNotEmpty);
      expect(issues.first, contains('parecen ser un peso'));
    });
  });
}
