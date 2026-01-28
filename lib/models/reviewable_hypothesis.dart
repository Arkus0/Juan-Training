import 'package:flutter/foundation.dart';
import 'input_hypothesis.dart';
import 'library_exercise.dart';
import 'raw_input_capture.dart';

/// Estado de revisión para UX defensiva
///
/// ## UX DEFENSIVA: OCR/Voz SIEMPRE pasan por pantalla de revisión
///
/// La pantalla muestra:
/// - Ejercicio detectado (editable)
/// - Series detectadas (editable)
/// - Confianza visible
/// - Acciones claras: Aceptar / Corregir / Eliminar
///
/// ## REGLA FUNDAMENTAL
/// > Si el sistema duda, el usuario manda.
///
/// Este modelo encapsula todo lo necesario para la pantalla de revisión,
/// facilitando una UX que no frustra pero tampoco se equivoca.
@immutable
class ReviewableHypothesis {
  /// ID único para tracking
  final String id;

  /// Hipótesis original del sistema
  final InputHypothesis hypothesis;

  /// Estado de revisión actual
  final ReviewState state;

  /// Ejercicio actualmente seleccionado (puede diferir del original)
  final ExerciseSelection? currentSelection;

  /// Series actualmente configuradas
  final int? currentSeries;

  /// Reps actualmente configuradas
  final String? currentRepsRange;

  /// Peso actualmente configurado
  final double? currentWeight;

  /// Si el usuario modificó algo
  final bool wasModified;

  /// Tiempo que el usuario ha pasado en revisión
  final Duration timeInReview;

  /// Timestamp de inicio de revisión
  final DateTime reviewStartedAt;

  /// Índice en la lista (para ordenamiento)
  final int orderIndex;

  const ReviewableHypothesis({
    required this.id,
    required this.hypothesis,
    required this.state,
    this.currentSelection,
    this.currentSeries,
    this.currentRepsRange,
    this.currentWeight,
    this.wasModified = false,
    this.timeInReview = Duration.zero,
    required this.reviewStartedAt,
    this.orderIndex = 0,
  });

  /// Factory desde hipótesis
  factory ReviewableHypothesis.fromHypothesis(
    InputHypothesis hypothesis, {
    int orderIndex = 0,
  }) {
    final topCandidate = hypothesis.topExerciseCandidate;
    final seriesReps = hypothesis.seriesRepsHypothesis;

    return ReviewableHypothesis(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      hypothesis: hypothesis,
      state: _calculateInitialState(hypothesis),
      currentSelection: topCandidate != null
          ? ExerciseSelection(
              exercise: topCandidate.exercise,
              confidence: topCandidate.confidence,
              source: SelectionSource.systemProposal,
            )
          : null,
      currentSeries: seriesReps.series?.value,
      currentRepsRange: seriesReps.repsRangeString,
      currentWeight: seriesReps.weight?.value,
      reviewStartedAt: DateTime.now(),
      orderIndex: orderIndex,
    );
  }

  static ReviewState _calculateInitialState(InputHypothesis hypothesis) {
    if (hypothesis.status == HypothesisStatus.failed) {
      return ReviewState.needsManualEntry;
    }
    if (hypothesis.status == HypothesisStatus.incomplete) {
      return ReviewState.incomplete;
    }
    if (hypothesis.status == HypothesisStatus.ambiguous) {
      return ReviewState.needsSelection;
    }
    if (hypothesis.exerciseHypothesis.hasHighConfidenceCandidate &&
        hypothesis.seriesRepsHypothesis.isComplete) {
      return ReviewState.readyToAccept;
    }
    return ReviewState.needsReview;
  }

  // =========================================
  // PROPIEDADES CALCULADAS
  // =========================================

  /// Candidatos de ejercicio disponibles
  List<ExerciseCandidate> get availableCandidates =>
      hypothesis.exerciseHypothesis.candidates;

  /// Si tiene un ejercicio válido seleccionado
  bool get hasValidSelection => currentSelection != null;

  /// Si está completo (ejercicio + series + reps)
  bool get isComplete =>
      hasValidSelection && currentSeries != null && currentRepsRange != null;

  /// Si está listo para aceptar
  bool get canAccept => isComplete && state != ReviewState.deleted;

  /// Confianza actual (del ejercicio seleccionado o 0)
  double get currentConfidence => currentSelection?.confidence ?? 0;

  /// Si la confianza es alta
  bool get isHighConfidence => currentConfidence >= 0.8;

  /// Texto original capturado
  String get originalText => hypothesis.rawCapture.rawText;

  /// Fuente de la captura
  CaptureSource get captureSource => hypothesis.rawCapture.source;

  /// Tiempo actual en revisión
  Duration get currentTimeInReview {
    if (state == ReviewState.accepted || state == ReviewState.deleted) {
      return timeInReview;
    }
    return DateTime.now().difference(reviewStartedAt);
  }

  /// Mensaje de guía para el usuario según el estado
  String get guidanceMessage {
    switch (state) {
      case ReviewState.needsManualEntry:
        return 'No se pudo identificar el ejercicio. Por favor, búscalo manualmente.';
      case ReviewState.needsSelection:
        return 'Se encontraron varios ejercicios posibles. Elige el correcto.';
      case ReviewState.incomplete:
        return 'Faltan datos. Por favor, completa series y repeticiones.';
      case ReviewState.needsReview:
        return 'Verifica que los datos sean correctos antes de aceptar.';
      case ReviewState.readyToAccept:
        return 'Todo parece correcto. Puedes aceptar o hacer cambios.';
      case ReviewState.accepted:
        return 'Ejercicio aceptado.';
      case ReviewState.deleted:
        return 'Ejercicio eliminado.';
    }
  }

  /// Color sugerido para el estado (hint para UI)
  String get stateColorHint {
    switch (state) {
      case ReviewState.needsManualEntry:
        return 'error';
      case ReviewState.needsSelection:
      case ReviewState.incomplete:
        return 'warning';
      case ReviewState.needsReview:
        return 'info';
      case ReviewState.readyToAccept:
        return 'success';
      case ReviewState.accepted:
        return 'success';
      case ReviewState.deleted:
        return 'neutral';
    }
  }

  // =========================================
  // MÉTODOS DE MODIFICACIÓN (INMUTABLE)
  // =========================================

  /// Selecciona un ejercicio de los candidatos
  ReviewableHypothesis selectExercise(
      LibraryExercise exercise, double confidence,) {
    return copyWith(
      currentSelection: ExerciseSelection(
        exercise: exercise,
        confidence: 1.0, // Usuario eligió = confianza máxima
        source: SelectionSource.userSelection,
      ),
      wasModified: true,
      state: _recalculateState(
        hasSelection: true,
        series: currentSeries,
        reps: currentRepsRange,
      ),
    );
  }

  /// Actualiza las series
  ReviewableHypothesis updateSeries(int series) {
    return copyWith(
      currentSeries: series,
      wasModified: true,
      state: _recalculateState(
        hasSelection: hasValidSelection,
        series: series,
        reps: currentRepsRange,
      ),
    );
  }

  /// Actualiza las reps
  ReviewableHypothesis updateRepsRange(String repsRange) {
    return copyWith(
      currentRepsRange: repsRange,
      wasModified: true,
      state: _recalculateState(
        hasSelection: hasValidSelection,
        series: currentSeries,
        reps: repsRange,
      ),
    );
  }

  /// Actualiza el peso
  ReviewableHypothesis updateWeight(double? weight) {
    return copyWith(
      currentWeight: weight,
      wasModified: true,
    );
  }

  /// Marca como aceptado
  ReviewableHypothesis accept() {
    if (!canAccept) return this;
    return copyWith(
      state: ReviewState.accepted,
      timeInReview: currentTimeInReview,
    );
  }

  /// Marca como eliminado
  ReviewableHypothesis delete() {
    return copyWith(
      state: ReviewState.deleted,
      timeInReview: currentTimeInReview,
    );
  }

  /// Recalcula el estado basado en los datos actuales
  ReviewState _recalculateState({
    required bool hasSelection,
    int? series,
    String? reps,
  }) {
    if (state == ReviewState.accepted || state == ReviewState.deleted) {
      return state; // No cambiar estados finales
    }

    if (!hasSelection) {
      return ReviewState.needsManualEntry;
    }

    if (series == null || reps == null || reps.isEmpty) {
      return ReviewState.incomplete;
    }

    return ReviewState.readyToAccept;
  }

  // =========================================
  // COPY WITH
  // =========================================

  ReviewableHypothesis copyWith({
    String? id,
    InputHypothesis? hypothesis,
    ReviewState? state,
    ExerciseSelection? currentSelection,
    int? currentSeries,
    String? currentRepsRange,
    double? currentWeight,
    bool? wasModified,
    Duration? timeInReview,
    DateTime? reviewStartedAt,
    int? orderIndex,
  }) {
    return ReviewableHypothesis(
      id: id ?? this.id,
      hypothesis: hypothesis ?? this.hypothesis,
      state: state ?? this.state,
      currentSelection: currentSelection ?? this.currentSelection,
      currentSeries: currentSeries ?? this.currentSeries,
      currentRepsRange: currentRepsRange ?? this.currentRepsRange,
      currentWeight: currentWeight ?? this.currentWeight,
      wasModified: wasModified ?? this.wasModified,
      timeInReview: timeInReview ?? this.timeInReview,
      reviewStartedAt: reviewStartedAt ?? this.reviewStartedAt,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  String toString() =>
      'ReviewableHypothesis(state: $state, exercise: ${currentSelection?.exercise.name}, '
      'series: $currentSeries, reps: $currentRepsRange)';
}

/// Estado de revisión
enum ReviewState {
  /// Necesita entrada manual (no se identificó nada)
  needsManualEntry,

  /// Necesita selección entre candidatos ambiguos
  needsSelection,

  /// Datos incompletos (falta series o reps)
  incomplete,

  /// Necesita revisión general
  needsReview,

  /// Listo para aceptar (todo parece correcto)
  readyToAccept,

  /// Aceptado por el usuario
  accepted,

  /// Eliminado por el usuario
  deleted,
}

/// Selección de ejercicio actual
@immutable
class ExerciseSelection {
  /// Ejercicio seleccionado
  final LibraryExercise exercise;

  /// Confianza de la selección
  final double confidence;

  /// Cómo se llegó a esta selección
  final SelectionSource source;

  const ExerciseSelection({
    required this.exercise,
    required this.confidence,
    required this.source,
  });

  /// Si la selección fue hecha por el usuario
  bool get wasUserSelected => source == SelectionSource.userSelection;
}

/// Fuente de la selección
enum SelectionSource {
  /// Propuesta inicial del sistema
  systemProposal,

  /// Usuario seleccionó de candidatos
  userSelection,

  /// Usuario buscó manualmente
  userSearch,
}

/// Lista de hipótesis revisables con estado agregado
@immutable
class ReviewSession {
  /// Lista de hipótesis a revisar
  final List<ReviewableHypothesis> hypotheses;

  /// Índice actual (para navegación)
  final int currentIndex;

  /// Timestamp de inicio de sesión
  final DateTime startedAt;

  /// Si la sesión está completa
  final bool isComplete;

  const ReviewSession({
    required this.hypotheses,
    this.currentIndex = 0,
    required this.startedAt,
    this.isComplete = false,
  });

  /// Factory vacía
  factory ReviewSession.empty() {
    return ReviewSession(
      hypotheses: const [],
      startedAt: DateTime.now(),
      isComplete: true,
    );
  }

  /// Factory desde lista de hipótesis
  factory ReviewSession.fromHypotheses(List<InputHypothesis> hypotheses) {
    return ReviewSession(
      hypotheses: hypotheses
          .asMap()
          .entries
          .map(
            (e) => ReviewableHypothesis.fromHypothesis(
              e.value,
              orderIndex: e.key,
            ),
          )
          .toList(),
      startedAt: DateTime.now(),
    );
  }

  /// Hipótesis actual
  ReviewableHypothesis? get current =>
      currentIndex < hypotheses.length ? hypotheses[currentIndex] : null;

  /// Total de hipótesis
  int get total => hypotheses.length;

  /// Hipótesis pendientes de revisión
  int get pendingCount => hypotheses
      .where((h) =>
          h.state != ReviewState.accepted && h.state != ReviewState.deleted,)
      .length;

  /// Hipótesis aceptadas
  int get acceptedCount =>
      hypotheses.where((h) => h.state == ReviewState.accepted).length;

  /// Hipótesis eliminadas
  int get deletedCount =>
      hypotheses.where((h) => h.state == ReviewState.deleted).length;

  /// Progreso (0.0 - 1.0)
  double get progress {
    if (total == 0) return 1.0;
    return (acceptedCount + deletedCount) / total;
  }

  /// Si todas las hipótesis fueron procesadas
  bool get allProcessed => pendingCount == 0;

  /// Actualiza una hipótesis específica
  ReviewSession updateHypothesis(int index, ReviewableHypothesis updated) {
    if (index < 0 || index >= hypotheses.length) return this;

    final newList = List<ReviewableHypothesis>.from(hypotheses);
    newList[index] = updated;

    return ReviewSession(
      hypotheses: newList,
      currentIndex: currentIndex,
      startedAt: startedAt,
      isComplete: newList.every(
        (h) =>
            h.state == ReviewState.accepted || h.state == ReviewState.deleted,
      ),
    );
  }

  /// Navega al siguiente
  ReviewSession next() {
    if (currentIndex >= hypotheses.length - 1) return this;
    return ReviewSession(
      hypotheses: hypotheses,
      currentIndex: currentIndex + 1,
      startedAt: startedAt,
      isComplete: isComplete,
    );
  }

  /// Navega al anterior
  ReviewSession previous() {
    if (currentIndex <= 0) return this;
    return ReviewSession(
      hypotheses: hypotheses,
      currentIndex: currentIndex - 1,
      startedAt: startedAt,
      isComplete: isComplete,
    );
  }

  /// Obtiene las hipótesis aceptadas listas para usar
  List<ReviewableHypothesis> get acceptedHypotheses =>
      hypotheses.where((h) => h.state == ReviewState.accepted).toList();
}
