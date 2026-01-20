import 'package:hive/hive.dart';
import 'serie_log.dart';

part 'ejercicio.g.dart';

@HiveType(typeId: 0)
class Ejercicio extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String nombre;

  @HiveField(2)
  final int series;

  @HiveField(3)
  final int reps;

  @HiveField(4)
  final double peso;

  @HiveField(5)
  final String? notas;

  @HiveField(6)
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

  // Helper to create a copy with new values if needed (immutability style, though HiveObjects are mutable)
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
