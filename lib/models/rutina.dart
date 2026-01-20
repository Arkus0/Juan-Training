import 'package:hive/hive.dart';
import 'dia.dart';

part 'rutina.g.dart';

@HiveType(typeId: 1)
class Rutina extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String nombre;

  @HiveField(2)
  List<Dia> dias;

  @HiveField(3)
  final DateTime creada;

  Rutina({
    required this.id,
    required this.nombre,
    required this.dias,
    required this.creada,
  });
}
