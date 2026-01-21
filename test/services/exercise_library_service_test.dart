import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:juan_training/services/exercise_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // Mock Path Provider
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      return '.';
    });

    // Mock Connectivity (Assume online)
    const MethodChannel('dev.fluttercommunity.plus/connectivity/status')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      return ['wifi'];
    });

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({
      'initial_library_sync_completed': false, // Force sync
    });

    // Reset service state
    ExerciseLibraryService.instance.dispose();
  });

  test('Benchmark syncLibrary performance and correctness', () async {
    final service = ExerciseLibraryService.instance;

    // We simulate 2 languages.
    // Lang 2 (English): Returns ID 100 with name "Push Up"
    // Lang 4 (Spanish): Returns ID 100 with name "Flexión"

    final mockClient = MockClient((request) async {
      final url = request.url.toString();
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 200));

      if (url.contains('language=2')) {
        return Response(jsonEncode({
          "next": null,
          "results": [
            {
              "id": 100,
              "name": "Push Up",
              "category": {"id": 11, "name": "Chest"},
              "description": "English desc",
              "muscles": [],
              "muscles_secondary": [],
              "equipment": [{"id": 1, "name": "Barbell"}],
              "images": [],
              "license_author": "me"
            }
          ]
        }), 200);
      } else if (url.contains('language=4')) {
        return Response(jsonEncode({
          "next": null,
          "results": [
            {
              "id": 100,
              "name": "Flexión",
              "category": {"id": 11, "name": "Pecho"},
              "description": "Spanish desc",
              "muscles": [],
              "muscles_secondary": [],
              "equipment": [{"id": 1, "name": "Barra"}],
              "images": [],
              "license_author": "yo"
            }
          ]
        }), 200);
      }
      return Response('Not Found', 404);
    });

    await runWithClient(() async {
      final stopwatch = Stopwatch()..start();

      // We need to bypass `init()` because it does other stuff.
      // But `syncLibrary` checks connectivity and prefs.
      // We mocked prefs to force sync.

      final result = await service.syncLibrary();

      stopwatch.stop();
      print('Sync result: $result');
      print('Sync took: ${stopwatch.elapsedMilliseconds} ms');

      expect(result, isTrue);

      // Verification
      final exercises = service.getExercises();
      final ex = exercises.firstWhere((e) => e.id == 100, orElse: () => throw Exception('Exercise not found'));

      print('Exercise Name: ${ex.name}');
      print('Exercise Desc: ${ex.description}');

      // Expectation for CORRECTNESS:
      // Spanish should win.
      expect(ex.name, equals('Flexión'));
      expect(ex.description, equals('Spanish desc'));

    }, () => mockClient);
  });
}
