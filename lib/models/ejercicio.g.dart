// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ejercicio.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EjercicioAdapter extends TypeAdapter<Ejercicio> {
  @override
  final int typeId = 0;

  @override
  Ejercicio read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Ejercicio(
      id: fields[0] as String,
      nombre: fields[1] as String,
      series: fields[2] as int,
      reps: fields[3] as int,
      peso: fields[4] as double,
      notas: fields[5] as String?,
      logs: (fields[6] as List?)?.cast<SerieLog>(),
    );
  }

  @override
  void write(BinaryWriter writer, Ejercicio obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nombre)
      ..writeByte(2)
      ..write(obj.series)
      ..writeByte(3)
      ..write(obj.reps)
      ..writeByte(4)
      ..write(obj.peso)
      ..writeByte(5)
      ..write(obj.notas)
      ..writeByte(6)
      ..write(obj.logs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EjercicioAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
