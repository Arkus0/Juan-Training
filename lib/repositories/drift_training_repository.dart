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
import 'i_training_repository.dart';

class DriftTrainingRepository implements ITrainingRepository {
  final AppDatabase db;

  DriftTrainingRepository(this.db);

  // --- Mappers ---

  Rutina _mapRutina(Routine row, List<RoutineDay> days, List<RoutineExercise> exercises) {
    // Map exercises to days
    final exercisesByDay = exercises.groupListsBy((e) => e.dayId);

    final dias = days.map((dayRow) {
      final dayExercises = exercisesByDay[dayRow.id] ?? [];
      // Sort by index
      dayExercises.sort((a, b) => a.exerciseIndex.compareTo(b.exerciseIndex));

      return Dia(
        id: dayRow.id,
        nombre: dayRow.name,
        progressionType: dayRow.progressionType,
        ejercicios: dayExercises.map((e) => EjercicioEnRutina(
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
        )).toList(),
      );
    }).toList();

    // Sort days
    dias.sort((a, b) {
      final dayA = days.firstWhere((d) => d.id == a.id);
      final dayB = days.firstWhere((d) => d.id == b.id);
      return dayA.dayIndex.compareTo(dayB.dayIndex);
    });

    return Rutina(
      id: row.id,
      nombre: row.name,
      dias: dias,
      creada: row.createdAt,
    );
  }

  Sesion _mapSesion(Session sessionRow, List<SessionExercise> sessionExercises, List<Set> sets) {
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
          id: row.libraryId ?? 'unknown', // Fallback
          nombre: row.name,
          series: exerciseSets.length, // Approximate
          reps: 0, // Not stored at exercise level in history, usually
          peso: 0, // Not stored
          notas: row.notes,
          logs: exerciseSets.map((s) => SerieLog(
            peso: s.weight,
            reps: s.reps,
            completed: s.completed,
            rpe: s.rpe,
            notas: s.notes,
            restSeconds: s.restSeconds,
            isFailure: s.isFailure,
            isDropset: s.isDropset,
            isWarmup: s.isWarmup,
          )).toList(),
        );
      }).toList();
    }

    return Sesion(
      id: sessionRow.id,
      rutinaId: sessionRow.routineId ?? '',
      fecha: sessionRow.startTime,
      durationSeconds: sessionRow.durationSeconds,
      ejerciciosCompletados: mapExercises(completedRows),
      ejerciciosObjetivo: mapExercises(targetRows),
    );
  }

  // --- Rutinas ---

  @override
  Stream<List<Rutina>> watchRutinas() {
    final query = db.select(db.routines).join([
      leftOuterJoin(db.routineDays, db.routineDays.routineId.equalsExp(db.routines.id)),
      leftOuterJoin(db.routineExercises, db.routineExercises.dayId.equalsExp(db.routineDays.id)),
    ]);

    return query.watch().map((rows) {
      final routines = <String, Routine>{};
      final days = <String, RoutineDay>{};
      final exercises = <String, RoutineExercise>{};

      for (final row in rows) {
        final routine = row.readTable(db.routines);
        routines.putIfAbsent(routine.id, () => routine);

        final day = row.readTableOrNull(db.routineDays);
        if (day != null) {
          days.putIfAbsent(day.id, () => day);
        }

        final exercise = row.readTableOrNull(db.routineExercises);
        if (exercise != null) {
          exercises.putIfAbsent(exercise.id, () => exercise);
        }
      }

      return routines.values.map((routine) {
        final routineDays = days.values.where((d) => d.routineId == routine.id).toList();
        final relevantDayIds = routineDays.map((d) => d.id).toSet();
        final routineExercises = exercises.values.where((e) => relevantDayIds.contains(e.dayId)).toList();

        return _mapRutina(routine, routineDays, routineExercises);
      }).toList()
        ..sort((a, b) => b.creada.compareTo(a.creada));
    });
  }

  @override
  Future<void> saveRutina(Rutina rutina) async {
    await db.transaction(() async {
      await (db.delete(db.routines)..where((r) => r.id.equals(rutina.id))).go();

      await db.into(db.routines).insert(RoutinesCompanion.insert(
        id: rutina.id,
        name: rutina.nombre,
        createdAt: rutina.creada,
      ));

      for (var i = 0; i < rutina.dias.length; i++) {
        final dia = rutina.dias[i];
        await db.into(db.routineDays).insert(RoutineDaysCompanion.insert(
          id: dia.id,
          routineId: rutina.id,
          name: dia.nombre,
          progressionType: Value(dia.progressionType),
          dayIndex: i,
        ));

        for (var j = 0; j < dia.ejercicios.length; j++) {
          final ej = dia.ejercicios[j];
          await db.into(db.routineExercises).insert(RoutineExercisesCompanion.insert(
            id: ej.instanceId,
            dayId: dia.id,
            libraryId: ej.id,
            name: ej.nombre,
            description: Value(ej.descripcion),
            musclesPrimary: ej.musculosPrincipales,
            musclesSecondary: ej.musculosSecundarios,
            equipment: ej.equipo,
            localImagePath: Value(ej.localImagePath),
            series: ej.series,
            repsRange: ej.repsRange,
            suggestedRestSeconds: Value(ej.descansoSugerido?.inSeconds),
            notes: Value(ej.notas),
            exerciseIndex: j,
          ));
        }
      }
    });
  }

  @override
  Future<void> deleteRutina(String id) async {
    await (db.delete(db.routines)..where((r) => r.id.equals(id))).go();
  }

  // --- Sesiones ---

  @override
  Stream<List<Sesion>> watchSesionesHistory() {
    final joinQuery = db.select(db.sessions).join([
      leftOuterJoin(db.sessionExercises, db.sessionExercises.sessionId.equalsExp(db.sessions.id)),
      leftOuterJoin(db.sets, db.sets.sessionExerciseId.equalsExp(db.sessionExercises.id)),
    ]);

    // We filter in memory or join condition, better filter in memory for simplicity with complex logic
    // Actually we should where clause on sessions
    // db.select(db.sessions)..where((s) => s.completedAt.isNotNull())
    // But join requires building on select.

    // Correct way:
    // (db.select(db.sessions)..where((s) => s.completedAt.isNotNull())).join(...)

    return ((db.select(db.sessions)..where((s) => s.completedAt.isNotNull())).join([
      leftOuterJoin(db.sessionExercises, db.sessionExercises.sessionId.equalsExp(db.sessions.id)),
      leftOuterJoin(db.sets, db.sets.sessionExerciseId.equalsExp(db.sessionExercises.id)),
    ])).watch().map((rows) {
      final sessions = <String, Session>{};
      final exercises = <String, SessionExercise>{};
      final sets = <int, Set>{};

      for (final row in rows) {
        final s = row.readTable(db.sessions);
        sessions.putIfAbsent(s.id, () => s);

        final e = row.readTableOrNull(db.sessionExercises);
        if (e != null) {
          exercises.putIfAbsent(e.id, () => e);
        }

        final st = row.readTableOrNull(db.sets);
        if (st != null) {
          sets.putIfAbsent(st.id, () => st);
        }
      }

      final result = sessions.values.map((s) {
        final sExercises = exercises.values.where((e) => e.sessionId == s.id).toList();
        final sExerciseIds = sExercises.map((e) => e.id).toSet();
        final sSets = sets.values.where((st) => sExerciseIds.contains(st.sessionExerciseId)).toList();

        return _mapSesion(s, sExercises, sSets);
      }).toList();

      result.sort((a, b) => b.fecha.compareTo(a.fecha));
      return result;
    });
  }

  @override
  Future<void> saveSesion(Sesion sesion) async {
    await db.transaction(() async {
      await _saveSessionInternal(sesion, isCompleted: true);
    });
  }

  Future<void> _saveSessionInternal(Sesion sesion, {required bool isCompleted}) async {
    await (db.delete(db.sessions)..where((s) => s.id.equals(sesion.id))).go();

    await db.into(db.sessions).insert(SessionsCompanion.insert(
      id: sesion.id,
      routineId: Value(sesion.rutinaId),
      startTime: sesion.fecha,
      durationSeconds: Value(sesion.durationSeconds),
      completedAt: isCompleted
          ? Value(sesion.fecha.add(Duration(seconds: sesion.durationSeconds ?? 0)))
          : const Value(null),
    ));

    Future<void> insertExercises(List<Ejercicio> list, bool isTarget) async {
      for (var i = 0; i < list.length; i++) {
        final ex = list[i];
        final rowId = 'se-${isTarget ? "t" : "c"}-${sesion.id}-$i-${ex.id}';

        await db.into(db.sessionExercises).insert(SessionExercisesCompanion.insert(
          id: rowId,
          sessionId: sesion.id,
          libraryId: Value(ex.id),
          name: ex.nombre,
          musclesPrimary: [],
          musclesSecondary: [],
          notes: Value(ex.notas),
          exerciseIndex: i,
          isTarget: Value(isTarget),
        ));

        for (var j = 0; j < ex.logs.length; j++) {
          final log = ex.logs[j];
          await db.into(db.sets).insert(SetsCompanion.insert(
            sessionExerciseId: rowId,
            setIndex: j,
            weight: log.peso,
            reps: log.reps,
            completed: Value(log.completed),
            rpe: Value(log.rpe),
            notes: Value(log.notas),
            restSeconds: Value(log.restSeconds),
            isFailure: Value(log.isFailure),
            isDropset: Value(log.isDropset),
            isWarmup: Value(log.isWarmup),
          ));
        }
      }
    }

    await insertExercises(sesion.ejerciciosCompletados, false);
    await insertExercises(sesion.ejerciciosObjetivo, true);
  }

  @override
  Future<List<Sesion>> getHistoryForExercise(String exerciseName) async {
    // 1. Find SessionExercises with this name (not targets)
    final exerciseRows = await (db.select(db.sessionExercises)
      ..where((e) => e.name.equals(exerciseName) & e.isTarget.equals(false)))
      .get();

    if (exerciseRows.isEmpty) return [];

    final sessionIds = exerciseRows.map((e) => e.sessionId).toSet();

    // 2. Fetch Sessions
    final sessions = await (db.select(db.sessions)..where((s) => s.id.isIn(sessionIds))).get();

    // 3. Fetch all related exercises and sets for these sessions to fully reconstruct them
    // This seems overkill if we just want to show history of this exercise,
    // but the UI typically expects full Session objects or at least the relevant part.
    // The interface returns `List<Sesion>`.
    // Let's reuse the logic but for specific IDs.

    final allSessionExercises = await (db.select(db.sessionExercises)..where((e) => e.sessionId.isIn(sessionIds))).get();
    final allSessionExerciseIds = allSessionExercises.map((e) => e.id).toList();
    final allSets = await (db.select(db.sets)..where((s) => s.sessionExerciseId.isIn(allSessionExerciseIds))).get();

    final result = sessions.map((s) {
      final sExercises = allSessionExercises.where((e) => e.sessionId == s.id).toList();
      final sExerciseIds = sExercises.map((e) => e.id).toSet();
      final sSets = allSets.where((st) => sExerciseIds.contains(st.sessionExerciseId)).toList();
      return _mapSesion(s, sExercises, sSets);
    }).toList();

    result.sort((a, b) => b.fecha.compareTo(a.fecha));
    return result;
  }

  @override
  Future<void> saveActiveSession(ActiveSessionData data) async {
    final session = Sesion(
      id: 'active_session', // Logic handled below
      rutinaId: data.activeRutina?.id ?? '',
      fecha: data.startTime ?? DateTime.now(),
      durationSeconds: 0,
      ejerciciosCompletados: data.exercises,
      ejerciciosObjetivo: data.targets,
    );

    final active = await (db.select(db.sessions)..where((s) => s.completedAt.isNull())).getSingleOrNull();
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

  @override
  Future<ActiveSessionData?> getActiveSession() async {
    final sessionRow = await (db.select(db.sessions)..where((s) => s.completedAt.isNull())).getSingleOrNull();
    if (sessionRow == null) return null;

    final sessionExercises = await (db.select(db.sessionExercises)..where((e) => e.sessionId.equals(sessionRow.id))).get();
    final sessionExerciseIds = sessionExercises.map((e) => e.id).toList();

    final sets = await (db.select(db.sets)..where((s) => s.sessionExerciseId.isIn(sessionExerciseIds))).get();

    final tempSession = _mapSesion(sessionRow, sessionExercises, sets);

    // Attempt to load active routine
    Rutina? activeRutina;
    if (tempSession.rutinaId.isNotEmpty) {
       // Minimal fetch for routine
       final rRow = await (db.select(db.routines)..where((r) => r.id.equals(tempSession.rutinaId))).getSingleOrNull();
       if (rRow != null) {
         // Deep fetch needed? Or just basic info?
         // ActiveSessionData expects `Rutina?`.
         // Ideally we should fully reconstruct it.
         // Let's do a single fetch.
         // This is getting redundant with `watchRutinas`.
         // I'll leave it null for now or implement a `getRutina(id)` helper.
         // The UI might need it. I'll implement a quick fetch.
         final days = await (db.select(db.routineDays)..where((d) => d.routineId.equals(rRow.id))).get();
         final dIds = days.map((d) => d.id).toList();
         final exs = await (db.select(db.routineExercises)..where((e) => e.dayId.isIn(dIds))).get();
         activeRutina = _mapRutina(rRow, days, exs);
       }
    }

    return ActiveSessionData(
      activeRutina: activeRutina,
      exercises: tempSession.ejerciciosCompletados,
      targets: tempSession.ejerciciosObjetivo,
      startTime: tempSession.fecha,
      defaultRestSeconds: 60,
      history: {},
    );
  }

  @override
  Stream<ActiveSessionData?> watchActiveSession() {
    return (db.select(db.sessions)..where((s) => s.completedAt.isNull()))
      .watchSingleOrNull()
      .asyncMap((sessionRow) async {
        if (sessionRow == null) return null;
        return await getActiveSession();
    });
  }

  @override
  Future<void> clearActiveSession() async {
     await (db.delete(db.sessions)..where((s) => s.completedAt.isNull())).go();
  }

  @override
  Future<String> getNote(String exerciseName) async {
    final row = await (db.select(db.exerciseNotes)..where((n) => n.exerciseName.equals(exerciseName))).getSingleOrNull();
    return row?.note ?? '';
  }

  @override
  Future<void> saveNote(String exerciseName, String note) async {
    await db.into(db.exerciseNotes).insertOnConflictUpdate(ExerciseNotesCompanion.insert(
      exerciseName: exerciseName,
      note: note,
    ));
  }
}
