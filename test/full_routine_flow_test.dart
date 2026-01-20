import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:juan_training/main.dart'; // Adjust path if needed, usually 'package:project_name/main.dart'
import 'package:juan_training/models/rutina.dart';
import 'package:juan_training/models/dia.dart';
import 'package:juan_training/models/ejercicio_en_rutina.dart';
import 'package:juan_training/models/ejercicio.dart';
import 'package:juan_training/models/serie_log.dart';
import 'package:juan_training/models/sesion.dart';
import 'package:juan_training/models/library_exercise.dart';

// Import necessary files to ensure adapters are registered
// Actually main.dart registers them, but we might need to do it manually in test if we don't call main()
// We will pump JuanTrainingApp which doesn't call main(). main() calls main().

void main() {
  setUpAll(() async {
    // We need to initialize Hive for tests.
    // In a widget test, we can use a temporary directory.
    // Note: path_provider might mock differently in tests.
    // For unit tests usually we use Directory.systemTemp.

    final tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);

    // Register Adapters
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(EjercicioAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(RutinaAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(SesionAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SerieLogAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(DiaAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(EjercicioEnRutinaAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(LibraryExerciseAdapter());
  });

  setUp(() async {
    // Open Boxes
    await Hive.openBox('settings');
    await Hive.openBox<Rutina>('rutinas');
    await Hive.openBox<Sesion>('sesiones');
    final libBox = await Hive.openBox<LibraryExercise>('library_exercises');

    // Clear boxes to ensure clean state
    await Hive.box('settings').clear();
    await Hive.box<Rutina>('rutinas').clear();
    await Hive.box<Sesion>('sesiones').clear();
    await libBox.clear();

    // Populate Library with Dummy Data
    await libBox.add(LibraryExercise(
      id: 1,
      uuid: 'lib_ex_1',
      name: 'Press de Banca',
      muscles: ['Pecho'],
      secondaryMuscles: ['Tríceps'],
      equipment: 'Barra',
      description: 'Push hard',
      category: 1,
      language: 2,
    ));
    await libBox.add(LibraryExercise(
      id: 2,
      uuid: 'lib_ex_2',
      name: 'Sentadilla',
      muscles: ['Piernas'],
      secondaryMuscles: ['Glúteos'],
      equipment: 'Barra',
      description: 'Leg day',
      category: 1,
      language: 2,
    ));
  });

  tearDownAll(() async {
     // Clean up if needed
     await Hive.deleteFromDisk();
  });

  testWidgets('Full Flow: Create 5-Day Routine and Start Training', (WidgetTester tester) async {
    // Set screen size to avoid overflow issues in test
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(const ProviderScope(child: JuanTrainingApp()));
    await tester.pumpAndSettle();

    // 1. Verify Home Screen (Empty Routines)
    expect(find.text('MIS RUTINAS'), findsOneWidget);
    // Depending on logic, it might show "NO HAY RUTINAS"
    expect(find.text('NO HAY RUTINAS'), findsOneWidget);

    // 2. Tap "NUEVA RUTINA"
    await tester.tap(find.text('NUEVA RUTINA'));
    await tester.pumpAndSettle();

    // Verify Create Screen
    expect(find.text('CREA TU RUTINA'), findsOneWidget);

    // 3. Add 5 Days
    // Initially empty?
    expect(find.text('AÑADE TU PRIMER DÍA'), findsOneWidget);

    final addDayFab = find.byTooltip('Add').first; // Or find by text "AÑADIR DÍA" inside FAB?
    // The code uses label: Text('AÑADIR DÍA') in FAB.
    final addDayBtn = find.text('AÑADIR DÍA');

    // Day 1
    await tester.tap(addDayBtn);
    await tester.pumpAndSettle();
    expect(find.text('Día 1'), findsOneWidget);

    // Day 2
    await tester.tap(addDayBtn);
    await tester.pumpAndSettle();

    // Day 3
    await tester.tap(addDayBtn);
    await tester.pumpAndSettle();

    // Day 4
    await tester.tap(addDayBtn);
    await tester.pumpAndSettle();

    // Day 5
    await tester.tap(addDayBtn);
    await tester.pumpAndSettle();

    // Scroll to see Day 5 if needed (it's in SingleChildScrollView)
    await tester.scrollUntilVisible(find.text('Día 5'), 500);
    expect(find.text('Día 5'), findsOneWidget);

    // 4. Add Exercises to Day 1
    // Need to find "AÑADIR EJERCICIO" for Day 1.
    // DayExpansionTile collapses/expands. Day 1 should be expanded by default?
    // Code: _isExpanded = true; init state.

    final addExBtn = find.text('AÑADIR EJERCICIO').first;
    await tester.ensureVisible(addExBtn);
    await tester.tap(addExBtn);
    await tester.pumpAndSettle(); // Sheet opens

    // Verify BottomSheet content (Library)
    expect(find.text('Press de Banca'), findsOneWidget);
    expect(find.text('Sentadilla'), findsOneWidget);

    // Select Press de Banca
    await tester.tap(find.text('Press de Banca'));
    await tester.pumpAndSettle();
    // Sheet might stay open or close? Code: "Don't pop, allow multiple adds? ... Standard is stay open".
    // The code I read says: `onAdd: (LibraryExercise ex) { ... }` inside `BibliotecaBottomSheet`.
    // It does NOT contain `Navigator.pop`.

    // Close sheet manually (tap outside or close button if exists)
    // Assuming we can tap outside.
    await tester.tapAt(const Offset(10, 10)); // Top left outside sheet?
    await tester.pumpAndSettle();

    // Verify Exercise added to Day 1
    expect(find.text('Press de Banca'), findsOneWidget);

    // 5. Name Routine
    final nameField = find.widgetWithText(TextField, 'Nombre que motive miedo'); // Hint text
    await tester.enterText(nameField, 'Spartan 5');
    await tester.pumpAndSettle();

    // 6. Save Routine
    await tester.tap(find.text('GUARDAR RUTINA'));
    await tester.pumpAndSettle();

    // Verify Success Snackbar/Flash (might need to wait)
    // Then it pops back to RutinasScreen
    await tester.pumpAndSettle(const Duration(seconds: 2)); // Wait for flash/animation

    expect(find.text('MIS RUTINAS'), findsOneWidget);
    expect(find.text('SPARTAN 5'), findsOneWidget);
    expect(find.text('5 DÍAS'), findsOneWidget);

    // 7. Go to Train Tab (Index 1)
    await tester.tap(find.byIcon(Icons.fitness_center).last); // Icon for Train tab?
    // BottomNavBar: Rutinas(0), Entrenar(1), Historial(2).
    // Labels? Usually BottomNavigationBarItem has labels.
    // I don't see labels in MainScreen code provided (I didn't read it fully but assuming).
    // Let's rely on finding by Icon. Icons.fitness_center might be used in multiple places.
    // Tab 1 usually "Entrenar".
    // Let's try finding Text 'Entrenar' in BottomNavBar
    await tester.tap(find.text('ENTRENAR'));
    await tester.pumpAndSettle();

    // Verify Train Selection Screen
    expect(find.text('SELECCIONAR ENTRENO'), findsOneWidget);
    expect(find.text('SPARTAN 5'), findsOneWidget);

    // 8. Tap Routine to Train
    await tester.tap(find.text('SPARTAN 5'));
    await tester.pumpAndSettle();

    // 9. Select Day Dialog
    expect(find.text('ELIGE DÍA'), findsOneWidget);
    expect(find.text('Día 1'), findsOneWidget);
    expect(find.text('Día 5'), findsOneWidget);

    // 10. Select Day 1
    await tester.tap(find.text('Día 1'));
    await tester.pumpAndSettle();

    // 11. Verify Training Session Screen
    // Title should be "SPARTAN 5" (or Entrenando)
    expect(find.text('SPARTAN 5'), findsOneWidget);

    // Verify Exercise is present
    expect(find.text('PRESS DE BANCA'), findsOneWidget); // Uppercase in UI

    // Verify Sets (Default 3)
    expect(find.text('1'), findsNWidgets(3)); // 3 sets numbered 1? No, 1, 2, 3.
    // But circle avatar has text '1', '2', '3'.
    // Just find 'KG' and 'REPS' headers
    expect(find.text('KG'), findsWidgets);
    expect(find.text('REPS'), findsWidgets);

  });
}
