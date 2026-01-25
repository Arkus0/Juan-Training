import 'package:uuid/uuid.dart';
import 'ejercicio.dart';
import 'serie_log.dart';
import 'sesion.dart';

/// Modelo de sesión de entrenamiento externa (no realizada en la app).
///
/// Permite al usuario registrar entrenamientos hechos fuera de la app,
/// manteniendo la continuidad del historial.
class ExternalSession {
  final String id;
  final DateTime sessionDate; // Fecha en que se realizó el entrenamiento
  final List<ExternalExercise> exercises;
  final String? notes;
  final bool includeInProgression; // Opt-in para afectar métricas automáticas
  final DateTime addedAt; // Cuándo se añadió a la app
  final ExternalSessionSource source; // Cómo se capturó

  const ExternalSession({
    required this.id,
    required this.sessionDate,
    required this.exercises,
    this.notes,
    this.includeInProgression = false,
    required this.addedAt,
    required this.source,
  });

  bool get isExternal => true;

  /// Calcula el volumen total aproximado
  double get estimatedVolume {
    double total = 0;
    for (final exercise in exercises) {
      final weight = exercise.weight ?? 0;
      final reps = _parseRepsAverage(exercise.repsRange);
      total += weight * reps * exercise.series;
    }
    return total;
  }

  int _parseRepsAverage(String repsRange) {
    if (repsRange.contains('-')) {
      final parts = repsRange.split('-');
      final min = int.tryParse(parts[0]) ?? 0;
      final max = int.tryParse(parts[1]) ?? 0;
      return ((min + max) / 2).round();
    }
    return int.tryParse(repsRange) ?? 10;
  }

  factory ExternalSession.create({
    required DateTime sessionDate,
    required List<ExternalExercise> exercises,
    String? notes,
    bool includeInProgression = false,
    required ExternalSessionSource source,
  }) {
    return ExternalSession(
      id: const Uuid().v4(),
      sessionDate: sessionDate,
      exercises: exercises,
      notes: notes,
      includeInProgression: includeInProgression,
      addedAt: DateTime.now(),
      source: source,
    );
  }

  ExternalSession copyWith({
    String? id,
    DateTime? sessionDate,
    List<ExternalExercise>? exercises,
    String? notes,
    bool? includeInProgression,
    DateTime? addedAt,
    ExternalSessionSource? source,
  }) {
    return ExternalSession(
      id: id ?? this.id,
      sessionDate: sessionDate ?? this.sessionDate,
      exercises: exercises ?? this.exercises,
      notes: notes ?? this.notes,
      includeInProgression: includeInProgression ?? this.includeInProgression,
      addedAt: addedAt ?? this.addedAt,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionDate': sessionDate.toIso8601String(),
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'notes': notes,
      'includeInProgression': includeInProgression,
      'addedAt': addedAt.toIso8601String(),
      'source': source.name,
      'isExternal': true,
    };
  }

  factory ExternalSession.fromJson(Map<String, dynamic> json) {
    return ExternalSession(
      id: json['id'] as String,
      sessionDate: DateTime.parse(json['sessionDate'] as String),
      exercises: (json['exercises'] as List)
          .map((e) => ExternalExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
      includeInProgression: json['includeInProgression'] as bool? ?? false,
      addedAt: DateTime.parse(json['addedAt'] as String),
      source: ExternalSessionSource.values.byName(json['source'] as String),
    );
  }

  /// 🎯 FIX #5: Convierte esta sesión externa a un modelo Sesion para guardarlo
  /// en el historial regular de la app.
  ///
  /// Usa 'external' como rutinaId y marca la sesión como "externa" en el dayName.
  Sesion toSesion() {
    final ejerciciosCompletados = exercises.map((ex) {
      // Parsear reps del formato "8" o "8-12" -> usar el promedio
      final reps = _parseRepsValue(ex.repsRange);

      // Crear logs de series (todas completadas)
      final logs = List.generate(
        ex.series,
        (i) => SerieLog(
          peso: ex.weight ?? 0.0,
          reps: reps,
          completed: true,
        ),
      );

      return Ejercicio(
        id: const Uuid().v4(),
        libraryId: ex.libraryId?.toString() ?? ex.name,
        nombre: ex.name,
        musculosPrincipales: const [],
        musculosSecundarios: const [],
        series: ex.series,
        reps: reps,
        peso: ex.weight ?? 0.0,
        notas: ex.notes,
        logs: logs,
      );
    }).toList();

    return Sesion(
      id: id,
      rutinaId: 'external', // Marca como sesión externa
      dayName: 'Sesión Externa (${source.displayName})',
      dayIndex: null,
      fecha: sessionDate,
      ejerciciosCompletados: ejerciciosCompletados,
      ejerciciosObjetivo: [], // Las sesiones externas no tienen objetivos predefinidos
      durationSeconds: null,
      isBadDay: !includeInProgression, // Si no incluye en progresión, es como un "día malo"
    );
  }

  /// Parsea el valor de reps de un rango como "8-12" -> 10 (promedio)
  int _parseRepsValue(String repsRange) {
    if (repsRange.contains('-')) {
      final parts = repsRange.split('-');
      final min = int.tryParse(parts[0]) ?? 8;
      final max = int.tryParse(parts[1]) ?? 12;
      return ((min + max) / 2).round();
    }
    return int.tryParse(repsRange) ?? 10;
  }
}

/// Ejercicio dentro de una sesión externa
class ExternalExercise {
  final String name;
  final int? libraryId; // ID en la biblioteca (null si no matcheó)
  final int series;
  final String repsRange; // "10" o "8-12"
  final double? weight; // kg
  final String? notes;
  final double confidence; // 0.0 - 1.0
  final String rawInput; // Texto original del usuario

  const ExternalExercise({
    required this.name,
    this.libraryId,
    required this.series,
    required this.repsRange,
    this.weight,
    this.notes,
    required this.confidence,
    required this.rawInput,
  });

  bool get isMatched => libraryId != null;

  /// Color de confianza para UI
  ConfidenceLevel get confidenceLevel {
    if (confidence >= 0.8) return ConfidenceLevel.high;
    if (confidence >= 0.6) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  ExternalExercise copyWith({
    String? name,
    int? libraryId,
    int? series,
    String? repsRange,
    double? weight,
    String? notes,
    double? confidence,
    String? rawInput,
  }) {
    return ExternalExercise(
      name: name ?? this.name,
      libraryId: libraryId ?? this.libraryId,
      series: series ?? this.series,
      repsRange: repsRange ?? this.repsRange,
      weight: weight ?? this.weight,
      notes: notes ?? this.notes,
      confidence: confidence ?? this.confidence,
      rawInput: rawInput ?? this.rawInput,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'libraryId': libraryId,
      'series': series,
      'repsRange': repsRange,
      'weight': weight,
      'notes': notes,
      'confidence': confidence,
      'rawInput': rawInput,
    };
  }

  factory ExternalExercise.fromJson(Map<String, dynamic> json) {
    return ExternalExercise(
      name: json['name'] as String,
      libraryId: json['libraryId'] as int?,
      series: json['series'] as int,
      repsRange: json['repsRange'] as String,
      weight: (json['weight'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      rawInput: json['rawInput'] as String,
    );
  }
}

/// Fuente de captura de la sesión externa
enum ExternalSessionSource {
  voice,  // Dictado por voz
  ocr,    // Escaneado con cámara
  text,   // Escrito manualmente
  manual, // Formulario manual
}

extension ExternalSessionSourceExt on ExternalSessionSource {
  String get displayName {
    switch (this) {
      case ExternalSessionSource.voice:
        return 'Voz';
      case ExternalSessionSource.ocr:
        return 'Escáner';
      case ExternalSessionSource.text:
        return 'Texto';
      case ExternalSessionSource.manual:
        return 'Manual';
    }
  }

  IconDataWrapper get icon {
    switch (this) {
      case ExternalSessionSource.voice:
        return const IconDataWrapper(0xe31d); // mic
      case ExternalSessionSource.ocr:
        return const IconDataWrapper(0xe3af); // photo_camera
      case ExternalSessionSource.text:
        return const IconDataWrapper(0xe244); // keyboard
      case ExternalSessionSource.manual:
        return const IconDataWrapper(0xef65); // touch_app
    }
  }
}

/// Wrapper para IconData sin depender de Flutter en el modelo
class IconDataWrapper {
  final int codePoint;
  const IconDataWrapper(this.codePoint);
}

/// Nivel de confianza para UI
enum ConfidenceLevel {
  high,   // >= 80% - Verde
  medium, // 60-79% - Amarillo
  low,    // < 60% - Rojo
}

extension ConfidenceLevelExt on ConfidenceLevel {
  String get label {
    switch (this) {
      case ConfidenceLevel.high:
        return 'Alta';
      case ConfidenceLevel.medium:
        return 'Media';
      case ConfidenceLevel.low:
        return 'Baja';
    }
  }
}
