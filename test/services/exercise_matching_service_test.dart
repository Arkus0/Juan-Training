import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/services/exercise_matching_service.dart';

void main() {
  group('ExerciseMatchingService', () {
    group('normalizeText', () {
      test('Debe convertir a minúsculas', () {
        expect(ExerciseMatchingService.normalizeText('PRESS BANCA'), 'press banca');
      });

      test('Debe remover acentos', () {
        expect(ExerciseMatchingService.normalizeText('Elevación Lateral'), 'elevacion lateral');
        expect(ExerciseMatchingService.normalizeText('Jalón'), 'jalon');
        expect(ExerciseMatchingService.normalizeText('Bíceps'), 'biceps');
      });

      test('Debe remover ñ', () {
        expect(ExerciseMatchingService.normalizeText('Leñadores'), 'lenadores');
      });

      test('Debe remover caracteres especiales', () {
        expect(ExerciseMatchingService.normalizeText('Press (Banca)'), 'press banca');
        expect(ExerciseMatchingService.normalizeText('Curl-Martillo'), 'curl martillo');
      });

      test('Debe normalizar espacios múltiples', () {
        expect(ExerciseMatchingService.normalizeText('Press    Banca'), 'press banca');
        expect(ExerciseMatchingService.normalizeText('  Press Banca  '), 'press banca');
      });

      test('Debe manejar strings vacíos', () {
        expect(ExerciseMatchingService.normalizeText(''), '');
        expect(ExerciseMatchingService.normalizeText('   '), '');
      });
    });

    group('ExerciseMatchResult', () {
      test('isValid debe ser false sin ejercicio', () {
        const result = ExerciseMatchResult(
          confidence: 0.9,
          source: MatchSource.noMatch,
          normalizedQuery: 'test',
        );

        expect(result.isValid, false);
      });

      test('isValid debe requerir confidence mínima', () {
        // Con confidence muy baja, no es válido aunque tenga ejercicio
        // (esto es teórico, en la práctica exercise sería null)
        const result = ExerciseMatchResult(
          confidence: 0.3, // Bajo el umbral de 0.5
          source: MatchSource.fuzzy,
          normalizedQuery: 'test',
        );

        expect(result.isValid, false);
      });

      test('isHighConfidence debe verificar umbral 0.8', () {
        const highResult = ExerciseMatchResult(
          confidence: 0.85,
          source: MatchSource.exactMatch,
          normalizedQuery: 'test',
        );

        const lowResult = ExerciseMatchResult(
          confidence: 0.6,
          source: MatchSource.fuzzy,
          normalizedQuery: 'test',
        );

        expect(highResult.isHighConfidence, true);
        expect(lowResult.isHighConfidence, false);
      });
    });

    group('MatchSource', () {
      test('Debe tener todos los tipos de fuente', () {
        expect(MatchSource.values, contains(MatchSource.exactMatch));
        expect(MatchSource.values, contains(MatchSource.synonym));
        expect(MatchSource.values, contains(MatchSource.keyword));
        expect(MatchSource.values, contains(MatchSource.fuzzy));
        expect(MatchSource.values, contains(MatchSource.noMatch));
      });
    });
  });
}
