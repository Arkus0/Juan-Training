import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/models/ejercicio.dart';
import 'package:juan_training/models/serie_log.dart';
import 'package:juan_training/widgets/session/exercise_card.dart';

void main() {
  testWidgets('Focused set keys use exercise id to avoid ghost mismatches', (tester) async {
    final exercise = Ejercicio(
      id: 'ex-1',
      libraryId: '1',
      nombre: 'Press banca',
      series: 1,
      reps: 10,
      logs: [
        SerieLog(peso: 0, reps: 0, completed: false),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExerciseCard(
            exerciseIndex: 0,
            exercise: exercise,
            historyLogs: const [],
            showAdvanced: false,
            onShowOptions: () {},
            onUpdateWeight: (_, __) {},
            onUpdateReps: (_, __) {},
            onUpdateCompleted: (_, __) {},
            onPlateCalc: (_, __) {},
            onSetLongPress: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('exex-1_focused_set0')), findsOneWidget);
  });
}
