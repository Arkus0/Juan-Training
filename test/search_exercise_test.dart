import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/screens/search_exercise_screen.dart';
import 'package:juan_training/services/exercise_library_service.dart';
import 'package:juan_training/models/library_exercise.dart';

void main() {
  testWidgets('SearchExerciseScreen filters exercises correctly', (WidgetTester tester) async {
    // 1. Setup data
    final exercises = [
      LibraryExercise(
        id: 1,
        name: 'Press de Banca',
        muscleGroup: 'Pecho',
        equipment: 'Barra',
        description: 'Desc',
        muscles: [],
        secondaryMuscles: [],
      ),
      LibraryExercise(
        id: 2,
        name: 'Sentadilla',
        muscleGroup: 'Piernas',
        equipment: 'Barra',
        description: 'Desc',
        muscles: [],
        secondaryMuscles: [],
      ),
    ];

    ExerciseLibraryService.instance.exercisesNotifier.value = exercises;

    // 2. Pump Widget
    await tester.pumpWidget(const MaterialApp(
      home: SearchExerciseScreen(),
    ));

    // Verify initial state (all exercises shown)
    // Note: The UI uppercases the names
    expect(find.text('PRESS DE BANCA'), findsOneWidget);
    expect(find.text('SENTADILLA'), findsOneWidget);

    // 3. Search
    await tester.enterText(find.byType(TextField), 'Press');

    // Pump to process input and update UI
    // We expect the filtering to happen.
    await tester.pumpAndSettle();

    // Verify filtered state
    expect(find.text('PRESS DE BANCA'), findsOneWidget);
    expect(find.text('SENTADILLA'), findsNothing);
  });
}
