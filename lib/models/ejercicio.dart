import 'serie_log.dart';

class Ejercicio {
  final String id;
  final String nombre;
  final int series;
  final int reps;
  final double peso;
  final String? notas;
  final List<SerieLog> logs;

  Ejercicio({
    required this.id,
    required this.nombre,
    required this.series,
    required this.reps,
    this.peso = 0.0,
    this.notas,
    List<SerieLog>? logs,
  }) : logs = logs ?? [];

  // Helper to create a copy with new values if needed
  Ejercicio copyWith({
    String? id,
    String? nombre,
    int? series,
    int? reps,
    double? peso,
    String? notas,
    List<SerieLog>? logs,
  }) {
    return Ejercicio(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      series: series ?? this.series,
      reps: reps ?? this.reps,
      peso: peso ?? this.peso,
      notas: notas ?? this.notas,
      logs: logs ?? this.logs,
    );
  }
}
