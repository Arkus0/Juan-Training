import 'package:flutter/foundation.dart';

import '../services/exercise_parsing_service.dart';
import '../services/routine_ocr_service.dart';
import '../services/voice_input_service.dart';
import 'ejercicio_en_rutina.dart';
import 'library_exercise.dart';

/// Fuente de detección del ejercicio
enum DetectionSource {
  /// Detectado via OCR (escaneo de imagen)
  ocr,

  /// Detectado via reconocimiento de voz
  voice,

  /// Añadido manualmente por el usuario
  manual,
}

/// Modelo intermedio que encapsula un ejercicio detectado (OCR o Voz)
/// con toda la metadata necesaria para edición controlada.
///
/// Este modelo actúa como "buffer de edición" entre:
/// - Input imperfecto (OCR/Voz con errores potenciales)
/// - Datos finales persistentes (EjercicioEnRutina)
///
/// Principios de diseño:
/// 1. Preserva datos originales para auditoría/debug
/// 2. Trackea si el usuario modificó algo
/// 3. Permite invalidar/recalcular confianza tras edición
/// 4. Soporta undo (comparando con originales)
@immutable
class DetectedExerciseDraft {
  // ============================================
  // DATOS ORIGINALES (INMUTABLES - para auditoría)
  // ============================================

  /// Texto crudo original tal como lo detectó OCR/Voz
  final String originalRawText;

  /// Nombre del ejercicio según match original de IA (puede ser null si no hubo match)
  final String? originalMatchedName;

  /// ID del ejercicio en biblioteca según match original
  final int? originalMatchedId;

  /// Confianza original del match (0.0 - 1.0)
  final double originalConfidence;

  /// Fuente de detección (OCR, voz, manual)
  final DetectionSource source;

  /// Timestamp de detección
  final DateTime detectedAt;

  // ============================================
  // DATOS ACTUALES (EDITABLES por usuario)
  // ============================================

  /// Nombre actual del ejercicio (puede diferir de original si usuario corrigió)
  final String? currentMatchedName;

  /// ID actual del ejercicio en biblioteca
  final int? currentMatchedId;

  /// Número de series
  final int series;

  /// Rango de repeticiones (ej: "10", "8-12")
  final String repsRange;

  /// Peso en kg (opcional)
  final double? weight;

  /// Notas adicionales
  final String? notes;

  /// Grupo de superserie (0 = no es superserie)
  final int supersetGroup;

  // ============================================
  // METADATA DE EDICIÓN
  // ============================================

  /// True si el usuario editó cualquier campo
  final bool wasManuallyEdited;

  /// True si el usuario cambió específicamente el ejercicio (nombre/id)
  final bool wasNameChanged;

  /// True si el usuario cambió series, reps o peso
  final bool wasSeriesRepsChanged;

  /// Timestamp de última edición (null si nunca se editó)
  final DateTime? lastEditedAt;

  // ============================================
  // ORDEN Y ESTADO
  // ============================================

  /// Índice de orden en la lista (para drag & drop)
  final int orderIndex;

  /// True si el usuario explícitamente marcó como "verificado/correcto"
  final bool isVerified;

  const DetectedExerciseDraft({
    // Originales
    required this.originalRawText,
    this.originalMatchedName,
    this.originalMatchedId,
    this.originalConfidence = 0.0,
    required this.source,
    required this.detectedAt,
    // Actuales
    this.currentMatchedName,
    this.currentMatchedId,
    this.series = 3,
    this.repsRange = '10',
    this.weight,
    this.notes,
    this.supersetGroup = 0,
    // Metadata edición
    this.wasManuallyEdited = false,
    this.wasNameChanged = false,
    this.wasSeriesRepsChanged = false,
    this.lastEditedAt,
    // Orden
    this.orderIndex = 0,
    this.isVerified = false,
  });

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  /// True si el ejercicio tiene un match válido (ID no null)
  bool get isValid => currentMatchedId != null;

  /// True si requiere revisión del usuario (baja confianza o editado)
  bool get needsReview => !isVerified && (originalConfidence < 0.7 || !isValid);

  /// True si es parte de una superserie
  bool get isSuperset => supersetGroup > 0;

  /// Confianza efectiva considerando ediciones
  /// - null si el nombre fue cambiado (usuario eligió, no hay "confianza IA")
  /// - originalConfidence si no hubo cambios
  double? get effectiveConfidence {
    if (wasNameChanged || isVerified) {
      return null; // Usuario verificó manualmente, confianza IA no aplica
    }
    return originalConfidence;
  }

  /// Label para mostrar en UI según estado de confianza
  String get confidenceLabel {
    if (isVerified || wasNameChanged) {
      return 'VERIFICADO';
    }

    final conf = effectiveConfidence;
    if (conf == null) return 'EDITADO';

    final percentage = (conf * 100).toInt();
    if (conf >= 0.8) return '$percentage%';
    if (conf >= 0.5) return '$percentage%';
    return '$percentage%';
  }

  /// Color sugerido para el indicador de confianza (como string para flexibilidad)
  String get confidenceColorHint {
    if (isVerified || wasNameChanged) return 'verified'; // Verde/Cyan
    final conf = effectiveConfidence;
    if (conf == null) return 'edited'; // Azul
    if (conf >= 0.8) return 'high'; // Verde
    if (conf >= 0.5) return 'medium'; // Amarillo
    return 'low'; // Rojo/Naranja
  }

  /// Número mínimo de reps del rango
  int get minReps {
    final parts = repsRange.split('-');
    return int.tryParse(parts.first.trim()) ?? 10;
  }

  /// Número máximo de reps del rango
  int get maxReps {
    final parts = repsRange.split('-');
    if (parts.length > 1) {
      return int.tryParse(parts.last.trim()) ?? minReps;
    }
    return minReps;
  }

  /// Resumen corto para debug/logs
  String get summary =>
      '${currentMatchedName ?? "NO MATCH"} ${series}x$repsRange ${weight != null ? "${weight}kg" : ""} [$confidenceLabel]';

  // ============================================
  // FACTORY CONSTRUCTORS
  // ============================================

  /// Crea un draft desde un ParsedExercise (resultado del parsing unificado)
  factory DetectedExerciseDraft.fromParsedExercise(
    ParsedExercise parsed, {
    required DetectionSource source,
    int orderIndex = 0,
  }) {
    final now = DateTime.now();
    return DetectedExerciseDraft(
      // Originales
      originalRawText: parsed.rawText,
      originalMatchedName: parsed.matchedName,
      originalMatchedId: parsed.matchedId,
      originalConfidence: parsed.confidence,
      source: source,
      detectedAt: now,
      // Actuales (copia de originales)
      currentMatchedName: parsed.matchedName,
      currentMatchedId: parsed.matchedId,
      series: parsed.series,
      repsRange: parsed.repsRange,
      weight: parsed.weight,
      notes: parsed.notes,
      supersetGroup: parsed.supersetGroup,
      orderIndex: orderIndex,
    );
  }

  /// Crea un draft desde VoiceParsedExercise (compatibilidad con código existente)
  factory DetectedExerciseDraft.fromVoiceParsed(
    VoiceParsedExercise voice, {
    int orderIndex = 0,
  }) {
    final now = DateTime.now();
    return DetectedExerciseDraft(
      originalRawText: voice.rawText,
      originalMatchedName: voice.matchedName,
      originalMatchedId: voice.matchedId,
      originalConfidence: voice.confidence,
      source: DetectionSource.voice,
      detectedAt: now,
      currentMatchedName: voice.matchedName,
      currentMatchedId: voice.matchedId,
      series: voice.series,
      repsRange: voice.repsRange,
      weight: voice.weight,
      notes: voice.notes,
      supersetGroup: voice.supersetGroup,
      orderIndex: orderIndex,
    );
  }

  /// Crea un draft desde ParsedExerciseCandidate (compatibilidad OCR existente)
  factory DetectedExerciseDraft.fromOcrCandidate(
    ParsedExerciseCandidate ocr, {
    int orderIndex = 0,
  }) {
    final now = DateTime.now();
    return DetectedExerciseDraft(
      originalRawText: ocr.rawText,
      originalMatchedName: ocr.matchedExerciseName,
      originalMatchedId: ocr.matchedExerciseId,
      originalConfidence: ocr.confidence,
      source: DetectionSource.ocr,
      detectedAt: now,
      currentMatchedName: ocr.matchedExerciseName,
      currentMatchedId: ocr.matchedExerciseId,
      series: ocr.series,
      repsRange: ocr.reps.toString(),
      weight: ocr.weight,
      orderIndex: orderIndex,
    );
  }

  /// Crea un draft vacío para entrada manual
  factory DetectedExerciseDraft.manual({
    required String name,
    required int exerciseId,
    int series = 3,
    String repsRange = '10',
    double? weight,
    int orderIndex = 0,
  }) {
    final now = DateTime.now();
    return DetectedExerciseDraft(
      originalRawText: name,
      originalMatchedName: name,
      originalMatchedId: exerciseId,
      originalConfidence: 1.0,
      source: DetectionSource.manual,
      detectedAt: now,
      currentMatchedName: name,
      currentMatchedId: exerciseId,
      series: series,
      repsRange: repsRange,
      weight: weight,
      orderIndex: orderIndex,
      isVerified: true, // Manual = siempre verificado
    );
  }

  // ============================================
  // COPY WITH (Inmutable updates)
  // ============================================

  DetectedExerciseDraft copyWith({
    String? originalRawText,
    String? originalMatchedName,
    int? originalMatchedId,
    double? originalConfidence,
    DetectionSource? source,
    DateTime? detectedAt,
    String? currentMatchedName,
    int? currentMatchedId,
    int? series,
    String? repsRange,
    double? weight,
    String? notes,
    int? supersetGroup,
    bool? wasManuallyEdited,
    bool? wasNameChanged,
    bool? wasSeriesRepsChanged,
    DateTime? lastEditedAt,
    int? orderIndex,
    bool? isVerified,
  }) {
    return DetectedExerciseDraft(
      originalRawText: originalRawText ?? this.originalRawText,
      originalMatchedName: originalMatchedName ?? this.originalMatchedName,
      originalMatchedId: originalMatchedId ?? this.originalMatchedId,
      originalConfidence: originalConfidence ?? this.originalConfidence,
      source: source ?? this.source,
      detectedAt: detectedAt ?? this.detectedAt,
      currentMatchedName: currentMatchedName ?? this.currentMatchedName,
      currentMatchedId: currentMatchedId ?? this.currentMatchedId,
      series: series ?? this.series,
      repsRange: repsRange ?? this.repsRange,
      weight: weight ?? this.weight,
      notes: notes ?? this.notes,
      supersetGroup: supersetGroup ?? this.supersetGroup,
      wasManuallyEdited: wasManuallyEdited ?? this.wasManuallyEdited,
      wasNameChanged: wasNameChanged ?? this.wasNameChanged,
      wasSeriesRepsChanged: wasSeriesRepsChanged ?? this.wasSeriesRepsChanged,
      lastEditedAt: lastEditedAt ?? this.lastEditedAt,
      orderIndex: orderIndex ?? this.orderIndex,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  // ============================================
  // MÉTODOS DE EDICIÓN (retornan nuevo draft)
  // ============================================

  /// Cambia el ejercicio matcheado (cuando usuario elige alternativa)
  DetectedExerciseDraft withNewMatch({
    required String newName,
    required int newId,
  }) {
    return copyWith(
      currentMatchedName: newName,
      currentMatchedId: newId,
      wasManuallyEdited: true,
      wasNameChanged: true,
      lastEditedAt: DateTime.now(),
      isVerified: true, // Usuario eligió explícitamente
    );
  }

  /// Actualiza series
  DetectedExerciseDraft withSeries(int newSeries) {
    if (newSeries == series) return this;
    return copyWith(
      series: newSeries,
      wasManuallyEdited: true,
      wasSeriesRepsChanged: true,
      lastEditedAt: DateTime.now(),
    );
  }

  /// Actualiza reps
  DetectedExerciseDraft withRepsRange(String newRepsRange) {
    if (newRepsRange == repsRange) return this;
    return copyWith(
      repsRange: newRepsRange,
      wasManuallyEdited: true,
      wasSeriesRepsChanged: true,
      lastEditedAt: DateTime.now(),
    );
  }

  /// Actualiza peso
  DetectedExerciseDraft withWeight(double? newWeight) {
    if (newWeight == weight) return this;
    return copyWith(
      weight: newWeight,
      wasManuallyEdited: true,
      wasSeriesRepsChanged: true,
      lastEditedAt: DateTime.now(),
    );
  }

  /// Actualiza notas
  DetectedExerciseDraft withNotes(String? newNotes) {
    if (newNotes == notes) return this;
    return copyWith(
      notes: newNotes,
      wasManuallyEdited: true,
      lastEditedAt: DateTime.now(),
    );
  }

  /// Actualiza orden
  DetectedExerciseDraft withOrderIndex(int newIndex) {
    return copyWith(orderIndex: newIndex);
  }

  /// Marca como verificado por el usuario
  DetectedExerciseDraft markAsVerified() {
    return copyWith(
      isVerified: true,
      wasManuallyEdited: true,
      lastEditedAt: DateTime.now(),
    );
  }

  /// Resetea a valores originales (undo)
  DetectedExerciseDraft resetToOriginal() {
    return copyWith(
      currentMatchedName: originalMatchedName,
      currentMatchedId: originalMatchedId,
      wasManuallyEdited: false,
      wasNameChanged: false,
      wasSeriesRepsChanged: false,
      isVerified: false,
    );
  }

  /// Crea una copia para duplicación
  DetectedExerciseDraft duplicate({required int newOrderIndex}) {
    return copyWith(
      orderIndex: newOrderIndex,
      detectedAt: DateTime.now(),
      // Mantener ediciones pero es una "nueva" instancia
    );
  }

  // ============================================
  // CONVERSIÓN A MODELO FINAL
  // ============================================

  /// Convierte a SmartImportedExercise (compatibilidad con código existente)
  /// DEPRECATED: Usar toEjercicioEnRutina para persistencia
  Map<String, dynamic> toSmartImportedData() {
    return {
      'rawText': originalRawText,
      'matchedName': currentMatchedName,
      'matchedId': currentMatchedId,
      'series': series,
      'repsRange': repsRange,
      'weight': weight,
      'confidence': effectiveConfidence ?? 1.0,
      'source': source.name,
      'wasManuallyEdited': wasManuallyEdited,
    };
  }

  @override
  String toString() =>
      'DetectedExerciseDraft($summary, source: ${source.name}, edited: $wasManuallyEdited)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DetectedExerciseDraft &&
        other.originalRawText == originalRawText &&
        other.currentMatchedId == currentMatchedId &&
        other.series == series &&
        other.repsRange == repsRange &&
        other.weight == weight &&
        other.orderIndex == orderIndex;
  }

  @override
  int get hashCode =>
      originalRawText.hashCode ^
      currentMatchedId.hashCode ^
      series.hashCode ^
      repsRange.hashCode ^
      orderIndex.hashCode;
}

/// Extensión para conversión a modelos finales
extension DetectedExerciseDraftConversion on DetectedExerciseDraft {
  /// Convierte este draft a EjercicioEnRutina usando datos de LibraryExercise.
  ///
  /// Requiere el LibraryExercise correspondiente para obtener datos completos
  /// (músculos, equipo, etc.) que no se almacenan en el draft.
  ///
  /// [libraryExercise] El ejercicio de biblioteca con datos completos.
  /// [supersetId] ID de superserie si aplica (generado externamente).
  EjercicioEnRutina toEjercicioEnRutina(
    LibraryExercise libraryExercise, {
    String? supersetId,
  }) {
    // Importación dinámica para evitar dependencia circular
    // ignore: depend_on_referenced_packages
    return EjercicioEnRutina(
      id: libraryExercise.id.toString(),
      nombre: libraryExercise.name,
      descripcion: libraryExercise.description,
      musculosPrincipales: libraryExercise.muscles.isNotEmpty
          ? libraryExercise.muscles
          : [libraryExercise.muscleGroup],
      musculosSecundarios: libraryExercise.secondaryMuscles,
      equipo: libraryExercise.equipment,
      localImagePath: libraryExercise.localImagePath,
      series: series,
      repsRange: repsRange,
      notas: _buildNotas(),
      supersetId: supersetId,
    );
  }

  /// Construye las notas combinando notas del draft + metadata de importación
  String? _buildNotas() {
    final parts = <String>[];

    // Notas originales del usuario
    if (notes != null && notes!.isNotEmpty) {
      parts.add(notes!);
    }

    // Si hay peso detectado, añadirlo como referencia
    if (weight != null) {
      parts.add('Peso sugerido: ${weight!.toStringAsFixed(1)}kg');
    }

    return parts.isEmpty ? null : parts.join(' | ');
  }
}
