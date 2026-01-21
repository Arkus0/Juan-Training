import 'package:drift/drift.dart';
import 'package:collection/collection.dart';
import 'package:logger/logger.dart';
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
  final _logger = Logger();

  DriftTrainingRepository(this.db);

  // --- Mappers ---

  Rutina _mapRutina(
      Routine row, List<RoutineDay> days, List<RoutineExercise> exercises) {
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
        ejercicios: dayExercises
            .map((e) => EjercicioEnRutina(
                  instanceId: e.id,
                  id: e.libraryId,
                  nombre: e.name,
                  descripcion: e.description,
                  musculosPrincipales: e.musclesPrimary,
                  musculosSecundarios: e.musclesSecondary ?? [],
                  equipo: e.equipment,
                  localImagePath: e.localImagePath,
                  series: e.series,
                  repsRange: e.repsRange,
                  descansoSugerido: e.suggestedRestSeconds != null
                      ? Duration(seconds: e.suggestedRestSeconds!)
                      : null,
                  notas: e.notes,
                ))
            .toList(),
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
          id: row.id, // Now using the correct instance ID
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
                    id: s.id, // ID from DB
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
      leftOuterJoin(
          db.routineDays, db.routineDays.routineId.equalsExp(db.routines.id)),
      leftOuterJoin(db.routineExercises,
          db.routineExercises.dayId.equalsExp(db.routineDays.id)),
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
        final routineDays =
            days.values.where((d) => d.routineId == routine.id).toList();
        final relevantDayIds = routineDays.map((d) => d.id).toSet();
        final routineExercises = exercises.values
            .where((e) => relevantDayIds.contains(e.dayId))
            .toList();

        return _mapRutina(routine, routineDays, routineExercises);
      }).toList()
        ..sort((a, b) => b.creada.compareTo(a.creada));
    });
  }

  /// This function handles both the creation of a new routine and the
  /// update of an existing one, preventing UNIQUE constraint errors.
  Future<void> createRoutine(Rutina rutina) async {
    try {
      await db.transaction(() async {
        // 1. Insert or Update the Routine itself.
        await db.into(db.routines).insertOnConflictUpdate(
              RoutinesCompanion.insert(
                id: rutina.id,
                name: rutina.nombre,
                createdAt: rutina.creada,
              ),
            );

        // 2. "Clean Update" for Routines (Assuming simpler model for Routines for now,
        // or leaving as destructive-recreate for Routines as per original code,
        // but user only asked to fix Session save. I will leave Routine save as is
        // unless requested, but the prompt focused on `_saveSessionInternal`).
        // The prompt said "Elimina el Guardado Destructivo... Reescribe _saveSessionInternal".
        // Routine structure is complex to upsert, so deleting days/exercises is standard for simple document replacement.

        await (db.delete(db.routineDays)
              ..where((tbl) => tbl.routineId.equals(rutina.id)))
            .go();

        // 3. Insert the new days and exercises.
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
            await db
                .into(db.routineExercises)
                .insert(RoutineExercisesCompanion.insert(
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
                  suggestedRestSeconds:
                      Value(ej.descansoSugerido?.inSeconds ?? 60),
                  notes: Value(ej.notas ?? ""),
                  exerciseIndex: j,
                ));
          }
        }
      });
    } catch (e, s) {
      _logger.e('Failed to create/save routine', error: e, stackTrace: s);
    }
  }

  @override
  Future<void> saveRutina(Rutina rutina) async {
    await createRoutine(rutina);
  }

  @override
  Future<void> deleteRutina(String id) async {
    await (db.delete(db.routines)..where((r) => r.id.equals(id))).go();
  }

  // --- Sesiones ---

  @override
  Stream<List<Sesion>> watchSesionesHistory() {
    return ((db.select(db.sessions)..where((s) => s.completedAt.isNotNull()))
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
      final sets = <String, WorkoutSet>{}; // Changed key to String (UUID) if needed or just handle List

      for (final row in rows) {
        final s = row.readTable(db.sessions);
        sessions.putIfAbsent(s.id, () => s);

        final e = row.readTableOrNull(db.sessionExercises);
        if (e != null) {
          exercises.putIfAbsent(e.id, () => e);
        }

        final st = row.readTableOrNull(db.workoutSets);
        if (st != null) {
          // Using ID string as key
          // Note: WorkoutSet.id is now String.
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

  @override
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
          startTime: sesion.fecha,
          durationSeconds: Value(sesion.durationSeconds),
          completedAt: isCompleted
              ? Value(sesion.fecha
                  .add(Duration(seconds: sesion.durationSeconds ?? 0)))
              : const Value(null),
        ));

    // 2. Track what we are saving to handle deletions
    final visitedExerciseIds = <String>{};
    final visitedSetIds = <String>{};

    Future<void> processExercises(List<Ejercicio> list, bool isTarget) async {
      for (var i = 0; i < list.length; i++) {
        final ex = list[i];
        // Ensure ex.id is the stable instance ID.
        final rowId = ex.id;
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
          )
        );

        for (var j = 0; j < ex.logs.length; j++) {
          final log = ex.logs[j];
          final setId = log.id;
          visitedSetIds.add(setId);

          await db.into(db.workoutSets).insertOnConflictUpdate(
            WorkoutSetsCompanion.insert(
                id: setId, // Using UUID primary key
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
              )
          );
        }
      }
    }

    await processExercises(sesion.ejerciciosCompletados, false);
    await processExercises(sesion.ejerciciosObjetivo, true);

    // 3. Clean up orphans
    // Delete exercises that belong to this session but were not in the updated list
    await (db.delete(db.sessionExercises)
      ..where((e) => e.sessionId.equals(sesion.id) & e.id.isNotIn(visitedExerciseIds)))
      .go();

    // Delete sets that belong to the kept exercises but were not in the updated list
    // Note: Sets of deleted exercises are removed via Cascade, so we only check visited exercises.
    if (visitedExerciseIds.isNotEmpty) {
      await (db.delete(db.workoutSets)
        ..where((s) => s.sessionExerciseId.isIn(visitedExerciseIds) & s.id.isNotIn(visitedSetIds)))
        .go();
    }
  }

  @override
  Future<List<Sesion>> getHistoryForExercise(String exerciseName) async {
    // 1. Get top 5 most recent sessions containing this exercise
    // We use distinct to avoid duplicate sessions if the exercise appears multiple times
    final distinctSessions = await (db.select(db.sessions, distinct: true).join([
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
    // Requirement: "filter strictly by name... only need last 5 sessions"
    // Optimization: Only load the specific exercise data to save memory
    final relevantExercises = await (db.select(db.sessionExercises)
      ..where((e) => e.sessionId.isIn(sessionIds) & e.name.equals(exerciseName)))
      .get();

    final relevantExerciseIds = relevantExercises.map((e) => e.id).toList();

    // 3. Fetch sets for these exercises
    final relevantSets = await (db.select(db.workoutSets)
      ..where((s) => s.sessionExerciseId.isIn(relevantExerciseIds)))
      .get();

    // 4. Map to Sesion objects (Sparse objects containing only the relevant history)
    final result = distinctSessions.map((s) {
      final sExercises = relevantExercises.where((e) => e.sessionId == s.id).toList();
      final sSets = relevantSets
          .where((st) => sExercises.any((e) => e.id == st.sessionExerciseId))
          .toList();

      // We populate 'ejerciciosCompletados' with the historical data for this specific exercise
      return _mapSesion(s, sExercises, sSets);
    }).toList();

    // Ensure order
    result.sort((a, b) => b.fecha.compareTo(a.fecha));

    return result;
  }

  @override
  Future<void> saveActiveSession(ActiveSessionData data) async {
    final session = Sesion(
      id: 'active_session', // Placeholder, ignored below
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

  @override
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
    final row = await (db.select(db.exerciseNotes)
          ..where((n) => n.exerciseName.equals(exerciseName)))
        .getSingleOrNull();
    return row?.note ?? '';
  }

  @override
  Future<void> saveNote(String exerciseName, String note) async {
    await db.into(db.exerciseNotes).insertOnConflictUpdate(
        ExerciseNotesCompanion.insert(
      exerciseName: exerciseName,
      note: note,
    ));
  }
}
