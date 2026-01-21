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

  Rutina copyWith({
    String? id,
    String? nombre,
    List<Dia>? dias,
    DateTime? creada,
  }) {
    return Rutina(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      dias: dias ?? this.dias,
      creada: creada ?? this.creada,
    );
  }
}
