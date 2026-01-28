import 'package:drift/drift.dart';
import 'package:logger/logger.dart';

import '../database/database.dart';
import '../models/dia.dart';
import '../models/ejercicio_en_rutina.dart';
import '../models/progression_type.dart';
import '../models/rutina.dart';

/// Repositorio especializado para operaciones de Rutinas.
/// Extraído de DriftTrainingRepository para mejor separación de responsabilidades.
class RoutineRepository {
  final AppDatabase db;
  final _logger = Logger();

  RoutineRepository(this.db);

  // --- Mappers ---

  Rutina mapRutina(
    Routine row,
    List<RoutineDay> days,
    List<RoutineExercise> exercises,
  ) {
    // Map exercises to days
    final exercisesByDay = <String, List<RoutineExercise>>{};
    for (final ex in exercises) {
      exercisesByDay.putIfAbsent(ex.dayId, () => []).add(ex);
    }

    final dias = days.map((dayRow) {
      final dayExercises = exercisesByDay[dayRow.id] ?? [];
      // Sort by index
      dayExercises.sort((a, b) => a.exerciseIndex.compareTo(b.exerciseIndex));

      return Dia(
        id: dayRow.id,
        nombre: dayRow.name,
        progressionType: dayRow.progressionType,
        ejercicios: dayExercises
            .map(
              (e) => EjercicioEnRutina(
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
              ),
            )
            .toList(),
      );
    }).toList();

    // Sort days by index (con manejo de inconsistencias de BD)
    dias.sort((a, b) {
      final dayA = days.where((d) => d.id == a.id).firstOrNull;
      final dayB = days.where((d) => d.id == b.id).firstOrNull;
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

  // --- CRUD Operations ---

  Stream<List<Rutina>> watchRutinas() {
    final query = db.select(db.routines).join([
      leftOuterJoin(
        db.routineDays,
        db.routineDays.routineId.equalsExp(db.routines.id),
      ),
      leftOuterJoin(
        db.routineExercises,
        db.routineExercises.dayId.equalsExp(db.routineDays.id),
      ),
    ]);

    return query.watch().map((rows) {
      try {
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

        final result = routines.values.map((routine) {
          final routineDays =
              days.values.where((d) => d.routineId == routine.id).toList();
          final relevantDayIds = routineDays.map((d) => d.id).toSet();
          final routineExercises = exercises.values
              .where((e) => relevantDayIds.contains(e.dayId))
              .toList();

          return mapRutina(routine, routineDays, routineExercises);
        }).toList()
          ..sort((a, b) => b.creada.compareTo(a.creada));

        return result;
      } catch (e, s) {
        _logger.e('Error while mapping routines stream',
            error: e, stackTrace: s,);
        return <Rutina>[];
      }
    });
  }

  Future<void> saveRutina(Rutina rutina) async {
    try {
      // Pre-validate to avoid silent DB errors or constraint violations
      final dayIds = rutina.dias.map((d) => d.id).toList();
      if (dayIds.length != dayIds.toSet().length) {
        throw Exception('Duplicated day IDs in rutina before DB insert.');
      }
      final allInstanceIds = rutina.dias
          .expand((d) => d.ejercicios.map((e) => e.instanceId))
          .toList();
      if (allInstanceIds.length != allInstanceIds.toSet().length) {
        throw Exception(
            'Duplicated exercise instance IDs in rutina before DB insert.',);
      }

      await db.transaction(() async {
        // 1. Insert or Update the Routine itself.
        await db.into(db.routines).insertOnConflictUpdate(
              RoutinesCompanion.insert(
                id: rutina.id,
                name: rutina.nombre,
                createdAt: rutina.creada,
              ),
            );

        // 2. Manual cleanup of old days and exercises
        final existingDays = await (db.select(db.routineDays)
              ..where((tbl) => tbl.routineId.equals(rutina.id)))
            .get();
        final existingDayIds = existingDays.map((d) => d.id).toList();

        if (existingDayIds.isNotEmpty) {
          await (db.delete(db.routineExercises)
                ..where((tbl) => tbl.dayId.isIn(existingDayIds)))
              .go();
        }

        await (db.delete(db.routineDays)
              ..where((tbl) => tbl.routineId.equals(rutina.id)))
            .go();

        // 3. Insert the new days and exercises using batch.
        final daysCompanions = <RoutineDaysCompanion>[];
        final exercisesCompanions = <RoutineExercisesCompanion>[];

        for (var i = 0; i < rutina.dias.length; i++) {
          final dia = rutina.dias[i];
          daysCompanions.add(
            RoutineDaysCompanion.insert(
              id: dia.id,
              routineId: rutina.id,
              name: dia.nombre,
              progressionType: Value(dia.progressionType),
              dayIndex: i,
            ),
          );

          for (var j = 0; j < dia.ejercicios.length; j++) {
            final ej = dia.ejercicios[j];
            exercisesCompanions.add(
              RoutineExercisesCompanion.insert(
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
                notes: Value(ej.notas ?? ''),
                supersetId: Value(ej.supersetId),
                exerciseIndex: j,
                progressionType: Value(ej.progressionType.value),
                weightIncrement: Value(ej.weightIncrement),
                targetRpe: Value(ej.targetRpe),
              ),
            );
          }
        }

        await db.batch((batch) {
          batch.insertAll(db.routineDays, daysCompanions);
          batch.insertAll(db.routineExercises, exercisesCompanions);
        });
      });
    } catch (e, s) {
      _logger.e('Failed to create/save routine', error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<void> deleteRutina(String id) async {
    await (db.delete(db.routines)..where((r) => r.id.equals(id))).go();
  }
}
