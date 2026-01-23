import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/widgets/session/exercise_card.dart';
import 'package:juan_training/models/ejercicio.dart';
import 'package:juan_training/models/serie_log.dart';
import 'package:juan_training/models/progression_engine_models.dart';

void main() {
  testWidgets('Mismo objetivo hoy aparece sólo una vez cuando decision es maintain', (WidgetTester tester) async {
    final ejercicio = Ejercicio(
      id: 'e1',
      libraryId: 'lib',
      nombre: 'Aperturas en máquina',
      series: 3,
      reps: 8,
      peso: 80.0,
      logs: [
        SerieLog(peso: 120.5, reps: 8, completed: true),
        SerieLog(peso: 80.0, reps: 8, completed: false),
        SerieLog(peso: 0.0, reps: 0, completed: false),
      ],
      descansoSugeridoSeconds: 90,
    );

    final decision = ProgressionDecision.maintain(weight: 80.0, reps: 8);

    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: ExerciseCard(
          exerciseIndex: 0,
          exercise: ejercicio,
          historyLogs: null,
          showAdvanced: false,
          progressionDecision: decision,
          onShowOptions: () {},
          onUpdateWeight: (int i, String s) {},
          onUpdateReps: (int i, String s) {},
          onUpdateCompleted: (int i, bool? b) {},
          onPlateCalc: (int i, double d) {},
          onSetLongPress: (int i) {},
        ),
      ),
    ));

    await tester.pumpAndSettle();

    final matches = find.text('Mismo objetivo hoy');
    expect(matches, findsOneWidget);
  });

  testWidgets('Botón aparece y se muestra mensaje de subida cuando decision es increaseWeight', (WidgetTester tester) async {
    final ejercicio = Ejercicio(
      id: 'e2',
      libraryId: 'lib',
      nombre: 'Press banca',
      series: 3,
      reps: 5,
      peso: 80.0,
      logs: [
        SerieLog(peso: 80.0, reps: 5, completed: true),
        SerieLog(peso: 80.0, reps: 5, completed: true),
        SerieLog(peso: 80.0, reps: 5, completed: true),
      ],
      descansoSugeridoSeconds: 90,
    );

    final decision = ProgressionDecision(
      action: ProgressionAction.increaseWeight,
      suggestedWeight: 82.5,
      suggestedReps: 5,
      reason: 'Clear improvement',
      userMessage: 'Si éxito: 82.5kg',
      isImprovement: true,
    );

    await tester.pumpWidget(MaterialApp(
      home: Material(
        child: ExerciseCard(
          exerciseIndex: 1,
          exercise: ejercicio,
          historyLogs: null,
          showAdvanced: false,
          progressionDecision: decision,
          onShowOptions: () {},
          onUpdateWeight: (int i, String s) {},
          onUpdateReps: (int i, String s) {},
          onUpdateCompleted: (int i, bool? b) {},
          onPlateCalc: (int i, double d) {},
          onSetLongPress: (int i) {},
        ),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Mismo objetivo hoy'), findsOneWidget);
    expect(find.text('Si éxito: 82.5kg'), findsOneWidget);
  });
}
