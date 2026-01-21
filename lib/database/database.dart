import 'package:drift/drift.dart';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// Type Converters
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    try {
      return List<String>.from(json.decode(fromDb));
    } catch (e) {
      return [];
    }
  }

  @override
  String toSql(List<String> value) {
    return json.encode(value);
  }
}

// Tables

// 1. Routines
class Routines extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// 2. Routine Days
class RoutineDays extends Table {
  TextColumn get id => text()();
  TextColumn get routineId => text().references(Routines, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get progressionType => text().withDefault(const Constant('none'))(); // 'none', 'lineal', 'double', 'percentage1RM'
  IntColumn get dayIndex => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// 3. Routine Exercises
class RoutineExercises extends Table {
  TextColumn get id => text()(); // instanceId
  TextColumn get dayId => text().references(RoutineDays, #id, onDelete: KeyAction.cascade)();

  // Library Data Embed
  TextColumn get libraryId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get musclesPrimary => text().map(const StringListConverter())();
  TextColumn get musclesSecondary => text().map(const StringListConverter())();
  TextColumn get equipment => text()();
  TextColumn get localImagePath => text().nullable()();

  // Routine Params
  IntColumn get series => integer()();
  TextColumn get repsRange => text()();
  IntColumn get suggestedRestSeconds => integer().nullable()();
  TextColumn get notes => text().nullable()();

  IntColumn get exerciseIndex => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// 4. Sessions
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get routineId => text().nullable()(); // Can be null if ad-hoc or deleted routine
  DateTimeColumn get startTime => dateTime()();
  IntColumn get durationSeconds => integer().nullable()();

  // Active Session Flag: If completedAt is null, it's an active session.
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// 5. Session Exercises
@TableIndex(name: 'session_exercises_name_idx', columns: {#name})
class SessionExercises extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id, onDelete: KeyAction.cascade)();

  TextColumn get libraryId => text().nullable()();
  TextColumn get name => text()();

  // Snapshot Data
  TextColumn get musclesPrimary => text().map(const StringListConverter())();
  TextColumn get musclesSecondary => text().map(const StringListConverter())();
  TextColumn get equipment => text().nullable()(); // Made nullable just in case

  TextColumn get notes => text().nullable()();
  IntColumn get exerciseIndex => integer()();

  // Target vs Completed
  BoolColumn get isTarget => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// 6. Sets
class WorkoutSets extends Table {
  TextColumn get id => text()(); // Changed from Int to Text (UUID)
  TextColumn get sessionExerciseId => text().references(SessionExercises, #id, onDelete: KeyAction.cascade)();

  IntColumn get setIndex => integer()();

  RealColumn get weight => real()();
  IntColumn get reps => integer()();
  BoolColumn get completed => boolean().withDefault(const Constant(true))();
  IntColumn get rpe => integer().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get restSeconds => integer().nullable()();

  BoolColumn get isFailure => boolean().withDefault(const Constant(false))();
  BoolColumn get isDropset => boolean().withDefault(const Constant(false))();
  BoolColumn get isWarmup => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// 7. Exercise Notes
class ExerciseNotes extends Table {
  TextColumn get exerciseName => text()();
  TextColumn get note => text()();

  @override
  Set<Column> get primaryKey => {exerciseName};
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [
  Routines,
  RoutineDays,
  RoutineExercises,
  Sessions,
  SessionExercises,
  WorkoutSets,
  ExerciseNotes,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}
