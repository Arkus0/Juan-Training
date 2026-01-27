import 'package:drift/drift.dart';
import 'package:collection/collection.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../models/rutina.dart';
import '../models/sesion.dart';
import '../models/ejercicio.dart';
import '../models/serie_log.dart';
import '../models/dia.dart';
import '../models/ejercicio_en_rutina.dart';
import '../models/progression_type.dart';
import 'i_training_repository.dart';

/// Repositorio especializado para operaciones de Sesiones.
/// Extraído de DriftTrainingRepository para mejor separación de responsabilidades.
class SessionRepository {
  final AppDatabase db;

  SessionRepository(this.db);

  // --- Mappers ---

  /// Mapper interno para sesiones. Convierte rows de BD a modelo Sesion.
  Sesion _mapSesion(Session sessionRow, List<SessionExercise> sessionExercises,
      List<WorkoutSet> sets) {
    final setsByExercise = sets.groupListsBy((s) => s.sessionExerciseId);

    // Split exercises into Completed and Target
    final completedRows = sessionExercises.where((e) => !e.isTarget).toList();
    final targetRows = sessionExercises.where((e) => e.isTarget).toList();

    completedRows.sort((a, b) => a.exerciseIndex.compareTo(b.exerciseIndex));
    targetRows.sort((a, b) => a.exerciseIndex.compareTo(b.exerciseIndex));

    List<Ejercicio> mapExercises(List<SessionExercise> rows) {
      return rows.map((row) {
        final exerciseSets = setsByExercise[row.id] ?? [];
        exerciseSets.sort((a, b) => a.setIndex.compareTo(b.setIndex));

        return Ejercicio(
          id: row.id,
          libraryId: row.libraryId ?? 'unknown',
          nombre: row.name,
          musculosPrincipales: row.musclesPrimary,
          musculosSecundarios: row.musclesSecondary,
          series: exerciseSets.length,
          reps: 0,
          peso: 0,
          notas: row.notes,
          logs: exerciseSets
              .map((s) => SerieLog(
                    id: s.id,
                    peso: s.weight,
                    reps: s.reps,
                    completed: s.completed,
                    rpe: s.rpe,
                    notas: s.notes,
                    restSeconds: s.restSeconds,
                    isFailure: s.isFailure,
                    isDropset: s.isDropset,
                    isWarmup: s.isWarmup,
                  ))
              .toList(),
        );
      }).toList();
    }

    return Sesion(
      id: sessionRow.id,
      rutinaId: sessionRow.routineId ?? '',
      dayName: sessionRow.dayName,
      dayIndex: sessionRow.dayIndex,
      fecha: sessionRow.startTime,
      durationSeconds: sessionRow.durationSeconds,
      isBadDay: sessionRow.isBadDay,
      ejerciciosCompletados: mapExercises(completedRows),
      ejerciciosObjetivo: mapExercises(targetRows),
    );
  }

  /// Mapper interno para rutinas (usado solo en getActiveSession para reconstruir contexto).
  Rutina _mapRutina(
      Routine row, List<RoutineDay> days, List<RoutineExercise> exercises) {
    final exercisesByDay = exercises.groupListsBy((e) => e.dayId);

    final dias = days.map((dayRow) {
      final dayExercises = exercisesByDay[dayRow.id] ?? [];
      dayExercises.sort((a, b) => a.exerciseIndex.compareTo(b.exerciseIndex));

      return Dia(
        id: dayRow.id,
        nombre: dayRow.name,
        progressionType: dayRow.progressionType,
        ejercicios: dayExercises
            .map((e) => EjercicioEnRutina(
                  instanceId: e.id,
                  id: e.libraryId,
                  nombre: e.name,
                  descripcion: e.description,
                  musculosPrincipales: e.musclesPrimary,
                  musculosSecundarios: e.musclesSecondary,
                  equipo: e.equipment,
                  localImagePath: e.localImagePath,
                  series: e.series,
                  repsRange: e.repsRange,
                  descansoSugerido: e.suggestedRestSeconds != null
                      ? Duration(seconds: e.suggestedRestSeconds!)
                      : null,
                  notas: e.notes,
                  supersetId: e.supersetId,
                  progressionType: ProgressionType.fromString(e.progressionType),
                  weightIncrement: e.weightIncrement,
                  targetRpe: e.targetRpe,
                ))
            .toList(),
      );
    }).toList();

    // Sort days (con manejo de inconsistencias de BD)
    dias.sort((a, b) {
      final dayA = days.firstWhereOrNull((d) => d.id == a.id);
      final dayB = days.firstWhereOrNull((d) => d.id == b.id);
      if (dayA == null || dayB == null) return 0;
      return dayA.dayIndex.compareTo(dayB.dayIndex);
    });

    return Rutina(
      id: row.id,
      nombre: row.name,
      dias: dias,
      creada: row.createdAt,
    );
  }

  // --- Session CRUD ---

  Stream<List<Sesion>> watchSesionesHistory({int limit = 50}) {
    return ((db.select(db.sessions)
          ..where((s) => s.completedAt.isNotNull())
          ..limit(limit))
        .join([
      leftOuterJoin(db.sessionExercises,
          db.sessionExercises.sessionId.equalsExp(db.sessions.id)),
      leftOuterJoin(db.workoutSets,
          db.workoutSets.sessionExerciseId.equalsExp(db.sessionExercises.id)),
    ]))
        .watch()
        .map((rows) {
      final sessions = <String, Session>{};
      final exercises = <String, SessionExercise>{};
      final sets = <String, WorkoutSet>{};

      for (final row in rows) {
        final s = row.readTable(db.sessions);
        sessions.putIfAbsent(s.id, () => s);

        final e = row.readTableOrNull(db.sessionExercises);
        if (e != null) {
          exercises.putIfAbsent(e.id, () => e);
        }

        final st = row.readTableOrNull(db.workoutSets);
        if (st != null) {
          sets.putIfAbsent(st.id, () => st);
        }
      }

      final result = sessions.values.map((s) {
        final sExercises =
            exercises.values.where((e) => e.sessionId == s.id).toList();
        final sExerciseIds = sExercises.map((e) => e.id).toSet();
        final sSets = sets.values
            .where((st) => sExerciseIds.contains(st.sessionExerciseId))
            .toList();

        return _mapSesion(s, sExercises, sSets);
      }).toList();

      result.sort((a, b) => b.fecha.compareTo(a.fecha));
      return result;
    });
  }

  Future<void> saveSesion(Sesion sesion) async {
    await db.transaction(() async {
      await _saveSessionInternal(sesion, isCompleted: true);
    });
  }

  Future<void> _saveSessionInternal(Sesion sesion,
      {required bool isCompleted}) async {
    // 1. Upsert Session
    await db.into(db.sessions).insertOnConflictUpdate(SessionsCompanion.insert(
          id: sesion.id,
          routineId: Value(sesion.rutinaId),
          dayName: Value(sesion.dayName),
          dayIndex: Value(sesion.dayIndex),
          startTime: sesion.fecha,
          durationSeconds: Value(sesion.durationSeconds),
          isBadDay: Value(sesion.isBadDay),
          completedAt: isCompleted
              ? Value(sesion.fecha
                  .add(Duration(seconds: sesion.durationSeconds ?? 0)))
              : const Value(null),
        ));

    // 2. Track what we are saving to handle deletions
    final visitedExerciseIds = <String>{};
    final visitedSetIds = <String>{};

    // Helper to avoid repeatedly appending the "_target" suffix when IDs already contain it
    String stripTargetSuffix(String id) {
      const suffix = '_target';
      if (id.endsWith(suffix)) {
        return id.substring(0, id.length - suffix.length);
      }
      return id;
    }

    Future<void> processExercises(List<Ejercicio> list, bool isTarget) async {
      for (var i = 0; i < list.length; i++) {
        final ex = list[i];
        // Normalize base ID to strip any existing suffix before applying target marker
        final baseExId = stripTargetSuffix(ex.id);
        final rowId = isTarget ? '${baseExId}_target' : baseExId;
        visitedExerciseIds.add(rowId);

        await db.into(db.sessionExercises).insertOnConflictUpdate(
              SessionExercisesCompanion.insert(
                id: rowId,
                sessionId: sesion.id,
                libraryId: Value(ex.libraryId),
                name: ex.nombre,
                musclesPrimary: ex.musculosPrincipales,
                musclesSecondary: ex.musculosSecundarios,
                notes: Value(ex.notas),
                exerciseIndex: i,
                isTarget: Value(isTarget),
              ),
            );

        for (var j = 0; j < ex.logs.length; j++) {
          final log = ex.logs[j];
          // Normalize set IDs as well to prevent repeated suffix growth
          final baseSetId = stripTargetSuffix(log.id);
          final setId = isTarget ? '${baseSetId}_target' : baseSetId;
          visitedSetIds.add(setId);

          await db.into(db.workoutSets).insertOnConflictUpdate(
                WorkoutSetsCompanion.insert(
                  id: setId,
                  sessionExerciseId: rowId,
                  setIndex: j,
                  weight: log.peso,
                  reps: log.reps,
                  completed: Value(log.completed),
                  rpe: Value(log.rpe),
                  notes: Value(log.notas),
                  restSeconds: Value(log.restSeconds),
                  isFailure: Value(log.isFailure),
                  isDropset: const Value.absent(),
                  isWarmup: Value(log.isWarmup),
                ),
              );
        }
      }
    }

    await processExercises(sesion.ejerciciosCompletados, false);
    await processExercises(sesion.ejerciciosObjetivo, true);

    // 3. Clean up orphans
    await (db.delete(db.sessionExercises)
          ..where((e) =>
              e.sessionId.equals(sesion.id) &
              e.id.isNotIn(visitedExerciseIds)))
        .go();

    if (visitedExerciseIds.isNotEmpty) {
      await (db.delete(db.workoutSets)
            ..where((s) =>
                s.sessionExerciseId.isIn(visitedExerciseIds) &
                s.id.isNotIn(visitedSetIds)))
          .go();
    }
  }

  Future<List<Sesion>> getHistoryForExercise(String exerciseName) async {
    // 1. Get top 5 most recent sessions containing this exercise
    final distinctSessions =
        await (db.select(db.sessions, distinct: true).join([
      innerJoin(db.sessionExercises,
          db.sessionExercises.sessionId.equalsExp(db.sessions.id))
    ])
              ..where(db.sessionExercises.name.equals(exerciseName) &
                  db.sessionExercises.isTarget.equals(false))
              ..orderBy([OrderingTerm.desc(db.sessions.startTime)])
              ..limit(5))
            .map((r) => r.readTable(db.sessions))
            .get();

    if (distinctSessions.isEmpty) return [];

    final sessionIds = distinctSessions.map((s) => s.id).toList();

    // 2. Fetch only the relevant exercises for these sessions
    final relevantExercises = await (db.select(db.sessionExercises)
          ..where(
              (e) => e.sessionId.isIn(sessionIds) & e.name.equals(exerciseName)))
        .get();

    final relevantExerciseIds = relevantExercises.map((e) => e.id).toList();

    // 3. Fetch sets for these exercises
    final relevantSets = await (db.select(db.workoutSets)
          ..where((s) => s.sessionExerciseId.isIn(relevantExerciseIds)))
        .get();

    // 4. Map to Sesion objects
    final result = distinctSessions.map((s) {
      final sExercises =
          relevantExercises.where((e) => e.sessionId == s.id).toList();
      final sSets = relevantSets
          .where((st) => sExercises.any((e) => e.id == st.sessionExerciseId))
          .toList();

      return _mapSesion(s, sExercises, sSets);
    }).toList();

    result.sort((a, b) => b.fecha.compareTo(a.fecha));

    return result;
  }

  Future<List<Sesion>> getExpandedHistoryForExercise(String exerciseName,
      {int limit = 4}) async {
    // 1. Get most recent sessions containing this exercise
    final distinctSessions =
        await (db.select(db.sessions, distinct: true).join([
      innerJoin(db.sessionExercises,
          db.sessionExercises.sessionId.equalsExp(db.sessions.id))
    ])
              ..where(db.sessionExercises.name.equals(exerciseName) &
                  db.sessionExercises.isTarget.equals(false) &
                  db.sessions.completedAt.isNotNull())
              ..orderBy([OrderingTerm.desc(db.sessions.startTime)])
              ..limit(limit))
            .map((r) => r.readTable(db.sessions))
            .get();

    if (distinctSessions.isEmpty) return [];

    final sessionIds = distinctSessions.map((s) => s.id).toList();

    // 2. Fetch exercises for these sessions
    final relevantExercises = await (db.select(db.sessionExercises)
          ..where(
              (e) => e.sessionId.isIn(sessionIds) & e.name.equals(exerciseName)))
        .get();

    final relevantExerciseIds = relevantExercises.map((e) => e.id).toList();

    // 3. Fetch sets
    final relevantSets = await (db.select(db.workoutSets)
          ..where((s) => s.sessionExerciseId.isIn(relevantExerciseIds)))
        .get();

    // 4. Map to Sesion objects
    final result = distinctSessions.map((s) {
      final sExercises =
          relevantExercises.where((e) => e.sessionId == s.id).toList();
      final sSets = relevantSets
          .where((st) => sExercises.any((e) => e.id == st.sessionExerciseId))
          .toList();

      return _mapSesion(s, sExercises, sSets);
    }).toList();

    result.sort((a, b) => b.fecha.compareTo(a.fecha));

    return result;
  }

  // --- Active Session ---

  Future<void> saveActiveSession(ActiveSessionData data) async {
    final session = Sesion(
      id: 'active_session',
      rutinaId: data.activeRutina?.id ?? '',
      fecha: data.startTime ?? DateTime.now(),
      durationSeconds: 0,
      ejerciciosCompletados: data.exercises,
      ejerciciosObjetivo: data.targets,
    );

    final active = await (db.select(db.sessions)
          ..where((s) => s.completedAt.isNull()))
        .getSingleOrNull();
    final idToUse = active?.id ?? const Uuid().v4();

    final sesionToSave = Sesion(
      id: idToUse,
      rutinaId: session.rutinaId,
      fecha: session.fecha,
      durationSeconds: session.durationSeconds,
      ejerciciosCompletados: session.ejerciciosCompletados,
      ejerciciosObjetivo: session.ejerciciosObjetivo,
    );

    await db.transaction(() async {
      await _saveSessionInternal(sesionToSave, isCompleted: false);
    });
  }

  Future<ActiveSessionData?> getActiveSession() async {
    final sessionRow = await (db.select(db.sessions)
          ..where((s) => s.completedAt.isNull()))
        .getSingleOrNull();
    if (sessionRow == null) return null;

    final sessionExercises = await (db.select(db.sessionExercises)
          ..where((e) => e.sessionId.equals(sessionRow.id)))
        .get();
    final sessionExerciseIds = sessionExercises.map((e) => e.id).toList();

    final sets = await (db.select(db.workoutSets)
          ..where((s) => s.sessionExerciseId.isIn(sessionExerciseIds)))
        .get();

    final tempSession = _mapSesion(sessionRow, sessionExercises, sets);

    Rutina? activeRutina;
    if (tempSession.rutinaId.isNotEmpty) {
      final rRow = await (db.select(db.routines)
            ..where((r) => r.id.equals(tempSession.rutinaId)))
          .getSingleOrNull();
      if (rRow != null) {
        final days = await (db.select(db.routineDays)
              ..where((d) => d.routineId.equals(rRow.id)))
            .get();
        final dIds = days.map((d) => d.id).toList();
        final exs = await (db.select(db.routineExercises)
              ..where((e) => e.dayId.isIn(dIds)))
            .get();
        activeRutina = _mapRutina(rRow, days, exs);
      }
    }

    // Reconstruct history map for each exercise to preserve 'ghost text' on restore
    final Map<String, List<SerieLog>> historyMap = {};
    for (final ex in tempSession.ejerciciosCompletados) {
      final historyList = await getHistoryForExercise(ex.nombre);
      if (historyList.isNotEmpty) {
        final lastSession = historyList.first;
        final match = lastSession.ejerciciosCompletados
            .firstWhereOrNull((e) => e.nombre == ex.nombre);
        if (match != null) {
          historyMap[ex.historyKey] = match.logs;
        }
      }
    }

    return ActiveSessionData(
      activeRutina: activeRutina,
      exercises: tempSession.ejerciciosCompletados,
      targets: tempSession.ejerciciosObjetivo,
      startTime: tempSession.fecha,
      defaultRestSeconds: 60,
      history: historyMap,
    );
  }

  Stream<ActiveSessionData?> watchActiveSession() {
    return (db.select(db.sessions)..where((s) => s.completedAt.isNull()))
        .watchSingleOrNull()
        .asyncMap((sessionRow) async {
      if (sessionRow == null) return null;
      return await getActiveSession();
    });
  }

  Future<void> clearActiveSession() async {
    await (db.delete(db.sessions)..where((s) => s.completedAt.isNull())).go();
  }

  /// FIX: Atomiza guardar sesión completada + limpiar sesión activa
  /// Esto evita estado inconsistente si hay un crash entre las dos operaciones.
  Future<void> finishAndClearSession(Sesion sesion) async {
    await db.transaction(() async {
      await _saveSessionInternal(sesion, isCompleted: true);
      await (db.delete(db.sessions)..where((s) => s.completedAt.isNull())).go();
    });
  }

  // --- Notes ---

  Future<String> getNote(String exerciseName) async {
    final row = await (db.select(db.exerciseNotes)
          ..where((n) => n.exerciseName.equals(exerciseName)))
        .getSingleOrNull();
    return row?.note ?? '';
  }

  Future<void> saveNote(String exerciseName, String note) async {
    await db.into(db.exerciseNotes).insertOnConflictUpdate(
        ExerciseNotesCompanion.insert(
      exerciseName: exerciseName,
      note: note,
    ));
  }
}
