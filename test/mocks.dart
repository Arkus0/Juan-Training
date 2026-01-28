import 'dart:async';
import 'package:juan_training/models/analysis_models.dart';
import 'package:juan_training/models/rutina.dart';
import 'package:juan_training/models/sesion.dart';
import 'package:juan_training/repositories/i_training_repository.dart';

/// Mock implementation of ITrainingRepository for testing
class MockTrainingRepository implements ITrainingRepository {
  List<Rutina> _rutinas = [];
  List<Sesion> _sesiones = [];
  final Map<String, String> _notes = {};

  final _rutinasController = StreamController<List<Rutina>>.broadcast();

  void dispose() {
    _rutinasController.close();
  }

  // Helper methods for testing
  void setRutinas(List<Rutina> rutinas) {
    _rutinas = List.from(rutinas);
    _rutinasController.add(_rutinas);
  }

  void setSesiones(List<Sesion> sesiones) {
    _sesiones = List.from(sesiones);
  }

  @override
  Stream<List<Rutina>> watchRutinas() {
    return _rutinasStream();
  }

  Stream<List<Rutina>> _rutinasStream() async* {
    yield _rutinas;
    yield* _rutinasController.stream;
  }

  @override
  Future<void> saveRutina(Rutina rutina) async {
    final index = _rutinas.indexWhere((r) => r.id == rutina.id);
    if (index >= 0) {
      _rutinas[index] = rutina;
    } else {
      _rutinas.add(rutina);
    }
    _rutinasController.add(_rutinas);
  }

  @override
  Future<void> deleteRutina(String id) async {
    _rutinas.removeWhere((r) => r.id == id);
    _rutinasController.add(_rutinas);
  }

  @override
  Stream<List<Sesion>> watchSesionesHistory({int limit = 50}) {
    // Ignore the limit in the mock, but accept the parameter to match interface
    return Stream.value(_sesiones);
  }

  @override
  Future<void> saveSesion(Sesion sesion) async {
    _sesiones.add(sesion);
  }

  @override
  Future<List<Sesion>> getHistoryForExercise(String exerciseName) async {
    // Check both completed and target exercises for history matches
    return _sesiones
        .where(
          (s) =>
              s.ejerciciosCompletados.any((e) => e.nombre == exerciseName) ||
              s.ejerciciosObjetivo.any((e) => e.nombre == exerciseName),
        )
        .toList();
  }

  @override
  Future<List<Sesion>> getExpandedHistoryForExercise(String exerciseName,
      {int limit = 4,}) async {
    // Same as getHistoryForExercise but with limit
    final all = await getHistoryForExercise(exerciseName);
    return all.take(limit).toList();
  }

  @override
  Future<void> saveActiveSession(ActiveSessionData data) async {}

  @override
  Future<ActiveSessionData?> getActiveSession() async => null;

  @override
  Stream<ActiveSessionData?> watchActiveSession() {
    return Stream.value(null);
  }

  @override
  Future<void> clearActiveSession() async {}

  @override
  Future<void> finishAndClearSession(Sesion sesion) async {
    // Simulate atomic save + clear: add to history and clear active session
    await saveSesion(sesion);
  }

  @override
  Future<String> getNote(String exerciseName) async {
    return _notes[exerciseName] ?? '';
  }

  @override
  Future<void> saveNote(String exerciseName, String note) async {
    _notes[exerciseName] = note;
  }

  // Analysis methods (mock implementations)
  @override
  Future<Map<DateTime, DailyActivity>> getYearlyActivityMap(int year) async =>
      {};

  @override
  Future<Map<String, MuscleVolume>> getMuscleVolumePeriod(
          {int days = 30,}) async =>
      {};

  @override
  Future<List<PersonalRecord>> getPersonalRecords(
          {List<String>? exerciseNames,}) async =>
      [];

  @override
  Future<Map<String, DateTime>> getLastTrainedDateByMuscle() async => {};

  @override
  Future<List<StrengthDataPoint>> getStrengthTrend(String exerciseName,
          {int months = 6,}) async =>
      [];

  @override
  Future<StreakData> getStreakData() async => StreakData(
        currentStreak: 0,
        longestStreak: 0,
        lastTrainingDate: _sesiones.isNotEmpty ? _sesiones.last.fecha : null,
      );

  @override
  Future<DailySnapshot?> getDailySnapshot(DateTime date) async => null;

  @override
  Future<List<Sesion>> getSessionsForDate(DateTime date) async => [];

  @override
  Future<List<String>> getExerciseNames() async => [];
}
