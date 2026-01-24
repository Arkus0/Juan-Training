import 'package:flutter/foundation.dart';
import '../services/exercise_matching_service.dart';
import 'library_exercise.dart';
import 'raw_input_capture.dart';

/// Fase 2 del pipeline defensivo: Hipótesis interpretadas
///
/// PRINCIPIO FUNDAMENTAL:
/// La interpretación genera HIPÓTESIS, no decisiones.
/// Siempre presenta múltiples candidatos con confianza explícita.
/// El usuario tiene la última palabra.
///
/// Este modelo representa una interpretación ACOTADA del input,
/// con candidatos rankeados y restricciones claras.
@immutable
class InputHypothesis {
  /// Captura bruta original (para auditoría)
  final RawInputCapture rawCapture;

  /// Hipótesis de ejercicio (top N candidatos)
  final ExerciseHypothesis exerciseHypothesis;

  /// Hipótesis de series/reps (parsing conservador)
  final SeriesRepsHypothesis seriesRepsHypothesis;

  /// Estado de la hipótesis
  final HypothesisStatus status;

  /// Razón si requiere revisión obligatoria
  final String? reviewReason;

  /// Timestamp de generación
  final DateTime generatedAt;

  const InputHypothesis({
    required this.rawCapture,
    required this.exerciseHypothesis,
    required this.seriesRepsHypothesis,
    required this.status,
    this.reviewReason,
    required this.generatedAt,
  });

  /// ¿Requiere confirmación del usuario?
  bool get requiresUserConfirmation {
    // SIEMPRE requiere confirmación si:
    // 1. Ningún candidato tiene confianza alta
    // 2. Las series/reps están incompletas
    // 3. Hay ambigüedad entre candidatos
    return status != HypothesisStatus.highConfidence ||
        !exerciseHypothesis.hasHighConfidenceCandidate ||
        !seriesRepsHypothesis.isComplete;
  }

  /// ¿Puede auto-aceptarse? (CASI NUNCA debería ser true)
  bool get canAutoAccept {
    return status == HypothesisStatus.highConfidence &&
        exerciseHypothesis.hasUnambiguousMatch &&
        seriesRepsHypothesis.isComplete &&
        seriesRepsHypothesis.isValid;
  }

  /// Obtiene el mejor candidato de ejercicio (puede ser null)
  ExerciseCandidate? get topExerciseCandidate =>
      exerciseHypothesis.candidates.isNotEmpty
          ? exerciseHypothesis.candidates.first
          : null;

  @override
  String toString() =>
      'InputHypothesis(status: $status, exercise: ${topExerciseCandidate?.exercise.name}, '
      'confidence: ${topExerciseCandidate?.confidence ?? 0}%)';
}

/// Hipótesis de ejercicio con candidatos rankeados
@immutable
class ExerciseHypothesis {
  /// Texto original usado para el matching
  final String queryText;

  /// Lista de candidatos ordenados por confianza (máximo 5)
  final List<ExerciseCandidate> candidates;

  /// Fuente del matching
  final MatchSource primaryMatchSource;

  const ExerciseHypothesis({
    required this.queryText,
    required this.candidates,
    required this.primaryMatchSource,
  });

  /// Factory para crear hipótesis sin candidatos
  factory ExerciseHypothesis.noMatch(String queryText) {
    return ExerciseHypothesis(
      queryText: queryText,
      candidates: const [],
      primaryMatchSource: MatchSource.noMatch,
    );
  }

  /// ¿Hay al menos un candidato con confianza >= 80%?
  bool get hasHighConfidenceCandidate =>
      candidates.isNotEmpty && candidates.first.confidence >= 0.8;

  /// ¿El mejor candidato es inequívocamente mejor que el segundo?
  bool get hasUnambiguousMatch {
    if (candidates.length < 2) return candidates.isNotEmpty;

    final gap = candidates[0].confidence - candidates[1].confidence;
    return gap >= 0.15 && candidates[0].confidence >= 0.75;
  }

  /// ¿Hay ambigüedad entre los top candidatos?
  bool get hasAmbiguity {
    if (candidates.length < 2) return false;

    final gap = candidates[0].confidence - candidates[1].confidence;
    return gap < 0.1; // Menos de 10% de diferencia = ambiguo
  }

  /// Número de candidatos viables (confianza >= 50%)
  int get viableCandidateCount =>
      candidates.where((c) => c.confidence >= 0.5).length;
}

/// Candidato de ejercicio con confianza
@immutable
class ExerciseCandidate {
  /// Ejercicio de la biblioteca
  final LibraryExercise exercise;

  /// Confianza del match (0.0 - 1.0)
  final double confidence;

  /// Fuente del match
  final MatchSource source;

  /// ¿Fue resuelto via sinónimo?
  final String? resolvedSynonym;

  /// Razón del match (para debug/UI)
  final String? matchReason;

  const ExerciseCandidate({
    required this.exercise,
    required this.confidence,
    required this.source,
    this.resolvedSynonym,
    this.matchReason,
  });

  /// Confianza como porcentaje (0-100)
  int get confidencePercent => (confidence * 100).round();

  /// Etiqueta de confianza para UI
  String get confidenceLabel {
    if (confidence >= 0.9) return 'Muy alta';
    if (confidence >= 0.8) return 'Alta';
    if (confidence >= 0.6) return 'Media';
    if (confidence >= 0.4) return 'Baja';
    return 'Muy baja';
  }

  /// Color sugerido para UI (como hint)
  String get confidenceColorHint {
    if (confidence >= 0.8) return 'green';
    if (confidence >= 0.6) return 'yellow';
    if (confidence >= 0.4) return 'orange';
    return 'red';
  }

  @override
  String toString() =>
      'ExerciseCandidate(${exercise.name}, $confidencePercent%, $source)';
}

/// Hipótesis de series y repeticiones (parsing conservador)
///
/// PRINCIPIO: Si falta información, se deja VACÍO.
/// NUNCA se infiere por contexto ni se copia de sesiones anteriores.
@immutable
class SeriesRepsHypothesis {
  /// Series detectadas (null si no se detectó claramente)
  final ParsedValue<int>? series;

  /// Reps mínimas detectadas (null si no se detectó)
  final ParsedValue<int>? minReps;

  /// Reps máximas (para rangos como "8-12")
  final ParsedValue<int>? maxReps;

  /// Peso detectado (null si no se detectó)
  final ParsedValue<double>? weight;

  /// Patrón original detectado (ej: "4x10", "tres series de ocho")
  final String? detectedPattern;

  /// Advertencias del parsing
  final List<String> warnings;

  const SeriesRepsHypothesis({
    this.series,
    this.minReps,
    this.maxReps,
    this.weight,
    this.detectedPattern,
    this.warnings = const [],
  });

  /// Factory para hipótesis vacía (nada detectado)
  factory SeriesRepsHypothesis.empty() {
    return const SeriesRepsHypothesis(
      warnings: ['No se detectaron series ni repeticiones'],
    );
  }

  /// ¿Está completa? (tiene al menos series Y reps)
  bool get isComplete =>
      series != null && series!.isConfident && minReps != null && minReps!.isConfident;

  /// ¿Es un rango de reps? (ej: 8-12)
  bool get isRepsRange => maxReps != null && maxReps!.value != minReps?.value;

  /// ¿Tiene peso detectado?
  bool get hasWeight => weight != null && weight!.isConfident;

  /// ¿Es válida? (valores dentro de rangos razonables)
  bool get isValid {
    if (series != null && (series!.value < 1 || series!.value > 20)) return false;
    if (minReps != null && (minReps!.value < 1 || minReps!.value > 100)) return false;
    if (maxReps != null && maxReps!.value < (minReps?.value ?? 0)) return false;
    if (weight != null && (weight!.value < 0 || weight!.value > 500)) return false;
    return true;
  }

  /// Campos que faltan
  List<String> get missingFields {
    final missing = <String>[];
    if (series == null || !series!.isConfident) missing.add('series');
    if (minReps == null || !minReps!.isConfident) missing.add('repeticiones');
    return missing;
  }

  /// Obtiene el rango de reps como string (ej: "8-12" o "10")
  String? get repsRangeString {
    if (minReps == null) return null;
    if (maxReps != null && maxReps!.value != minReps!.value) {
      return '${minReps!.value}-${maxReps!.value}';
    }
    return minReps!.value.toString();
  }

  @override
  String toString() =>
      'SeriesRepsHypothesis(${series?.value ?? "?"}x${repsRangeString ?? "?"} '
      '${weight != null ? "${weight!.value}kg" : ""} complete: $isComplete)';
}

/// Valor parseado con confianza
@immutable
class ParsedValue<T> {
  /// Valor parseado
  final T value;

  /// Confianza del parsing (0.0 - 1.0)
  final double confidence;

  /// Texto original del que se extrajo
  final String sourceText;

  const ParsedValue({
    required this.value,
    required this.confidence,
    required this.sourceText,
  });

  /// ¿Es lo suficientemente confiable?
  bool get isConfident => confidence >= 0.7;

  /// ¿Requiere verificación?
  bool get needsVerification => confidence < 0.9;

  @override
  String toString() => 'ParsedValue($value, ${(confidence * 100).toInt()}%)';
}

/// Estado de la hipótesis
enum HypothesisStatus {
  /// Alta confianza, podría auto-aceptarse (raro)
  highConfidence,

  /// Confianza media, requiere confirmación
  mediumConfidence,

  /// Baja confianza, requiere corrección probable
  lowConfidence,

  /// Incompleto, faltan datos críticos
  incomplete,

  /// Ambiguo, múltiples candidatos similares
  ambiguous,

  /// No se pudo interpretar
  failed,
}

/// Extension para calcular el estado de una hipótesis
extension HypothesisStatusExtension on InputHypothesis {
  /// Calcula el estado basado en los componentes
  static HypothesisStatus calculateStatus({
    required ExerciseHypothesis exercise,
    required SeriesRepsHypothesis seriesReps,
  }) {
    // Sin candidatos = fallido
    if (exercise.candidates.isEmpty) {
      return HypothesisStatus.failed;
    }

    // Incompleto si faltan datos críticos
    if (!seriesReps.isComplete) {
      return HypothesisStatus.incomplete;
    }

    // Ambiguo si hay candidatos muy similares
    if (exercise.hasAmbiguity) {
      return HypothesisStatus.ambiguous;
    }

    // Calcular confianza combinada
    final topConfidence = exercise.candidates.first.confidence;

    if (topConfidence >= 0.8 && seriesReps.isValid) {
      return HypothesisStatus.highConfidence;
    }

    if (topConfidence >= 0.5) {
      return HypothesisStatus.mediumConfidence;
    }

    return HypothesisStatus.lowConfidence;
  }
}
