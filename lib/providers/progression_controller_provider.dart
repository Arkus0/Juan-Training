import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/progression_engine_models.dart';
import '../models/progression_type.dart';
import '../services/progression_controller.dart';

// ════════════════════════════════════════════════════════════════════════════
// PROGRESSION CONTROLLER PROVIDER
// ════════════════════════════════════════════════════════════════════════════

/// Provider familia para controladores por ejercicio
///
/// Cada ejercicio tiene su propio controlador con su propio estado.
/// El modelo y umbrales pueden cambiar sin perder el estado.
final exerciseControllerProvider =
    Provider.family<ProgressionController, String>(
  (ref, exerciseId) {
    return ProgressionController(
      model: const DoubleProgressionModel(),
      thresholds: ProgressionThresholds.defaults,
    );
  },
);

/// Provider para modelo de progresión seleccionado globalmente
final globalProgressionModelProvider =
    NotifierProvider<GlobalProgressionModelNotifier, ProgressionModel>(
  GlobalProgressionModelNotifier.new,
);

class GlobalProgressionModelNotifier extends Notifier<ProgressionModel> {
  @override
  ProgressionModel build() => const DoubleProgressionModel();
}

/// Provider para umbrales globales
final globalThresholdsProvider =
    NotifierProvider<GlobalThresholdsNotifier, ProgressionThresholds>(
  GlobalThresholdsNotifier.new,
);

class GlobalThresholdsNotifier extends Notifier<ProgressionThresholds> {
  @override
  ProgressionThresholds build() => ProgressionThresholds.defaults;
}

/// Crear modelo desde ProgressionType
final progressionModelFromTypeProvider =
    Provider.family<ProgressionModel, ProgressionType>(
  (ref, type) => createProgressionModel(type),
);

// ════════════════════════════════════════════════════════════════════════════
// EXECUTION DATA BUILDER
// ════════════════════════════════════════════════════════════════════════════

/// Construye ExecutionData desde datos del repositorio
class ExecutionDataBuilder {
  /// Convierte historial de series a ExecutionData
  static ExecutionData build({
    required String exerciseName,
    required double currentWeight,
    required int targetReps,
    int maxReps = 12,
    required List<Map<String, dynamic>> rawSessionHistory,
    int weeksAtCurrentWeight = 0,
  }) {
    final category = ExerciseCategory.inferFromName(exerciseName);

    final sessionHistory = rawSessionHistory.map((session) {
      final sets = (session['sets'] as List<dynamic>? ?? []).map((set) {
        return SetExecutionData(
          reps: set['reps'] as int? ?? 0,
          weight: (set['weight'] as num?)?.toDouble() ?? 0.0,
          targetReps: targetReps,
          completed: set['completed'] as bool? ?? true,
          rpe: (set['rpe'] as num?)?.toDouble(),
        );
      }).toList();

      return SessionExecutionData(
        date: DateTime.tryParse(session['date'] as String? ?? '') ??
            DateTime.now(),
        weight: (session['weight'] as num?)?.toDouble() ?? currentWeight,
        sets: sets,
      );
    }).toList();

    return ExecutionData(
      exerciseName: exerciseName,
      category: category,
      confirmedWeight: currentWeight,
      repsRange: (targetReps, maxReps),
      sessionHistory: sessionHistory,
      weeksAtCurrentWeight: weeksAtCurrentWeight,
    );
  }

  /// Construye desde SerieLog list (formato actual de la app)
  static SessionExecutionData buildSessionFromSeries({
    required DateTime date,
    required double weight,
    required List<({int reps, bool completed, double? rpe})> series,
    required int targetReps,
  }) {
    return SessionExecutionData(
      date: date,
      weight: weight,
      sets: series
          .map(
            (s) => SetExecutionData(
              reps: s.reps,
              weight: weight,
              targetReps: targetReps,
              completed: s.completed,
              rpe: s.rpe,
            ),
          )
          .toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// UI HELPER EXTENSIONS
// ════════════════════════════════════════════════════════════════════════════

extension ControllerStateUI on ControllerState {
  /// Color del estado para UI
  String get colorHex => switch (this) {
        ControllerState.calibrating => '#9E9E9E', // Gris
        ControllerState.progressing => '#4CAF50', // Verde
        ControllerState.confirming => '#2196F3', // Azul
        ControllerState.plateau => '#FF9800', // Naranja
        ControllerState.deloading => '#9C27B0', // Morado
        ControllerState.fatigued => '#F44336', // Rojo
        ControllerState.regression => '#795548', // Marrón
      };

  /// Descripción corta para tooltip
  String get tooltip => switch (this) {
        ControllerState.calibrating => 'Recopilando datos iniciales',
        ControllerState.progressing => 'Progresión normal',
        ControllerState.confirming => 'Esperando confirmación',
        ControllerState.plateau => 'Estancamiento detectado',
        ControllerState.deloading => 'Fase de deload',
        ControllerState.fatigued => 'Fatiga acumulada',
        ControllerState.regression => 'Necesita bajar peso',
      };

  /// ¿Debería mostrar alerta al usuario?
  bool get requiresAttention => switch (this) {
        ControllerState.plateau => true,
        ControllerState.fatigued => true,
        ControllerState.regression => true,
        _ => false,
      };
}

extension ProgressionActionUI on ProgressionAction {
  /// Icono del action
  String get icon => switch (this) {
        ProgressionAction.increaseWeight => '⬆️',
        ProgressionAction.increaseReps => '📈',
        ProgressionAction.maintain => '➡️',
        ProgressionAction.decreaseWeight => '⬇️',
        ProgressionAction.decreaseReps => '📉',
      };

  /// Verbo para mensaje
  String get verb => switch (this) {
        ProgressionAction.increaseWeight => 'Sube',
        ProgressionAction.increaseReps => 'Añade',
        ProgressionAction.maintain => 'Mantén',
        ProgressionAction.decreaseWeight => 'Baja',
        ProgressionAction.decreaseReps => 'Reduce',
      };
}

extension ProgressionConfidenceUI on ProgressionConfidence {
  /// Barra de confianza visual
  String get bar => switch (this) {
        ProgressionConfidence.high => '███',
        ProgressionConfidence.medium => '██░',
        ProgressionConfidence.low => '█░░',
      };

  /// Porcentaje aproximado
  int get percentage => switch (this) {
        ProgressionConfidence.high => 90,
        ProgressionConfidence.medium => 70,
        ProgressionConfidence.low => 40,
      };
}
