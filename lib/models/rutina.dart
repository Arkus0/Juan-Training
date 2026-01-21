import 'dia.dart';

class Rutina {
  final String id;
  String nombre;
  List<Dia> dias;
  final DateTime creada;

  Rutina({
    required this.id,
    required this.nombre,
    required this.dias,
    required this.creada,
  });
}
