import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/services/exercise_library_service.dart';

void main() {
  group('Main Initialization Flow', () {
    setUp(() async {
      // Initialize Hive in a test directory
      Hive.init('test_hive_storage');
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
    });

    test('Library Service loads correctly with pre-opened box', () async {
      // 1. Register Adapter
      // Ensure we don't double register if running multiple tests
      if (!Hive.isAdapterRegistered(6)) {
        Hive.registerAdapter(LibraryExerciseAdapter());
      }

      // 2. Open Box (Simulating main.dart behavior)
      await Hive.openBox<LibraryExercise>('library_exercises');
      expect(Hive.isBoxOpen('library_exercises'), true, reason: 'Box should be open before service call');

      // 3. Load Library (Service should use the existing box)
      // This is the critical await the user was concerned about
      await ExerciseLibraryService.instance.loadLibrary();

      // 4. Verify Service State
      expect(ExerciseLibraryService.instance.isLoaded, true, reason: 'Service should be marked as loaded');

      // 5. Verify Box Content (should have fallback data if was empty)
      final box = Hive.box<LibraryExercise>('library_exercises');
      expect(box.isNotEmpty, true, reason: 'Box should contain fallback data');
      expect(box.values.first.name, isNotEmpty);
    });
  });
}
