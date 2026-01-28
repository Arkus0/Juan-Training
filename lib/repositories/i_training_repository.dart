import '../models/analysis_models.dart';
import '../models/ejercicio.dart';
import '../models/rutina.dart';
import '../models/serie_log.dart';
import '../models/sesion.dart';

class ActiveSessionData {
  final Rutina? activeRutina;
  final List<Ejercicio> exercises;
  final List<Ejercicio> targets;
  final DateTime? startTime;
  final int defaultRestSeconds;
  final Map<String, List<SerieLog>> history;

  ActiveSessionData({
    this.activeRutina,
    required this.exercises,
    required this.targets,
    this.startTime,
    required this.defaultRestSeconds,
    required this.history,
  });

  /// Total sets completed across all exercises in this session
  int get completedSets =>
      history.values.fold(0, (sum, logs) => sum + logs.length);

  /// Total sets planned for this session
  int get totalSets => exercises.fold(0, (sum, ex) => sum + ex.series);
}

abstract class ITrainingRepository {
  // Rutinas
  Stream<List<Rutina>> watchRutinas();
  Future<void> saveRutina(Rutina rutina);
  Future<void> deleteRutina(String id);

  // Sesiones
  Stream<List<Sesion>> watchSesionesHistory({int limit = 50});
  Future<void> saveSesion(Sesion sesion);
  Future<List<Sesion>> getHistoryForExercise(String exerciseName);

  /// Get expanded history for progression engine v2
  /// Returns last N sessions with full exercise data for calculating
  /// consecutive successes/failures
  Future<List<Sesion>> getExpandedHistoryForExercise(String exerciseName,
      {int limit = 4,});

  // Active Session
  Future<void> saveActiveSession(ActiveSessionData data);
  Future<ActiveSessionData?> getActiveSession();
  Stream<ActiveSessionData?> watchActiveSession();
  Future<void> clearActiveSession();

  /// FIX: Atomiza save + clear para evitar estado inconsistente
  /// Guarda la sesión completada y limpia la sesión activa en una sola transacción.
  Future<void> finishAndClearSession(Sesion sesion);

  // Notes
  Future<String> getNote(String exerciseName);
  Future<void> saveNote(String exerciseName, String note);

  // ==========================================================================
  // ANALYSIS METHODS - Centro de Comando Anabólico
  // ==========================================================================

  /// Get yearly activity map for heatmap visualization.
  /// Returns a map of DateTime (date only) to DailyActivity.
  Future<Map<DateTime, DailyActivity>> getYearlyActivityMap(int year);

  /// Get muscle volume for the last N days (default 30)
  /// Used for symmetry radar chart
  Future<Map<String, MuscleVolume>> getMuscleVolumePeriod({int days = 30});

  /// Get personal records for specified exercises (or all if null)
  /// Used for Hall of Fame
  Future<List<PersonalRecord>> getPersonalRecords(
      {List<String>? exerciseNames,});

  /// Get last trained date for each muscle group
  /// Used for recovery monitor
  Future<Map<String, DateTime>> getLastTrainedDateByMuscle();

  /// Get strength trend data for a specific exercise
  /// Returns estimated 1RM over time
  Future<List<StrengthDataPoint>> getStrengthTrend(String exerciseName,
      {int months = 6,});

  /// Get current and longest streak data
  Future<StreakData> getStreakData();

  /// Get daily snapshot for a specific date
  /// Returns null if no session on that date
  Future<DailySnapshot?> getDailySnapshot(DateTime date);

  /// Get list of all sessions for a specific date
  Future<List<Sesion>> getSessionsForDate(DateTime date);

  /// Get unique exercise names from history for dropdown selectors
  Future<List<String>> getExerciseNames();
}
