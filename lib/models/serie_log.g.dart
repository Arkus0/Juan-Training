// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'serie_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SerieLogAdapter extends TypeAdapter<SerieLog> {
  @override
  final int typeId = 3;

  @override
  SerieLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SerieLog(
      peso: fields[0] as double,
      reps: fields[1] as int,
      completed: fields[2] as bool,
      rpe: fields[3] as int?,
      notas: fields[4] as String?,
      restSeconds: fields[5] as int?,
      isFailure: fields[6] as bool? ?? false,
      isDropset: fields[7] as bool? ?? false,
      isWarmup: fields[8] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, SerieLog obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.peso)
      ..writeByte(1)
      ..write(obj.reps)
      ..writeByte(2)
      ..write(obj.completed)
      ..writeByte(3)
      ..write(obj.rpe)
      ..writeByte(4)
      ..write(obj.notas)
      ..writeByte(5)
      ..write(obj.restSeconds)
      ..writeByte(6)
      ..write(obj.isFailure)
      ..writeByte(7)
      ..write(obj.isDropset)
      ..writeByte(8)
      ..write(obj.isWarmup);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SerieLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
