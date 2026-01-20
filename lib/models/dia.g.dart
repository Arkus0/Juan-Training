// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dia.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DiaAdapter extends TypeAdapter<Dia> {
  @override
  final int typeId = 4;

  @override
  Dia read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Dia(
      nombre: fields[0] as String,
      ejercicios: (fields[1] as List).cast<EjercicioEnRutina>(),
      progressionType: fields[2] as String,
      id: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Dia obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.nombre)
      ..writeByte(1)
      ..write(obj.ejercicios)
      ..writeByte(2)
      ..write(obj.progressionType)
      ..writeByte(3)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
