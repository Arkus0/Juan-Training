import 'ejercicio.dart';

class Sesion {
  final String id;
  final String rutinaId;
  final DateTime fecha;
  final List<Ejercicio> ejerciciosCompletados;
  final List<Ejercicio> ejerciciosObjetivo;
  final int? durationSeconds;

  Sesion({
    required this.id,
    required this.rutinaId,
    required this.fecha,
    required this.ejerciciosCompletados,
    required this.ejerciciosObjetivo,
    this.durationSeconds,
  });
}
