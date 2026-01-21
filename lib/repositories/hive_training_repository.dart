import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import '../models/rutina.dart';
import '../models/sesion.dart';
import '../models/ejercicio.dart';
import '../models/serie_log.dart';
import 'i_training_repository.dart';

class HiveTrainingRepository implements ITrainingRepository {
  final Box<Rutina> _rutinasBox;
  final Box<Sesion> _sesionesBox;
  final Box _activeSessionBox;
  final Box _exerciseNotesBox;
  final Logger _logger = Logger();

  HiveTrainingRepository({
    required Box<Rutina> rutinasBox,
    required Box<Sesion> sesionesBox,
    required Box activeSessionBox,
    required Box exerciseNotesBox,
  })  : _rutinasBox = rutinasBox,
        _sesionesBox = sesionesBox,
        _activeSessionBox = activeSessionBox,
        _exerciseNotesBox = exerciseNotesBox;

  // --- Rutinas ---

  @override
  Stream<List<Rutina>> watchRutinas() async* {
    yield _rutinasBox.values.toList();
    yield* _rutinasBox.watch().map((_) {
      final list = _rutinasBox.values.toList();
      // Optional: Sort if needed here, or let UI/Provider sort.
      // RutinasScreen sorts by date descending.
      list.sort((a, b) => b.creada.compareTo(a.creada));
      return list;
    });
  }

  @override
  Future<void> saveRutina(Rutina rutina) async {
    // Upsert logic based on ID
    // Since ID is in the object, we can iterate to find key or just add if not found.
    // Hive keys might not match ID. Best practice is to use ID as key if possible,
    // but here we just iterate.

    // Check if exists
    dynamic keyToUpdate;
    for (var key in _rutinasBox.keys) {
      final r = _rutinasBox.get(key);
      if (r?.id == rutina.id) {
        keyToUpdate = key;
        break;
      }
    }

    if (keyToUpdate != null) {
      await _rutinasBox.put(keyToUpdate, rutina);
    } else {
      await _rutinasBox.add(rutina);
    }
  }

  @override
  Future<void> deleteRutina(String id) async {
    dynamic keyToDelete;
    for (var key in _rutinasBox.keys) {
      final r = _rutinasBox.get(key);
      if (r?.id == id) {
        keyToDelete = key;
        break;
      }
    }
    if (keyToDelete != null) {
      await _rutinasBox.delete(keyToDelete);
    }
  }

  // --- Sesiones ---

  @override
  Stream<List<Sesion>> watchSesionesHistory() async* {
    List<Sesion> getSorted() {
      final list = _sesionesBox.values.toList();
      list.sort((a, b) => b.fecha.compareTo(a.fecha));
      return list;
    }

    yield getSorted();
    yield* _sesionesBox.watch().map((_) => getSorted());
  }

  @override
  Future<void> saveSesion(Sesion sesion) async {
    await _sesionesBox.add(sesion);
  }

  @override
  Future<List<Sesion>> getHistoryForExercise(String exerciseName) async {
    return _sesionesBox.values
        .where((s) => s.ejerciciosCompletados.any((e) => e.nombre == exerciseName))
        .toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  // --- Active Session ---

  @override
  Future<void> saveActiveSession(ActiveSessionData data) async {
    await _activeSessionBox.put('activeRutina', data.activeRutina);
    await _activeSessionBox.put('exercises', data.exercises);
    await _activeSessionBox.put('targets', data.targets);
    await _activeSessionBox.put('startTime', data.startTime);
    await _activeSessionBox.put('defaultRestSeconds', data.defaultRestSeconds);
    await _activeSessionBox.put('history', data.history);
  }

  @override
  Stream<ActiveSessionData?> watchActiveSession() async* {
    yield await getActiveSession();
    yield* _activeSessionBox.watch().asyncMap((_) => getActiveSession());
  }

  @override
  Future<ActiveSessionData?> getActiveSession() async {
    try {
      final activeRutina = _activeSessionBox.get('activeRutina') as Rutina?;
      final exercisesList = _activeSessionBox.get('exercises') as List?;
      final targetsList = _activeSessionBox.get('targets') as List?;
      final startTime = _activeSessionBox.get('startTime') as DateTime?;
      final defaultRestSeconds = _activeSessionBox.get('defaultRestSeconds') as int? ?? 90;
      final historyMapRaw = _activeSessionBox.get('history') as Map?;

      if (activeRutina != null && exercisesList != null) {
        final exercises = exercisesList.cast<Ejercicio>();
        final targets = targetsList?.cast<Ejercicio>() ?? [];

        final Map<String, List<SerieLog>> history = {};
        if (historyMapRaw != null) {
          historyMapRaw.forEach((key, value) {
            if (key is String && value is List) {
              history[key] = value.cast<SerieLog>();
            }
          });
        }

        return ActiveSessionData(
          activeRutina: activeRutina,
          exercises: exercises,
          targets: targets,
          startTime: startTime,
          defaultRestSeconds: defaultRestSeconds,
          history: history,
        );
      }
    } catch (e) {
      _logger.e('Error restoring active session', error: e);
      await clearActiveSession();
    }
    return null;
  }

  @override
  Future<void> clearActiveSession() async {
    await _activeSessionBox.clear();
  }

  // --- Notes ---

  @override
  Future<String> getNote(String exerciseName) async {
    return _exerciseNotesBox.get(exerciseName, defaultValue: '') as String;
  }

  @override
  Future<void> saveNote(String exerciseName, String note) async {
    await _exerciseNotesBox.put(exerciseName, note);
  }
}
