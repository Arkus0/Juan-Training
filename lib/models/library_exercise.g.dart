// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_exercise.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LibraryExerciseAdapter extends TypeAdapter<LibraryExercise> {
  @override
  final int typeId = 6;

  @override
  LibraryExercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LibraryExercise(
      id: fields[0] as int,
      name: fields[1] as String,
      muscleGroup: fields[2] as String,
      equipment: fields[3] as String,
      description: fields[4] as String?,
      license: fields[5] as String?,
      imageUrls: (fields[6] as List).cast<String>(),
      localImagePath: fields[7] as String?,
      muscles: (fields[8] as List).cast<String>(),
      secondaryMuscles: (fields[9] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, LibraryExercise obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.muscleGroup)
      ..writeByte(3)
      ..write(obj.equipment)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.license)
      ..writeByte(6)
      ..write(obj.imageUrls)
      ..writeByte(7)
      ..write(obj.localImagePath)
      ..writeByte(8)
      ..write(obj.muscles)
      ..writeByte(9)
      ..write(obj.secondaryMuscles);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
