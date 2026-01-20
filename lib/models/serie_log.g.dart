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
    );
  }

  @override
  void write(BinaryWriter writer, SerieLog obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.peso)
      ..writeByte(1)
      ..write(obj.reps)
      ..writeByte(2)
      ..write(obj.completed);
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
