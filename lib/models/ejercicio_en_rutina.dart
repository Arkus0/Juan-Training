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

  /// Creates a copy with updated fields.
  /// To explicitly clear nullable fields, pass the special [clearField] value.
  EjercicioEnRutina copyWith({
    String? id,
    String? nombre,
    Object? descripcion = _sentinel,
    List<String>? musculosPrincipales,
    List<String>? musculosSecundarios,
    String? equipo,
    Object? localImagePath = _sentinel,
    int? series,
    String? repsRange,
    Object? descansoSugerido = _sentinel,
    Object? notas = _sentinel,
    String? instanceId,
    Object? supersetId = _sentinel,
  }) {
    return EjercicioEnRutina(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion == _sentinel
          ? this.descripcion
          : descripcion as String?,
      musculosPrincipales: musculosPrincipales ?? this.musculosPrincipales,
      musculosSecundarios: musculosSecundarios ?? this.musculosSecundarios,
      equipo: equipo ?? this.equipo,
      localImagePath: localImagePath == _sentinel
          ? this.localImagePath
          : localImagePath as String?,
      series: series ?? this.series,
      repsRange: repsRange ?? this.repsRange,
      descansoSugerido: descansoSugerido == _sentinel
          ? this.descansoSugerido
          : descansoSugerido as Duration?,
      notas: notas == _sentinel ? this.notas : notas as String?,
      instanceId: instanceId ?? this.instanceId,
      supersetId: supersetId == _sentinel
          ? this.supersetId
          : supersetId as String?,
    );
  }
}

/// Sentinel value used by copyWith to distinguish between null and undefined
const _sentinel = Object();
