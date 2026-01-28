/// Tipos de progresión soportados para ejercicios en rutina.
///
/// Basados en clásicos del entrenamiento de fuerza:
/// - Starting Strength (Rippetoe): Lineal agresiva para novatos
/// - StrongLifts 5x5 (Mehdi): Lineal con deload estructurado
/// - Lyle McDonald: Doble progresión para hipertrofia
enum ProgressionType {
  /// Sin progresión automática
  none('none', 'Ninguna'),

  /// Progresión lineal NOVICE (Rippetoe/StrongLifts):
  /// - Sube peso CADA sesión exitosa (sin confirmación)
  /// - +2.5kg upper body, +2.5-5kg lower body
  /// - Stall = 3 fallos al MISMO peso → deload 10%
  /// - Ideal para: Novatos (<1 año entrenando)
  lineal('lineal', 'Lineal'),

  /// Doble progresión (Lyle McDonald):
  /// - Rango de reps (ej: 8-12)
  /// - Sube reps hasta que TODAS las series alcanzan max
  /// - Luego sube peso y vuelve a min reps
  /// - Sin confirmación de 2 sesiones para subir reps
  /// - Confirmación de 1 sesión para subir peso
  /// - Ideal para: Intermedios, hipertrofia
  dobleRepsFirst('double', 'Doble Progresión'),

  /// Progresión basada en RPE (autoregulación):
  /// - Ajusta según esfuerzo percibido (1-10)
  /// - RPE 8 = 2 reps en reserva (RIR)
  /// - Requiere calibración inicial
  /// - Ideal para: Avanzados, periodización
  rpe('rpe', 'Basada en RPE');

  final String value;
  final String label;

  const ProgressionType(this.value, this.label);

  static ProgressionType fromString(String? value) {
    if (value == null) return ProgressionType.none;
    for (final type in ProgressionType.values) {
      if (type.value == value) return type;
    }
    return ProgressionType.none;
  }

  /// Descripción científica del tipo de progresión
  String get scientificDescription => switch (this) {
        ProgressionType.none =>
          'Progresión manual. El usuario decide cuándo subir peso.',
        ProgressionType.lineal =>
          'Basada en Starting Strength/StrongLifts 5x5. '
              'Sube peso cada sesión exitosa. '
              'Tras 3 fallos al mismo peso: deload 10%.',
        ProgressionType.dobleRepsFirst => 'Basada en Lyle McDonald. '
            'Primero sube reps hasta el máximo del rango en todas las series, '
            'luego sube peso y reinicia reps.',
        ProgressionType.rpe => 'Autoregulación por esfuerzo percibido. '
            'RPE 8 = 2 repeticiones en reserva. '
            'Ajusta peso según fatiga real.',
      };
}

/// Datos de sugerencia de progresión para una serie.
class ProgressionSuggestion {
  /// Peso sugerido para la próxima serie
  final double suggestedWeight;

  /// Reps sugeridas para la próxima serie
  final int suggestedReps;

  /// Si hay mejora respecto a la última sesión
  final bool isImprovement;

  /// Mensaje descriptivo para el usuario
  final String? message;

  const ProgressionSuggestion({
    required this.suggestedWeight,
    required this.suggestedReps,
    this.isImprovement = false,
    this.message,
  });

  @override
  String toString() => 'Sugerencia: ${suggestedWeight}kg x $suggestedReps';
}

/// Datos históricos para calcular progresión.
class ExerciseProgressionData {
  /// Nombre del ejercicio
  final String exerciseName;

  /// Historial de sesiones (peso, reps) - ordenado de más reciente a más antiguo
  final List<SetHistoryEntry> history;

  /// Tipo de progresión configurado
  final ProgressionType progressionType;

  const ExerciseProgressionData({
    required this.exerciseName,
    required this.history,
    required this.progressionType,
  });
}

/// Entrada de historial para una serie.
class SetHistoryEntry {
  final DateTime date;
  final double weight;
  final int reps;
  final int? rpe;
  final bool completed;

  const SetHistoryEntry({
    required this.date,
    required this.weight,
    required this.reps,
    this.rpe,
    this.completed = true,
  });
}
