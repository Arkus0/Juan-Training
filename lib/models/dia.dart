import 'package:uuid/uuid.dart';
import 'ejercicio_en_rutina.dart';

class Dia {
  String nombre;
  List<EjercicioEnRutina> ejercicios;
  String progressionType; // 'none', 'lineal', 'double', 'percentage1RM'
  final String id;

  Dia({
    required this.nombre,
    required this.ejercicios,
    this.progressionType = 'none',
    String? id,
  }) : id = id ?? const Uuid().v4();
}
