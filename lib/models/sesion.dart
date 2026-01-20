import 'package:hive/hive.dart';
import 'ejercicio.dart';

part 'sesion.g.dart';

@HiveType(typeId: 2)
class Sesion extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String rutinaId;

  @HiveField(2)
  final DateTime fecha;

  @HiveField(3)
  final List<Ejercicio> ejerciciosCompletados;

  Sesion({
    required this.id,
    required this.rutinaId,
    required this.fecha,
    required this.ejerciciosCompletados,
  });
}
