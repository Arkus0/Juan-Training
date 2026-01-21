// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RoutinesTable extends Routines with TableInfo<$RoutinesTable, Routine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routines';
  @override
  VerificationContext validateIntegrity(Insertable<Routine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Routine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Routine(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $RoutinesTable createAlias(String alias) {
    return $RoutinesTable(attachedDatabase, alias);
  }
}

class Routine extends DataClass implements Insertable<Routine> {
  final String id;
  final String name;
  final DateTime createdAt;
  const Routine(
      {required this.id, required this.name, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RoutinesCompanion toCompanion(bool nullToAbsent) {
    return RoutinesCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory Routine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Routine(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Routine copyWith({String? id, String? name, DateTime? createdAt}) => Routine(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  Routine copyWithCompanion(RoutinesCompanion data) {
    return Routine(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Routine(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Routine &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class RoutinesCompanion extends UpdateCompanion<Routine> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RoutinesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutinesCompanion.insert({
    required String id,
    required String name,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAt = Value(createdAt);
  static Insertable<Routine> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutinesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return RoutinesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutinesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutineDaysTable extends RoutineDays
    with TableInfo<$RoutineDaysTable, RoutineDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _routineIdMeta =
      const VerificationMeta('routineId');
  @override
  late final GeneratedColumn<String> routineId = GeneratedColumn<String>(
      'routine_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES routines (id) ON DELETE CASCADE'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _progressionTypeMeta =
      const VerificationMeta('progressionType');
  @override
  late final GeneratedColumn<String> progressionType = GeneratedColumn<String>(
      'progression_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('none'));
  static const VerificationMeta _dayIndexMeta =
      const VerificationMeta('dayIndex');
  @override
  late final GeneratedColumn<int> dayIndex = GeneratedColumn<int>(
      'day_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, routineId, name, progressionType, dayIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_days';
  @override
  VerificationContext validateIntegrity(Insertable<RoutineDay> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('routine_id')) {
      context.handle(_routineIdMeta,
          routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta));
    } else if (isInserting) {
      context.missing(_routineIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('progression_type')) {
      context.handle(
          _progressionTypeMeta,
          progressionType.isAcceptableOrUnknown(
              data['progression_type']!, _progressionTypeMeta));
    }
    if (data.containsKey('day_index')) {
      context.handle(_dayIndexMeta,
          dayIndex.isAcceptableOrUnknown(data['day_index']!, _dayIndexMeta));
    } else if (isInserting) {
      context.missing(_dayIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineDay(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      routineId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}routine_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      progressionType: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}progression_type'])!,
      dayIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_index'])!,
    );
  }

  @override
  $RoutineDaysTable createAlias(String alias) {
    return $RoutineDaysTable(attachedDatabase, alias);
  }
}

class RoutineDay extends DataClass implements Insertable<RoutineDay> {
  final String id;
  final String routineId;
  final String name;
  final String progressionType;
  final int dayIndex;
  const RoutineDay(
      {required this.id,
      required this.routineId,
      required this.name,
      required this.progressionType,
      required this.dayIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['routine_id'] = Variable<String>(routineId);
    map['name'] = Variable<String>(name);
    map['progression_type'] = Variable<String>(progressionType);
    map['day_index'] = Variable<int>(dayIndex);
    return map;
  }

  RoutineDaysCompanion toCompanion(bool nullToAbsent) {
    return RoutineDaysCompanion(
      id: Value(id),
      routineId: Value(routineId),
      name: Value(name),
      progressionType: Value(progressionType),
      dayIndex: Value(dayIndex),
    );
  }

  factory RoutineDay.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineDay(
      id: serializer.fromJson<String>(json['id']),
      routineId: serializer.fromJson<String>(json['routineId']),
      name: serializer.fromJson<String>(json['name']),
      progressionType: serializer.fromJson<String>(json['progressionType']),
      dayIndex: serializer.fromJson<int>(json['dayIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routineId': serializer.toJson<String>(routineId),
      'name': serializer.toJson<String>(name),
      'progressionType': serializer.toJson<String>(progressionType),
      'dayIndex': serializer.toJson<int>(dayIndex),
    };
  }

  RoutineDay copyWith(
          {String? id,
          String? routineId,
          String? name,
          String? progressionType,
          int? dayIndex}) =>
      RoutineDay(
        id: id ?? this.id,
        routineId: routineId ?? this.routineId,
        name: name ?? this.name,
        progressionType: progressionType ?? this.progressionType,
        dayIndex: dayIndex ?? this.dayIndex,
      );
  RoutineDay copyWithCompanion(RoutineDaysCompanion data) {
    return RoutineDay(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      name: data.name.present ? data.name.value : this.name,
      progressionType: data.progressionType.present
          ? data.progressionType.value
          : this.progressionType,
      dayIndex: data.dayIndex.present ? data.dayIndex.value : this.dayIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineDay(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('name: $name, ')
          ..write('progressionType: $progressionType, ')
          ..write('dayIndex: $dayIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, routineId, name, progressionType, dayIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineDay &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.name == this.name &&
          other.progressionType == this.progressionType &&
          other.dayIndex == this.dayIndex);
}

class RoutineDaysCompanion extends UpdateCompanion<RoutineDay> {
  final Value<String> id;
  final Value<String> routineId;
  final Value<String> name;
  final Value<String> progressionType;
  final Value<int> dayIndex;
  final Value<int> rowid;
  const RoutineDaysCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.name = const Value.absent(),
    this.progressionType = const Value.absent(),
    this.dayIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutineDaysCompanion.insert({
    required String id,
    required String routineId,
    required String name,
    this.progressionType = const Value.absent(),
    required int dayIndex,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        routineId = Value(routineId),
        name = Value(name),
        dayIndex = Value(dayIndex);
  static Insertable<RoutineDay> custom({
    Expression<String>? id,
    Expression<String>? routineId,
    Expression<String>? name,
    Expression<String>? progressionType,
    Expression<int>? dayIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (name != null) 'name': name,
      if (progressionType != null) 'progression_type': progressionType,
      if (dayIndex != null) 'day_index': dayIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutineDaysCompanion copyWith(
      {Value<String>? id,
      Value<String>? routineId,
      Value<String>? name,
      Value<String>? progressionType,
      Value<int>? dayIndex,
      Value<int>? rowid}) {
    return RoutineDaysCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      name: name ?? this.name,
      progressionType: progressionType ?? this.progressionType,
      dayIndex: dayIndex ?? this.dayIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<String>(routineId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (progressionType.present) {
      map['progression_type'] = Variable<String>(progressionType.value);
    }
    if (dayIndex.present) {
      map['day_index'] = Variable<int>(dayIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineDaysCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('name: $name, ')
          ..write('progressionType: $progressionType, ')
          ..write('dayIndex: $dayIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutineExercisesTable extends RoutineExercises
    with TableInfo<$RoutineExercisesTable, RoutineExercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutineExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dayIdMeta = const VerificationMeta('dayId');
  @override
  late final GeneratedColumn<String> dayId = GeneratedColumn<String>(
      'day_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES routine_days (id) ON DELETE CASCADE'));
  static const VerificationMeta _libraryIdMeta =
      const VerificationMeta('libraryId');
  @override
  late final GeneratedColumn<String> libraryId = GeneratedColumn<String>(
      'library_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
      musclesPrimary = GeneratedColumn<String>(
              'muscles_primary', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<String>>(
              $RoutineExercisesTable.$convertermusclesPrimary);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
      musclesSecondary = GeneratedColumn<String>(
              'muscles_secondary', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<String>>(
              $RoutineExercisesTable.$convertermusclesSecondary);
  static const VerificationMeta _equipmentMeta =
      const VerificationMeta('equipment');
  @override
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
      'equipment', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localImagePathMeta =
      const VerificationMeta('localImagePath');
  @override
  late final GeneratedColumn<String> localImagePath = GeneratedColumn<String>(
      'local_image_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _seriesMeta = const VerificationMeta('series');
  @override
  late final GeneratedColumn<int> series = GeneratedColumn<int>(
      'series', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _repsRangeMeta =
      const VerificationMeta('repsRange');
  @override
  late final GeneratedColumn<String> repsRange = GeneratedColumn<String>(
      'reps_range', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _suggestedRestSecondsMeta =
      const VerificationMeta('suggestedRestSeconds');
  @override
  late final GeneratedColumn<int> suggestedRestSeconds = GeneratedColumn<int>(
      'suggested_rest_seconds', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _exerciseIndexMeta =
      const VerificationMeta('exerciseIndex');
  @override
  late final GeneratedColumn<int> exerciseIndex = GeneratedColumn<int>(
      'exercise_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        dayId,
        libraryId,
        name,
        description,
        musclesPrimary,
        musclesSecondary,
        equipment,
        localImagePath,
        series,
        repsRange,
        suggestedRestSeconds,
        notes,
        exerciseIndex
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routine_exercises';
  @override
  VerificationContext validateIntegrity(Insertable<RoutineExercise> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('day_id')) {
      context.handle(
          _dayIdMeta, dayId.isAcceptableOrUnknown(data['day_id']!, _dayIdMeta));
    } else if (isInserting) {
      context.missing(_dayIdMeta);
    }
    if (data.containsKey('library_id')) {
      context.handle(_libraryIdMeta,
          libraryId.isAcceptableOrUnknown(data['library_id']!, _libraryIdMeta));
    } else if (isInserting) {
      context.missing(_libraryIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('equipment')) {
      context.handle(_equipmentMeta,
          equipment.isAcceptableOrUnknown(data['equipment']!, _equipmentMeta));
    } else if (isInserting) {
      context.missing(_equipmentMeta);
    }
    if (data.containsKey('local_image_path')) {
      context.handle(
          _localImagePathMeta,
          localImagePath.isAcceptableOrUnknown(
              data['local_image_path']!, _localImagePathMeta));
    }
    if (data.containsKey('series')) {
      context.handle(_seriesMeta,
          series.isAcceptableOrUnknown(data['series']!, _seriesMeta));
    } else if (isInserting) {
      context.missing(_seriesMeta);
    }
    if (data.containsKey('reps_range')) {
      context.handle(_repsRangeMeta,
          repsRange.isAcceptableOrUnknown(data['reps_range']!, _repsRangeMeta));
    } else if (isInserting) {
      context.missing(_repsRangeMeta);
    }
    if (data.containsKey('suggested_rest_seconds')) {
      context.handle(
          _suggestedRestSecondsMeta,
          suggestedRestSeconds.isAcceptableOrUnknown(
              data['suggested_rest_seconds']!, _suggestedRestSecondsMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('exercise_index')) {
      context.handle(
          _exerciseIndexMeta,
          exerciseIndex.isAcceptableOrUnknown(
              data['exercise_index']!, _exerciseIndexMeta));
    } else if (isInserting) {
      context.missing(_exerciseIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RoutineExercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RoutineExercise(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      dayId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}day_id'])!,
      libraryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}library_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      musclesPrimary: $RoutineExercisesTable.$convertermusclesPrimary.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}muscles_primary'])!),
      musclesSecondary: $RoutineExercisesTable.$convertermusclesSecondary
          .fromSql(attachedDatabase.typeMapping.read(DriftSqlType.string,
              data['${effectivePrefix}muscles_secondary'])!),
      equipment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}equipment'])!,
      localImagePath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}local_image_path']),
      series: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}series'])!,
      repsRange: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reps_range'])!,
      suggestedRestSeconds: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}suggested_rest_seconds']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      exerciseIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}exercise_index'])!,
    );
  }

  @override
  $RoutineExercisesTable createAlias(String alias) {
    return $RoutineExercisesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertermusclesPrimary =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertermusclesSecondary =
      const StringListConverter();
}

class RoutineExercise extends DataClass implements Insertable<RoutineExercise> {
  final String id;
  final String dayId;
  final String libraryId;
  final String name;
  final String? description;
  final List<String> musclesPrimary;
  final List<String> musclesSecondary;
  final String equipment;
  final String? localImagePath;
  final int series;
  final String repsRange;
  final int? suggestedRestSeconds;
  final String? notes;
  final int exerciseIndex;
  const RoutineExercise(
      {required this.id,
      required this.dayId,
      required this.libraryId,
      required this.name,
      this.description,
      required this.musclesPrimary,
      required this.musclesSecondary,
      required this.equipment,
      this.localImagePath,
      required this.series,
      required this.repsRange,
      this.suggestedRestSeconds,
      this.notes,
      required this.exerciseIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['day_id'] = Variable<String>(dayId);
    map['library_id'] = Variable<String>(libraryId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    {
      map['muscles_primary'] = Variable<String>($RoutineExercisesTable
          .$convertermusclesPrimary
          .toSql(musclesPrimary));
    }
    {
      map['muscles_secondary'] = Variable<String>($RoutineExercisesTable
          .$convertermusclesSecondary
          .toSql(musclesSecondary));
    }
    map['equipment'] = Variable<String>(equipment);
    if (!nullToAbsent || localImagePath != null) {
      map['local_image_path'] = Variable<String>(localImagePath);
    }
    map['series'] = Variable<int>(series);
    map['reps_range'] = Variable<String>(repsRange);
    if (!nullToAbsent || suggestedRestSeconds != null) {
      map['suggested_rest_seconds'] = Variable<int>(suggestedRestSeconds);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['exercise_index'] = Variable<int>(exerciseIndex);
    return map;
  }

  RoutineExercisesCompanion toCompanion(bool nullToAbsent) {
    return RoutineExercisesCompanion(
      id: Value(id),
      dayId: Value(dayId),
      libraryId: Value(libraryId),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      musclesPrimary: Value(musclesPrimary),
      musclesSecondary: Value(musclesSecondary),
      equipment: Value(equipment),
      localImagePath: localImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(localImagePath),
      series: Value(series),
      repsRange: Value(repsRange),
      suggestedRestSeconds: suggestedRestSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedRestSeconds),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      exerciseIndex: Value(exerciseIndex),
    );
  }

  factory RoutineExercise.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RoutineExercise(
      id: serializer.fromJson<String>(json['id']),
      dayId: serializer.fromJson<String>(json['dayId']),
      libraryId: serializer.fromJson<String>(json['libraryId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      musclesPrimary: serializer.fromJson<List<String>>(json['musclesPrimary']),
      musclesSecondary:
          serializer.fromJson<List<String>>(json['musclesSecondary']),
      equipment: serializer.fromJson<String>(json['equipment']),
      localImagePath: serializer.fromJson<String?>(json['localImagePath']),
      series: serializer.fromJson<int>(json['series']),
      repsRange: serializer.fromJson<String>(json['repsRange']),
      suggestedRestSeconds:
          serializer.fromJson<int?>(json['suggestedRestSeconds']),
      notes: serializer.fromJson<String?>(json['notes']),
      exerciseIndex: serializer.fromJson<int>(json['exerciseIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'dayId': serializer.toJson<String>(dayId),
      'libraryId': serializer.toJson<String>(libraryId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'musclesPrimary': serializer.toJson<List<String>>(musclesPrimary),
      'musclesSecondary': serializer.toJson<List<String>>(musclesSecondary),
      'equipment': serializer.toJson<String>(equipment),
      'localImagePath': serializer.toJson<String?>(localImagePath),
      'series': serializer.toJson<int>(series),
      'repsRange': serializer.toJson<String>(repsRange),
      'suggestedRestSeconds': serializer.toJson<int?>(suggestedRestSeconds),
      'notes': serializer.toJson<String?>(notes),
      'exerciseIndex': serializer.toJson<int>(exerciseIndex),
    };
  }

  RoutineExercise copyWith(
          {String? id,
          String? dayId,
          String? libraryId,
          String? name,
          Value<String?> description = const Value.absent(),
          List<String>? musclesPrimary,
          List<String>? musclesSecondary,
          String? equipment,
          Value<String?> localImagePath = const Value.absent(),
          int? series,
          String? repsRange,
          Value<int?> suggestedRestSeconds = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          int? exerciseIndex}) =>
      RoutineExercise(
        id: id ?? this.id,
        dayId: dayId ?? this.dayId,
        libraryId: libraryId ?? this.libraryId,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        musclesPrimary: musclesPrimary ?? this.musclesPrimary,
        musclesSecondary: musclesSecondary ?? this.musclesSecondary,
        equipment: equipment ?? this.equipment,
        localImagePath:
            localImagePath.present ? localImagePath.value : this.localImagePath,
        series: series ?? this.series,
        repsRange: repsRange ?? this.repsRange,
        suggestedRestSeconds: suggestedRestSeconds.present
            ? suggestedRestSeconds.value
            : this.suggestedRestSeconds,
        notes: notes.present ? notes.value : this.notes,
        exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      );
  RoutineExercise copyWithCompanion(RoutineExercisesCompanion data) {
    return RoutineExercise(
      id: data.id.present ? data.id.value : this.id,
      dayId: data.dayId.present ? data.dayId.value : this.dayId,
      libraryId: data.libraryId.present ? data.libraryId.value : this.libraryId,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      musclesPrimary: data.musclesPrimary.present
          ? data.musclesPrimary.value
          : this.musclesPrimary,
      musclesSecondary: data.musclesSecondary.present
          ? data.musclesSecondary.value
          : this.musclesSecondary,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      localImagePath: data.localImagePath.present
          ? data.localImagePath.value
          : this.localImagePath,
      series: data.series.present ? data.series.value : this.series,
      repsRange: data.repsRange.present ? data.repsRange.value : this.repsRange,
      suggestedRestSeconds: data.suggestedRestSeconds.present
          ? data.suggestedRestSeconds.value
          : this.suggestedRestSeconds,
      notes: data.notes.present ? data.notes.value : this.notes,
      exerciseIndex: data.exerciseIndex.present
          ? data.exerciseIndex.value
          : this.exerciseIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RoutineExercise(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('libraryId: $libraryId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('musclesPrimary: $musclesPrimary, ')
          ..write('musclesSecondary: $musclesSecondary, ')
          ..write('equipment: $equipment, ')
          ..write('localImagePath: $localImagePath, ')
          ..write('series: $series, ')
          ..write('repsRange: $repsRange, ')
          ..write('suggestedRestSeconds: $suggestedRestSeconds, ')
          ..write('notes: $notes, ')
          ..write('exerciseIndex: $exerciseIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      dayId,
      libraryId,
      name,
      description,
      musclesPrimary,
      musclesSecondary,
      equipment,
      localImagePath,
      series,
      repsRange,
      suggestedRestSeconds,
      notes,
      exerciseIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RoutineExercise &&
          other.id == this.id &&
          other.dayId == this.dayId &&
          other.libraryId == this.libraryId &&
          other.name == this.name &&
          other.description == this.description &&
          other.musclesPrimary == this.musclesPrimary &&
          other.musclesSecondary == this.musclesSecondary &&
          other.equipment == this.equipment &&
          other.localImagePath == this.localImagePath &&
          other.series == this.series &&
          other.repsRange == this.repsRange &&
          other.suggestedRestSeconds == this.suggestedRestSeconds &&
          other.notes == this.notes &&
          other.exerciseIndex == this.exerciseIndex);
}

class RoutineExercisesCompanion extends UpdateCompanion<RoutineExercise> {
  final Value<String> id;
  final Value<String> dayId;
  final Value<String> libraryId;
  final Value<String> name;
  final Value<String?> description;
  final Value<List<String>> musclesPrimary;
  final Value<List<String>> musclesSecondary;
  final Value<String> equipment;
  final Value<String?> localImagePath;
  final Value<int> series;
  final Value<String> repsRange;
  final Value<int?> suggestedRestSeconds;
  final Value<String?> notes;
  final Value<int> exerciseIndex;
  final Value<int> rowid;
  const RoutineExercisesCompanion({
    this.id = const Value.absent(),
    this.dayId = const Value.absent(),
    this.libraryId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.musclesPrimary = const Value.absent(),
    this.musclesSecondary = const Value.absent(),
    this.equipment = const Value.absent(),
    this.localImagePath = const Value.absent(),
    this.series = const Value.absent(),
    this.repsRange = const Value.absent(),
    this.suggestedRestSeconds = const Value.absent(),
    this.notes = const Value.absent(),
    this.exerciseIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutineExercisesCompanion.insert({
    required String id,
    required String dayId,
    required String libraryId,
    required String name,
    this.description = const Value.absent(),
    required List<String> musclesPrimary,
    required List<String> musclesSecondary,
    required String equipment,
    this.localImagePath = const Value.absent(),
    required int series,
    required String repsRange,
    this.suggestedRestSeconds = const Value.absent(),
    this.notes = const Value.absent(),
    required int exerciseIndex,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        dayId = Value(dayId),
        libraryId = Value(libraryId),
        name = Value(name),
        musclesPrimary = Value(musclesPrimary),
        musclesSecondary = Value(musclesSecondary),
        equipment = Value(equipment),
        series = Value(series),
        repsRange = Value(repsRange),
        exerciseIndex = Value(exerciseIndex);
  static Insertable<RoutineExercise> custom({
    Expression<String>? id,
    Expression<String>? dayId,
    Expression<String>? libraryId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? musclesPrimary,
    Expression<String>? musclesSecondary,
    Expression<String>? equipment,
    Expression<String>? localImagePath,
    Expression<int>? series,
    Expression<String>? repsRange,
    Expression<int>? suggestedRestSeconds,
    Expression<String>? notes,
    Expression<int>? exerciseIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dayId != null) 'day_id': dayId,
      if (libraryId != null) 'library_id': libraryId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (musclesPrimary != null) 'muscles_primary': musclesPrimary,
      if (musclesSecondary != null) 'muscles_secondary': musclesSecondary,
      if (equipment != null) 'equipment': equipment,
      if (localImagePath != null) 'local_image_path': localImagePath,
      if (series != null) 'series': series,
      if (repsRange != null) 'reps_range': repsRange,
      if (suggestedRestSeconds != null)
        'suggested_rest_seconds': suggestedRestSeconds,
      if (notes != null) 'notes': notes,
      if (exerciseIndex != null) 'exercise_index': exerciseIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutineExercisesCompanion copyWith(
      {Value<String>? id,
      Value<String>? dayId,
      Value<String>? libraryId,
      Value<String>? name,
      Value<String?>? description,
      Value<List<String>>? musclesPrimary,
      Value<List<String>>? musclesSecondary,
      Value<String>? equipment,
      Value<String?>? localImagePath,
      Value<int>? series,
      Value<String>? repsRange,
      Value<int?>? suggestedRestSeconds,
      Value<String?>? notes,
      Value<int>? exerciseIndex,
      Value<int>? rowid}) {
    return RoutineExercisesCompanion(
      id: id ?? this.id,
      dayId: dayId ?? this.dayId,
      libraryId: libraryId ?? this.libraryId,
      name: name ?? this.name,
      description: description ?? this.description,
      musclesPrimary: musclesPrimary ?? this.musclesPrimary,
      musclesSecondary: musclesSecondary ?? this.musclesSecondary,
      equipment: equipment ?? this.equipment,
      localImagePath: localImagePath ?? this.localImagePath,
      series: series ?? this.series,
      repsRange: repsRange ?? this.repsRange,
      suggestedRestSeconds: suggestedRestSeconds ?? this.suggestedRestSeconds,
      notes: notes ?? this.notes,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dayId.present) {
      map['day_id'] = Variable<String>(dayId.value);
    }
    if (libraryId.present) {
      map['library_id'] = Variable<String>(libraryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (musclesPrimary.present) {
      map['muscles_primary'] = Variable<String>($RoutineExercisesTable
          .$convertermusclesPrimary
          .toSql(musclesPrimary.value));
    }
    if (musclesSecondary.present) {
      map['muscles_secondary'] = Variable<String>($RoutineExercisesTable
          .$convertermusclesSecondary
          .toSql(musclesSecondary.value));
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (localImagePath.present) {
      map['local_image_path'] = Variable<String>(localImagePath.value);
    }
    if (series.present) {
      map['series'] = Variable<int>(series.value);
    }
    if (repsRange.present) {
      map['reps_range'] = Variable<String>(repsRange.value);
    }
    if (suggestedRestSeconds.present) {
      map['suggested_rest_seconds'] = Variable<int>(suggestedRestSeconds.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (exerciseIndex.present) {
      map['exercise_index'] = Variable<int>(exerciseIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutineExercisesCompanion(')
          ..write('id: $id, ')
          ..write('dayId: $dayId, ')
          ..write('libraryId: $libraryId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('musclesPrimary: $musclesPrimary, ')
          ..write('musclesSecondary: $musclesSecondary, ')
          ..write('equipment: $equipment, ')
          ..write('localImagePath: $localImagePath, ')
          ..write('series: $series, ')
          ..write('repsRange: $repsRange, ')
          ..write('suggestedRestSeconds: $suggestedRestSeconds, ')
          ..write('notes: $notes, ')
          ..write('exerciseIndex: $exerciseIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _routineIdMeta =
      const VerificationMeta('routineId');
  @override
  late final GeneratedColumn<String> routineId = GeneratedColumn<String>(
      'routine_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startTimeMeta =
      const VerificationMeta('startTime');
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
      'start_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, routineId, startTime, durationSeconds, completedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<Session> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('routine_id')) {
      context.handle(_routineIdMeta,
          routineId.isAcceptableOrUnknown(data['routine_id']!, _routineIdMeta));
    }
    if (data.containsKey('start_time')) {
      context.handle(_startTimeMeta,
          startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta));
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      routineId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}routine_id']),
      startTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_time'])!,
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds']),
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String id;
  final String? routineId;
  final DateTime startTime;
  final int? durationSeconds;
  final DateTime? completedAt;
  const Session(
      {required this.id,
      this.routineId,
      required this.startTime,
      this.durationSeconds,
      this.completedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || routineId != null) {
      map['routine_id'] = Variable<String>(routineId);
    }
    map['start_time'] = Variable<DateTime>(startTime);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      routineId: routineId == null && nullToAbsent
          ? const Value.absent()
          : Value(routineId),
      startTime: Value(startTime),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<String>(json['id']),
      routineId: serializer.fromJson<String?>(json['routineId']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'routineId': serializer.toJson<String?>(routineId),
      'startTime': serializer.toJson<DateTime>(startTime),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  Session copyWith(
          {String? id,
          Value<String?> routineId = const Value.absent(),
          DateTime? startTime,
          Value<int?> durationSeconds = const Value.absent(),
          Value<DateTime?> completedAt = const Value.absent()}) =>
      Session(
        id: id ?? this.id,
        routineId: routineId.present ? routineId.value : this.routineId,
        startTime: startTime ?? this.startTime,
        durationSeconds: durationSeconds.present
            ? durationSeconds.value
            : this.durationSeconds,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
      );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      routineId: data.routineId.present ? data.routineId.value : this.routineId,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('startTime: $startTime, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, routineId, startTime, durationSeconds, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.routineId == this.routineId &&
          other.startTime == this.startTime &&
          other.durationSeconds == this.durationSeconds &&
          other.completedAt == this.completedAt);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> id;
  final Value<String?> routineId;
  final Value<DateTime> startTime;
  final Value<int?> durationSeconds;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.routineId = const Value.absent(),
    this.startTime = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    this.routineId = const Value.absent(),
    required DateTime startTime,
    this.durationSeconds = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        startTime = Value(startTime);
  static Insertable<Session> custom({
    Expression<String>? id,
    Expression<String>? routineId,
    Expression<DateTime>? startTime,
    Expression<int>? durationSeconds,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (routineId != null) 'routine_id': routineId,
      if (startTime != null) 'start_time': startTime,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith(
      {Value<String>? id,
      Value<String?>? routineId,
      Value<DateTime>? startTime,
      Value<int?>? durationSeconds,
      Value<DateTime?>? completedAt,
      Value<int>? rowid}) {
    return SessionsCompanion(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      startTime: startTime ?? this.startTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (routineId.present) {
      map['routine_id'] = Variable<String>(routineId.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('routineId: $routineId, ')
          ..write('startTime: $startTime, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionExercisesTable extends SessionExercises
    with TableInfo<$SessionExercisesTable, SessionExercise> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionExercisesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES sessions (id) ON DELETE CASCADE'));
  static const VerificationMeta _libraryIdMeta =
      const VerificationMeta('libraryId');
  @override
  late final GeneratedColumn<String> libraryId = GeneratedColumn<String>(
      'library_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
      musclesPrimary = GeneratedColumn<String>(
              'muscles_primary', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<String>>(
              $SessionExercisesTable.$convertermusclesPrimary);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String>
      musclesSecondary = GeneratedColumn<String>(
              'muscles_secondary', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<String>>(
              $SessionExercisesTable.$convertermusclesSecondary);
  static const VerificationMeta _equipmentMeta =
      const VerificationMeta('equipment');
  @override
  late final GeneratedColumn<String> equipment = GeneratedColumn<String>(
      'equipment', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _exerciseIndexMeta =
      const VerificationMeta('exerciseIndex');
  @override
  late final GeneratedColumn<int> exerciseIndex = GeneratedColumn<int>(
      'exercise_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isTargetMeta =
      const VerificationMeta('isTarget');
  @override
  late final GeneratedColumn<bool> isTarget = GeneratedColumn<bool>(
      'is_target', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_target" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionId,
        libraryId,
        name,
        musclesPrimary,
        musclesSecondary,
        equipment,
        notes,
        exerciseIndex,
        isTarget
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_exercises';
  @override
  VerificationContext validateIntegrity(Insertable<SessionExercise> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('library_id')) {
      context.handle(_libraryIdMeta,
          libraryId.isAcceptableOrUnknown(data['library_id']!, _libraryIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('equipment')) {
      context.handle(_equipmentMeta,
          equipment.isAcceptableOrUnknown(data['equipment']!, _equipmentMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('exercise_index')) {
      context.handle(
          _exerciseIndexMeta,
          exerciseIndex.isAcceptableOrUnknown(
              data['exercise_index']!, _exerciseIndexMeta));
    } else if (isInserting) {
      context.missing(_exerciseIndexMeta);
    }
    if (data.containsKey('is_target')) {
      context.handle(_isTargetMeta,
          isTarget.isAcceptableOrUnknown(data['is_target']!, _isTargetMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionExercise map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionExercise(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id'])!,
      libraryId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}library_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      musclesPrimary: $SessionExercisesTable.$convertermusclesPrimary.fromSql(
          attachedDatabase.typeMapping.read(
              DriftSqlType.string, data['${effectivePrefix}muscles_primary'])!),
      musclesSecondary: $SessionExercisesTable.$convertermusclesSecondary
          .fromSql(attachedDatabase.typeMapping.read(DriftSqlType.string,
              data['${effectivePrefix}muscles_secondary'])!),
      equipment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}equipment']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      exerciseIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}exercise_index'])!,
      isTarget: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_target'])!,
    );
  }

  @override
  $SessionExercisesTable createAlias(String alias) {
    return $SessionExercisesTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertermusclesPrimary =
      const StringListConverter();
  static TypeConverter<List<String>, String> $convertermusclesSecondary =
      const StringListConverter();
}

class SessionExercise extends DataClass implements Insertable<SessionExercise> {
  final String id;
  final String sessionId;
  final String? libraryId;
  final String name;
  final List<String> musclesPrimary;
  final List<String> musclesSecondary;
  final String? equipment;
  final String? notes;
  final int exerciseIndex;
  final bool isTarget;
  const SessionExercise(
      {required this.id,
      required this.sessionId,
      this.libraryId,
      required this.name,
      required this.musclesPrimary,
      required this.musclesSecondary,
      this.equipment,
      this.notes,
      required this.exerciseIndex,
      required this.isTarget});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    if (!nullToAbsent || libraryId != null) {
      map['library_id'] = Variable<String>(libraryId);
    }
    map['name'] = Variable<String>(name);
    {
      map['muscles_primary'] = Variable<String>($SessionExercisesTable
          .$convertermusclesPrimary
          .toSql(musclesPrimary));
    }
    {
      map['muscles_secondary'] = Variable<String>($SessionExercisesTable
          .$convertermusclesSecondary
          .toSql(musclesSecondary));
    }
    if (!nullToAbsent || equipment != null) {
      map['equipment'] = Variable<String>(equipment);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['exercise_index'] = Variable<int>(exerciseIndex);
    map['is_target'] = Variable<bool>(isTarget);
    return map;
  }

  SessionExercisesCompanion toCompanion(bool nullToAbsent) {
    return SessionExercisesCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      libraryId: libraryId == null && nullToAbsent
          ? const Value.absent()
          : Value(libraryId),
      name: Value(name),
      musclesPrimary: Value(musclesPrimary),
      musclesSecondary: Value(musclesSecondary),
      equipment: equipment == null && nullToAbsent
          ? const Value.absent()
          : Value(equipment),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      exerciseIndex: Value(exerciseIndex),
      isTarget: Value(isTarget),
    );
  }

  factory SessionExercise.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionExercise(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      libraryId: serializer.fromJson<String?>(json['libraryId']),
      name: serializer.fromJson<String>(json['name']),
      musclesPrimary: serializer.fromJson<List<String>>(json['musclesPrimary']),
      musclesSecondary:
          serializer.fromJson<List<String>>(json['musclesSecondary']),
      equipment: serializer.fromJson<String?>(json['equipment']),
      notes: serializer.fromJson<String?>(json['notes']),
      exerciseIndex: serializer.fromJson<int>(json['exerciseIndex']),
      isTarget: serializer.fromJson<bool>(json['isTarget']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'libraryId': serializer.toJson<String?>(libraryId),
      'name': serializer.toJson<String>(name),
      'musclesPrimary': serializer.toJson<List<String>>(musclesPrimary),
      'musclesSecondary': serializer.toJson<List<String>>(musclesSecondary),
      'equipment': serializer.toJson<String?>(equipment),
      'notes': serializer.toJson<String?>(notes),
      'exerciseIndex': serializer.toJson<int>(exerciseIndex),
      'isTarget': serializer.toJson<bool>(isTarget),
    };
  }

  SessionExercise copyWith(
          {String? id,
          String? sessionId,
          Value<String?> libraryId = const Value.absent(),
          String? name,
          List<String>? musclesPrimary,
          List<String>? musclesSecondary,
          Value<String?> equipment = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          int? exerciseIndex,
          bool? isTarget}) =>
      SessionExercise(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        libraryId: libraryId.present ? libraryId.value : this.libraryId,
        name: name ?? this.name,
        musclesPrimary: musclesPrimary ?? this.musclesPrimary,
        musclesSecondary: musclesSecondary ?? this.musclesSecondary,
        equipment: equipment.present ? equipment.value : this.equipment,
        notes: notes.present ? notes.value : this.notes,
        exerciseIndex: exerciseIndex ?? this.exerciseIndex,
        isTarget: isTarget ?? this.isTarget,
      );
  SessionExercise copyWithCompanion(SessionExercisesCompanion data) {
    return SessionExercise(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      libraryId: data.libraryId.present ? data.libraryId.value : this.libraryId,
      name: data.name.present ? data.name.value : this.name,
      musclesPrimary: data.musclesPrimary.present
          ? data.musclesPrimary.value
          : this.musclesPrimary,
      musclesSecondary: data.musclesSecondary.present
          ? data.musclesSecondary.value
          : this.musclesSecondary,
      equipment: data.equipment.present ? data.equipment.value : this.equipment,
      notes: data.notes.present ? data.notes.value : this.notes,
      exerciseIndex: data.exerciseIndex.present
          ? data.exerciseIndex.value
          : this.exerciseIndex,
      isTarget: data.isTarget.present ? data.isTarget.value : this.isTarget,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionExercise(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('libraryId: $libraryId, ')
          ..write('name: $name, ')
          ..write('musclesPrimary: $musclesPrimary, ')
          ..write('musclesSecondary: $musclesSecondary, ')
          ..write('equipment: $equipment, ')
          ..write('notes: $notes, ')
          ..write('exerciseIndex: $exerciseIndex, ')
          ..write('isTarget: $isTarget')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      sessionId,
      libraryId,
      name,
      musclesPrimary,
      musclesSecondary,
      equipment,
      notes,
      exerciseIndex,
      isTarget);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionExercise &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.libraryId == this.libraryId &&
          other.name == this.name &&
          other.musclesPrimary == this.musclesPrimary &&
          other.musclesSecondary == this.musclesSecondary &&
          other.equipment == this.equipment &&
          other.notes == this.notes &&
          other.exerciseIndex == this.exerciseIndex &&
          other.isTarget == this.isTarget);
}

class SessionExercisesCompanion extends UpdateCompanion<SessionExercise> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String?> libraryId;
  final Value<String> name;
  final Value<List<String>> musclesPrimary;
  final Value<List<String>> musclesSecondary;
  final Value<String?> equipment;
  final Value<String?> notes;
  final Value<int> exerciseIndex;
  final Value<bool> isTarget;
  final Value<int> rowid;
  const SessionExercisesCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.libraryId = const Value.absent(),
    this.name = const Value.absent(),
    this.musclesPrimary = const Value.absent(),
    this.musclesSecondary = const Value.absent(),
    this.equipment = const Value.absent(),
    this.notes = const Value.absent(),
    this.exerciseIndex = const Value.absent(),
    this.isTarget = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionExercisesCompanion.insert({
    required String id,
    required String sessionId,
    this.libraryId = const Value.absent(),
    required String name,
    required List<String> musclesPrimary,
    required List<String> musclesSecondary,
    this.equipment = const Value.absent(),
    this.notes = const Value.absent(),
    required int exerciseIndex,
    this.isTarget = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionId = Value(sessionId),
        name = Value(name),
        musclesPrimary = Value(musclesPrimary),
        musclesSecondary = Value(musclesSecondary),
        exerciseIndex = Value(exerciseIndex);
  static Insertable<SessionExercise> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? libraryId,
    Expression<String>? name,
    Expression<String>? musclesPrimary,
    Expression<String>? musclesSecondary,
    Expression<String>? equipment,
    Expression<String>? notes,
    Expression<int>? exerciseIndex,
    Expression<bool>? isTarget,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (libraryId != null) 'library_id': libraryId,
      if (name != null) 'name': name,
      if (musclesPrimary != null) 'muscles_primary': musclesPrimary,
      if (musclesSecondary != null) 'muscles_secondary': musclesSecondary,
      if (equipment != null) 'equipment': equipment,
      if (notes != null) 'notes': notes,
      if (exerciseIndex != null) 'exercise_index': exerciseIndex,
      if (isTarget != null) 'is_target': isTarget,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionExercisesCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionId,
      Value<String?>? libraryId,
      Value<String>? name,
      Value<List<String>>? musclesPrimary,
      Value<List<String>>? musclesSecondary,
      Value<String?>? equipment,
      Value<String?>? notes,
      Value<int>? exerciseIndex,
      Value<bool>? isTarget,
      Value<int>? rowid}) {
    return SessionExercisesCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      libraryId: libraryId ?? this.libraryId,
      name: name ?? this.name,
      musclesPrimary: musclesPrimary ?? this.musclesPrimary,
      musclesSecondary: musclesSecondary ?? this.musclesSecondary,
      equipment: equipment ?? this.equipment,
      notes: notes ?? this.notes,
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      isTarget: isTarget ?? this.isTarget,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (libraryId.present) {
      map['library_id'] = Variable<String>(libraryId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (musclesPrimary.present) {
      map['muscles_primary'] = Variable<String>($SessionExercisesTable
          .$convertermusclesPrimary
          .toSql(musclesPrimary.value));
    }
    if (musclesSecondary.present) {
      map['muscles_secondary'] = Variable<String>($SessionExercisesTable
          .$convertermusclesSecondary
          .toSql(musclesSecondary.value));
    }
    if (equipment.present) {
      map['equipment'] = Variable<String>(equipment.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (exerciseIndex.present) {
      map['exercise_index'] = Variable<int>(exerciseIndex.value);
    }
    if (isTarget.present) {
      map['is_target'] = Variable<bool>(isTarget.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionExercisesCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('libraryId: $libraryId, ')
          ..write('name: $name, ')
          ..write('musclesPrimary: $musclesPrimary, ')
          ..write('musclesSecondary: $musclesSecondary, ')
          ..write('equipment: $equipment, ')
          ..write('notes: $notes, ')
          ..write('exerciseIndex: $exerciseIndex, ')
          ..write('isTarget: $isTarget, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSetsTable extends WorkoutSets
    with TableInfo<$WorkoutSetsTable, WorkoutSet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionExerciseIdMeta =
      const VerificationMeta('sessionExerciseId');
  @override
  late final GeneratedColumn<String> sessionExerciseId =
      GeneratedColumn<String>('session_exercise_id', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'REFERENCES session_exercises (id) ON DELETE CASCADE'));
  static const VerificationMeta _setIndexMeta =
      const VerificationMeta('setIndex');
  @override
  late final GeneratedColumn<int> setIndex = GeneratedColumn<int>(
      'set_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
      'weight', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
      'reps', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _completedMeta =
      const VerificationMeta('completed');
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
      'completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("completed" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _rpeMeta = const VerificationMeta('rpe');
  @override
  late final GeneratedColumn<int> rpe = GeneratedColumn<int>(
      'rpe', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _restSecondsMeta =
      const VerificationMeta('restSeconds');
  @override
  late final GeneratedColumn<int> restSeconds = GeneratedColumn<int>(
      'rest_seconds', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _isFailureMeta =
      const VerificationMeta('isFailure');
  @override
  late final GeneratedColumn<bool> isFailure = GeneratedColumn<bool>(
      'is_failure', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_failure" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isDropsetMeta =
      const VerificationMeta('isDropset');
  @override
  late final GeneratedColumn<bool> isDropset = GeneratedColumn<bool>(
      'is_dropset', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_dropset" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isWarmupMeta =
      const VerificationMeta('isWarmup');
  @override
  late final GeneratedColumn<bool> isWarmup = GeneratedColumn<bool>(
      'is_warmup', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_warmup" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        sessionExerciseId,
        setIndex,
        weight,
        reps,
        completed,
        rpe,
        notes,
        restSeconds,
        isFailure,
        isDropset,
        isWarmup
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_sets';
  @override
  VerificationContext validateIntegrity(Insertable<WorkoutSet> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_exercise_id')) {
      context.handle(
          _sessionExerciseIdMeta,
          sessionExerciseId.isAcceptableOrUnknown(
              data['session_exercise_id']!, _sessionExerciseIdMeta));
    } else if (isInserting) {
      context.missing(_sessionExerciseIdMeta);
    }
    if (data.containsKey('set_index')) {
      context.handle(_setIndexMeta,
          setIndex.isAcceptableOrUnknown(data['set_index']!, _setIndexMeta));
    } else if (isInserting) {
      context.missing(_setIndexMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(_weightMeta,
          weight.isAcceptableOrUnknown(data['weight']!, _weightMeta));
    } else if (isInserting) {
      context.missing(_weightMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
          _repsMeta, reps.isAcceptableOrUnknown(data['reps']!, _repsMeta));
    } else if (isInserting) {
      context.missing(_repsMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(_completedMeta,
          completed.isAcceptableOrUnknown(data['completed']!, _completedMeta));
    }
    if (data.containsKey('rpe')) {
      context.handle(
          _rpeMeta, rpe.isAcceptableOrUnknown(data['rpe']!, _rpeMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('rest_seconds')) {
      context.handle(
          _restSecondsMeta,
          restSeconds.isAcceptableOrUnknown(
              data['rest_seconds']!, _restSecondsMeta));
    }
    if (data.containsKey('is_failure')) {
      context.handle(_isFailureMeta,
          isFailure.isAcceptableOrUnknown(data['is_failure']!, _isFailureMeta));
    }
    if (data.containsKey('is_dropset')) {
      context.handle(_isDropsetMeta,
          isDropset.isAcceptableOrUnknown(data['is_dropset']!, _isDropsetMeta));
    }
    if (data.containsKey('is_warmup')) {
      context.handle(_isWarmupMeta,
          isWarmup.isAcceptableOrUnknown(data['is_warmup']!, _isWarmupMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSet(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      sessionExerciseId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}session_exercise_id'])!,
      setIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}set_index'])!,
      weight: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}weight'])!,
      reps: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reps'])!,
      completed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}completed'])!,
      rpe: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rpe']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      restSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rest_seconds']),
      isFailure: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_failure'])!,
      isDropset: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_dropset'])!,
      isWarmup: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_warmup'])!,
    );
  }

  @override
  $WorkoutSetsTable createAlias(String alias) {
    return $WorkoutSetsTable(attachedDatabase, alias);
  }
}

class WorkoutSet extends DataClass implements Insertable<WorkoutSet> {
  final String id;
  final String sessionExerciseId;
  final int setIndex;
  final double weight;
  final int reps;
  final bool completed;
  final int? rpe;
  final String? notes;
  final int? restSeconds;
  final bool isFailure;
  final bool isDropset;
  final bool isWarmup;
  const WorkoutSet(
      {required this.id,
      required this.sessionExerciseId,
      required this.setIndex,
      required this.weight,
      required this.reps,
      required this.completed,
      this.rpe,
      this.notes,
      this.restSeconds,
      required this.isFailure,
      required this.isDropset,
      required this.isWarmup});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_exercise_id'] = Variable<String>(sessionExerciseId);
    map['set_index'] = Variable<int>(setIndex);
    map['weight'] = Variable<double>(weight);
    map['reps'] = Variable<int>(reps);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || rpe != null) {
      map['rpe'] = Variable<int>(rpe);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || restSeconds != null) {
      map['rest_seconds'] = Variable<int>(restSeconds);
    }
    map['is_failure'] = Variable<bool>(isFailure);
    map['is_dropset'] = Variable<bool>(isDropset);
    map['is_warmup'] = Variable<bool>(isWarmup);
    return map;
  }

  WorkoutSetsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSetsCompanion(
      id: Value(id),
      sessionExerciseId: Value(sessionExerciseId),
      setIndex: Value(setIndex),
      weight: Value(weight),
      reps: Value(reps),
      completed: Value(completed),
      rpe: rpe == null && nullToAbsent ? const Value.absent() : Value(rpe),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      restSeconds: restSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(restSeconds),
      isFailure: Value(isFailure),
      isDropset: Value(isDropset),
      isWarmup: Value(isWarmup),
    );
  }

  factory WorkoutSet.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSet(
      id: serializer.fromJson<String>(json['id']),
      sessionExerciseId: serializer.fromJson<String>(json['sessionExerciseId']),
      setIndex: serializer.fromJson<int>(json['setIndex']),
      weight: serializer.fromJson<double>(json['weight']),
      reps: serializer.fromJson<int>(json['reps']),
      completed: serializer.fromJson<bool>(json['completed']),
      rpe: serializer.fromJson<int?>(json['rpe']),
      notes: serializer.fromJson<String?>(json['notes']),
      restSeconds: serializer.fromJson<int?>(json['restSeconds']),
      isFailure: serializer.fromJson<bool>(json['isFailure']),
      isDropset: serializer.fromJson<bool>(json['isDropset']),
      isWarmup: serializer.fromJson<bool>(json['isWarmup']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionExerciseId': serializer.toJson<String>(sessionExerciseId),
      'setIndex': serializer.toJson<int>(setIndex),
      'weight': serializer.toJson<double>(weight),
      'reps': serializer.toJson<int>(reps),
      'completed': serializer.toJson<bool>(completed),
      'rpe': serializer.toJson<int?>(rpe),
      'notes': serializer.toJson<String?>(notes),
      'restSeconds': serializer.toJson<int?>(restSeconds),
      'isFailure': serializer.toJson<bool>(isFailure),
      'isDropset': serializer.toJson<bool>(isDropset),
      'isWarmup': serializer.toJson<bool>(isWarmup),
    };
  }

  WorkoutSet copyWith(
          {String? id,
          String? sessionExerciseId,
          int? setIndex,
          double? weight,
          int? reps,
          bool? completed,
          Value<int?> rpe = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          Value<int?> restSeconds = const Value.absent(),
          bool? isFailure,
          bool? isDropset,
          bool? isWarmup}) =>
      WorkoutSet(
        id: id ?? this.id,
        sessionExerciseId: sessionExerciseId ?? this.sessionExerciseId,
        setIndex: setIndex ?? this.setIndex,
        weight: weight ?? this.weight,
        reps: reps ?? this.reps,
        completed: completed ?? this.completed,
        rpe: rpe.present ? rpe.value : this.rpe,
        notes: notes.present ? notes.value : this.notes,
        restSeconds: restSeconds.present ? restSeconds.value : this.restSeconds,
        isFailure: isFailure ?? this.isFailure,
        isDropset: isDropset ?? this.isDropset,
        isWarmup: isWarmup ?? this.isWarmup,
      );
  WorkoutSet copyWithCompanion(WorkoutSetsCompanion data) {
    return WorkoutSet(
      id: data.id.present ? data.id.value : this.id,
      sessionExerciseId: data.sessionExerciseId.present
          ? data.sessionExerciseId.value
          : this.sessionExerciseId,
      setIndex: data.setIndex.present ? data.setIndex.value : this.setIndex,
      weight: data.weight.present ? data.weight.value : this.weight,
      reps: data.reps.present ? data.reps.value : this.reps,
      completed: data.completed.present ? data.completed.value : this.completed,
      rpe: data.rpe.present ? data.rpe.value : this.rpe,
      notes: data.notes.present ? data.notes.value : this.notes,
      restSeconds:
          data.restSeconds.present ? data.restSeconds.value : this.restSeconds,
      isFailure: data.isFailure.present ? data.isFailure.value : this.isFailure,
      isDropset: data.isDropset.present ? data.isDropset.value : this.isDropset,
      isWarmup: data.isWarmup.present ? data.isWarmup.value : this.isWarmup,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSet(')
          ..write('id: $id, ')
          ..write('sessionExerciseId: $sessionExerciseId, ')
          ..write('setIndex: $setIndex, ')
          ..write('weight: $weight, ')
          ..write('reps: $reps, ')
          ..write('completed: $completed, ')
          ..write('rpe: $rpe, ')
          ..write('notes: $notes, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('isFailure: $isFailure, ')
          ..write('isDropset: $isDropset, ')
          ..write('isWarmup: $isWarmup')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionExerciseId, setIndex, weight, reps,
      completed, rpe, notes, restSeconds, isFailure, isDropset, isWarmup);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSet &&
          other.id == this.id &&
          other.sessionExerciseId == this.sessionExerciseId &&
          other.setIndex == this.setIndex &&
          other.weight == this.weight &&
          other.reps == this.reps &&
          other.completed == this.completed &&
          other.rpe == this.rpe &&
          other.notes == this.notes &&
          other.restSeconds == this.restSeconds &&
          other.isFailure == this.isFailure &&
          other.isDropset == this.isDropset &&
          other.isWarmup == this.isWarmup);
}

class WorkoutSetsCompanion extends UpdateCompanion<WorkoutSet> {
  final Value<String> id;
  final Value<String> sessionExerciseId;
  final Value<int> setIndex;
  final Value<double> weight;
  final Value<int> reps;
  final Value<bool> completed;
  final Value<int?> rpe;
  final Value<String?> notes;
  final Value<int?> restSeconds;
  final Value<bool> isFailure;
  final Value<bool> isDropset;
  final Value<bool> isWarmup;
  final Value<int> rowid;
  const WorkoutSetsCompanion({
    this.id = const Value.absent(),
    this.sessionExerciseId = const Value.absent(),
    this.setIndex = const Value.absent(),
    this.weight = const Value.absent(),
    this.reps = const Value.absent(),
    this.completed = const Value.absent(),
    this.rpe = const Value.absent(),
    this.notes = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.isFailure = const Value.absent(),
    this.isDropset = const Value.absent(),
    this.isWarmup = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutSetsCompanion.insert({
    required String id,
    required String sessionExerciseId,
    required int setIndex,
    required double weight,
    required int reps,
    this.completed = const Value.absent(),
    this.rpe = const Value.absent(),
    this.notes = const Value.absent(),
    this.restSeconds = const Value.absent(),
    this.isFailure = const Value.absent(),
    this.isDropset = const Value.absent(),
    this.isWarmup = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        sessionExerciseId = Value(sessionExerciseId),
        setIndex = Value(setIndex),
        weight = Value(weight),
        reps = Value(reps);
  static Insertable<WorkoutSet> custom({
    Expression<String>? id,
    Expression<String>? sessionExerciseId,
    Expression<int>? setIndex,
    Expression<double>? weight,
    Expression<int>? reps,
    Expression<bool>? completed,
    Expression<int>? rpe,
    Expression<String>? notes,
    Expression<int>? restSeconds,
    Expression<bool>? isFailure,
    Expression<bool>? isDropset,
    Expression<bool>? isWarmup,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionExerciseId != null) 'session_exercise_id': sessionExerciseId,
      if (setIndex != null) 'set_index': setIndex,
      if (weight != null) 'weight': weight,
      if (reps != null) 'reps': reps,
      if (completed != null) 'completed': completed,
      if (rpe != null) 'rpe': rpe,
      if (notes != null) 'notes': notes,
      if (restSeconds != null) 'rest_seconds': restSeconds,
      if (isFailure != null) 'is_failure': isFailure,
      if (isDropset != null) 'is_dropset': isDropset,
      if (isWarmup != null) 'is_warmup': isWarmup,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutSetsCompanion copyWith(
      {Value<String>? id,
      Value<String>? sessionExerciseId,
      Value<int>? setIndex,
      Value<double>? weight,
      Value<int>? reps,
      Value<bool>? completed,
      Value<int?>? rpe,
      Value<String?>? notes,
      Value<int?>? restSeconds,
      Value<bool>? isFailure,
      Value<bool>? isDropset,
      Value<bool>? isWarmup,
      Value<int>? rowid}) {
    return WorkoutSetsCompanion(
      id: id ?? this.id,
      sessionExerciseId: sessionExerciseId ?? this.sessionExerciseId,
      setIndex: setIndex ?? this.setIndex,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      completed: completed ?? this.completed,
      rpe: rpe ?? this.rpe,
      notes: notes ?? this.notes,
      restSeconds: restSeconds ?? this.restSeconds,
      isFailure: isFailure ?? this.isFailure,
      isDropset: isDropset ?? this.isDropset,
      isWarmup: isWarmup ?? this.isWarmup,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionExerciseId.present) {
      map['session_exercise_id'] = Variable<String>(sessionExerciseId.value);
    }
    if (setIndex.present) {
      map['set_index'] = Variable<int>(setIndex.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (rpe.present) {
      map['rpe'] = Variable<int>(rpe.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (restSeconds.present) {
      map['rest_seconds'] = Variable<int>(restSeconds.value);
    }
    if (isFailure.present) {
      map['is_failure'] = Variable<bool>(isFailure.value);
    }
    if (isDropset.present) {
      map['is_dropset'] = Variable<bool>(isDropset.value);
    }
    if (isWarmup.present) {
      map['is_warmup'] = Variable<bool>(isWarmup.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetsCompanion(')
          ..write('id: $id, ')
          ..write('sessionExerciseId: $sessionExerciseId, ')
          ..write('setIndex: $setIndex, ')
          ..write('weight: $weight, ')
          ..write('reps: $reps, ')
          ..write('completed: $completed, ')
          ..write('rpe: $rpe, ')
          ..write('notes: $notes, ')
          ..write('restSeconds: $restSeconds, ')
          ..write('isFailure: $isFailure, ')
          ..write('isDropset: $isDropset, ')
          ..write('isWarmup: $isWarmup, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExerciseNotesTable extends ExerciseNotes
    with TableInfo<$ExerciseNotesTable, ExerciseNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _exerciseNameMeta =
      const VerificationMeta('exerciseName');
  @override
  late final GeneratedColumn<String> exerciseName = GeneratedColumn<String>(
      'exercise_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [exerciseName, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_notes';
  @override
  VerificationContext validateIntegrity(Insertable<ExerciseNote> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('exercise_name')) {
      context.handle(
          _exerciseNameMeta,
          exerciseName.isAcceptableOrUnknown(
              data['exercise_name']!, _exerciseNameMeta));
    } else if (isInserting) {
      context.missing(_exerciseNameMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    } else if (isInserting) {
      context.missing(_noteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {exerciseName};
  @override
  ExerciseNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseNote(
      exerciseName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}exercise_name'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note'])!,
    );
  }

  @override
  $ExerciseNotesTable createAlias(String alias) {
    return $ExerciseNotesTable(attachedDatabase, alias);
  }
}

class ExerciseNote extends DataClass implements Insertable<ExerciseNote> {
  final String exerciseName;
  final String note;
  const ExerciseNote({required this.exerciseName, required this.note});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['exercise_name'] = Variable<String>(exerciseName);
    map['note'] = Variable<String>(note);
    return map;
  }

  ExerciseNotesCompanion toCompanion(bool nullToAbsent) {
    return ExerciseNotesCompanion(
      exerciseName: Value(exerciseName),
      note: Value(note),
    );
  }

  factory ExerciseNote.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseNote(
      exerciseName: serializer.fromJson<String>(json['exerciseName']),
      note: serializer.fromJson<String>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'exerciseName': serializer.toJson<String>(exerciseName),
      'note': serializer.toJson<String>(note),
    };
  }

  ExerciseNote copyWith({String? exerciseName, String? note}) => ExerciseNote(
        exerciseName: exerciseName ?? this.exerciseName,
        note: note ?? this.note,
      );
  ExerciseNote copyWithCompanion(ExerciseNotesCompanion data) {
    return ExerciseNote(
      exerciseName: data.exerciseName.present
          ? data.exerciseName.value
          : this.exerciseName,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseNote(')
          ..write('exerciseName: $exerciseName, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(exerciseName, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseNote &&
          other.exerciseName == this.exerciseName &&
          other.note == this.note);
}

class ExerciseNotesCompanion extends UpdateCompanion<ExerciseNote> {
  final Value<String> exerciseName;
  final Value<String> note;
  final Value<int> rowid;
  const ExerciseNotesCompanion({
    this.exerciseName = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExerciseNotesCompanion.insert({
    required String exerciseName,
    required String note,
    this.rowid = const Value.absent(),
  })  : exerciseName = Value(exerciseName),
        note = Value(note);
  static Insertable<ExerciseNote> custom({
    Expression<String>? exerciseName,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (exerciseName != null) 'exercise_name': exerciseName,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExerciseNotesCompanion copyWith(
      {Value<String>? exerciseName, Value<String>? note, Value<int>? rowid}) {
    return ExerciseNotesCompanion(
      exerciseName: exerciseName ?? this.exerciseName,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (exerciseName.present) {
      map['exercise_name'] = Variable<String>(exerciseName.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseNotesCompanion(')
          ..write('exerciseName: $exerciseName, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RoutinesTable routines = $RoutinesTable(this);
  late final $RoutineDaysTable routineDays = $RoutineDaysTable(this);
  late final $RoutineExercisesTable routineExercises =
      $RoutineExercisesTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $SessionExercisesTable sessionExercises =
      $SessionExercisesTable(this);
  late final $WorkoutSetsTable workoutSets = $WorkoutSetsTable(this);
  late final $ExerciseNotesTable exerciseNotes = $ExerciseNotesTable(this);
  late final Index sessionExercisesNameIdx = Index('session_exercises_name_idx',
      'CREATE INDEX session_exercises_name_idx ON session_exercises (name)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        routines,
        routineDays,
        routineExercises,
        sessions,
        sessionExercises,
        workoutSets,
        exerciseNotes,
        sessionExercisesNameIdx
      ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('routines',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('routine_days', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('routine_days',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('routine_exercises', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('sessions',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('session_exercises', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('session_exercises',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('workout_sets', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$RoutinesTableCreateCompanionBuilder = RoutinesCompanion Function({
  required String id,
  required String name,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$RoutinesTableUpdateCompanionBuilder = RoutinesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$RoutinesTableReferences
    extends BaseReferences<_$AppDatabase, $RoutinesTable, Routine> {
  $$RoutinesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RoutineDaysTable, List<RoutineDay>>
      _routineDaysRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.routineDays,
          aliasName:
              $_aliasNameGenerator(db.routines.id, db.routineDays.routineId));

  $$RoutineDaysTableProcessedTableManager get routineDaysRefs {
    final manager = $$RoutineDaysTableTableManager($_db, $_db.routineDays)
        .filter((f) => f.routineId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_routineDaysRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RoutinesTableFilterComposer
    extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> routineDaysRefs(
      Expression<bool> Function($$RoutineDaysTableFilterComposer f) f) {
    final $$RoutineDaysTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.routineDays,
        getReferencedColumn: (t) => t.routineId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoutineDaysTableFilterComposer(
              $db: $db,
              $table: $db.routineDays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RoutinesTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$RoutinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> routineDaysRefs<T extends Object>(
      Expression<T> Function($$RoutineDaysTableAnnotationComposer a) f) {
    final $$RoutineDaysTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.routineDays,
        getReferencedColumn: (t) => t.routineId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoutineDaysTableAnnotationComposer(
              $db: $db,
              $table: $db.routineDays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RoutinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RoutinesTable,
    Routine,
    $$RoutinesTableFilterComposer,
    $$RoutinesTableOrderingComposer,
    $$RoutinesTableAnnotationComposer,
    $$RoutinesTableCreateCompanionBuilder,
    $$RoutinesTableUpdateCompanionBuilder,
    (Routine, $$RoutinesTableReferences),
    Routine,
    PrefetchHooks Function({bool routineDaysRefs})> {
  $$RoutinesTableTableManager(_$AppDatabase db, $RoutinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoutinesCompanion(
            id: id,
            name: name,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              RoutinesCompanion.insert(
            id: id,
            name: name,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$RoutinesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({routineDaysRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (routineDaysRefs) db.routineDays],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (routineDaysRefs)
                    await $_getPrefetchedData<Routine, $RoutinesTable,
                            RoutineDay>(
                        currentTable: table,
                        referencedTable:
                            $$RoutinesTableReferences._routineDaysRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$RoutinesTableReferences(db, table, p0)
                                .routineDaysRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.routineId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$RoutinesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RoutinesTable,
    Routine,
    $$RoutinesTableFilterComposer,
    $$RoutinesTableOrderingComposer,
    $$RoutinesTableAnnotationComposer,
    $$RoutinesTableCreateCompanionBuilder,
    $$RoutinesTableUpdateCompanionBuilder,
    (Routine, $$RoutinesTableReferences),
    Routine,
    PrefetchHooks Function({bool routineDaysRefs})>;
typedef $$RoutineDaysTableCreateCompanionBuilder = RoutineDaysCompanion
    Function({
  required String id,
  required String routineId,
  required String name,
  Value<String> progressionType,
  required int dayIndex,
  Value<int> rowid,
});
typedef $$RoutineDaysTableUpdateCompanionBuilder = RoutineDaysCompanion
    Function({
  Value<String> id,
  Value<String> routineId,
  Value<String> name,
  Value<String> progressionType,
  Value<int> dayIndex,
  Value<int> rowid,
});

final class $$RoutineDaysTableReferences
    extends BaseReferences<_$AppDatabase, $RoutineDaysTable, RoutineDay> {
  $$RoutineDaysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RoutinesTable _routineIdTable(_$AppDatabase db) =>
      db.routines.createAlias(
          $_aliasNameGenerator(db.routineDays.routineId, db.routines.id));

  $$RoutinesTableProcessedTableManager get routineId {
    final $_column = $_itemColumn<String>('routine_id')!;

    final manager = $$RoutinesTableTableManager($_db, $_db.routines)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_routineIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$RoutineExercisesTable, List<RoutineExercise>>
      _routineExercisesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.routineExercises,
              aliasName: $_aliasNameGenerator(
                  db.routineDays.id, db.routineExercises.dayId));

  $$RoutineExercisesTableProcessedTableManager get routineExercisesRefs {
    final manager =
        $$RoutineExercisesTableTableManager($_db, $_db.routineExercises)
            .filter((f) => f.dayId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_routineExercisesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RoutineDaysTableFilterComposer
    extends Composer<_$AppDatabase, $RoutineDaysTable> {
  $$RoutineDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get progressionType => $composableBuilder(
      column: $table.progressionType,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dayIndex => $composableBuilder(
      column: $table.dayIndex, builder: (column) => ColumnFilters(column));

  $$RoutinesTableFilterComposer get routineId {
    final $$RoutinesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.routineId,
        referencedTable: $db.routines,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoutinesTableFilterComposer(
              $db: $db,
              $table: $db.routines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> routineExercisesRefs(
      Expression<bool> Function($$RoutineExercisesTableFilterComposer f) f) {
    final $$RoutineExercisesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.routineExercises,
        getReferencedColumn: (t) => t.dayId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoutineExercisesTableFilterComposer(
              $db: $db,
              $table: $db.routineExercises,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RoutineDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutineDaysTable> {
  $$RoutineDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get progressionType => $composableBuilder(
      column: $table.progressionType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dayIndex => $composableBuilder(
      column: $table.dayIndex, builder: (column) => ColumnOrderings(column));

  $$RoutinesTableOrderingComposer get routineId {
    final $$RoutinesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.routineId,
        referencedTable: $db.routines,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoutinesTableOrderingComposer(
              $db: $db,
              $table: $db.routines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RoutineDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutineDaysTable> {
  $$RoutineDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get progressionType => $composableBuilder(
      column: $table.progressionType, builder: (column) => column);

  GeneratedColumn<int> get dayIndex =>
      $composableBuilder(column: $table.dayIndex, builder: (column) => column);

  $$RoutinesTableAnnotationComposer get routineId {
    final $$RoutinesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.routineId,
        referencedTable: $db.routines,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoutinesTableAnnotationComposer(
              $db: $db,
              $table: $db.routines,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> routineExercisesRefs<T extends Object>(
      Expression<T> Function($$RoutineExercisesTableAnnotationComposer a) f) {
    final $$RoutineExercisesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.routineExercises,
        getReferencedColumn: (t) => t.dayId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoutineExercisesTableAnnotationComposer(
              $db: $db,
              $table: $db.routineExercises,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RoutineDaysTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RoutineDaysTable,
    RoutineDay,
    $$RoutineDaysTableFilterComposer,
    $$RoutineDaysTableOrderingComposer,
    $$RoutineDaysTableAnnotationComposer,
    $$RoutineDaysTableCreateCompanionBuilder,
    $$RoutineDaysTableUpdateCompanionBuilder,
    (RoutineDay, $$RoutineDaysTableReferences),
    RoutineDay,
    PrefetchHooks Function({bool routineId, bool routineExercisesRefs})> {
  $$RoutineDaysTableTableManager(_$AppDatabase db, $RoutineDaysTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutineDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutineDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutineDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> routineId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> progressionType = const Value.absent(),
            Value<int> dayIndex = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoutineDaysCompanion(
            id: id,
            routineId: routineId,
            name: name,
            progressionType: progressionType,
            dayIndex: dayIndex,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String routineId,
            required String name,
            Value<String> progressionType = const Value.absent(),
            required int dayIndex,
            Value<int> rowid = const Value.absent(),
          }) =>
              RoutineDaysCompanion.insert(
            id: id,
            routineId: routineId,
            name: name,
            progressionType: progressionType,
            dayIndex: dayIndex,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$RoutineDaysTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {routineId = false, routineExercisesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (routineExercisesRefs) db.routineExercises
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (routineId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.routineId,
                    referencedTable:
                        $$RoutineDaysTableReferences._routineIdTable(db),
                    referencedColumn:
                        $$RoutineDaysTableReferences._routineIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (routineExercisesRefs)
                    await $_getPrefetchedData<RoutineDay, $RoutineDaysTable,
                            RoutineExercise>(
                        currentTable: table,
                        referencedTable: $$RoutineDaysTableReferences
                            ._routineExercisesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$RoutineDaysTableReferences(db, table, p0)
                                .routineExercisesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.dayId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$RoutineDaysTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RoutineDaysTable,
    RoutineDay,
    $$RoutineDaysTableFilterComposer,
    $$RoutineDaysTableOrderingComposer,
    $$RoutineDaysTableAnnotationComposer,
    $$RoutineDaysTableCreateCompanionBuilder,
    $$RoutineDaysTableUpdateCompanionBuilder,
    (RoutineDay, $$RoutineDaysTableReferences),
    RoutineDay,
    PrefetchHooks Function({bool routineId, bool routineExercisesRefs})>;
typedef $$RoutineExercisesTableCreateCompanionBuilder
    = RoutineExercisesCompanion Function({
  required String id,
  required String dayId,
  required String libraryId,
  required String name,
  Value<String?> description,
  required List<String> musclesPrimary,
  required List<String> musclesSecondary,
  required String equipment,
  Value<String?> localImagePath,
  required int series,
  required String repsRange,
  Value<int?> suggestedRestSeconds,
  Value<String?> notes,
  required int exerciseIndex,
  Value<int> rowid,
});
typedef $$RoutineExercisesTableUpdateCompanionBuilder
    = RoutineExercisesCompanion Function({
  Value<String> id,
  Value<String> dayId,
  Value<String> libraryId,
  Value<String> name,
  Value<String?> description,
  Value<List<String>> musclesPrimary,
  Value<List<String>> musclesSecondary,
  Value<String> equipment,
  Value<String?> localImagePath,
  Value<int> series,
  Value<String> repsRange,
  Value<int?> suggestedRestSeconds,
  Value<String?> notes,
  Value<int> exerciseIndex,
  Value<int> rowid,
});

final class $$RoutineExercisesTableReferences extends BaseReferences<
    _$AppDatabase, $RoutineExercisesTable, RoutineExercise> {
  $$RoutineExercisesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $RoutineDaysTable _dayIdTable(_$AppDatabase db) =>
      db.routineDays.createAlias(
          $_aliasNameGenerator(db.routineExercises.dayId, db.routineDays.id));

  $$RoutineDaysTableProcessedTableManager get dayId {
    final $_column = $_itemColumn<String>('day_id')!;

    final manager = $$RoutineDaysTableTableManager($_db, $_db.routineDays)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_dayIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$RoutineExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $RoutineExercisesTable> {
  $$RoutineExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get libraryId => $composableBuilder(
      column: $table.libraryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
      get musclesPrimary => $composableBuilder(
          column: $table.musclesPrimary,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
      get musclesSecondary => $composableBuilder(
          column: $table.musclesSecondary,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get equipment => $composableBuilder(
      column: $table.equipment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localImagePath => $composableBuilder(
      column: $table.localImagePath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get series => $composableBuilder(
      column: $table.series, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get repsRange => $composableBuilder(
      column: $table.repsRange, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get suggestedRestSeconds => $composableBuilder(
      column: $table.suggestedRestSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get exerciseIndex => $composableBuilder(
      column: $table.exerciseIndex, builder: (column) => ColumnFilters(column));

  $$RoutineDaysTableFilterComposer get dayId {
    final $$RoutineDaysTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.dayId,
        referencedTable: $db.routineDays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoutineDaysTableFilterComposer(
              $db: $db,
              $table: $db.routineDays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RoutineExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutineExercisesTable> {
  $$RoutineExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get libraryId => $composableBuilder(
      column: $table.libraryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get musclesPrimary => $composableBuilder(
      column: $table.musclesPrimary,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get musclesSecondary => $composableBuilder(
      column: $table.musclesSecondary,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get equipment => $composableBuilder(
      column: $table.equipment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localImagePath => $composableBuilder(
      column: $table.localImagePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get series => $composableBuilder(
      column: $table.series, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get repsRange => $composableBuilder(
      column: $table.repsRange, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get suggestedRestSeconds => $composableBuilder(
      column: $table.suggestedRestSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get exerciseIndex => $composableBuilder(
      column: $table.exerciseIndex,
      builder: (column) => ColumnOrderings(column));

  $$RoutineDaysTableOrderingComposer get dayId {
    final $$RoutineDaysTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.dayId,
        referencedTable: $db.routineDays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoutineDaysTableOrderingComposer(
              $db: $db,
              $table: $db.routineDays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RoutineExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutineExercisesTable> {
  $$RoutineExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get libraryId =>
      $composableBuilder(column: $table.libraryId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get musclesPrimary =>
      $composableBuilder(
          column: $table.musclesPrimary, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get musclesSecondary =>
      $composableBuilder(
          column: $table.musclesSecondary, builder: (column) => column);

  GeneratedColumn<String> get equipment =>
      $composableBuilder(column: $table.equipment, builder: (column) => column);

  GeneratedColumn<String> get localImagePath => $composableBuilder(
      column: $table.localImagePath, builder: (column) => column);

  GeneratedColumn<int> get series =>
      $composableBuilder(column: $table.series, builder: (column) => column);

  GeneratedColumn<String> get repsRange =>
      $composableBuilder(column: $table.repsRange, builder: (column) => column);

  GeneratedColumn<int> get suggestedRestSeconds => $composableBuilder(
      column: $table.suggestedRestSeconds, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get exerciseIndex => $composableBuilder(
      column: $table.exerciseIndex, builder: (column) => column);

  $$RoutineDaysTableAnnotationComposer get dayId {
    final $$RoutineDaysTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.dayId,
        referencedTable: $db.routineDays,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RoutineDaysTableAnnotationComposer(
              $db: $db,
              $table: $db.routineDays,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RoutineExercisesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RoutineExercisesTable,
    RoutineExercise,
    $$RoutineExercisesTableFilterComposer,
    $$RoutineExercisesTableOrderingComposer,
    $$RoutineExercisesTableAnnotationComposer,
    $$RoutineExercisesTableCreateCompanionBuilder,
    $$RoutineExercisesTableUpdateCompanionBuilder,
    (RoutineExercise, $$RoutineExercisesTableReferences),
    RoutineExercise,
    PrefetchHooks Function({bool dayId})> {
  $$RoutineExercisesTableTableManager(
      _$AppDatabase db, $RoutineExercisesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutineExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutineExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutineExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> dayId = const Value.absent(),
            Value<String> libraryId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<List<String>> musclesPrimary = const Value.absent(),
            Value<List<String>> musclesSecondary = const Value.absent(),
            Value<String> equipment = const Value.absent(),
            Value<String?> localImagePath = const Value.absent(),
            Value<int> series = const Value.absent(),
            Value<String> repsRange = const Value.absent(),
            Value<int?> suggestedRestSeconds = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> exerciseIndex = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoutineExercisesCompanion(
            id: id,
            dayId: dayId,
            libraryId: libraryId,
            name: name,
            description: description,
            musclesPrimary: musclesPrimary,
            musclesSecondary: musclesSecondary,
            equipment: equipment,
            localImagePath: localImagePath,
            series: series,
            repsRange: repsRange,
            suggestedRestSeconds: suggestedRestSeconds,
            notes: notes,
            exerciseIndex: exerciseIndex,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String dayId,
            required String libraryId,
            required String name,
            Value<String?> description = const Value.absent(),
            required List<String> musclesPrimary,
            required List<String> musclesSecondary,
            required String equipment,
            Value<String?> localImagePath = const Value.absent(),
            required int series,
            required String repsRange,
            Value<int?> suggestedRestSeconds = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required int exerciseIndex,
            Value<int> rowid = const Value.absent(),
          }) =>
              RoutineExercisesCompanion.insert(
            id: id,
            dayId: dayId,
            libraryId: libraryId,
            name: name,
            description: description,
            musclesPrimary: musclesPrimary,
            musclesSecondary: musclesSecondary,
            equipment: equipment,
            localImagePath: localImagePath,
            series: series,
            repsRange: repsRange,
            suggestedRestSeconds: suggestedRestSeconds,
            notes: notes,
            exerciseIndex: exerciseIndex,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$RoutineExercisesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({dayId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (dayId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.dayId,
                    referencedTable:
                        $$RoutineExercisesTableReferences._dayIdTable(db),
                    referencedColumn:
                        $$RoutineExercisesTableReferences._dayIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$RoutineExercisesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RoutineExercisesTable,
    RoutineExercise,
    $$RoutineExercisesTableFilterComposer,
    $$RoutineExercisesTableOrderingComposer,
    $$RoutineExercisesTableAnnotationComposer,
    $$RoutineExercisesTableCreateCompanionBuilder,
    $$RoutineExercisesTableUpdateCompanionBuilder,
    (RoutineExercise, $$RoutineExercisesTableReferences),
    RoutineExercise,
    PrefetchHooks Function({bool dayId})>;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  Value<String?> routineId,
  required DateTime startTime,
  Value<int?> durationSeconds,
  Value<DateTime?> completedAt,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<String?> routineId,
  Value<DateTime> startTime,
  Value<int?> durationSeconds,
  Value<DateTime?> completedAt,
  Value<int> rowid,
});

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SessionExercisesTable, List<SessionExercise>>
      _sessionExercisesRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.sessionExercises,
              aliasName: $_aliasNameGenerator(
                  db.sessions.id, db.sessionExercises.sessionId));

  $$SessionExercisesTableProcessedTableManager get sessionExercisesRefs {
    final manager = $$SessionExercisesTableTableManager(
            $_db, $_db.sessionExercises)
        .filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_sessionExercisesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get routineId => $composableBuilder(
      column: $table.routineId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  Expression<bool> sessionExercisesRefs(
      Expression<bool> Function($$SessionExercisesTableFilterComposer f) f) {
    final $$SessionExercisesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sessionExercises,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionExercisesTableFilterComposer(
              $db: $db,
              $table: $db.sessionExercises,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get routineId => $composableBuilder(
      column: $table.routineId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get routineId =>
      $composableBuilder(column: $table.routineId, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  Expression<T> sessionExercisesRefs<T extends Object>(
      Expression<T> Function($$SessionExercisesTableAnnotationComposer a) f) {
    final $$SessionExercisesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.sessionExercises,
        getReferencedColumn: (t) => t.sessionId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionExercisesTableAnnotationComposer(
              $db: $db,
              $table: $db.sessionExercises,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionsTable,
    Session,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (Session, $$SessionsTableReferences),
    Session,
    PrefetchHooks Function({bool sessionExercisesRefs})> {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> routineId = const Value.absent(),
            Value<DateTime> startTime = const Value.absent(),
            Value<int?> durationSeconds = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsCompanion(
            id: id,
            routineId: routineId,
            startTime: startTime,
            durationSeconds: durationSeconds,
            completedAt: completedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> routineId = const Value.absent(),
            required DateTime startTime,
            Value<int?> durationSeconds = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsCompanion.insert(
            id: id,
            routineId: routineId,
            startTime: startTime,
            durationSeconds: durationSeconds,
            completedAt: completedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$SessionsTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({sessionExercisesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (sessionExercisesRefs) db.sessionExercises
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (sessionExercisesRefs)
                    await $_getPrefetchedData<Session, $SessionsTable,
                            SessionExercise>(
                        currentTable: table,
                        referencedTable: $$SessionsTableReferences
                            ._sessionExercisesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionsTableReferences(db, table, p0)
                                .sessionExercisesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionsTable,
    Session,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (Session, $$SessionsTableReferences),
    Session,
    PrefetchHooks Function({bool sessionExercisesRefs})>;
typedef $$SessionExercisesTableCreateCompanionBuilder
    = SessionExercisesCompanion Function({
  required String id,
  required String sessionId,
  Value<String?> libraryId,
  required String name,
  required List<String> musclesPrimary,
  required List<String> musclesSecondary,
  Value<String?> equipment,
  Value<String?> notes,
  required int exerciseIndex,
  Value<bool> isTarget,
  Value<int> rowid,
});
typedef $$SessionExercisesTableUpdateCompanionBuilder
    = SessionExercisesCompanion Function({
  Value<String> id,
  Value<String> sessionId,
  Value<String?> libraryId,
  Value<String> name,
  Value<List<String>> musclesPrimary,
  Value<List<String>> musclesSecondary,
  Value<String?> equipment,
  Value<String?> notes,
  Value<int> exerciseIndex,
  Value<bool> isTarget,
  Value<int> rowid,
});

final class $$SessionExercisesTableReferences extends BaseReferences<
    _$AppDatabase, $SessionExercisesTable, SessionExercise> {
  $$SessionExercisesTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias(
          $_aliasNameGenerator(db.sessionExercises.sessionId, db.sessions.id));

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$SessionsTableTableManager($_db, $_db.sessions)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$WorkoutSetsTable, List<WorkoutSet>>
      _workoutSetsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.workoutSets,
              aliasName: $_aliasNameGenerator(
                  db.sessionExercises.id, db.workoutSets.sessionExerciseId));

  $$WorkoutSetsTableProcessedTableManager get workoutSetsRefs {
    final manager = $$WorkoutSetsTableTableManager($_db, $_db.workoutSets)
        .filter((f) =>
            f.sessionExerciseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_workoutSetsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$SessionExercisesTableFilterComposer
    extends Composer<_$AppDatabase, $SessionExercisesTable> {
  $$SessionExercisesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get libraryId => $composableBuilder(
      column: $table.libraryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
      get musclesPrimary => $composableBuilder(
          column: $table.musclesPrimary,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String>
      get musclesSecondary => $composableBuilder(
          column: $table.musclesSecondary,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get equipment => $composableBuilder(
      column: $table.equipment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get exerciseIndex => $composableBuilder(
      column: $table.exerciseIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isTarget => $composableBuilder(
      column: $table.isTarget, builder: (column) => ColumnFilters(column));

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableFilterComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> workoutSetsRefs(
      Expression<bool> Function($$WorkoutSetsTableFilterComposer f) f) {
    final $$WorkoutSetsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.workoutSets,
        getReferencedColumn: (t) => t.sessionExerciseId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WorkoutSetsTableFilterComposer(
              $db: $db,
              $table: $db.workoutSets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SessionExercisesTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionExercisesTable> {
  $$SessionExercisesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get libraryId => $composableBuilder(
      column: $table.libraryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get musclesPrimary => $composableBuilder(
      column: $table.musclesPrimary,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get musclesSecondary => $composableBuilder(
      column: $table.musclesSecondary,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get equipment => $composableBuilder(
      column: $table.equipment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get exerciseIndex => $composableBuilder(
      column: $table.exerciseIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isTarget => $composableBuilder(
      column: $table.isTarget, builder: (column) => ColumnOrderings(column));

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableOrderingComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$SessionExercisesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionExercisesTable> {
  $$SessionExercisesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get libraryId =>
      $composableBuilder(column: $table.libraryId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get musclesPrimary =>
      $composableBuilder(
          column: $table.musclesPrimary, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get musclesSecondary =>
      $composableBuilder(
          column: $table.musclesSecondary, builder: (column) => column);

  GeneratedColumn<String> get equipment =>
      $composableBuilder(column: $table.equipment, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get exerciseIndex => $composableBuilder(
      column: $table.exerciseIndex, builder: (column) => column);

  GeneratedColumn<bool> get isTarget =>
      $composableBuilder(column: $table.isTarget, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionId,
        referencedTable: $db.sessions,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionsTableAnnotationComposer(
              $db: $db,
              $table: $db.sessions,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> workoutSetsRefs<T extends Object>(
      Expression<T> Function($$WorkoutSetsTableAnnotationComposer a) f) {
    final $$WorkoutSetsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.workoutSets,
        getReferencedColumn: (t) => t.sessionExerciseId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$WorkoutSetsTableAnnotationComposer(
              $db: $db,
              $table: $db.workoutSets,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$SessionExercisesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionExercisesTable,
    SessionExercise,
    $$SessionExercisesTableFilterComposer,
    $$SessionExercisesTableOrderingComposer,
    $$SessionExercisesTableAnnotationComposer,
    $$SessionExercisesTableCreateCompanionBuilder,
    $$SessionExercisesTableUpdateCompanionBuilder,
    (SessionExercise, $$SessionExercisesTableReferences),
    SessionExercise,
    PrefetchHooks Function({bool sessionId, bool workoutSetsRefs})> {
  $$SessionExercisesTableTableManager(
      _$AppDatabase db, $SessionExercisesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionExercisesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionExercisesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionExercisesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionId = const Value.absent(),
            Value<String?> libraryId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<List<String>> musclesPrimary = const Value.absent(),
            Value<List<String>> musclesSecondary = const Value.absent(),
            Value<String?> equipment = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> exerciseIndex = const Value.absent(),
            Value<bool> isTarget = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionExercisesCompanion(
            id: id,
            sessionId: sessionId,
            libraryId: libraryId,
            name: name,
            musclesPrimary: musclesPrimary,
            musclesSecondary: musclesSecondary,
            equipment: equipment,
            notes: notes,
            exerciseIndex: exerciseIndex,
            isTarget: isTarget,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionId,
            Value<String?> libraryId = const Value.absent(),
            required String name,
            required List<String> musclesPrimary,
            required List<String> musclesSecondary,
            Value<String?> equipment = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required int exerciseIndex,
            Value<bool> isTarget = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionExercisesCompanion.insert(
            id: id,
            sessionId: sessionId,
            libraryId: libraryId,
            name: name,
            musclesPrimary: musclesPrimary,
            musclesSecondary: musclesSecondary,
            equipment: equipment,
            notes: notes,
            exerciseIndex: exerciseIndex,
            isTarget: isTarget,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$SessionExercisesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {sessionId = false, workoutSetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (workoutSetsRefs) db.workoutSets],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sessionId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionId,
                    referencedTable:
                        $$SessionExercisesTableReferences._sessionIdTable(db),
                    referencedColumn: $$SessionExercisesTableReferences
                        ._sessionIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (workoutSetsRefs)
                    await $_getPrefetchedData<SessionExercise,
                            $SessionExercisesTable, WorkoutSet>(
                        currentTable: table,
                        referencedTable: $$SessionExercisesTableReferences
                            ._workoutSetsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$SessionExercisesTableReferences(db, table, p0)
                                .workoutSetsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.sessionExerciseId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$SessionExercisesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionExercisesTable,
    SessionExercise,
    $$SessionExercisesTableFilterComposer,
    $$SessionExercisesTableOrderingComposer,
    $$SessionExercisesTableAnnotationComposer,
    $$SessionExercisesTableCreateCompanionBuilder,
    $$SessionExercisesTableUpdateCompanionBuilder,
    (SessionExercise, $$SessionExercisesTableReferences),
    SessionExercise,
    PrefetchHooks Function({bool sessionId, bool workoutSetsRefs})>;
typedef $$WorkoutSetsTableCreateCompanionBuilder = WorkoutSetsCompanion
    Function({
  required String id,
  required String sessionExerciseId,
  required int setIndex,
  required double weight,
  required int reps,
  Value<bool> completed,
  Value<int?> rpe,
  Value<String?> notes,
  Value<int?> restSeconds,
  Value<bool> isFailure,
  Value<bool> isDropset,
  Value<bool> isWarmup,
  Value<int> rowid,
});
typedef $$WorkoutSetsTableUpdateCompanionBuilder = WorkoutSetsCompanion
    Function({
  Value<String> id,
  Value<String> sessionExerciseId,
  Value<int> setIndex,
  Value<double> weight,
  Value<int> reps,
  Value<bool> completed,
  Value<int?> rpe,
  Value<String?> notes,
  Value<int?> restSeconds,
  Value<bool> isFailure,
  Value<bool> isDropset,
  Value<bool> isWarmup,
  Value<int> rowid,
});

final class $$WorkoutSetsTableReferences
    extends BaseReferences<_$AppDatabase, $WorkoutSetsTable, WorkoutSet> {
  $$WorkoutSetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionExercisesTable _sessionExerciseIdTable(_$AppDatabase db) =>
      db.sessionExercises.createAlias($_aliasNameGenerator(
          db.workoutSets.sessionExerciseId, db.sessionExercises.id));

  $$SessionExercisesTableProcessedTableManager get sessionExerciseId {
    final $_column = $_itemColumn<String>('session_exercise_id')!;

    final manager =
        $$SessionExercisesTableTableManager($_db, $_db.sessionExercises)
            .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionExerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$WorkoutSetsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get setIndex => $composableBuilder(
      column: $table.setIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get weight => $composableBuilder(
      column: $table.weight, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reps => $composableBuilder(
      column: $table.reps, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get completed => $composableBuilder(
      column: $table.completed, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rpe => $composableBuilder(
      column: $table.rpe, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get restSeconds => $composableBuilder(
      column: $table.restSeconds, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFailure => $composableBuilder(
      column: $table.isFailure, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDropset => $composableBuilder(
      column: $table.isDropset, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isWarmup => $composableBuilder(
      column: $table.isWarmup, builder: (column) => ColumnFilters(column));

  $$SessionExercisesTableFilterComposer get sessionExerciseId {
    final $$SessionExercisesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionExerciseId,
        referencedTable: $db.sessionExercises,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionExercisesTableFilterComposer(
              $db: $db,
              $table: $db.sessionExercises,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WorkoutSetsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get setIndex => $composableBuilder(
      column: $table.setIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get weight => $composableBuilder(
      column: $table.weight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reps => $composableBuilder(
      column: $table.reps, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get completed => $composableBuilder(
      column: $table.completed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rpe => $composableBuilder(
      column: $table.rpe, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get restSeconds => $composableBuilder(
      column: $table.restSeconds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFailure => $composableBuilder(
      column: $table.isFailure, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDropset => $composableBuilder(
      column: $table.isDropset, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isWarmup => $composableBuilder(
      column: $table.isWarmup, builder: (column) => ColumnOrderings(column));

  $$SessionExercisesTableOrderingComposer get sessionExerciseId {
    final $$SessionExercisesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionExerciseId,
        referencedTable: $db.sessionExercises,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionExercisesTableOrderingComposer(
              $db: $db,
              $table: $db.sessionExercises,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WorkoutSetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSetsTable> {
  $$WorkoutSetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get setIndex =>
      $composableBuilder(column: $table.setIndex, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<int> get rpe =>
      $composableBuilder(column: $table.rpe, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get restSeconds => $composableBuilder(
      column: $table.restSeconds, builder: (column) => column);

  GeneratedColumn<bool> get isFailure =>
      $composableBuilder(column: $table.isFailure, builder: (column) => column);

  GeneratedColumn<bool> get isDropset =>
      $composableBuilder(column: $table.isDropset, builder: (column) => column);

  GeneratedColumn<bool> get isWarmup =>
      $composableBuilder(column: $table.isWarmup, builder: (column) => column);

  $$SessionExercisesTableAnnotationComposer get sessionExerciseId {
    final $$SessionExercisesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.sessionExerciseId,
        referencedTable: $db.sessionExercises,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$SessionExercisesTableAnnotationComposer(
              $db: $db,
              $table: $db.sessionExercises,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$WorkoutSetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkoutSetsTable,
    WorkoutSet,
    $$WorkoutSetsTableFilterComposer,
    $$WorkoutSetsTableOrderingComposer,
    $$WorkoutSetsTableAnnotationComposer,
    $$WorkoutSetsTableCreateCompanionBuilder,
    $$WorkoutSetsTableUpdateCompanionBuilder,
    (WorkoutSet, $$WorkoutSetsTableReferences),
    WorkoutSet,
    PrefetchHooks Function({bool sessionExerciseId})> {
  $$WorkoutSetsTableTableManager(_$AppDatabase db, $WorkoutSetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutSetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutSetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutSetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> sessionExerciseId = const Value.absent(),
            Value<int> setIndex = const Value.absent(),
            Value<double> weight = const Value.absent(),
            Value<int> reps = const Value.absent(),
            Value<bool> completed = const Value.absent(),
            Value<int?> rpe = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int?> restSeconds = const Value.absent(),
            Value<bool> isFailure = const Value.absent(),
            Value<bool> isDropset = const Value.absent(),
            Value<bool> isWarmup = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkoutSetsCompanion(
            id: id,
            sessionExerciseId: sessionExerciseId,
            setIndex: setIndex,
            weight: weight,
            reps: reps,
            completed: completed,
            rpe: rpe,
            notes: notes,
            restSeconds: restSeconds,
            isFailure: isFailure,
            isDropset: isDropset,
            isWarmup: isWarmup,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String sessionExerciseId,
            required int setIndex,
            required double weight,
            required int reps,
            Value<bool> completed = const Value.absent(),
            Value<int?> rpe = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int?> restSeconds = const Value.absent(),
            Value<bool> isFailure = const Value.absent(),
            Value<bool> isDropset = const Value.absent(),
            Value<bool> isWarmup = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkoutSetsCompanion.insert(
            id: id,
            sessionExerciseId: sessionExerciseId,
            setIndex: setIndex,
            weight: weight,
            reps: reps,
            completed: completed,
            rpe: rpe,
            notes: notes,
            restSeconds: restSeconds,
            isFailure: isFailure,
            isDropset: isDropset,
            isWarmup: isWarmup,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$WorkoutSetsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({sessionExerciseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (sessionExerciseId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.sessionExerciseId,
                    referencedTable: $$WorkoutSetsTableReferences
                        ._sessionExerciseIdTable(db),
                    referencedColumn: $$WorkoutSetsTableReferences
                        ._sessionExerciseIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$WorkoutSetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WorkoutSetsTable,
    WorkoutSet,
    $$WorkoutSetsTableFilterComposer,
    $$WorkoutSetsTableOrderingComposer,
    $$WorkoutSetsTableAnnotationComposer,
    $$WorkoutSetsTableCreateCompanionBuilder,
    $$WorkoutSetsTableUpdateCompanionBuilder,
    (WorkoutSet, $$WorkoutSetsTableReferences),
    WorkoutSet,
    PrefetchHooks Function({bool sessionExerciseId})>;
typedef $$ExerciseNotesTableCreateCompanionBuilder = ExerciseNotesCompanion
    Function({
  required String exerciseName,
  required String note,
  Value<int> rowid,
});
typedef $$ExerciseNotesTableUpdateCompanionBuilder = ExerciseNotesCompanion
    Function({
  Value<String> exerciseName,
  Value<String> note,
  Value<int> rowid,
});

class $$ExerciseNotesTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseNotesTable> {
  $$ExerciseNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get exerciseName => $composableBuilder(
      column: $table.exerciseName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));
}

class $$ExerciseNotesTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseNotesTable> {
  $$ExerciseNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get exerciseName => $composableBuilder(
      column: $table.exerciseName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));
}

class $$ExerciseNotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseNotesTable> {
  $$ExerciseNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get exerciseName => $composableBuilder(
      column: $table.exerciseName, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);
}

class $$ExerciseNotesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ExerciseNotesTable,
    ExerciseNote,
    $$ExerciseNotesTableFilterComposer,
    $$ExerciseNotesTableOrderingComposer,
    $$ExerciseNotesTableAnnotationComposer,
    $$ExerciseNotesTableCreateCompanionBuilder,
    $$ExerciseNotesTableUpdateCompanionBuilder,
    (
      ExerciseNote,
      BaseReferences<_$AppDatabase, $ExerciseNotesTable, ExerciseNote>
    ),
    ExerciseNote,
    PrefetchHooks Function()> {
  $$ExerciseNotesTableTableManager(_$AppDatabase db, $ExerciseNotesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExerciseNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExerciseNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExerciseNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> exerciseName = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ExerciseNotesCompanion(
            exerciseName: exerciseName,
            note: note,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String exerciseName,
            required String note,
            Value<int> rowid = const Value.absent(),
          }) =>
              ExerciseNotesCompanion.insert(
            exerciseName: exerciseName,
            note: note,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ExerciseNotesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ExerciseNotesTable,
    ExerciseNote,
    $$ExerciseNotesTableFilterComposer,
    $$ExerciseNotesTableOrderingComposer,
    $$ExerciseNotesTableAnnotationComposer,
    $$ExerciseNotesTableCreateCompanionBuilder,
    $$ExerciseNotesTableUpdateCompanionBuilder,
    (
      ExerciseNote,
      BaseReferences<_$AppDatabase, $ExerciseNotesTable, ExerciseNote>
    ),
    ExerciseNote,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RoutinesTableTableManager get routines =>
      $$RoutinesTableTableManager(_db, _db.routines);
  $$RoutineDaysTableTableManager get routineDays =>
      $$RoutineDaysTableTableManager(_db, _db.routineDays);
  $$RoutineExercisesTableTableManager get routineExercises =>
      $$RoutineExercisesTableTableManager(_db, _db.routineExercises);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$SessionExercisesTableTableManager get sessionExercises =>
      $$SessionExercisesTableTableManager(_db, _db.sessionExercises);
  $$WorkoutSetsTableTableManager get workoutSets =>
      $$WorkoutSetsTableTableManager(_db, _db.workoutSets);
  $$ExerciseNotesTableTableManager get exerciseNotes =>
      $$ExerciseNotesTableTableManager(_db, _db.exerciseNotes);
}
