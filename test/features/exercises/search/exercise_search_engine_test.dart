import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/features/exercises/search/exercise_search_engine.dart';
import 'package:juan_training/models/library_exercise.dart';

LibraryExercise _exercise(
  int id,
  String name, {
  String muscleGroup = 'Pecho',
  String equipment = 'Barra',
}) {
  return LibraryExercise(
    id: id,
    name: name,
    muscleGroup: muscleGroup,
    equipment: equipment,
  );
}

void main() {
  group('ExerciseSearchEngine', () {
    test('normalize tildes: "press banca" == "Press Bánca"', () {
      expect(normalize('Press Bánca'), 'press banca');
      expect(normalize('press banca'), 'press banca');
    });

    test('alias: "dominadas" encuentra "pull up"', () {
      const engine = ExerciseSearchEngine();
      final exercises = [
        _exercise(1, 'Pull Up', muscleGroup: 'Espalda'),
        _exercise(2, 'Press de Banca'),
      ];
      final index = ExerciseSearchIndex.build(exercises);

      final results = engine.searchWithIndex('dominadas', index, limit: 10);

      expect(results.first.name, 'Pull Up');
    });

    test('typo: "benhc pres" encuentra "bench press"', () {
      const engine = ExerciseSearchEngine();
      final exercises = [
        _exercise(1, 'Bench Press'),
        _exercise(2, 'Incline Bench Press'),
      ];
      final index = ExerciseSearchIndex.build(exercises);

      final results = engine.searchWithIndex('benhc pres', index, limit: 5);

      expect(results.first.name, 'Bench Press');
    });

    test('ranking: exact > prefix > tokens > fuzzy', () {
      const engine = ExerciseSearchEngine();
      final exercises = [
        _exercise(1, 'Bench Press'),
        _exercise(2, 'Bench Press Incline'),
        _exercise(3, 'Press Bench'),
        _exercise(4, 'Benhc Pres'),
      ];
      final index = ExerciseSearchIndex.build(exercises);

      final results = engine.searchWithIndex('bench press', index, limit: 10);

      expect(results[0].name, 'Bench Press');
      expect(results[1].name, 'Bench Press Incline');
      expect(results[2].name, 'Press Bench');
      expect(results.last.name, 'Benhc Pres');
    });

    test('performance: 5000 ejercicios < 200ms', () {
      const engine = ExerciseSearchEngine();
      final exercises = List.generate(
        5000,
        (i) => _exercise(i, 'Exercise $i', muscleGroup: 'Grupo $i'),
      )..add(_exercise(6000, 'Bench Press'));

      final index = ExerciseSearchIndex.build(exercises);
      final stopwatch = Stopwatch()..start();
      final results = engine.searchWithIndex('bench press', index, limit: 10);
      stopwatch.stop();

      expect(results.isNotEmpty, true);
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });
  });
}
