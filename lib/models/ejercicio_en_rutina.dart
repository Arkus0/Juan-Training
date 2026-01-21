import 'package:uuid/uuid.dart';

class EjercicioEnRutina {
  // Embedded Library Data
  final String id; // Wger/Library ID
  final String nombre;
  final String? descripcion;
  final List<String> musculosPrincipales;
  final List<String> musculosSecundarios;
  final String equipo;
  final String? localImagePath;

  // Routine Specific Data
  int series;
  String repsRange;
  Duration? descansoSugerido;
  String? notas;
  final String instanceId;
  final String? supersetId;

  EjercicioEnRutina({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.musculosPrincipales,
    required this.musculosSecundarios,
    required this.equipo,
    this.localImagePath,
    this.series = 3,
    this.repsRange = '8-12',
    this.descansoSugerido,
    this.notas,
    String? instanceId,
    this.supersetId,
  }) : instanceId = instanceId ?? const Uuid().v4();

  EjercicioEnRutina copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    List<String>? musculosPrincipales,
    List<String>? musculosSecundarios,
    String? equipo,
    String? localImagePath,
    int? series,
    String? repsRange,
    Duration? descansoSugerido,
    String? notas,
    String? instanceId,
    String? supersetId,
  }) {
    return EjercicioEnRutina(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      musculosPrincipales: musculosPrincipales ?? this.musculosPrincipales,
      musculosSecundarios: musculosSecundarios ?? this.musculosSecundarios,
      equipo: equipo ?? this.equipo,
      localImagePath: localImagePath ?? this.localImagePath,
      series: series ?? this.series,
      repsRange: repsRange ?? this.repsRange,
      descansoSugerido: descansoSugerido ?? this.descansoSugerido,
      notas: notas ?? this.notas,
      instanceId: instanceId ?? this.instanceId,
      supersetId: supersetId ?? this.supersetId,
    );
  }
}
