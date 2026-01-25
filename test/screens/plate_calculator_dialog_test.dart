import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/screens/plate_calculator_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PlateCalculatorDialog shows semantics for plates', (WidgetTester tester) async {
    // Override settings to ensure stable environment
    // actually default SettingsNotifier behavior with mocked SP is enough

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PlateCalculatorDialog(
              currentWeight: 100.0,
            ),
          ),
        ),
      ),
    );

    // Pump to allow any async init (like loading settings)
    await tester.pumpAndSettle();

    // Verify dialog title is present
    expect(find.text('CALCULADORA DE PLACAS'), findsOneWidget);

    // Initial state: 100kg total. Bar 20kg.
    // (100 - 20) / 2 = 40kg per side.
    // Plates: 20kg, 20kg.

    // Check if the visualization exists (by looking for a specific container or key?
    // The visualization is a container with 'Barra: 20.0kg' text nearby)
    expect(find.textContaining('Barra: 20.0kg'), findsOneWidget);

    // NOW, checks for accessibility semantics.
    // We expect a semantic node describing the plates.
    // 40kg per side -> 20kg, 20kg plates.
    // The label should be something like "Placas por lado: 20kg, 20kg" or similar.
    // For now, let's look for ANY semantic label containing "Placas" or "20kg, 20kg".

    final semanticFinder = find.bySemanticsLabel(RegExp(r'Placas por lado|Barra cargada'));

    // This expects to fail initially
    if (semanticFinder.evaluate().isEmpty) {
        print('TEST FAILURE EXPECTED: No semantics found for plate visualization.');
    } else {
        print('TEST SUCCESS (Unexpected): Semantics found.');
    }

    expect(semanticFinder, findsOneWidget, reason: 'Should have a semantic label describing the plates');
  });
}
