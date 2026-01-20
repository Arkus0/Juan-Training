// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sesion.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SesionAdapter extends TypeAdapter<Sesion> {
  @override
  final int typeId = 2;

  @override
  Sesion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Sesion(
      id: fields[0] as String,
      rutinaId: fields[1] as String,
      fecha: fields[2] as DateTime,
      ejerciciosCompletados: (fields[3] as List).cast<Ejercicio>(),
    );
  }

  @override
  void write(BinaryWriter writer, Sesion obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.rutinaId)
      ..writeByte(2)
      ..write(obj.fecha)
      ..writeByte(3)
      ..write(obj.ejerciciosCompletados);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SesionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
