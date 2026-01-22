import 'ejercicio.dart';

class Sesion {
  final String id;
  final String rutinaId;
  final String? dayName; // Nombre del día entrenado
  final int? dayIndex; // Índice del día en la rutina (para sugerencia inteligente)
  final DateTime fecha;
  final List<Ejercicio> ejerciciosCompletados;
  final List<Ejercicio> ejerciciosObjetivo;
  final int? durationSeconds;

  // Optional rest timer metadata for active sessions
  final DateTime? restTimerEndTime;
  final int? restTimerTotalSeconds;
  final bool restTimerIsPaused;

  Sesion({
    required this.id,
    required this.rutinaId,
    this.dayName,
    this.dayIndex,
    required this.fecha,
    required this.ejerciciosCompletados,
    required this.ejerciciosObjetivo,
    this.durationSeconds,
    this.restTimerEndTime,
    this.restTimerTotalSeconds,
    this.restTimerIsPaused = false,
  });

  Sesion copyWith({
    String? id,
    String? rutinaId,
    String? dayName,
    int? dayIndex,
    DateTime? fecha,
    List<Ejercicio>? ejerciciosCompletados,
    List<Ejercicio>? ejerciciosObjetivo,
    int? durationSeconds,
  }) {
    return Sesion(
      id: id ?? this.id,
      rutinaId: rutinaId ?? this.rutinaId,
      dayName: dayName ?? this.dayName,
      dayIndex: dayIndex ?? this.dayIndex,
      fecha: fecha ?? this.fecha,
      ejerciciosCompletados: ejerciciosCompletados ?? this.ejerciciosCompletados,
      ejerciciosObjetivo: ejerciciosObjetivo ?? this.ejerciciosObjetivo,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  /// Calcula el volumen total de la sesión (peso x reps de todas las series completadas).
  double get totalVolume {
    double volume = 0;
    for (final ejercicio in ejerciciosCompletados) {
      for (final log in ejercicio.logs) {
        if (log.completed) {
          volume += log.peso * log.reps;
        }
      }
    }
    return volume;
  }

  /// Cuenta el total de series completadas.
  int get completedSetsCount {
    int count = 0;
    for (final ejercicio in ejerciciosCompletados) {
      count += ejercicio.logs.where((l) => l.completed).length;
    }
    return count;
  }

  /// Duración formateada (ej: "45 min").
  String get formattedDuration {
    if (durationSeconds == null) return 'N/A';
    final minutes = (durationSeconds! / 60).round();
    return '$minutes min';
  }
}
