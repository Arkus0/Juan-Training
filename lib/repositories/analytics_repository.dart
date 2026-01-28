import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../database/database.dart';
import '../models/analysis_models.dart';
import '../models/ejercicio.dart';
import '../models/serie_log.dart';
import '../models/sesion.dart';

/// Repositorio especializado para operaciones de Análisis y Estadísticas.
/// Extraído de DriftTrainingRepository para mejor separación de responsabilidades.
class AnalyticsRepository {
  final AppDatabase db;

  AnalyticsRepository(this.db);

  // --- Mapper interno ---

  /// Mapper para sesiones (usado en getSessionsForDate y getDailySnapshot).
  Sesion _mapSesion(
    Session sessionRow,
    List<SessionExercise> sessionExercises,
    List<WorkoutSet> sets,
  ) {
    final setsByExercise = sets.groupListsBy((s) => s.sessionExerciseId);

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
          notas: row.notes,
          logs: exerciseSets
              .map(
                (s) => SerieLog(
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
                ),
              )
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

  // --- Analysis Methods ---

  Future<Map<DateTime, DailyActivity>> getYearlyActivityMap(int year) async {
    final startOfYear = DateTime(year);
    final endOfYear = DateTime(year + 1);

    final sessions = await (db.select(db.sessions)
          ..where((s) => s.completedAt.isNotNull())
          ..where((s) => s.startTime.isBiggerOrEqualValue(startOfYear))
          ..where((s) => s.startTime.isSmallerThanValue(endOfYear)))
        .get();

    if (sessions.isEmpty) return {};

    final sessionIds = sessions.map((s) => s.id).toList();

    final exercises = await (db.select(db.sessionExercises)
          ..where((e) => e.sessionId.isIn(sessionIds))
          ..where((e) => e.isTarget.equals(false)))
        .get();

    final exerciseIds = exercises.map((e) => e.id).toList();

    final sets = await (db.select(db.workoutSets)
          ..where((s) => s.sessionExerciseId.isIn(exerciseIds))
          ..where((s) => s.completed.equals(true)))
        .get();

    final setsByExercise = sets.groupListsBy((s) => s.sessionExerciseId);

    final volumeByExercise = <String, double>{};
    for (final entry in setsByExercise.entries) {
      final volume = entry.value
          .fold<double>(0, (sum, set) => sum + (set.weight * set.reps));
      volumeByExercise[entry.key] = volume;
    }

    final exercisesBySession = exercises.groupListsBy((e) => e.sessionId);

    final result = <DateTime, DailyActivity>{};

    for (final session in sessions) {
      final date = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );

      final sessionExercises = exercisesBySession[session.id] ?? [];
      final sessionVolume = sessionExercises.fold<double>(
        0,
        (sum, e) => sum + (volumeByExercise[e.id] ?? 0),
      );

      final durationMinutes = (session.durationSeconds ?? 0) ~/ 60;

      final existing = result[date];
      if (existing != null) {
        result[date] = DailyActivity(
          date: date,
          sessionsCount: existing.sessionsCount + 1,
          totalVolume: existing.totalVolume + sessionVolume,
          durationMinutes: existing.durationMinutes + durationMinutes,
        );
      } else {
        result[date] = DailyActivity(
          date: date,
          sessionsCount: 1,
          totalVolume: sessionVolume,
          durationMinutes: durationMinutes,
        );
      }
    }

    return result;
  }

  Future<Map<String, MuscleVolume>> getMuscleVolumePeriod(
      {int days = 30,}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    final sessions = await (db.select(db.sessions)
          ..where((s) => s.completedAt.isNotNull())
          ..where((s) => s.startTime.isBiggerOrEqualValue(cutoffDate)))
        .get();

    if (sessions.isEmpty) return {};

    final sessionIds = sessions.map((s) => s.id).toList();

    final exercises = await (db.select(db.sessionExercises)
          ..where((e) => e.sessionId.isIn(sessionIds))
          ..where((e) => e.isTarget.equals(false)))
        .get();

    final exerciseIds = exercises.map((e) => e.id).toList();

    final sets = await (db.select(db.workoutSets)
          ..where((s) => s.sessionExerciseId.isIn(exerciseIds))
          ..where((s) => s.completed.equals(true)))
        .get();

    final setsByExercise = sets.groupListsBy((s) => s.sessionExerciseId);

    final sessionById = {for (final s in sessions) s.id: s};

    final muscleVolumes = <String, _MuscleVolumeAccumulator>{};

    for (final exercise in exercises) {
      final primaryMuscles = exercise.musclesPrimary;
      if (primaryMuscles.isEmpty) continue;

      final exerciseSets = setsByExercise[exercise.id] ?? [];
      if (exerciseSets.isEmpty) continue;

      final volume = exerciseSets.fold<double>(
        0,
        (sum, set) => sum + (set.weight * set.reps),
      );
      final setsCount = exerciseSets.length;

      final session = sessionById[exercise.sessionId];
      final sessionDate = session?.startTime;

      for (final muscle in primaryMuscles) {
        final normalized = normalizeMuscleGroup(muscle);

        final acc = muscleVolumes.putIfAbsent(
          normalized,
          () => _MuscleVolumeAccumulator(
            normalized,
            getMuscleDisplayName(muscle),
          ),
        );
        acc.addVolume(volume, setsCount, sessionDate);
      }
    }

    return muscleVolumes.map((key, acc) => MapEntry(key, acc.toMuscleVolume()));
  }

  Future<List<PersonalRecord>> getPersonalRecords({
    List<String>? exerciseNames,
  }) async {
    final sessions = await (db.select(db.sessions)
          ..where((s) => s.completedAt.isNotNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startTime)]))
        .get();

    if (sessions.isEmpty) return [];

    final sessionIds = sessions.map((s) => s.id).toList();
    final sessionById = {for (final s in sessions) s.id: s};

    final exercisesQuery = db.select(db.sessionExercises)
      ..where((e) => e.sessionId.isIn(sessionIds))
      ..where((e) => e.isTarget.equals(false));

    final exercises = await exercisesQuery.get();

    List<SessionExercise> filteredExercises;
    if (exerciseNames != null && exerciseNames.isNotEmpty) {
      final normalizedSearchNames =
          exerciseNames.map((n) => n.toLowerCase()).toSet();
      filteredExercises = exercises.where((e) {
        final eName = e.name.toLowerCase();
        if (normalizedSearchNames.contains(eName)) return true;
        final normalized = normalizeBigLift(e.name);
        if (normalized != null &&
            normalizedSearchNames.contains(normalized.toLowerCase())) {
          return true;
        }
        return false;
      }).toList();
    } else {
      filteredExercises = exercises;
    }

    if (filteredExercises.isEmpty) return [];

    final exerciseIds = filteredExercises.map((e) => e.id).toList();

    final sets = await (db.select(db.workoutSets)
          ..where((s) => s.sessionExerciseId.isIn(exerciseIds))
          ..where((s) => s.completed.equals(true)))
        .get();

    final setsByExercise = sets.groupListsBy((s) => s.sessionExerciseId);

    final bestByExercise = <String, PersonalRecord>{};

    for (final exercise in filteredExercises) {
      final exerciseSets = setsByExercise[exercise.id] ?? [];
      if (exerciseSets.isEmpty) continue;

      WorkoutSet? maxSet;
      for (final set in exerciseSets) {
        if (maxSet == null || set.weight > maxSet.weight) {
          maxSet = set;
        } else if (set.weight == maxSet.weight && set.reps > maxSet.reps) {
          maxSet = set;
        }
      }

      if (maxSet == null) continue;

      final session = sessionById[exercise.sessionId];
      if (session == null) continue;

      final normalized = normalizeBigLift(exercise.name) ?? exercise.name;
      final estimated1RM = estimateOneRepMax(maxSet.weight, maxSet.reps);

      final current = PersonalRecord(
        exerciseName: normalized,
        maxWeight: maxSet.weight,
        repsAtMax: maxSet.reps,
        estimated1RM: estimated1RM,
        achievedAt: session.startTime,
      );

      final existing = bestByExercise[normalized];
      if (existing == null || current.maxWeight > existing.maxWeight) {
        bestByExercise[normalized] = current;
      } else if (current.maxWeight == existing.maxWeight &&
          current.repsAtMax > existing.repsAtMax) {
        bestByExercise[normalized] = current;
      }
    }

    final result = bestByExercise.values.toList()
      ..sort((a, b) => b.maxWeight.compareTo(a.maxWeight));

    return result;
  }

  Future<Map<String, DateTime>> getLastTrainedDateByMuscle() async {
    final sessions = await (db.select(db.sessions)
          ..where((s) => s.completedAt.isNotNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startTime)]))
        .get();

    if (sessions.isEmpty) return {};

    final sessionIds = sessions.map((s) => s.id).toList();
    final sessionById = {for (final s in sessions) s.id: s};

    final exercises = await (db.select(db.sessionExercises)
          ..where((e) => e.sessionId.isIn(sessionIds))
          ..where((e) => e.isTarget.equals(false)))
        .get();

    final lastTrained = <String, DateTime>{};

    for (final exercise in exercises) {
      final session = sessionById[exercise.sessionId];
      if (session == null) continue;

      for (final muscle in exercise.musclesPrimary) {
        final normalized = normalizeMuscleGroup(muscle);
        final existing = lastTrained[normalized];
        if (existing == null || session.startTime.isAfter(existing)) {
          lastTrained[normalized] = session.startTime;
        }
      }
    }

    return lastTrained;
  }

  Future<List<StrengthDataPoint>> getStrengthTrend(
    String exerciseName, {
    int months = 6,
  }) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: months * 30));

    final sessions = await (db.select(db.sessions)
          ..where((s) => s.completedAt.isNotNull())
          ..where((s) => s.startTime.isBiggerOrEqualValue(cutoffDate))
          ..orderBy([(s) => OrderingTerm.asc(s.startTime)]))
        .get();

    if (sessions.isEmpty) return [];

    final sessionIds = sessions.map((s) => s.id).toList();
    final sessionById = {for (final s in sessions) s.id: s};

    final exercises = await (db.select(db.sessionExercises)
          ..where((e) => e.sessionId.isIn(sessionIds))
          ..where((e) => e.isTarget.equals(false)))
        .get();

    final searchLower = exerciseName.toLowerCase();
    final normalizedSearch = normalizeBigLift(exerciseName);

    final filteredExercises = exercises.where((e) {
      final eName = e.name.toLowerCase();
      if (eName == searchLower) return true;
      final normalized = normalizeBigLift(e.name);
      if (normalized != null &&
          normalizedSearch != null &&
          normalized.toLowerCase() == normalizedSearch.toLowerCase()) {
        return true;
      }
      return eName.contains(searchLower) || searchLower.contains(eName);
    }).toList();

    if (filteredExercises.isEmpty) return [];

    final exerciseIds = filteredExercises.map((e) => e.id).toList();

    final sets = await (db.select(db.workoutSets)
          ..where((s) => s.sessionExerciseId.isIn(exerciseIds))
          ..where((s) => s.completed.equals(true)))
        .get();

    final setsByExercise = sets.groupListsBy((s) => s.sessionExerciseId);

    final dataPointsByDate = <DateTime, StrengthDataPoint>{};

    for (final exercise in filteredExercises) {
      final session = sessionById[exercise.sessionId];
      if (session == null) continue;

      final exerciseSets = setsByExercise[exercise.id] ?? [];
      if (exerciseSets.isEmpty) continue;

      double maxEstimated1RM = 0;
      double maxWeight = 0;
      var repsAtMax = 0;

      for (final set in exerciseSets) {
        final e1RM = estimateOneRepMax(set.weight, set.reps);
        if (e1RM > maxEstimated1RM) {
          maxEstimated1RM = e1RM;
          maxWeight = set.weight;
          repsAtMax = set.reps;
        }
      }

      final date = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );

      final existing = dataPointsByDate[date];
      if (existing == null || maxEstimated1RM > existing.estimated1RM) {
        dataPointsByDate[date] = StrengthDataPoint(
          date: date,
          estimated1RM: maxEstimated1RM,
          actualMax: maxWeight,
          repsAtMax: repsAtMax,
        );
      }
    }

    final result = dataPointsByDate.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return result;
  }

  Future<StreakData> getStreakData() async {
    final sessions = await (db.select(db.sessions)
          ..where((s) => s.completedAt.isNotNull())
          ..orderBy([(s) => OrderingTerm.desc(s.startTime)]))
        .get();

    if (sessions.isEmpty) {
      return StreakData.empty;
    }

    // FIX: Usar timezone local para normalizar fechas correctamente
    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);

    final trainingDates = <DateTime>{};
    for (final session in sessions) {
      final localTime = session.startTime.toLocal();
      final date = DateTime(
        localTime.year,
        localTime.month,
        localTime.day,
      );
      trainingDates.add(date);
    }

    final sortedDates = trainingDates.toList()..sort((a, b) => b.compareTo(a));

    final lastTrainingDate = sortedDates.first;

    var currentStreak = 0;
    var checkDate = todayNormalized;

    if (!trainingDates.contains(todayNormalized)) {
      final yesterday = todayNormalized.subtract(const Duration(days: 1));
      if (!trainingDates.contains(yesterday)) {
        currentStreak = 0;
      } else {
        checkDate = yesterday;
        currentStreak = 1;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    } else {
      currentStreak = 1;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    if (currentStreak > 0) {
      while (trainingDates.contains(checkDate)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    }

    var longestStreak = 0;
    var tempStreak = 0;
    DateTime? previousDate;

    for (final date in sortedDates.reversed) {
      if (previousDate == null) {
        tempStreak = 1;
      } else {
        final diff = date.difference(previousDate).inDays;
        if (diff == 1) {
          tempStreak++;
        } else {
          if (tempStreak > longestStreak) {
            longestStreak = tempStreak;
          }
          tempStreak = 1;
        }
      }
      previousDate = date;
    }
    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
    }

    final recentDates = <DateTime>[];
    for (var i = 6; i >= 0; i--) {
      final date = todayNormalized.subtract(Duration(days: i));
      if (trainingDates.contains(date)) {
        recentDates.add(date);
      }
    }

    return StreakData(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      lastTrainingDate: lastTrainingDate,
      recentDates: recentDates,
    );
  }

  Future<DailySnapshot?> getDailySnapshot(DateTime date) async {
    final sessions = await getSessionsForDate(date);
    if (sessions.isEmpty) return null;

    double totalVolume = 0;
    var totalDuration = 0;
    var totalSets = 0;
    BestSetInfo? bestSet;
    double bestSetVolume = 0;
    final exerciseNames = <String>{};
    String? routineName;
    String? dayName;

    for (final session in sessions) {
      routineName ??= session.rutinaId.isNotEmpty ? session.rutinaId : null;
      dayName ??= session.dayName;
      totalDuration += session.durationSeconds ?? 0;

      for (final exercise in session.ejerciciosCompletados) {
        exerciseNames.add(exercise.nombre);

        for (final log in exercise.logs) {
          if (log.completed) {
            totalSets++;
            final setVolume = log.peso * log.reps;
            totalVolume += setVolume;

            if (setVolume > bestSetVolume) {
              bestSetVolume = setVolume;
              bestSet = BestSetInfo(
                exerciseName: exercise.nombre,
                weight: log.peso,
                reps: log.reps,
                rpe: log.rpe,
              );
            }
          }
        }
      }
    }

    return DailySnapshot(
      date: date,
      routineName: routineName,
      dayName: dayName,
      totalVolume: totalVolume,
      durationMinutes: totalDuration ~/ 60,
      setsCompleted: totalSets,
      bestSet: bestSet,
      exerciseNames: exerciseNames.toList(),
    );
  }

  Future<List<Sesion>> getSessionsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final sessionRows = await (db.select(db.sessions)
          ..where((s) => s.completedAt.isNotNull())
          ..where((s) => s.startTime.isBiggerOrEqualValue(startOfDay))
          ..where((s) => s.startTime.isSmallerThanValue(endOfDay))
          ..orderBy([(s) => OrderingTerm.asc(s.startTime)]))
        .get();

    if (sessionRows.isEmpty) return [];

    final sessionIds = sessionRows.map((s) => s.id).toList();

    final exercises = await (db.select(db.sessionExercises)
          ..where((e) => e.sessionId.isIn(sessionIds)))
        .get();

    final exerciseIds = exercises.map((e) => e.id).toList();

    final sets = await (db.select(db.workoutSets)
          ..where((s) => s.sessionExerciseId.isIn(exerciseIds)))
        .get();

    return sessionRows.map((s) {
      final sExercises = exercises.where((e) => e.sessionId == s.id).toList();
      final sExerciseIds = sExercises.map((e) => e.id).toSet();
      final sSets = sets
          .where((st) => sExerciseIds.contains(st.sessionExerciseId))
          .toList();
      return _mapSesion(s, sExercises, sSets);
    }).toList();
  }

  Future<List<String>> getExerciseNames() async {
    final results = await (db.selectOnly(db.sessionExercises, distinct: true)
          ..addColumns([db.sessionExercises.name])
          ..where(db.sessionExercises.isTarget.equals(false)))
        .get();

    return results
        .map((row) => row.read(db.sessionExercises.name))
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
  }
}

// Helper class for accumulating muscle volume
class _MuscleVolumeAccumulator {
  final String muscleName;
  final String displayName;
  double totalVolume = 0;
  int setsCount = 0;
  DateTime? lastTrained;

  _MuscleVolumeAccumulator(this.muscleName, this.displayName);

  void addVolume(double volume, int sets, DateTime? date) {
    totalVolume += volume;
    setsCount += sets;
    if (date != null && (lastTrained == null || date.isAfter(lastTrained!))) {
      lastTrained = date;
    }
  }

  MuscleVolume toMuscleVolume() {
    return MuscleVolume(
      muscleName: muscleName,
      displayName: displayName,
      totalVolume: totalVolume,
      setsCount: setsCount,
      lastTrained: lastTrained,
    );
  }
}
