import '../database/database.dart';
import '../models/rutina.dart';
import '../models/sesion.dart';
import '../models/analysis_models.dart';
import 'i_training_repository.dart';
import 'routine_repository.dart';
import 'session_repository.dart';
import 'analytics_repository.dart';

/// Repositorio principal que implementa ITrainingRepository.
/// Delega operaciones a repositorios especializados para mejor separación de responsabilidades.
///
/// Estructura de delegación:
/// - Rutinas → RoutineRepository
/// - Sesiones → SessionRepository
/// - Analytics → AnalyticsRepository
class DriftTrainingRepository implements ITrainingRepository {
  final AppDatabase db;

  // Repositorios especializados (lazy initialization)
  late final RoutineRepository _routineRepo = RoutineRepository(db);
  late final SessionRepository _sessionRepo = SessionRepository(db);
  late final AnalyticsRepository _analyticsRepo = AnalyticsRepository(db);

  DriftTrainingRepository(this.db);

  // ==========================================================================
  // RUTINAS - Delegado a RoutineRepository
  // ==========================================================================

  @override
  Stream<List<Rutina>> watchRutinas() => _routineRepo.watchRutinas();

  @override
  Future<void> saveRutina(Rutina rutina) => _routineRepo.saveRutina(rutina);

  @override
  Future<void> deleteRutina(String id) => _routineRepo.deleteRutina(id);

  // ==========================================================================
  // SESIONES - Delegado a SessionRepository
  // ==========================================================================

  @override
  Stream<List<Sesion>> watchSesionesHistory({int limit = 50}) =>
      _sessionRepo.watchSesionesHistory(limit: limit);

  @override
  Future<void> saveSesion(Sesion sesion) => _sessionRepo.saveSesion(sesion);

  @override
  Future<List<Sesion>> getHistoryForExercise(String exerciseName) =>
      _sessionRepo.getHistoryForExercise(exerciseName);

  @override
  Future<List<Sesion>> getExpandedHistoryForExercise(String exerciseName,
          {int limit = 4}) =>
      _sessionRepo.getExpandedHistoryForExercise(exerciseName, limit: limit);

  @override
  Future<void> saveActiveSession(ActiveSessionData data) =>
      _sessionRepo.saveActiveSession(data);

  @override
  Future<ActiveSessionData?> getActiveSession() =>
      _sessionRepo.getActiveSession();

  @override
  Stream<ActiveSessionData?> watchActiveSession() =>
      _sessionRepo.watchActiveSession();

  @override
  Future<void> clearActiveSession() => _sessionRepo.clearActiveSession();

  @override
  Future<void> finishAndClearSession(Sesion sesion) =>
      _sessionRepo.finishAndClearSession(sesion);

  @override
  Future<String> getNote(String exerciseName) =>
      _sessionRepo.getNote(exerciseName);

  @override
  Future<void> saveNote(String exerciseName, String note) =>
      _sessionRepo.saveNote(exerciseName, note);

  // ==========================================================================
  // ANALYTICS - Delegado a AnalyticsRepository
  // ==========================================================================

  @override
  Future<Map<DateTime, DailyActivity>> getYearlyActivityMap(int year) =>
      _analyticsRepo.getYearlyActivityMap(year);

  @override
  Future<Map<String, MuscleVolume>> getMuscleVolumePeriod({int days = 30}) =>
      _analyticsRepo.getMuscleVolumePeriod(days: days);

  @override
  Future<List<PersonalRecord>> getPersonalRecords({List<String>? exerciseNames}) =>
      _analyticsRepo.getPersonalRecords(exerciseNames: exerciseNames);

  @override
  Future<Map<String, DateTime>> getLastTrainedDateByMuscle() =>
      _analyticsRepo.getLastTrainedDateByMuscle();

  @override
  Future<List<StrengthDataPoint>> getStrengthTrend(String exerciseName,
          {int months = 6}) =>
      _analyticsRepo.getStrengthTrend(exerciseName, months: months);

  @override
  Future<StreakData> getStreakData() => _analyticsRepo.getStreakData();

  @override
  Future<DailySnapshot?> getDailySnapshot(DateTime date) =>
      _analyticsRepo.getDailySnapshot(date);

  @override
  Future<List<Sesion>> getSessionsForDate(DateTime date) =>
      _analyticsRepo.getSessionsForDate(date);

  @override
  Future<List<String>> getExerciseNames() => _analyticsRepo.getExerciseNames();
}
