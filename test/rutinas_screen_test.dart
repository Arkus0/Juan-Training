import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juan_training/models/rutina.dart';
import 'package:juan_training/models/sesion.dart';
import 'package:juan_training/models/ejercicio.dart';
import 'package:juan_training/models/dia.dart';
import 'package:juan_training/models/ejercicio_en_rutina.dart';
import 'package:juan_training/repositories/i_training_repository.dart';
import 'package:juan_training/providers/training_provider.dart';
import 'package:juan_training/screens/rutinas_screen.dart';

// Reuse MockTrainingRepository
class MockTrainingRepository implements ITrainingRepository {
  List<Rutina> _rutinas = [];
  final _rutinasController = StreamController<List<Rutina>>.broadcast();

  MockTrainingRepository() {
    _rutinasController.add(_rutinas);
  }

  void addRutina(Rutina rutina) {
    _rutinas.add(rutina);
    _rutinasController.add(List.from(_rutinas));
  }

  @override
  Stream<List<Rutina>> watchRutinas() {
    return _rutinasController.stream;
  }

  @override
  Future<void> saveRutina(Rutina rutina) async {
    final index = _rutinas.indexWhere((r) => r.id == rutina.id);
    if (index >= 0) {
      _rutinas[index] = rutina;
    } else {
      _rutinas.add(rutina);
    }
    _rutinasController.add(List.from(_rutinas));
  }

  @override
  Future<void> deleteRutina(String id) async {
    _rutinas.removeWhere((r) => r.id == id);
    _rutinasController.add(List.from(_rutinas));
  }

  // Unused methods for this test
  @override
  Stream<List<Sesion>> watchSesionesHistory() => const Stream.empty();
  @override
  Future<void> saveSesion(Sesion sesion) async {}
  @override
  Future<List<Sesion>> getHistoryForExercise(String exerciseName) async => [];
  @override
  Future<void> saveActiveSession(ActiveSessionData data) async {}
  @override
  Future<ActiveSessionData?> getActiveSession() async => null;
  @override
  Stream<ActiveSessionData?> watchActiveSession() => const Stream.empty();
  @override
  Future<void> clearActiveSession() async {}
  @override
  Future<String> getNote(String exerciseName) async => '';
  @override
  Future<void> saveNote(String exerciseName, String note) async {}

  void dispose() {
    _rutinasController.close();
  }
}

void main() {
  testWidgets('Swipe to delete routine works and shows Undo SnackBar', (WidgetTester tester) async {
    // Setup Mock Repository
    final mockRepo = MockTrainingRepository();

    // Create a dummy routine
    final rutina = Rutina(
      id: '1',
      nombre: 'Test Routine',
      dias: [
        Dia(
          id: 'd1',
          nombre: 'Day 1',
          ejercicios: [],
          progressionType: 'LINEAR',
        )
      ],
      creada: DateTime.now(),
    );
    mockRepo.addRutina(rutina);

    // Build App with Provider Override
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          trainingRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: RutinasScreen(),
        ),
      ),
    );

    // Initial Pump
    await tester.pump();

    // Verify Routine is displayed
    expect(find.text('TEST ROUTINE'), findsOneWidget);

    // Swipe to dismiss
    await tester.drag(find.text('TEST ROUTINE'), const Offset(-500.0, 0.0));
    await tester.pumpAndSettle();

    // Verify Routine is removed from UI
    expect(find.text('TEST ROUTINE'), findsNothing);

    // Verify SnackBar appears
    expect(find.text('RUTINA "TEST ROUTINE" ELIMINADA'), findsOneWidget);
    expect(find.text('DESHACER'), findsOneWidget);

    // Tap Undo
    await tester.tap(find.text('DESHACER'));
    await tester.pumpAndSettle();

    // Verify Routine is restored
    expect(find.text('TEST ROUTINE'), findsOneWidget);

    mockRepo.dispose();
  });
}
