// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ejercicio_en_rutina.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EjercicioEnRutinaAdapter extends TypeAdapter<EjercicioEnRutina> {
  @override
  final int typeId = 5;

  @override
  EjercicioEnRutina read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EjercicioEnRutina(
      id: fields[0] as String,
      nombre: fields[1] as String,
      descripcion: fields[2] as String?,
      musculosPrincipales: (fields[3] as List).cast<String>(),
      musculosSecundarios: (fields[4] as List).cast<String>(),
      equipo: fields[5] as String,
      localImagePath: fields[6] as String?,
      series: fields[7] as int,
      repsRange: fields[8] as String,
      descansoSugerido: fields[9] as Duration?,
      notas: fields[10] as String?,
      instanceId: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, EjercicioEnRutina obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nombre)
      ..writeByte(2)
      ..write(obj.descripcion)
      ..writeByte(3)
      ..write(obj.musculosPrincipales)
      ..writeByte(4)
      ..write(obj.musculosSecundarios)
      ..writeByte(5)
      ..write(obj.equipo)
      ..writeByte(6)
      ..write(obj.localImagePath)
      ..writeByte(7)
      ..write(obj.series)
      ..writeByte(8)
      ..write(obj.repsRange)
      ..writeByte(9)
      ..write(obj.descansoSugerido)
      ..writeByte(10)
      ..write(obj.notas)
      ..writeByte(11)
      ..write(obj.instanceId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EjercicioEnRutinaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
