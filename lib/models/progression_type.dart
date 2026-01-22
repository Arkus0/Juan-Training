/// Tipos de progresión soportados para ejercicios en rutina.
enum ProgressionType {
  /// Sin progresión automática
  none('none', 'Ninguna'),

  /// Progresión lineal: incrementar peso fijo cada sesión exitosa
  lineal('lineal', 'Lineal'),

  /// Doble progresión: primero subir reps hasta max, luego subir peso y bajar reps
  dobleRepsFirst('double', 'Doble Progresión'),

  /// Progresión basada en RPE objetivo
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
