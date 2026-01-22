import 'serie_log.dart';

class Ejercicio {
  final String id; // Instance ID (UUID)
  final String libraryId; // Reference to Library Exercise ID
  final String nombre;
  final List<String> musculosPrincipales;
  final List<String> musculosSecundarios;
  final int series;
  final int reps;
  final double peso;
  final String? notas;
  final List<SerieLog> logs;
  final String? supersetId; // Para agrupar ejercicios en superseries
  final int? descansoSugeridoSeconds; // Descanso sugerido en segundos

  Ejercicio({
    required this.id,
    required this.libraryId,
    required this.nombre,
    this.musculosPrincipales = const [],
    this.musculosSecundarios = const [],
    required this.series,
    required this.reps,
    this.peso = 0.0,
    this.notas,
    List<SerieLog>? logs,
    this.supersetId,
    this.descansoSugeridoSeconds,
  }) : logs = logs ?? [];

  // Helper to create a copy with new values if needed
  Ejercicio copyWith({
    String? id,
    String? libraryId,
    String? nombre,
    List<String>? musculosPrincipales,
    List<String>? musculosSecundarios,
    int? series,
    int? reps,
    double? peso,
    String? notas,
    List<SerieLog>? logs,
    String? supersetId,
    int? descansoSugeridoSeconds,
    bool clearSupersetId = false,
  }) {
    return Ejercicio(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      nombre: nombre ?? this.nombre,
      musculosPrincipales: musculosPrincipales ?? this.musculosPrincipales,
      musculosSecundarios: musculosSecundarios ?? this.musculosSecundarios,
      series: series ?? this.series,
      reps: reps ?? this.reps,
      peso: peso ?? this.peso,
      notas: notas ?? this.notas,
      logs: logs ?? this.logs,
      supersetId: clearSupersetId ? null : (supersetId ?? this.supersetId),
      descansoSugeridoSeconds: descansoSugeridoSeconds ?? this.descansoSugeridoSeconds,
    );
  }

  /// Verifica si este ejercicio pertenece a un superset
  bool get isInSuperset => supersetId != null && supersetId!.isNotEmpty;
}
