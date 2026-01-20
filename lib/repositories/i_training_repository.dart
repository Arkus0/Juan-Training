import '../models/rutina.dart';
import '../models/sesion.dart';
import '../models/ejercicio.dart';
import '../models/serie_log.dart';

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
}

abstract class ITrainingRepository {
  // Rutinas
  Stream<List<Rutina>> watchRutinas();
  Future<void> saveRutina(Rutina rutina);
  Future<void> deleteRutina(String id);

  // Sesiones
  Stream<List<Sesion>> watchSesionesHistory();
  Future<void> saveSesion(Sesion sesion);
  List<Sesion> getHistoryForExercise(String exerciseName);

  // Active Session
  Future<void> saveActiveSession(ActiveSessionData data);
  Future<ActiveSessionData?> getActiveSession();
  Stream<ActiveSessionData?> watchActiveSession();
  Future<void> clearActiveSession();

  // Notes
  String getNote(String exerciseName);
  Future<void> saveNote(String exerciseName, String note);
}
