/// Motor de progresión determinista v2
///
/// Principios:
/// 1. Decisiones basadas en sesión completa, no serie individual
/// 2. Confirmación de 2 sesiones antes de subir peso
/// 3. Degradación elegante (días malos no castigan)
/// 4. Usuario puede predecir la siguiente sesión
library;

/// Estado actual del ciclo de progresión de un ejercicio
enum ProgressionState {
  /// Fase inicial: Recopilando datos (primeras 2 sesiones)
  calibrating('calibrating', 'Calibrando'),

  /// Progresión normal: Siguiendo el modelo
  progressing('progressing', 'Progresando'),

  /// Confirmación: Esperando 2da sesión exitosa
  confirming('confirming', 'Confirmando'),

  /// Estancamiento: 3+ semanas sin progreso
  plateau('plateau', 'Estancado'),

  /// Deload planificado
  deloading('deloading', 'Deload');

  final String value;
  final String label;

  const ProgressionState(this.value, this.label);

  static ProgressionState fromString(String? value) {
    if (value == null) return ProgressionState.calibrating;
    for (final state in ProgressionState.values) {
      if (state.value == value) return state;
    }
    return ProgressionState.calibrating;
  }
}

/// Categoría del ejercicio (afecta incrementos y expectativas)
enum ExerciseCategory {
  /// Compuestos pesados: Sentadilla, Peso Muerto, Press Banca
  /// Incremento: 2.5kg (>60kg) o 1.25kg (<60kg)
  heavyCompound('heavy_compound', 'Compuesto Pesado'),

  /// Compuestos ligeros: Remo, Press Militar, Dominadas
  /// Incremento: 2.5kg (>40kg) o 1.25kg (<40kg)
  lightCompound('light_compound', 'Compuesto Ligero'),

  /// Aislamiento: Curls, Extensiones, Laterales
  /// Incremento: 1.25kg o +1 rep preferido
  isolation('isolation', 'Aislamiento'),

  /// Máquinas: Incrementos fijos de la máquina
  machine('machine', 'Máquina');

  final String value;
  final String label;

  const ExerciseCategory(this.value, this.label);

  static ExerciseCategory fromString(String? value) {
    if (value == null) return ExerciseCategory.isolation;
    for (final cat in ExerciseCategory.values) {
      if (cat.value == value) return cat;
    }
    return ExerciseCategory.isolation;
  }

  /// Auto-detecta la categoría basándose en el nombre del ejercicio
  static ExerciseCategory inferFromName(String exerciseName) {
    final name = exerciseName.toLowerCase();

    // Compuestos pesados
    const heavyKeywords = [
      'sentadilla',
      'squat',
      'peso muerto',
      'deadlift',
      'press banca',
      'bench press',
      'press de banca',
      'hip thrust',
    ];
    for (final kw in heavyKeywords) {
      if (name.contains(kw)) return ExerciseCategory.heavyCompound;
    }

    // Compuestos ligeros
    const lightKeywords = [
      'remo',
      'row',
      'press militar',
      'overhead press',
      'press hombro',
      'dominada',
      'pull up',
      'chin up',
      'fondos',
      'dips',
      'peso muerto rumano',
      'romanian',
      'zancada',
      'lunge',
    ];
    for (final kw in lightKeywords) {
      if (name.contains(kw)) return ExerciseCategory.lightCompound;
    }

    // Máquinas
    const machineKeywords = [
      'máquina',
      'machine',
      'polea',
      'cable',
      'smith',
      'prensa',
      'leg press',
      'hack',
    ];
    for (final kw in machineKeywords) {
      if (name.contains(kw)) return ExerciseCategory.machine;
    }

    // Default: aislamiento
    return ExerciseCategory.isolation;
  }

  /// Obtiene el incremento de peso apropiado para esta categoría
  double getIncrement(double currentWeight) {
    switch (this) {
      case ExerciseCategory.heavyCompound:
        return currentWeight >= 60 ? 2.5 : 1.25;
      case ExerciseCategory.lightCompound:
        return currentWeight >= 40 ? 2.5 : 1.25;
      case ExerciseCategory.isolation:
        return 1.25; // Siempre pequeño
      case ExerciseCategory.machine:
        return 2.5; // Las máquinas suelen tener incrementos fijos
    }
  }
}

/// Resultado de evaluación de una sesión completa
enum SessionResult {
  /// 100% de sets completaron objetivo
  complete,

  /// ≥80% de sets completaron objetivo
  acceptable,

  /// 50-79% de sets completaron objetivo
  partial,

  /// <50% de sets completaron objetivo
  failed,
}

/// Acción recomendada por el motor de progresión
enum ProgressionAction {
  /// Subir peso
  increaseWeight,

  /// Subir reps (mismo peso)
  increaseReps,

  /// Mantener peso y reps
  maintain,

  /// Bajar peso (deload o regresión)
  decreaseWeight,

  /// Bajar reps (consolidar)
  decreaseReps,
}

/// Nivel de confianza en la decisión
enum ProgressionConfidence {
  /// Alta: Patrón claro, decisión segura
  high,

  /// Media: Datos suficientes pero no concluyentes
  medium,

  /// Baja: Pocos datos o patrón ambiguo
  low,
}

/// Decisión de progresión con contexto completo
class ProgressionDecision {
  /// Acción recomendada
  final ProgressionAction action;

  /// Peso sugerido
  final double suggestedWeight;

  /// Reps sugeridas
  final int suggestedReps;

  /// Razón técnica (para logs/debug)
  final String reason;

  /// Mensaje amigable para el usuario
  final String userMessage;

  /// Nivel de confianza
  final ProgressionConfidence confidence;

  /// Si representa una mejora respecto al estado actual
  final bool isImprovement;

  /// Qué pasará después si el usuario tiene éxito
  final String? nextStepPreview;

  const ProgressionDecision({
    required this.action,
    required this.suggestedWeight,
    required this.suggestedReps,
    required this.reason,
    required this.userMessage,
    this.confidence = ProgressionConfidence.medium,
    this.isImprovement = false,
    this.nextStepPreview,
  });

  /// Decisión de mantener (convenience constructor)
  factory ProgressionDecision.maintain({
    required double weight,
    required int reps,
    String? reason,
    String? userMessage,
  }) {
    return ProgressionDecision(
      action: ProgressionAction.maintain,
      suggestedWeight: weight,
      suggestedReps: reps,
      reason: reason ?? 'Mantener actual',
      userMessage: userMessage ?? 'Repite el mismo objetivo',
    );
  }

  /// Decisión de calibración (primeras sesiones)
  factory ProgressionDecision.calibrating({
    required double weight,
    required int reps,
    required int sessionNumber,
  }) {
    return ProgressionDecision(
      action: ProgressionAction.maintain,
      suggestedWeight: weight,
      suggestedReps: reps,
      reason: 'Calibración $sessionNumber/2',
      userMessage:
          'Sesión $sessionNumber de calibración. Establece tu baseline.',
      confidence: ProgressionConfidence.low,
    );
  }

  @override
  String toString() =>
      'ProgressionDecision($action: ${suggestedWeight}kg x $suggestedReps - $reason)';
}

/// Resumen de una serie para análisis
class SetSummary {
  final double weight;
  final int reps;
  final int targetReps;
  final bool completed;
  final int? rpe;

  const SetSummary({
    required this.weight,
    required this.reps,
    required this.targetReps,
    required this.completed,
    this.rpe,
  });

  /// Si esta serie alcanzó el objetivo de reps
  bool get hitTarget => reps >= targetReps;

  /// Si esta serie superó el objetivo
  bool get exceededTarget => reps > targetReps;
}

/// Resumen de una sesión para análisis de progresión
class SessionSummary {
  final DateTime date;
  final List<SetSummary> sets;
  final int targetReps;
  final double weight;

  const SessionSummary({
    required this.date,
    required this.sets,
    required this.targetReps,
    required this.weight,
  });

  /// Promedio de reps en la sesión
  double get averageReps {
    if (sets.isEmpty) return 0;
    return sets.map((s) => s.reps).reduce((a, b) => a + b) / sets.length;
  }

  /// Número de sets que alcanzaron el objetivo
  int get setsHitTarget => sets.where((s) => s.hitTarget).length;

  /// Porcentaje de éxito (0.0 - 1.0)
  double get successRate {
    if (sets.isEmpty) return 0;
    return setsHitTarget / sets.length;
  }

  /// Evalúa el resultado de la sesión
  SessionResult evaluate() {
    final rate = successRate;
    if (rate >= 1.0) return SessionResult.complete;
    if (rate >= 0.8) return SessionResult.acceptable;
    if (rate >= 0.5) return SessionResult.partial;
    return SessionResult.failed;
  }

  /// RPE promedio (si hay datos)
  double? get averageRpe {
    final rpes = sets.map((s) => s.rpe).whereType<int>().toList();
    if (rpes.isEmpty) return null;
    return rpes.reduce((a, b) => a + b) / rpes.length;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // MÉTODOS ADICIONALES PARA CIENCIA CLÁSICA
  // ════════════════════════════════════════════════════════════════════════════

  /// LYLE McDONALD: ¿TODAS las series alcanzaron las reps máximas?
  ///
  /// Criterio estricto de doble progresión:
  /// "Once you can complete ALL sets at the top of the rep range, add weight."
  ///
  /// El promedio NO es suficiente - todas deben estar en max.
  bool allSetsHitMaxReps(int maxReps) {
    if (sets.isEmpty) return false;
    return sets.every((s) => s.reps >= maxReps);
  }

  /// ¿TODAS las series completaron el objetivo mínimo?
  ///
  /// Para lineal: Si todas las series alcanzan target, sesión exitosa.
  bool get allSetsHitTarget {
    if (sets.isEmpty) return false;
    return sets.every((s) => s.hitTarget);
  }

  /// Mínimo de reps en la sesión (para detectar fatiga)
  int get minReps {
    if (sets.isEmpty) return 0;
    return sets.map((s) => s.reps).reduce((a, b) => a < b ? a : b);
  }

  /// Máximo de reps en la sesión
  int get maxReps {
    if (sets.isEmpty) return 0;
    return sets.map((s) => s.reps).reduce((a, b) => a > b ? a : b);
  }

  /// Volumen total de la sesión (peso × reps × series)
  ///
  /// Métrica importante para hipertrofia según Lyle McDonald.
  double get totalVolume {
    return sets.fold(0.0, (sum, s) => sum + (s.weight * s.reps));
  }
}

/// Contexto completo de progresión para un ejercicio
class ExerciseProgressionContext {
  final String exerciseId;
  final String exerciseName;
  final ProgressionState state;

  /// Últimas sesiones (máximo 4, ordenadas de más reciente a más antiguo)
  final List<SessionSummary> recentSessions;

  /// Sesiones exitosas consecutivas (para confirmación)
  final int consecutiveSuccesses;

  /// Sesiones fallidas consecutivas
  final int consecutiveFailures;

  /// Semanas en el mismo peso (para detectar plateau)
  final int weeksAtCurrentWeight;

  /// Tipo de ejercicio
  final ExerciseCategory category;

  /// Peso "confirmado" (baseline validado, no último intento)
  final double confirmedWeight;

  /// Rango de reps (min, max)
  final (int, int) repsRange;

  const ExerciseProgressionContext({
    required this.exerciseId,
    required this.exerciseName,
    required this.state,
    required this.recentSessions,
    required this.consecutiveSuccesses,
    required this.consecutiveFailures,
    required this.weeksAtCurrentWeight,
    required this.category,
    required this.confirmedWeight,
    required this.repsRange,
  });

  /// Target de reps actual (mínimo del rango)
  int get targetReps => repsRange.$1;

  /// Máximo de reps del rango
  int get maxReps => repsRange.$2;

  /// Si hay suficientes datos para tomar decisiones confiables
  bool get hasEnoughData => recentSessions.length >= 2;

  /// Última sesión (si existe)
  SessionSummary? get lastSession =>
      recentSessions.isNotEmpty ? recentSessions.first : null;

  // ════════════════════════════════════════════════════════════════════════════
  // MÉTODOS PARA STALL DETECTION (Rippetoe/StrongLifts)
  // ════════════════════════════════════════════════════════════════════════════

  /// RIPPETOE: Cuenta fallos consecutivos AL MISMO PESO
  ///
  /// Un "stall" es fallar 3 veces al MISMO peso, no cualquier fallo.
  /// Esto es crítico: si subes peso y fallas, eso no es stall del peso anterior.
  ///
  /// "A stall is defined as failing to complete the work sets for three
  /// consecutive workouts at the same weight."
  /// — Starting Strength, 3rd Edition, p.303
  int get failuresAtCurrentWeight {
    var count = 0;
    for (final session in recentSessions) {
      // Solo contar si el peso es el mismo que el confirmado
      if ((session.weight - confirmedWeight).abs() > 0.1) break;

      final result = session.evaluate();
      if (result == SessionResult.partial || result == SessionResult.failed) {
        count++;
      } else {
        break; // Un éxito rompe la racha de fallos
      }
    }
    return count;
  }

  /// ¿Es un stall según Rippetoe? (3 fallos al mismo peso)
  bool get isStall => failuresAtCurrentWeight >= 3;

  /// ¿La última sesión fue exitosa en todas las series?
  ///
  /// Criterio más estricto que SessionResult.complete:
  /// Todas las series deben alcanzar el target, no solo 100% success rate.
  bool get lastSessionAllSetsSuccessful {
    final last = lastSession;
    if (last == null) return false;
    return last.allSetsHitTarget;
  }

  /// ¿La última sesión alcanzó max reps en TODAS las series?
  ///
  /// Criterio de Lyle McDonald para doble progresión.
  bool get lastSessionAllSetsAtMaxReps {
    final last = lastSession;
    if (last == null) return false;
    return last.allSetsHitMaxReps(maxReps);
  }
}
