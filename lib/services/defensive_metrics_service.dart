import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Sistema de métricas DEFENSIVAS para OCR y Voz
///
/// CAMBIO DE PARADIGMA:
/// ❌ NO medir % de aciertos del OCR (accuracy técnica)
/// ✅ Medir experiencia del usuario con el sistema
///
/// Métricas correctas:
/// - % de sesiones corregidas sin frustración
/// - % de propuestas aceptadas tras revisión
/// - Tiempo medio de corrección
/// - Abandonos tras OCR/Voz
///
/// OBJETIVO:
/// Que OCR y voz sean un "asistente torpe pero útil",
/// no un "autómata confiado que se equivoca".
class DefensiveMetricsService {
  static final DefensiveMetricsService instance = DefensiveMetricsService._();
  DefensiveMetricsService._();

  final _logger = Logger();

  // Keys para persistencia
  static const _keyPrefix = 'defensive_metrics_';
  static const _keyImportSessions = '${_keyPrefix}import_sessions';
  static const _keyAggregates = '${_keyPrefix}aggregates';

  // Sesión actual (in-memory)
  ImportSession? _currentSession;

  // Agregados históricos
  AggregatedMetrics _aggregates = AggregatedMetrics.empty();

  /// Inicializa el servicio y carga métricas históricas
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final aggregatesJson = prefs.getString(_keyAggregates);
      if (aggregatesJson != null) {
        _aggregates = AggregatedMetrics.fromJson(jsonDecode(aggregatesJson));
      }
      _logger.i('DefensiveMetricsService inicializado');
    } catch (e) {
      _logger.e('Error cargando métricas: $e');
    }
  }

  // =========================================
  // TRACKING DE SESIÓN DE IMPORTACIÓN
  // =========================================

  /// Inicia una nueva sesión de importación (OCR o Voz)
  void startImportSession({
    required ImportSource source,
    required int initialProposalCount,
  }) {
    _currentSession = ImportSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      source: source,
      startedAt: DateTime.now(),
      initialProposalCount: initialProposalCount,
    );
    _logger.d('Sesión de importación iniciada: ${source.name}');
  }

  /// Registra una corrección del usuario
  void recordCorrection({
    required CorrectionType type,
    required Duration timeToCorrect,
    String? originalValue,
    String? correctedValue,
  }) {
    if (_currentSession == null) {
      _logger.w('No hay sesión activa para registrar corrección');
      return;
    }

    final correction = UserCorrection(
      type: type,
      timeToCorrect: timeToCorrect,
      correctedAt: DateTime.now(),
      originalValue: originalValue,
      correctedValue: correctedValue,
    );

    _currentSession = _currentSession!.addCorrection(correction);
    _logger.d('Corrección registrada: $type (${timeToCorrect.inSeconds}s)');
  }

  /// Registra una propuesta aceptada sin cambios
  void recordAcceptance({
    required double confidence,
  }) {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.addAcceptance(confidence);
    _logger.d('Propuesta aceptada (confianza: ${(confidence * 100).toInt()}%)');
  }

  /// Registra un ejercicio eliminado de la propuesta
  void recordDeletion() {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.addDeletion();
    _logger.d('Ejercicio eliminado de propuesta');
  }

  /// Registra abandono de la sesión de importación
  void recordAbandonment({
    required AbandonmentReason reason,
    String? feedback,
  }) {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.markAbandoned(reason, feedback);
    _endSession();
    _logger.w('Sesión abandonada: ${reason.name}');
  }

  /// Finaliza la sesión exitosamente
  void completeSession({
    required int finalExerciseCount,
  }) {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.markCompleted(finalExerciseCount);
    _endSession();
    _logger.i('Sesión completada: $finalExerciseCount ejercicios importados');
  }

  /// Guarda la sesión y actualiza agregados
  Future<void> _endSession() async {
    if (_currentSession == null) return;

    final session = _currentSession!;
    _currentSession = null;

    // Actualizar agregados
    _aggregates = _aggregates.incorporateSession(session);

    // Persistir
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAggregates, jsonEncode(_aggregates.toJson()));
    } catch (e) {
      _logger.e('Error guardando métricas: $e');
    }
  }

  // =========================================
  // CONSULTA DE MÉTRICAS
  // =========================================

  /// Obtiene las métricas agregadas actuales
  AggregatedMetrics get aggregatedMetrics => _aggregates;

  /// Obtiene un resumen para mostrar en dashboard
  MetricsSummary getSummary() {
    return MetricsSummary(
      acceptanceRate: _aggregates.acceptanceRate,
      averageCorrectionTime: _aggregates.averageCorrectionTime,
      abandonmentRate: _aggregates.abandonmentRate,
      frustratedSessionRate: _aggregates.frustratedSessionRate,
      totalSessions: _aggregates.totalSessions,
    );
  }

  /// Evalúa la salud del sistema
  SystemHealth evaluateHealth() {
    final summary = getSummary();

    // Umbrales de salud
    if (summary.abandonmentRate > 0.3 || summary.frustratedSessionRate > 0.25) {
      return SystemHealth.poor;
    }
    if (summary.abandonmentRate > 0.15 || summary.frustratedSessionRate > 0.15) {
      return SystemHealth.needsAttention;
    }
    if (summary.acceptanceRate >= 0.6 && summary.abandonmentRate < 0.1) {
      return SystemHealth.good;
    }
    return SystemHealth.acceptable;
  }

  /// Limpia todas las métricas (para testing o reset)
  Future<void> clearAll() async {
    _aggregates = AggregatedMetrics.empty();
    _currentSession = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAggregates);
      await prefs.remove(_keyImportSessions);
    } catch (_) {}
  }
}

// =========================================
// MODELOS DE DATOS
// =========================================

/// Sesión de importación individual
@immutable
class ImportSession {
  final String id;
  final ImportSource source;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int initialProposalCount;
  final int? finalExerciseCount;
  final List<UserCorrection> corrections;
  final List<double> acceptedConfidences;
  final int deletedCount;
  final SessionOutcome outcome;
  final AbandonmentReason? abandonmentReason;
  final String? userFeedback;

  const ImportSession({
    required this.id,
    required this.source,
    required this.startedAt,
    this.completedAt,
    required this.initialProposalCount,
    this.finalExerciseCount,
    this.corrections = const [],
    this.acceptedConfidences = const [],
    this.deletedCount = 0,
    this.outcome = SessionOutcome.inProgress,
    this.abandonmentReason,
    this.userFeedback,
  });

  /// Duración de la sesión
  Duration get duration {
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  /// Número total de correcciones
  int get correctionCount => corrections.length;

  /// Tiempo total de correcciones
  Duration get totalCorrectionTime {
    return corrections.fold(
      Duration.zero,
      (total, c) => total + c.timeToCorrect,
    );
  }

  /// % de propuestas aceptadas sin cambios
  double get acceptanceRate {
    final total = correctionCount + acceptedConfidences.length + deletedCount;
    if (total == 0) return 0;
    return acceptedConfidences.length / total;
  }

  /// ¿Sesión frustrante? (muchas correcciones o tiempo excesivo)
  bool get wasFrustrating {
    // Más de 3 correcciones o más de 2 minutos de correcciones
    return correctionCount > 3 ||
        totalCorrectionTime.inSeconds > 120 ||
        outcome == SessionOutcome.abandoned;
  }

  // Factory methods para actualizar inmutablemente
  ImportSession addCorrection(UserCorrection correction) {
    return ImportSession(
      id: id,
      source: source,
      startedAt: startedAt,
      completedAt: completedAt,
      initialProposalCount: initialProposalCount,
      finalExerciseCount: finalExerciseCount,
      corrections: [...corrections, correction],
      acceptedConfidences: acceptedConfidences,
      deletedCount: deletedCount,
      outcome: outcome,
      abandonmentReason: abandonmentReason,
      userFeedback: userFeedback,
    );
  }

  ImportSession addAcceptance(double confidence) {
    return ImportSession(
      id: id,
      source: source,
      startedAt: startedAt,
      completedAt: completedAt,
      initialProposalCount: initialProposalCount,
      finalExerciseCount: finalExerciseCount,
      corrections: corrections,
      acceptedConfidences: [...acceptedConfidences, confidence],
      deletedCount: deletedCount,
      outcome: outcome,
      abandonmentReason: abandonmentReason,
      userFeedback: userFeedback,
    );
  }

  ImportSession addDeletion() {
    return ImportSession(
      id: id,
      source: source,
      startedAt: startedAt,
      completedAt: completedAt,
      initialProposalCount: initialProposalCount,
      finalExerciseCount: finalExerciseCount,
      corrections: corrections,
      acceptedConfidences: acceptedConfidences,
      deletedCount: deletedCount + 1,
      outcome: outcome,
      abandonmentReason: abandonmentReason,
      userFeedback: userFeedback,
    );
  }

  ImportSession markCompleted(int finalCount) {
    return ImportSession(
      id: id,
      source: source,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      initialProposalCount: initialProposalCount,
      finalExerciseCount: finalCount,
      corrections: corrections,
      acceptedConfidences: acceptedConfidences,
      deletedCount: deletedCount,
      outcome: SessionOutcome.completed,
      abandonmentReason: null,
      userFeedback: userFeedback,
    );
  }

  ImportSession markAbandoned(AbandonmentReason reason, String? feedback) {
    return ImportSession(
      id: id,
      source: source,
      startedAt: startedAt,
      completedAt: DateTime.now(),
      initialProposalCount: initialProposalCount,
      finalExerciseCount: 0,
      corrections: corrections,
      acceptedConfidences: acceptedConfidences,
      deletedCount: deletedCount,
      outcome: SessionOutcome.abandoned,
      abandonmentReason: reason,
      userFeedback: feedback,
    );
  }
}

/// Corrección realizada por el usuario
@immutable
class UserCorrection {
  final CorrectionType type;
  final Duration timeToCorrect;
  final DateTime correctedAt;
  final String? originalValue;
  final String? correctedValue;

  const UserCorrection({
    required this.type,
    required this.timeToCorrect,
    required this.correctedAt,
    this.originalValue,
    this.correctedValue,
  });
}

/// Métricas agregadas históricas
@immutable
class AggregatedMetrics {
  // Contadores totales
  final int totalSessions;
  final int completedSessions;
  final int abandonedSessions;
  final int frustratedSessions;

  // Correcciones
  final int totalCorrections;
  final int totalAcceptances;
  final int totalDeletions;
  final Duration totalCorrectionTime;

  // Por tipo de corrección
  final Map<CorrectionType, int> correctionsByType;

  // Por fuente
  final Map<ImportSource, int> sessionsBySource;
  final Map<ImportSource, int> abandonmentsBySource;

  const AggregatedMetrics({
    required this.totalSessions,
    required this.completedSessions,
    required this.abandonedSessions,
    required this.frustratedSessions,
    required this.totalCorrections,
    required this.totalAcceptances,
    required this.totalDeletions,
    required this.totalCorrectionTime,
    required this.correctionsByType,
    required this.sessionsBySource,
    required this.abandonmentsBySource,
  });

  factory AggregatedMetrics.empty() {
    return const AggregatedMetrics(
      totalSessions: 0,
      completedSessions: 0,
      abandonedSessions: 0,
      frustratedSessions: 0,
      totalCorrections: 0,
      totalAcceptances: 0,
      totalDeletions: 0,
      totalCorrectionTime: Duration.zero,
      correctionsByType: {},
      sessionsBySource: {},
      abandonmentsBySource: {},
    );
  }

  // Métricas calculadas

  /// % de propuestas aceptadas sin cambios
  double get acceptanceRate {
    final total = totalCorrections + totalAcceptances + totalDeletions;
    if (total == 0) return 0;
    return totalAcceptances / total;
  }

  /// Tiempo promedio de corrección
  Duration get averageCorrectionTime {
    if (totalCorrections == 0) return Duration.zero;
    return Duration(
      milliseconds: totalCorrectionTime.inMilliseconds ~/ totalCorrections,
    );
  }

  /// % de sesiones abandonadas
  double get abandonmentRate {
    if (totalSessions == 0) return 0;
    return abandonedSessions / totalSessions;
  }

  /// % de sesiones frustrantes
  double get frustratedSessionRate {
    if (totalSessions == 0) return 0;
    return frustratedSessions / totalSessions;
  }

  /// Incorpora una sesión nueva
  AggregatedMetrics incorporateSession(ImportSession session) {
    final newCorrectionsByType = Map<CorrectionType, int>.from(correctionsByType);
    for (final c in session.corrections) {
      newCorrectionsByType[c.type] = (newCorrectionsByType[c.type] ?? 0) + 1;
    }

    final newSessionsBySource = Map<ImportSource, int>.from(sessionsBySource);
    newSessionsBySource[session.source] = (newSessionsBySource[session.source] ?? 0) + 1;

    final newAbandonmentsBySource = Map<ImportSource, int>.from(abandonmentsBySource);
    if (session.outcome == SessionOutcome.abandoned) {
      newAbandonmentsBySource[session.source] =
          (newAbandonmentsBySource[session.source] ?? 0) + 1;
    }

    return AggregatedMetrics(
      totalSessions: totalSessions + 1,
      completedSessions:
          completedSessions + (session.outcome == SessionOutcome.completed ? 1 : 0),
      abandonedSessions:
          abandonedSessions + (session.outcome == SessionOutcome.abandoned ? 1 : 0),
      frustratedSessions: frustratedSessions + (session.wasFrustrating ? 1 : 0),
      totalCorrections: totalCorrections + session.correctionCount,
      totalAcceptances: totalAcceptances + session.acceptedConfidences.length,
      totalDeletions: totalDeletions + session.deletedCount,
      totalCorrectionTime: totalCorrectionTime + session.totalCorrectionTime,
      correctionsByType: newCorrectionsByType,
      sessionsBySource: newSessionsBySource,
      abandonmentsBySource: newAbandonmentsBySource,
    );
  }

  // Serialización
  Map<String, dynamic> toJson() => {
        'totalSessions': totalSessions,
        'completedSessions': completedSessions,
        'abandonedSessions': abandonedSessions,
        'frustratedSessions': frustratedSessions,
        'totalCorrections': totalCorrections,
        'totalAcceptances': totalAcceptances,
        'totalDeletions': totalDeletions,
        'totalCorrectionTimeMs': totalCorrectionTime.inMilliseconds,
        'correctionsByType':
            correctionsByType.map((k, v) => MapEntry(k.name, v)),
        'sessionsBySource': sessionsBySource.map((k, v) => MapEntry(k.name, v)),
        'abandonmentsBySource':
            abandonmentsBySource.map((k, v) => MapEntry(k.name, v)),
      };

  factory AggregatedMetrics.fromJson(Map<String, dynamic> json) {
    return AggregatedMetrics(
      totalSessions: json['totalSessions'] ?? 0,
      completedSessions: json['completedSessions'] ?? 0,
      abandonedSessions: json['abandonedSessions'] ?? 0,
      frustratedSessions: json['frustratedSessions'] ?? 0,
      totalCorrections: json['totalCorrections'] ?? 0,
      totalAcceptances: json['totalAcceptances'] ?? 0,
      totalDeletions: json['totalDeletions'] ?? 0,
      totalCorrectionTime:
          Duration(milliseconds: json['totalCorrectionTimeMs'] ?? 0),
      correctionsByType: (json['correctionsByType'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(
                    CorrectionType.values.firstWhere((e) => e.name == k),
                    v as int,
                  )) ??
          {},
      sessionsBySource: (json['sessionsBySource'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(
                    ImportSource.values.firstWhere((e) => e.name == k),
                    v as int,
                  )) ??
          {},
      abandonmentsBySource:
          (json['abandonmentsBySource'] as Map<String, dynamic>?)?.map((k, v) =>
                  MapEntry(
                    ImportSource.values.firstWhere((e) => e.name == k),
                    v as int,
                  )) ??
              {},
    );
  }
}

/// Resumen de métricas para dashboard
@immutable
class MetricsSummary {
  final double acceptanceRate;
  final Duration averageCorrectionTime;
  final double abandonmentRate;
  final double frustratedSessionRate;
  final int totalSessions;

  const MetricsSummary({
    required this.acceptanceRate,
    required this.averageCorrectionTime,
    required this.abandonmentRate,
    required this.frustratedSessionRate,
    required this.totalSessions,
  });

  /// Formato legible para UI
  String get acceptanceRateFormatted => '${(acceptanceRate * 100).toInt()}%';
  String get correctionTimeFormatted => '${averageCorrectionTime.inSeconds}s';
  String get abandonmentRateFormatted => '${(abandonmentRate * 100).toInt()}%';
}

// =========================================
// ENUMS
// =========================================

/// Fuente de importación
enum ImportSource {
  ocr,
  voice,
}

/// Tipo de corrección realizada
enum CorrectionType {
  /// Usuario cambió el ejercicio propuesto
  exerciseChanged,

  /// Usuario cambió las series
  seriesChanged,

  /// Usuario cambió las reps
  repsChanged,

  /// Usuario cambió el peso
  weightChanged,

  /// Usuario eligió de candidatos alternativos
  selectedFromAlternatives,

  /// Usuario buscó manualmente
  manualSearch,
}

/// Resultado de la sesión
enum SessionOutcome {
  inProgress,
  completed,
  abandoned,
}

/// Razón de abandono
enum AbandonmentReason {
  /// Propuestas eran incorrectas
  incorrectProposals,

  /// Toma demasiado tiempo corregir
  tooTimeConsuming,

  /// Usuario decidió hacerlo manualmente
  preferManual,

  /// Error técnico
  technicalError,

  /// Usuario canceló sin razón explícita
  userCancelled,

  /// Otra razón
  other,
}

/// Salud del sistema
enum SystemHealth {
  /// Todo funciona bien
  good,

  /// Aceptable pero podría mejorar
  acceptable,

  /// Necesita atención
  needsAttention,

  /// Problemas serios
  poor,
}
