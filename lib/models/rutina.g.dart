// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rutina.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RutinaAdapter extends TypeAdapter<Rutina> {
  @override
  final int typeId = 1;

  @override
  Rutina read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Rutina(
      id: fields[0] as String,
      nombre: fields[1] as String,
      ejercicios: (fields[2] as List).cast<Ejercicio>(),
      creada: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Rutina obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nombre)
      ..writeByte(2)
      ..write(obj.ejercicios)
      ..writeByte(3)
      ..write(obj.creada);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RutinaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
