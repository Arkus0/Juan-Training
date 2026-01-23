import '../models/progression_type.dart';
import '../models/progression_engine_models.dart';

// ════════════════════════════════════════════════════════════════════════════
// PROGRESSION CONTROLLER v3
// ════════════════════════════════════════════════════════════════════════════
// 
// Arquitectura de 3 capas:
// 
// ┌─────────────────────────────────────────────────────────────────────────┐
// │                        PROGRESSION CONTROLLER                           │
// │                     (Orquestador / Máquina de Estados)                  │
// ├─────────────────────────────────────────────────────────────────────────┤
// │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐      │
// │  │  EXECUTION DATA  │  │ PROGRESSION MODEL│  │    DECISION      │      │
// │  │  (Datos Crudos)  │  │  (Estrategia)    │  │   (Resultado)    │      │
// │  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤      │
// │  │ - SessionHistory │  │ - Linear         │  │ - Action         │      │
// │  │ - CurrentWeight  │  │ - Double         │  │ - NewWeight      │      │
// │  │ - TargetReps     │  │ - RPE/RIR        │  │ - UserMessage    │      │
// │  │ - Category       │  │ - Custom         │  │ - NextPreview    │      │
// │  └──────────────────┘  └──────────────────┘  └──────────────────┘      │
// └─────────────────────────────────────────────────────────────────────────┘
// 
// DIAGRAMA DE ESTADOS:
// 
//                    ┌──────────────────┐
//                    │    CALIBRATING   │ ←─── Inicio (0-1 sesiones)
//                    │    (calibrando)  │
//                    └────────┬─────────┘
//                             │ 2 sesiones completadas
//                             ▼
//     ┌──────────────────────────────────────────────────────────────┐
//     │                                                              │
//     │  ┌──────────────┐    éxito    ┌──────────────┐              │
//     │  │  PROGRESSING │ ──────────► │  CONFIRMING  │              │
//     │  │ (progresando)│ ◄────────── │ (confirmando)│              │
//     │  └──────────────┘   fracaso   └──────┬───────┘              │
//     │         │                            │                       │
//     │         │ 3+ fracasos                │ 2do éxito             │
//     │         ▼                            ▼                       │
//     │  ┌──────────────┐           ┌──────────────┐                │
//     │  │   PLATEAU    │           │   PROGRESS   │ (subir peso)   │
//     │  │  (estancado) │           │   ACHIEVED   │                │
//     │  └──────┬───────┘           └──────────────┘                │
//     │         │                                                    │
//     │         │ deload completado                                  │
//     │         ▼                                                    │
//     │  ┌──────────────┐                                           │
//     │  │   DELOADING  │ ───────────────────────────────────►      │
//     │  │   (deload)   │              vuelve a PROGRESSING         │
//     │  └──────────────┘                                           │
//     │                                                              │
//     └──────────────────────────────────────────────────────────────┘
// 
// ════════════════════════════════════════════════════════════════════════════

/// Estado extendido del controlador de progresión
enum ControllerState {
  /// Recopilando datos iniciales (0-1 sesiones)
  calibrating('calibrating', 'Calibrando', '⚙️'),
  
  /// Progresión normal activa
  progressing('progressing', 'Progresando', '📈'),
  
  /// Esperando confirmación de 2da sesión exitosa
  confirming('confirming', 'Confirmando', '🔄'),
  
  /// Estancamiento detectado (3+ fracasos)
  plateau('plateau', 'Estancado', '⚠️'),
  
  /// En fase de deload
  deloading('deloading', 'Deload', '🔽'),
  
  /// Fatiga acumulada detectada (RPE consistentemente alto)
  fatigued('fatigued', 'Fatiga', '😓'),
  
  /// Regresión necesaria (peso demasiado alto)
  regression('regression', 'Regresión', '↩️');

  final String value;
  final String label;
  final String emoji;
  
  const ControllerState(this.value, this.label, this.emoji);
  
  static ControllerState fromString(String? value) {
    if (value == null) return ControllerState.calibrating;
    for (final state in ControllerState.values) {
      if (state.value == value) return state;
    }
    return ControllerState.calibrating;
  }
}

/// Reglas de transición entre estados (explícitas y visibles)
class TransitionRule {
  final ControllerState from;
  final ControllerState to;
  final String condition;
  final String userExplanation;
  
  const TransitionRule({
    required this.from,
    required this.to,
    required this.condition,
    required this.userExplanation,
  });
  
  @override
  String toString() => '$from → $to: $condition';
}

/// Umbrales configurables (visibles para el usuario)
class ProgressionThresholds {
  /// % mínimo de series exitosas para considerar sesión "exitosa"
  final double successRate;
  
  /// Sesiones exitosas consecutivas para subir peso
  final int confirmationSessions;
  
  /// Sesiones fallidas consecutivas para detectar estancamiento
  final int plateauThreshold;
  
  /// RPE promedio para detectar fatiga
  final double fatigueRpeThreshold;
  
  /// Semanas máximas en el mismo peso antes de forzar cambio
  final int maxWeeksAtWeight;
  
  const ProgressionThresholds({
    this.successRate = 0.80, // 80%
    this.confirmationSessions = 2,
    this.plateauThreshold = 3,
    this.fatigueRpeThreshold = 9.0,
    this.maxWeeksAtWeight = 4,
  });
  
  /// Umbrales por defecto
  static const defaults = ProgressionThresholds();
  
  /// Umbrales más agresivos (para principiantes)
  static const aggressive = ProgressionThresholds(
    successRate: 0.75,
    confirmationSessions: 1,
    plateauThreshold: 2,
  );
  
  /// Umbrales conservadores (para intermedios/avanzados)
  static const conservative = ProgressionThresholds(
    successRate: 0.85,
    confirmationSessions: 3,
    plateauThreshold: 4,
    maxWeeksAtWeight: 6,
  );
  
  /// Copia con modificaciones
  ProgressionThresholds copyWith({
    double? successRate,
    int? confirmationSessions,
    int? plateauThreshold,
    double? fatigueRpeThreshold,
    int? maxWeeksAtWeight,
  }) {
    return ProgressionThresholds(
      successRate: successRate ?? this.successRate,
      confirmationSessions: confirmationSessions ?? this.confirmationSessions,
      plateauThreshold: plateauThreshold ?? this.plateauThreshold,
      fatigueRpeThreshold: fatigueRpeThreshold ?? this.fatigueRpeThreshold,
      maxWeeksAtWeight: maxWeeksAtWeight ?? this.maxWeeksAtWeight,
    );
  }
  
  /// Descripción legible de los umbrales
  String describe() {
    return '''
Umbrales de Progresión:
• Éxito de sesión: ≥${(successRate * 100).round()}% series completadas
• Confirmar subida: $confirmationSessions sesiones exitosas consecutivas
• Detectar estancamiento: $plateauThreshold sesiones fallidas
• Fatiga: RPE promedio ≥$fatigueRpeThreshold
• Máximo en mismo peso: $maxWeeksAtWeight semanas
''';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CAPA 1: DATOS DE EJECUCIÓN
// ════════════════════════════════════════════════════════════════════════════

/// Datos crudos de ejecución (independientes del modelo de progresión)
class ExecutionData {
  /// Nombre del ejercicio
  final String exerciseName;
  
  /// Categoría del ejercicio
  final ExerciseCategory category;
  
  /// Peso actual confirmado (baseline)
  final double confirmedWeight;
  
  /// Rango de reps objetivo (min, max)
  final (int, int) repsRange;
  
  /// Historial de últimas N sesiones
  final List<SessionExecutionData> sessionHistory;
  
  /// Semanas en el peso actual
  final int weeksAtCurrentWeight;
  
  const ExecutionData({
    required this.exerciseName,
    required this.category,
    required this.confirmedWeight,
    required this.repsRange,
    required this.sessionHistory,
    this.weeksAtCurrentWeight = 0,
  });
  
  /// ¿Hay suficientes datos para decisiones?
  bool get hasEnoughData => sessionHistory.length >= 2;
  
  /// Última sesión
  SessionExecutionData? get lastSession => 
      sessionHistory.isNotEmpty ? sessionHistory.first : null;
  
  /// Reps objetivo (mínimo del rango)
  int get targetReps => repsRange.$1;
  
  /// Reps máximas (máximo del rango)
  int get maxReps => repsRange.$2;
  
  /// Incremento de peso apropiado
  double get increment => category.getIncrement(confirmedWeight);
  
  /// Calcula éxitos consecutivos
  int get consecutiveSuccesses {
    int count = 0;
    for (final session in sessionHistory) {
      if (session.isSuccess) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }
  
  /// Calcula fracasos consecutivos
  int get consecutiveFailures {
    int count = 0;
    for (final session in sessionHistory) {
      if (!session.isSuccess) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }
  
  /// RPE promedio de las últimas N sesiones
  double? get averageRpe {
    final rpeSessions = sessionHistory
        .where((s) => s.averageRpe != null)
        .take(3)
        .toList();
    if (rpeSessions.isEmpty) return null;
    return rpeSessions.map((s) => s.averageRpe!).reduce((a, b) => a + b) / 
           rpeSessions.length;
  }
}

/// Datos de una sesión ejecutada
class SessionExecutionData {
  final DateTime date;
  final double weight;
  final List<SetExecutionData> sets;
  
  const SessionExecutionData({
    required this.date,
    required this.weight,
    required this.sets,
  });
  
  /// ¿Sesión exitosa? (≥80% series OK)
  bool get isSuccess => successRate >= 0.80;
  
  /// Tasa de éxito (0.0 - 1.0)
  double get successRate {
    if (sets.isEmpty) return 0.0;
    final completed = sets.where((s) => s.completed && s.metTarget).length;
    return completed / sets.length;
  }
  
  /// Reps promedio
  double get averageReps {
    if (sets.isEmpty) return 0;
    return sets.map((s) => s.reps).reduce((a, b) => a + b) / sets.length;
  }
  
  /// RPE promedio
  double? get averageRpe {
    final setsWithRpe = sets.where((s) => s.rpe != null).toList();
    if (setsWithRpe.isEmpty) return null;
    return setsWithRpe.map((s) => s.rpe!).reduce((a, b) => a + b) / 
           setsWithRpe.length;
  }
  
  /// Evalúa resultado de la sesión
  SessionResult evaluate() {
    final rate = successRate;
    if (rate >= 1.0) return SessionResult.complete;
    if (rate >= 0.80) return SessionResult.acceptable;
    if (rate >= 0.50) return SessionResult.partial;
    return SessionResult.failed;
  }
}

/// Datos de una serie ejecutada
class SetExecutionData {
  final int reps;
  final double weight;
  final int targetReps;
  final bool completed;
  final double? rpe;
  
  const SetExecutionData({
    required this.reps,
    required this.weight,
    required this.targetReps,
    required this.completed,
    this.rpe,
  });
  
  /// ¿Alcanzó el objetivo?
  bool get metTarget => completed && reps >= targetReps;
}

// ════════════════════════════════════════════════════════════════════════════
// CAPA 2: MODELOS DE PROGRESIÓN (ESTRATEGIAS INTERCAMBIABLES)
// ════════════════════════════════════════════════════════════════════════════

/// Interfaz para modelos de progresión
abstract class ProgressionModel {
  /// Nombre del modelo
  String get name;
  
  /// Descripción para el usuario
  String get description;
  
  /// Calcula la decisión basada en datos y estado
  ProgressionDecision calculate({
    required ExecutionData data,
    required ControllerState currentState,
    required ProgressionThresholds thresholds,
  });
  
  /// Determina si debe cambiar de estado
  ControllerState? shouldTransition({
    required ExecutionData data,
    required ControllerState currentState,
    required ProgressionThresholds thresholds,
  });
}

/// Modelo: Progresión Lineal
/// 
/// Reglas:
/// - Si éxito → subir peso
/// - Si fracaso → mantener
/// - Si 3+ fracasos → bajar peso
class LinearProgressionModel implements ProgressionModel {
  const LinearProgressionModel();
  
  @override
  String get name => 'Lineal';
  
  @override
  String get description => 
      'Sube peso cada vez que completes el objetivo. Simple y efectivo.';
  
  @override
  ProgressionDecision calculate({
    required ExecutionData data,
    required ControllerState currentState,
    required ProgressionThresholds thresholds,
  }) {
    final lastSession = data.lastSession;
    if (lastSession == null) {
      return ProgressionDecision.calibrating(
        weight: data.confirmedWeight,
        reps: data.targetReps,
        sessionNumber: 1,
      );
    }
    
    final result = lastSession.evaluate();
    
    // En plateau o deload → sugerir peso reducido
    if (currentState == ControllerState.plateau || 
        currentState == ControllerState.deloading) {
      final newWeight = data.confirmedWeight - data.increment;
      return ProgressionDecision(
        action: ProgressionAction.decreaseWeight,
        suggestedWeight: newWeight.clamp(0, double.infinity),
        suggestedReps: data.targetReps,
        reason: 'Deload: consolidando base',
        userMessage: 'Baja a ${_fmt(newWeight)}kg para consolidar.',
        confidence: ProgressionConfidence.high,
      );
    }
    
    // Confirmando → esperando 2do éxito
    if (currentState == ControllerState.confirming) {
      if (result == SessionResult.complete || result == SessionResult.acceptable) {
        // ¡Confirmado! Subir peso
        final newWeight = data.confirmedWeight + data.increment;
        return ProgressionDecision(
          action: ProgressionAction.increaseWeight,
          suggestedWeight: newWeight,
          suggestedReps: data.targetReps,
          reason: 'Confirmado: ${thresholds.confirmationSessions} sesiones exitosas',
          userMessage: '¡Sube a ${_fmt(newWeight)}kg!',
          confidence: ProgressionConfidence.high,
          isImprovement: true,
          nextStepPreview: 'Próximo: ${_fmt(newWeight)}kg × ${data.targetReps}',
        );
      } else {
        // Fracaso en confirmación → volver a progressing
        return ProgressionDecision(
          action: ProgressionAction.maintain,
          suggestedWeight: data.confirmedWeight,
          suggestedReps: data.targetReps,
          reason: 'Confirmación fallida, reintentar',
          userMessage: 'Repite ${_fmt(data.confirmedWeight)}kg × ${data.targetReps}.',
          confidence: ProgressionConfidence.medium,
        );
      }
    }
    
    // Progressing normal
    if (result == SessionResult.complete || result == SessionResult.acceptable) {
      if (data.consecutiveSuccesses >= thresholds.confirmationSessions - 1) {
        // Suficientes éxitos → confirmar
        final newWeight = data.confirmedWeight + data.increment;
        return ProgressionDecision(
          action: ProgressionAction.increaseWeight,
          suggestedWeight: newWeight,
          suggestedReps: data.targetReps,
          reason: 'Éxito confirmado',
          userMessage: '¡Sube a ${_fmt(newWeight)}kg!',
          confidence: ProgressionConfidence.high,
          isImprovement: true,
        );
      } else {
        // Primer éxito → esperando confirmación
        return ProgressionDecision(
          action: ProgressionAction.maintain,
          suggestedWeight: data.confirmedWeight,
          suggestedReps: data.targetReps,
          reason: 'Confirmando (${data.consecutiveSuccesses + 1}/${thresholds.confirmationSessions})',
          userMessage: 'Repite para confirmar. Éxito = +${_fmt(data.increment)}kg.',
          confidence: ProgressionConfidence.medium,
          nextStepPreview: 'Si éxito: ${_fmt(data.confirmedWeight + data.increment)}kg',
        );
      }
    }
    
    // Fracaso
    return ProgressionDecision(
      action: ProgressionAction.maintain,
      suggestedWeight: data.confirmedWeight,
      suggestedReps: data.targetReps,
      reason: 'Día difícil, mantener',
      userMessage: 'Repite el objetivo. Un día malo no cambia nada.',
      confidence: ProgressionConfidence.medium,
    );
  }
  
  @override
  ControllerState? shouldTransition({
    required ExecutionData data,
    required ControllerState currentState,
    required ProgressionThresholds thresholds,
  }) {
    // Ver reglas de transición más abajo
    return null; // Delegado al controller
  }
  
  String _fmt(double w) => w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
}

/// Modelo: Doble Progresión (Reps primero, luego peso)
/// 
/// Reglas:
/// - Primero subir reps hasta max del rango
/// - Cuando alcanza max reps 2 veces → subir peso, volver a min reps
class DoubleProgressionModel implements ProgressionModel {
  const DoubleProgressionModel();
  
  @override
  String get name => 'Doble Progresión';
  
  @override
  String get description => 
      'Primero sube reps (8→12), luego sube peso y vuelve a 8. Más gradual.';
  
  @override
  ProgressionDecision calculate({
    required ExecutionData data,
    required ControllerState currentState,
    required ProgressionThresholds thresholds,
  }) {
    final lastSession = data.lastSession;
    if (lastSession == null) {
      return ProgressionDecision.calibrating(
        weight: data.confirmedWeight,
        reps: data.targetReps,
        sessionNumber: 1,
      );
    }
    
    final result = lastSession.evaluate();
    final avgReps = lastSession.averageReps;
    final (minReps, maxReps) = data.repsRange;
    
    // Plateau/Deload
    if (currentState == ControllerState.plateau || 
        currentState == ControllerState.deloading) {
      final newWeight = data.confirmedWeight - data.increment;
      return ProgressionDecision(
        action: ProgressionAction.decreaseWeight,
        suggestedWeight: newWeight.clamp(0, double.infinity),
        suggestedReps: maxReps, // Volver a max reps con peso reducido
        reason: 'Deload: reconstruyendo',
        userMessage: 'Baja a ${_fmt(newWeight)}kg × $maxReps para consolidar.',
        confidence: ProgressionConfidence.high,
        nextStepPreview: 'Objetivo: ${_fmt(newWeight)}kg × $maxReps → volver a subir',
      );
    }
    
    // Sesión exitosa
    if (result == SessionResult.complete || result == SessionResult.acceptable) {
      // ¿Alcanzó max reps?
      if (avgReps >= maxReps) {
        // ¿Es la 2da sesión en max reps?
        final prevAtMax = data.sessionHistory.length > 1 && 
                          data.sessionHistory[1].averageReps >= maxReps;
        
        if (data.consecutiveSuccesses >= 1 && prevAtMax) {
          // ¡Subir peso!
          final newWeight = data.confirmedWeight + data.increment;
          return ProgressionDecision(
            action: ProgressionAction.increaseWeight,
            suggestedWeight: newWeight,
            suggestedReps: minReps,
            reason: '2 sesiones a $maxReps reps',
            userMessage: '¡Sube a ${_fmt(newWeight)}kg! Empieza con $minReps reps.',
            confidence: ProgressionConfidence.high,
            isImprovement: true,
            nextStepPreview: 'Próximo: ${_fmt(newWeight)}kg × ${minReps + 1}',
          );
        } else {
          // Esperando confirmación
          return ProgressionDecision(
            action: ProgressionAction.maintain,
            suggestedWeight: data.confirmedWeight,
            suggestedReps: maxReps,
            reason: 'Confirmando (1/2 a max reps)',
            userMessage: 'Repite ${_fmt(data.confirmedWeight)}kg × $maxReps. Si lo logras, subirás peso.',
            confidence: ProgressionConfidence.medium,
            nextStepPreview: 'Si éxito: ${_fmt(data.confirmedWeight + data.increment)}kg × $minReps',
          );
        }
      } else {
        // Subir reps
        final nextReps = (avgReps + 1).clamp(minReps, maxReps).toInt();
        return ProgressionDecision(
          action: ProgressionAction.increaseReps,
          suggestedWeight: data.confirmedWeight,
          suggestedReps: nextReps,
          reason: 'Progresando en reps',
          userMessage: 'Intenta $nextReps reps hoy.',
          confidence: ProgressionConfidence.high,
          isImprovement: true,
          nextStepPreview: nextReps >= maxReps 
              ? 'Próximo hito: confirmar para subir peso'
              : 'Siguiente: ${nextReps + 1} reps',
        );
      }
    }
    
    // Fracaso
    return ProgressionDecision(
      action: ProgressionAction.maintain,
      suggestedWeight: data.confirmedWeight,
      suggestedReps: data.targetReps,
      reason: 'Día difícil, mantener',
      userMessage: 'Repite el objetivo. Un día malo no cambia nada.',
      confidence: ProgressionConfidence.medium,
    );
  }
  
  @override
  ControllerState? shouldTransition({
    required ExecutionData data,
    required ControllerState currentState,
    required ProgressionThresholds thresholds,
  }) => null;
  
  String _fmt(double w) => w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
}

/// Modelo: RPE/RIR (Autorregulación)
/// 
/// Reglas:
/// - RPE < 7 → subir peso
/// - RPE 7-9 → mantener (zona óptima)
/// - RPE > 9 consistente → bajar peso o deload
class RpeProgressionModel implements ProgressionModel {
  const RpeProgressionModel();
  
  @override
  String get name => 'RPE/RIR';
  
  @override
  String get description => 
      'Ajusta basándose en tu esfuerzo percibido. Ideal para autorregulación.';
  
  @override
  ProgressionDecision calculate({
    required ExecutionData data,
    required ControllerState currentState,
    required ProgressionThresholds thresholds,
  }) {
    final lastSession = data.lastSession;
    if (lastSession == null) {
      return ProgressionDecision.calibrating(
        weight: data.confirmedWeight,
        reps: data.targetReps,
        sessionNumber: 1,
      );
    }
    
    final avgRpe = lastSession.averageRpe;
    
    // Sin datos RPE → fallback a mantener
    if (avgRpe == null) {
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: data.confirmedWeight,
        suggestedReps: data.targetReps,
        reason: 'Sin datos RPE',
        userMessage: 'Registra RPE para sugerencias automáticas.',
        confidence: ProgressionConfidence.low,
      );
    }
    
    // Fatiga detectada
    if (currentState == ControllerState.fatigued) {
      final newWeight = data.confirmedWeight - data.increment;
      return ProgressionDecision(
        action: ProgressionAction.decreaseWeight,
        suggestedWeight: newWeight.clamp(0, double.infinity),
        suggestedReps: data.targetReps,
        reason: 'Fatiga: RPE consistentemente alto',
        userMessage: 'RPE alto. Baja a ${_fmt(newWeight)}kg para recuperar.',
        confidence: ProgressionConfidence.high,
      );
    }
    
    // RPE muy bajo → subir peso
    if (avgRpe < 7) {
      final newWeight = data.confirmedWeight + data.increment;
      return ProgressionDecision(
        action: ProgressionAction.increaseWeight,
        suggestedWeight: newWeight,
        suggestedReps: data.targetReps,
        reason: 'RPE ${avgRpe.toStringAsFixed(1)} < 7',
        userMessage: 'RPE bajo. Sube a ${_fmt(newWeight)}kg.',
        confidence: ProgressionConfidence.high,
        isImprovement: true,
      );
    }
    
    // RPE en rango óptimo (7-9)
    if (avgRpe >= 7 && avgRpe <= 9) {
      return ProgressionDecision(
        action: ProgressionAction.maintain,
        suggestedWeight: data.confirmedWeight,
        suggestedReps: data.targetReps,
        reason: 'RPE ${avgRpe.toStringAsFixed(1)} en zona óptima',
        userMessage: 'RPE ${avgRpe.toStringAsFixed(1)} perfecto. Mantén.',
        confidence: ProgressionConfidence.high,
      );
    }
    
    // RPE muy alto (> 9)
    if (data.consecutiveFailures >= 1 || (data.averageRpe ?? 0) > 9) {
      final newWeight = data.confirmedWeight - data.increment;
      return ProgressionDecision(
        action: ProgressionAction.decreaseWeight,
        suggestedWeight: newWeight.clamp(0, double.infinity),
        suggestedReps: data.targetReps,
        reason: 'RPE ${avgRpe.toStringAsFixed(1)} > 9',
        userMessage: 'RPE muy alto. Baja a ${_fmt(newWeight)}kg.',
        confidence: ProgressionConfidence.high,
      );
    }
    
    // RPE alto pero solo 1 sesión → observar
    return ProgressionDecision(
      action: ProgressionAction.maintain,
      suggestedWeight: data.confirmedWeight,
      suggestedReps: data.targetReps,
      reason: 'RPE ${avgRpe.toStringAsFixed(1)} alto (1 sesión)',
      userMessage: 'RPE alto hoy. Repite para evaluar.',
      confidence: ProgressionConfidence.medium,
    );
  }
  
  @override
  ControllerState? shouldTransition({
    required ExecutionData data,
    required ControllerState currentState,
    required ProgressionThresholds thresholds,
  }) {
    // Detectar fatiga
    final avgRpe = data.averageRpe;
    if (avgRpe != null && avgRpe >= thresholds.fatigueRpeThreshold) {
      if (currentState != ControllerState.fatigued) {
        return ControllerState.fatigued;
      }
    }
    return null;
  }
  
  String _fmt(double w) => w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
}

// ════════════════════════════════════════════════════════════════════════════
// CAPA 3: CONTROLADOR CENTRAL (MÁQUINA DE ESTADOS)
// ════════════════════════════════════════════════════════════════════════════

/// Controlador central de progresión
/// 
/// Responsabilidades:
/// 1. Mantener estado actual
/// 2. Aplicar reglas de transición
/// 3. Delegar cálculo al modelo activo
/// 4. Comunicar cambios al usuario
class ProgressionController {
  /// Estado actual
  ControllerState _state;
  
  /// Modelo de progresión activo
  ProgressionModel _model;
  
  /// Umbrales configurados
  ProgressionThresholds _thresholds;
  
  /// Historial de transiciones (para debug/explicación)
  final List<TransitionRecord> _transitionHistory = [];
  
  ProgressionController({
    ControllerState initialState = ControllerState.calibrating,
    ProgressionModel? model,
    ProgressionThresholds? thresholds,
  }) : _state = initialState,
       _model = model ?? const DoubleProgressionModel(),
       _thresholds = thresholds ?? ProgressionThresholds.defaults;
  
  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────
  
  ControllerState get state => _state;
  ProgressionModel get model => _model;
  ProgressionThresholds get thresholds => _thresholds;
  List<TransitionRecord> get transitionHistory => List.unmodifiable(_transitionHistory);
  
  // ─────────────────────────────────────────────────────────────────────────
  // CONFIGURACIÓN
  // ─────────────────────────────────────────────────────────────────────────
  
  /// Cambia el modelo de progresión
  void setModel(ProgressionModel newModel) {
    _model = newModel;
  }
  
  /// Cambia los umbrales
  void setThresholds(ProgressionThresholds newThresholds) {
    _thresholds = newThresholds;
  }
  
  /// Fuerza un estado (para testing/override manual)
  void forceState(ControllerState newState, {String? reason}) {
    final oldState = _state;
    _state = newState;
    _recordTransition(oldState, newState, reason ?? 'Forzado manualmente');
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // CÁLCULO PRINCIPAL
  // ─────────────────────────────────────────────────────────────────────────
  
  /// Calcula la decisión de progresión
  ProgressionDecision calculate(ExecutionData data) {
    // 1. Evaluar transiciones de estado
    _evaluateTransitions(data);
    
    // 2. Delegar al modelo
    final decision = _model.calculate(
      data: data,
      currentState: _state,
      thresholds: _thresholds,
    );
    
    return decision;
  }
  
  /// Evalúa y aplica transiciones de estado
  void _evaluateTransitions(ExecutionData data) {
    final newState = _determineState(data);
    if (newState != _state) {
      final oldState = _state;
      _state = newState;
      _recordTransition(oldState, newState, _getTransitionReason(oldState, newState, data));
    }
  }
  
  /// Determina el estado correcto basado en datos
  ControllerState _determineState(ExecutionData data) {
    // Calibración: menos de 2 sesiones
    if (!data.hasEnoughData) {
      return ControllerState.calibrating;
    }
    
    // Dejar que el modelo sugiera transición
    final modelSuggestion = _model.shouldTransition(
      data: data,
      currentState: _state,
      thresholds: _thresholds,
    );
    if (modelSuggestion != null) {
      return modelSuggestion;
    }
    
    // Reglas globales de transición
    
    // Estancamiento: N fracasos consecutivos
    if (data.consecutiveFailures >= _thresholds.plateauThreshold) {
      if (_state != ControllerState.deloading) {
        return ControllerState.plateau;
      }
    }
    
    // Fatiga: RPE consistentemente alto
    final avgRpe = data.averageRpe;
    if (avgRpe != null && avgRpe >= _thresholds.fatigueRpeThreshold) {
      return ControllerState.fatigued;
    }
    
    // Demasiado tiempo en mismo peso
    if (data.weeksAtCurrentWeight >= _thresholds.maxWeeksAtWeight) {
      return ControllerState.plateau;
    }
    
    // Confirmando: 1 éxito, esperando 2do
    if (_state == ControllerState.progressing && 
        data.consecutiveSuccesses == 1 &&
        _thresholds.confirmationSessions > 1) {
      return ControllerState.confirming;
    }
    
    // Éxito confirmado → volver a progressing
    if (_state == ControllerState.confirming && 
        data.consecutiveSuccesses >= _thresholds.confirmationSessions) {
      return ControllerState.progressing;
    }
    
    // Fracaso en confirmación → volver a progressing
    if (_state == ControllerState.confirming && data.consecutiveFailures > 0) {
      return ControllerState.progressing;
    }
    
    // Saliendo de deload
    if (_state == ControllerState.deloading && data.consecutiveSuccesses >= 1) {
      return ControllerState.progressing;
    }
    
    // Plateau → deload
    if (_state == ControllerState.plateau) {
      return ControllerState.deloading;
    }
    
    // Default: progressing
    if (_state == ControllerState.calibrating && data.hasEnoughData) {
      return ControllerState.progressing;
    }
    
    return _state;
  }
  
  String _getTransitionReason(ControllerState from, ControllerState to, ExecutionData data) {
    return switch ((from, to)) {
      (ControllerState.calibrating, ControllerState.progressing) =>
        '2 sesiones completadas',
      (ControllerState.progressing, ControllerState.confirming) =>
        '1 éxito, esperando confirmación',
      (ControllerState.confirming, ControllerState.progressing) =>
        'Confirmado o fracaso',
      (ControllerState.progressing, ControllerState.plateau) =>
        '${data.consecutiveFailures} fracasos consecutivos',
      (ControllerState.plateau, ControllerState.deloading) =>
        'Iniciando deload',
      (ControllerState.deloading, ControllerState.progressing) =>
        'Deload completado',
      (_, ControllerState.fatigued) =>
        'RPE promedio ≥${_thresholds.fatigueRpeThreshold}',
      _ => 'Transición automática',
    };
  }
  
  void _recordTransition(ControllerState from, ControllerState to, String reason) {
    _transitionHistory.add(TransitionRecord(
      timestamp: DateTime.now(),
      from: from,
      to: to,
      reason: reason,
    ));
    
    // Mantener solo últimas 20 transiciones
    if (_transitionHistory.length > 20) {
      _transitionHistory.removeAt(0);
    }
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // REGLAS DE TRANSICIÓN (EXPLÍCITAS)
  // ─────────────────────────────────────────────────────────────────────────
  
  /// Obtiene todas las reglas de transición (para documentación/UI)
  static List<TransitionRule> get allTransitionRules => [
    const TransitionRule(
      from: ControllerState.calibrating,
      to: ControllerState.progressing,
      condition: 'sessionHistory.length >= 2',
      userExplanation: 'Después de 2 sesiones, el sistema tiene datos suficientes.',
    ),
    const TransitionRule(
      from: ControllerState.progressing,
      to: ControllerState.confirming,
      condition: 'consecutiveSuccesses == 1 && confirmationSessions > 1',
      userExplanation: '1 sesión exitosa. Repite para confirmar subida.',
    ),
    const TransitionRule(
      from: ControllerState.confirming,
      to: ControllerState.progressing,
      condition: 'consecutiveSuccesses >= confirmationSessions',
      userExplanation: 'Confirmado. Subes peso y vuelves a progresión normal.',
    ),
    const TransitionRule(
      from: ControllerState.confirming,
      to: ControllerState.progressing,
      condition: 'consecutiveFailures > 0',
      userExplanation: 'Confirmación fallida. Vuelves a intentar.',
    ),
    const TransitionRule(
      from: ControllerState.progressing,
      to: ControllerState.plateau,
      condition: 'consecutiveFailures >= plateauThreshold',
      userExplanation: 'Varias sesiones difíciles. Considera un deload.',
    ),
    const TransitionRule(
      from: ControllerState.plateau,
      to: ControllerState.deloading,
      condition: 'automático',
      userExplanation: 'Iniciando fase de deload para recuperar.',
    ),
    const TransitionRule(
      from: ControllerState.deloading,
      to: ControllerState.progressing,
      condition: 'consecutiveSuccesses >= 1',
      userExplanation: 'Deload completado. Vuelves a progresar.',
    ),
    const TransitionRule(
      from: ControllerState.progressing,
      to: ControllerState.fatigued,
      condition: 'averageRpe >= fatigueRpeThreshold',
      userExplanation: 'RPE consistentemente alto. Necesitas recuperar.',
    ),
  ];
}

/// Registro de una transición de estado
class TransitionRecord {
  final DateTime timestamp;
  final ControllerState from;
  final ControllerState to;
  final String reason;
  
  const TransitionRecord({
    required this.timestamp,
    required this.from,
    required this.to,
    required this.reason,
  });
  
  @override
  String toString() => '${from.emoji} → ${to.emoji}: $reason';
}

// ════════════════════════════════════════════════════════════════════════════
// FACTORY: CREAR MODELO DESDE TIPO
// ════════════════════════════════════════════════════════════════════════════

/// Crea el modelo de progresión apropiado
ProgressionModel createProgressionModel(ProgressionType type) {
  return switch (type) {
    ProgressionType.lineal => const LinearProgressionModel(),
    ProgressionType.dobleRepsFirst => const DoubleProgressionModel(),
    ProgressionType.rpe => const RpeProgressionModel(),
    ProgressionType.none => const LinearProgressionModel(), // fallback
  };
}
