import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juan_training/screens/rutinas_screen.dart';
import 'package:juan_training/providers/training_provider.dart';
import 'package:juan_training/models/rutina.dart';
import '../mocks.dart';

void main() {
  testWidgets('RutinasScreen allows deleting a routine with undo', (WidgetTester tester) async {
    final mockRepository = MockTrainingRepository();
    final rutina = Rutina(
      id: '1',
      nombre: 'Test Routine',
      dias: [],
      creada: DateTime.now(),
    );
    mockRepository.setRutinas([rutina]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingRepositoryProvider.overrideWithValue(mockRepository),
        ],
        child: const MaterialApp(home: RutinasScreen()),
      ),
    );

    // Initial load
    await tester.pumpAndSettle();
    expect(find.text('TEST ROUTINE'), findsOneWidget);

    // Swipe to dismiss
    await tester.drag(find.text('TEST ROUTINE'), const Offset(-500.0, 0.0));
    await tester.pumpAndSettle();

    // Verify item is removed (visually)
    expect(find.text('TEST ROUTINE'), findsNothing);

    // Verify Undo SnackBar
    expect(find.text('RUTINA ELIMINADA'), findsOneWidget);
    expect(find.text('DESHACER'), findsOneWidget);

    // Tap Undo
    await tester.tap(find.text('DESHACER'));
    await tester.pumpAndSettle();

    // Verify item is back
    expect(find.text('TEST ROUTINE'), findsOneWidget);
  });
}
