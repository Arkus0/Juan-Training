import '../models/progression_type.dart';
import '../models/progression_engine_models.dart';
import '../models/serie_log.dart';
import 'progression_engine.dart';

/// Servicio que calcula sugerencias de progresión basadas en el historial.
/// 
/// NOTA: Este servicio ahora es un wrapper de compatibilidad sobre [ProgressionEngine].
/// Para nuevas implementaciones, usar directamente [ProgressionEngine.instance].
/// 
/// El nuevo motor ofrece:
/// - Análisis de sesión completa (no solo serie individual)
/// - Confirmación de 2 sesiones antes de subir peso
/// - Mensajes descriptivos para el usuario
/// - Incrementos inteligentes según tipo de ejercicio
class ProgressionCalculator {
  ProgressionCalculator._internal();
  static final ProgressionCalculator instance = ProgressionCalculator._internal();
  
  /// Referencia al nuevo motor de progresión
  final ProgressionEngine _engine = ProgressionEngine.instance;

  /// Calcula la sugerencia de progresión usando el nuevo motor v2.
  /// 
  /// Este método ofrece:
  /// - Análisis de sesión completa
  /// - Mensajes descriptivos para el usuario
  /// - Incrementos inteligentes según tipo de ejercicio
  /// - Preview del siguiente paso
  ProgressionDecision? calculateSuggestionV2({
    required ProgressionType progressionType,
    required int targetReps,
    required int maxReps,
    required List<SerieLog>? previousLogs,
    String? exerciseName,
  }) {
    return _engine.calculateFromLegacyData(
      progressionType: progressionType,
      weightIncrement: 2.5, // Será recalculado por el motor según categoría
      targetReps: targetReps,
      maxReps: maxReps,
      previousLogs: previousLogs,
      setIndex: 0, // Para decisión de sesión, usamos índice 0
      exerciseName: exerciseName,
    );
  }

  /// Calcula la sugerencia de progresión para un ejercicio dado su historial.
  /// 
  /// DEPRECATED: Usar [calculateSuggestionV2] para acceso al nuevo motor.
  ///
  /// [progressionType]: Tipo de progresión configurado
  /// [weightIncrement]: Incremento de peso para progresión lineal (ej: 2.5kg)
  /// [targetReps]: Reps objetivo (ej: 10, extraído de repsRange)
  /// [maxReps]: Máximo de reps del rango (ej: 12, para doble progresión)
  /// [previousLogs]: Logs de la última sesión para este ejercicio
  /// [setIndex]: Índice de la serie actual (0-based)
  ProgressionSuggestion? calculateSuggestion({
    required ProgressionType progressionType,
    required double weightIncrement,
    required int targetReps,
    required int maxReps,
    required List<SerieLog>? previousLogs,
    required int setIndex,
    int? targetRpe,
  }) {
    if (progressionType == ProgressionType.none) return null;
    if (previousLogs == null || previousLogs.isEmpty) return null;

    // Obtener el log de la serie correspondiente de la sesión anterior
    final SerieLog? prevLog = setIndex < previousLogs.length ? previousLogs[setIndex] : null;
    if (prevLog == null) return null;

    switch (progressionType) {
      case ProgressionType.lineal:
        return _calculateLineal(prevLog, weightIncrement, targetReps);

      case ProgressionType.dobleRepsFirst:
        return _calculateDoble(prevLog, weightIncrement, targetReps, maxReps);

      case ProgressionType.rpe:
        return _calculateRpeBased(prevLog, targetRpe ?? 8);

      case ProgressionType.none:
        return null;
    }
  }

  /// Progresión lineal: Si se completaron las reps objetivo, subir peso.
  ProgressionSuggestion _calculateLineal(
    SerieLog prevLog,
    double increment,
    int targetReps,
  ) {
    final prevCompleted = prevLog.completed;
    final prevReps = prevLog.reps;
    final prevWeight = prevLog.peso;

    // Si completó las reps objetivo o más, sugerir subir peso
    if (prevCompleted && prevReps >= targetReps) {
      return ProgressionSuggestion(
        suggestedWeight: prevWeight + increment,
        suggestedReps: targetReps,
        isImprovement: true,
        message: '+${increment}kg 💪',
      );
    }

    // Si no completó, mantener peso y reps
    return ProgressionSuggestion(
      suggestedWeight: prevWeight,
      suggestedReps: targetReps,
      isImprovement: false,
      message: 'Mantener',
    );
  }

  /// Doble progresión: Primero subir reps hasta max, luego subir peso y bajar reps.
  ProgressionSuggestion _calculateDoble(
    SerieLog prevLog,
    double increment,
    int minReps,
    int maxReps,
  ) {
    final prevCompleted = prevLog.completed;
    final prevReps = prevLog.reps;
    final prevWeight = prevLog.peso;

    if (!prevCompleted) {
      // No completó, mantener todo
      return ProgressionSuggestion(
        suggestedWeight: prevWeight,
        suggestedReps: prevReps > 0 ? prevReps : minReps,
        isImprovement: false,
        message: 'Mantener',
      );
    }

    // Si alcanzó el máximo de reps, subir peso y volver al mínimo
    if (prevReps >= maxReps) {
      return ProgressionSuggestion(
        suggestedWeight: prevWeight + increment,
        suggestedReps: minReps,
        isImprovement: true,
        message: '+${increment}kg, $minReps reps 🔥',
      );
    }

    // Si no alcanzó el máximo, sugerir +1 rep
    return ProgressionSuggestion(
      suggestedWeight: prevWeight,
      suggestedReps: prevReps + 1,
      isImprovement: true,
      message: '+1 rep',
    );
  }

  /// Progresión basada en RPE: Si el RPE fue menor al objetivo, subir peso.
  ProgressionSuggestion _calculateRpeBased(
    SerieLog prevLog,
    int targetRpe,
  ) {
    final prevRpe = prevLog.rpe;
    final prevWeight = prevLog.peso;
    final prevReps = prevLog.reps;

    if (prevRpe == null) {
      // Sin RPE registrado, mantener
      return ProgressionSuggestion(
        suggestedWeight: prevWeight,
        suggestedReps: prevReps,
        isImprovement: false,
        message: 'Registra RPE para sugerencias',
      );
    }

    // RPE menor al objetivo = muy fácil, subir peso
    if (prevRpe < targetRpe - 1) {
      return ProgressionSuggestion(
        suggestedWeight: prevWeight + 2.5,
        suggestedReps: prevReps,
        isImprovement: true,
        message: 'RPE bajo, +2.5kg',
      );
    }

    // RPE mayor al objetivo = muy difícil, bajar peso
    if (prevRpe > targetRpe + 1) {
      return ProgressionSuggestion(
        suggestedWeight: (prevWeight - 2.5).clamp(0, double.infinity),
        suggestedReps: prevReps,
        isImprovement: false,
        message: 'RPE alto, -2.5kg',
      );
    }

    // RPE en rango objetivo, mantener
    return ProgressionSuggestion(
      suggestedWeight: prevWeight,
      suggestedReps: prevReps,
      isImprovement: false,
      message: 'RPE $prevRpe OK',
    );
  }

  /// Parsea un repsRange (ej: "8-12") y devuelve (min, max).
  (int, int) parseRepsRange(String repsRange) {
    final parts = repsRange.split('-');
    if (parts.length == 2) {
      final min = int.tryParse(parts[0].trim()) ?? 8;
      final max = int.tryParse(parts[1].trim()) ?? 12;
      return (min, max);
    }
    // Reps fijas (ej: "10")
    final fixed = int.tryParse(repsRange.trim()) ?? 10;
    return (fixed, fixed);
  }

  /// Calcula el volumen total (peso x reps x series) de una lista de logs.
  double calculateVolume(List<SerieLog> logs) {
    return logs.fold(0.0, (sum, log) {
      if (log.completed) {
        return sum + (log.peso * log.reps);
      }
      return sum;
    });
  }

  /// Calcula el peso máximo de una lista de logs.
  double calculateMaxWeight(List<SerieLog> logs) {
    if (logs.isEmpty) return 0.0;
    return logs
        .where((l) => l.completed)
        .fold(0.0, (max, log) => log.peso > max ? log.peso : max);
  }

  /// Estima 1RM usando fórmula de Epley.
  double estimate1RM(double weight, int reps) {
    if (reps <= 0 || weight <= 0) return 0.0;
    if (reps == 1) return weight;
    return weight * (1 + reps / 30);
  }
}
