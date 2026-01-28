import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/models/rutina.dart';
import 'package:juan_training/providers/training_provider.dart';
import 'package:juan_training/screens/rutinas_screen.dart';

import '../mocks.dart';

void main() {
  testWidgets('RutinasScreen allows deleting a routine with undo',
      (WidgetTester tester) async {
    final mockRepository = MockTrainingRepository();
    final rutina = Rutina(
      id: '1',
      nombre: 'Test Routine',
      dias: [],
      creada: DateTime.now(),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingRepositoryProvider.overrideWithValue(mockRepository),
        ],
        child: const MaterialApp(home: RutinasScreen()),
      ),
    );

    // Initial load
    mockRepository.setRutinas([rutina]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    final container =
        ProviderScope.containerOf(tester.element(find.byType(RutinasScreen)));
    final rutinasAsync = container.read(rutinasStreamProvider);
    expect(rutinasAsync.asData?.value.length, 1);
    final dismissibleFinder = find.byType(Dismissible);
    final routineFinder = dismissibleFinder;
    expect(routineFinder, findsOneWidget);

    // Swipe to dismiss
    await tester.fling(routineFinder, const Offset(-500.0, 0.0), 1000);
    await tester.pumpAndSettle();

    final afterDelete =
        container.read(rutinasStreamProvider).asData?.value.length;
    expect(afterDelete, 0);

    // Verify Undo SnackBar
    expect(find.text('RUTINA ELIMINADA'), findsOneWidget);
    expect(find.text('DESHACER'), findsOneWidget);

    // Tap Undo
    await tester.tap(find.text('DESHACER'));
    await tester.pumpAndSettle();

    final afterUndo =
        container.read(rutinasStreamProvider).asData?.value.length;
    expect(afterUndo, 1);
  });
}
