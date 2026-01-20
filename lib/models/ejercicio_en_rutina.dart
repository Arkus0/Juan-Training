import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'ejercicio_en_rutina.g.dart';

@HiveType(typeId: 5)
class EjercicioEnRutina extends HiveObject {
  // Embedded Library Data
  @HiveField(0)
  final String id; // Wger/Library ID

  @HiveField(1)
  final String nombre;

  @HiveField(2)
  final String? descripcion;

  @HiveField(3)
  final List<String> musculosPrincipales;

  @HiveField(4)
  final List<String> musculosSecundarios;

  @HiveField(5)
  final String equipo;

  @HiveField(6)
  final String? localImagePath;

  // Routine Specific Data
  @HiveField(7)
  int series;

  @HiveField(8)
  String repsRange;

  @HiveField(9)
  Duration? descansoSugerido;

  @HiveField(10)
  String? notas;

  @HiveField(11)
  final String instanceId;

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
    );
  }
}
