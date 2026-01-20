import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'ejercicio_en_rutina.dart';

part 'dia.g.dart';

@HiveType(typeId: 4)
class Dia extends HiveObject {
  @HiveField(0)
  String nombre;

  @HiveField(1)
  List<EjercicioEnRutina> ejercicios;

  @HiveField(2)
  String progressionType; // 'none', 'lineal', 'double', 'percentage1RM'

  @HiveField(3)
  final String id;

  Dia({
    required this.nombre,
    required this.ejercicios,
    this.progressionType = 'none',
    String? id,
  }) : id = id ?? const Uuid().v4();
}
