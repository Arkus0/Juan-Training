import 'package:hive/hive.dart';
import 'ejercicio.dart';

part 'rutina.g.dart';

@HiveType(typeId: 1)
class Rutina extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String nombre;

  @HiveField(2)
  final List<Ejercicio> ejercicios;

  @HiveField(3)
  final DateTime creada;

  Rutina({
    required this.id,
    required this.nombre,
    required this.ejercicios,
    required this.creada,
  });
}
