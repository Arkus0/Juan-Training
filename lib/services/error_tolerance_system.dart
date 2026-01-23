import '../models/progression_engine_models.dart';
import 'progression_controller.dart';

// ════════════════════════════════════════════════════════════════════════════
// ERROR TOLERANCE SYSTEM
// ════════════════════════════════════════════════════════════════════════════
// 
// Filosofía: El sistema debe ser más tolerante que un entrenador humano.
// 
// Principios:
// 1. NUNCA castigar - Solo ajustar expectativas
// 2. NUNCA romperse - Siempre tener un fallback sensato
// 3. NUNCA perder credibilidad - Explicar cambios claramente
// 
// ════════════════════════════════════════════════════════════════════════════

/// Tipos de situaciones que el sistema debe manejar
enum UserSituation {
  /// Serie con menos reps de las esperadas
  failedSet,
  
  /// Dato claramente erróneo (ej: 500kg en curl)
  dataEntryError,
  
  /// Sesión saltada (días sin entrenar)
  skippedSession,
  
  /// Varias series malas en un día
  badDay,
  
  /// Rendimiento inconsistente (muy alto o muy bajo)
  suspiciousPerformance,
  
  /// Usuario ajusta peso manualmente
  manualOverride,
  
  /// Cambio brusco de rendimiento entre sesiones
  performanceJump,
}

/// Resultado del análisis de tolerancia
class ToleranceResult {
  /// ¿El dato es válido?
  final bool isValid;
  
  /// ¿Requiere corrección automática?
  final bool needsCorrection;
  
  /// Valor corregido (si aplica)
  final double? correctedValue;
  
  /// Mensaje para el usuario (si necesita explicación)
  final String? userMessage;
  
  /// Severidad del problema
  final ToleranceSeverity severity;
  
  /// ¿Debería afectar la progresión?
  final bool affectsProgression;
  
  const ToleranceResult({
    required this.isValid,
    this.needsCorrection = false,
    this.correctedValue,
    this.userMessage,
    this.severity = ToleranceSeverity.none,
    this.affectsProgression = true,
  });
  
  /// Todo OK
  static const ok = ToleranceResult(isValid: true);
  
  /// Dato inválido pero recuperable
  factory ToleranceResult.corrected({
    required double correctedValue,
    String? message,
  }) {
    return ToleranceResult(
      isValid: true,
      needsCorrection: true,
      correctedValue: correctedValue,
      userMessage: message,
      severity: ToleranceSeverity.low,
    );
  }
  
  /// Día malo - no afecta progresión
  factory ToleranceResult.badDay({String? message}) {
    return ToleranceResult(
      isValid: true,
      userMessage: message ?? 'Día difícil. No afecta tu progreso.',
      severity: ToleranceSeverity.low,
      affectsProgression: false,
    );
  }
  
  /// Dato sospechoso - pedir confirmación
  factory ToleranceResult.suspicious({
    required String message,
  }) {
    return ToleranceResult(
      isValid: true,
      userMessage: message,
      severity: ToleranceSeverity.medium,
    );
  }
}

enum ToleranceSeverity {
  none,
  low,
  medium,
  high,
}

// ════════════════════════════════════════════════════════════════════════════
// REGLAS DE TOLERANCIA
// ════════════════════════════════════════════════════════════════════════════

class ErrorToleranceRules {
  
  // ─────────────────────────────────────────────────────────────────────────
  // REGLA 1: SERIE FALLIDA
  // ─────────────────────────────────────────────────────────────────────────
  // 
  // Situación: Usuario hace 5 reps cuando el objetivo era 8
  // 
  // ❌ MAL: "¡Fallaste! -1 punto de progreso"
  // ✅ BIEN: "Registrado. Un día difícil no cambia nada."
  // 
  // Regla: Una serie mala NUNCA afecta directamente la progresión.
  //        Solo afecta si es patrón repetido (3+ sesiones).
  // ─────────────────────────────────────────────────────────────────────────
  
  static ToleranceResult evaluateFailedSet({
    required int actualReps,
    required int targetReps,
    required int setNumber,
    required int totalSets,
    required List<int> previousSetsReps,
  }) {
    final deficit = targetReps - actualReps;
    
    // Si logró el objetivo o más, todo bien
    if (deficit <= 0) {
      return ToleranceResult.ok;
    }
    
    // Si es la última serie y las anteriores fueron buenas, es fatiga normal
    if (setNumber == totalSets && _averageReps(previousSetsReps) >= targetReps) {
      return const ToleranceResult(
        isValid: true,
        userMessage: null, // Silencio - es normal
        severity: ToleranceSeverity.none,
        affectsProgression: true, // Cuenta pero no castiga
      );
    }
    
    // Si falló por mucho (< 50% de objetivo), probablemente hay un problema
    if (actualReps < targetReps * 0.5) {
      return const ToleranceResult(
        isValid: true,
        userMessage: '¿Pasó algo? No te preocupes, continúa.',
        severity: ToleranceSeverity.low,
        affectsProgression: true,
      );
    }
    
    // Fallo normal - no decir nada negativo
    return const ToleranceResult(
      isValid: true,
      userMessage: null, // Silencio = normalizado
      severity: ToleranceSeverity.none,
      affectsProgression: true,
    );
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // REGLA 2: ERROR DE ENTRADA DE DATOS
  // ─────────────────────────────────────────────────────────────────────────
  // 
  // Situación: Usuario pone 500kg en curl de bíceps
  // 
  // ❌ MAL: Guardar y romper el sistema
  // ✅ BIEN: "¿Quisiste decir 50kg?" con opción de confirmar
  // 
  // Regla: Detectar valores imposibles y ofrecer corrección SIN bloquear
  // ─────────────────────────────────────────────────────────────────────────
  
  static ToleranceResult evaluateDataEntry({
    required double enteredWeight,
    required double lastKnownWeight,
    required String exerciseName,
    required ExerciseCategory category,
  }) {
    // Límites por categoría (valores razonables máximos)
    final maxReasonable = _getMaxReasonableWeight(category);
    const minReasonable = 0.0;
    
    // Cambio máximo permitido entre sesiones (%)
    const maxChangePercent = 0.30; // 30%
    
    // Peso negativo - claramente error
    if (enteredWeight < minReasonable) {
      return ToleranceResult.corrected(
        correctedValue: lastKnownWeight,
        message: 'Peso ajustado a ${_fmt(lastKnownWeight)}kg',
      );
    }
    
    // Peso imposiblemente alto
    if (enteredWeight > maxReasonable) {
      final suggested = _suggestCorrection(enteredWeight, lastKnownWeight);
      return ToleranceResult.suspicious(
        message: '¿Quisiste decir ${_fmt(suggested)}kg?',
      );
    }
    
    // Cambio muy grande respecto a la última sesión
    if (lastKnownWeight > 0) {
      final change = (enteredWeight - lastKnownWeight).abs() / lastKnownWeight;
      
      if (change > maxChangePercent) {
        // Probablemente error de dedo o confusión
        return ToleranceResult.suspicious(
          message: 'Cambio grande: ${_fmt(lastKnownWeight)}kg → ${_fmt(enteredWeight)}kg. ¿Confirmar?',
        );
      }
    }
    
    return ToleranceResult.ok;
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // REGLA 3: SESIÓN SALTADA
  // ─────────────────────────────────────────────────────────────────────────
  // 
  // Situación: Usuario no entrena en 1-2 semanas
  // 
  // ❌ MAL: "Has perdido progreso. Reiniciando..."
  // ✅ BIEN: "¡Bienvenido! Empezamos donde lo dejaste."
  // 
  // Regla: 
  // - < 7 días: Sin cambios
  // - 7-14 días: Mantener peso, resetear confirmación
  // - 14-30 días: Sugerir peso ligeramente menor (5-10%)
  // - > 30 días: Sugerir recalibración (opción, no obligación)
  // ─────────────────────────────────────────────────────────────────────────
  
  static SessionGapResult evaluateSessionGap({
    required DateTime lastSessionDate,
    required DateTime currentDate,
    required double lastWeight,
    required ControllerState lastState,
  }) {
    final daysSinceLastSession = currentDate.difference(lastSessionDate).inDays;
    
    // Menos de 7 días - sin cambios
    if (daysSinceLastSession < 7) {
      return SessionGapResult(
        adjustedWeight: lastWeight,
        adjustedState: lastState,
        message: null,
        requiresRecalibration: false,
      );
    }
    
    // 7-14 días - mantener pero resetear confirmación
    if (daysSinceLastSession < 14) {
      return SessionGapResult(
        adjustedWeight: lastWeight,
        adjustedState: ControllerState.progressing, // Reset confirming
        message: '¡De vuelta! Continuamos con ${_fmt(lastWeight)}kg.',
        requiresRecalibration: false,
      );
    }
    
    // 14-30 días - sugerir reducción pequeña
    if (daysSinceLastSession < 30) {
      final suggestedWeight = (lastWeight * 0.95).roundToDouble(); // -5%
      return SessionGapResult(
        adjustedWeight: suggestedWeight,
        adjustedState: ControllerState.progressing,
        message: 'Han pasado $daysSinceLastSession días. Sugerimos ${_fmt(suggestedWeight)}kg para retomar.',
        requiresRecalibration: false,
        isReductionSuggested: true,
        originalWeight: lastWeight,
      );
    }
    
    // > 30 días - sugerir recalibración
    final suggestedWeight = (lastWeight * 0.85).roundToDouble(); // -15%
    return SessionGapResult(
      adjustedWeight: suggestedWeight,
      adjustedState: ControllerState.calibrating,
      message: '¡Bienvenido de nuevo! Te sugerimos empezar con ${_fmt(suggestedWeight)}kg y recalibrar.',
      requiresRecalibration: true,
      isReductionSuggested: true,
      originalWeight: lastWeight,
    );
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // REGLA 4: DÍA MALO (TODAS LAS SERIES MALAS)
  // ─────────────────────────────────────────────────────────────────────────
  // 
  // Situación: Usuario normalmente hace 8,8,8 pero hoy hace 5,4,4
  // 
  // ❌ MAL: "Rendimiento -40%. Bajando peso."
  // ✅ BIEN: "Día difícil. No afecta tu progreso. La próxima irá mejor."
  // 
  // Regla: Un día malo aislado NO afecta la progresión.
  //        Solo cuenta si se repite 2+ veces consecutivas.
  // ─────────────────────────────────────────────────────────────────────────
  
  static BadDayResult evaluateBadDay({
    required List<int> todayReps,
    required int targetReps,
    required List<List<int>> previousSessionsReps,
  }) {
    final todayAvg = _averageReps(todayReps);
    final targetTotal = targetReps * todayReps.length;
    final actualTotal = todayReps.fold(0, (a, b) => a + b);
    final completionRate = actualTotal / targetTotal;
    
    // Si completó >= 80%, no es un día malo
    if (completionRate >= 0.80) {
      return const BadDayResult(
        isBadDay: false,
        affectsProgression: true,
      );
    }
    
    // Si completó >= 50%, es un día difícil pero cuenta
    if (completionRate >= 0.50) {
      // Verificar si es patrón (2+ días malos consecutivos)
      final previousBadDays = _countConsecutiveBadDays(
        previousSessionsReps, 
        targetReps,
      );
      
      if (previousBadDays >= 1) {
        // Patrón de días malos - esto SÍ afecta
        return BadDayResult(
          isBadDay: true,
          affectsProgression: true,
          message: 'Segunda sesión difícil. Considera descansar.',
          suggestDeload: previousBadDays >= 2,
        );
      }
      
      // Día malo aislado - NO afecta
      return const BadDayResult(
        isBadDay: true,
        affectsProgression: false,
        message: 'Día difícil. No afecta tu progreso.',
      );
    }
    
    // < 50% - algo pasó, pero no castigar
    return const BadDayResult(
      isBadDay: true,
      affectsProgression: false,
      message: 'Todos tenemos días así. La próxima irá mejor.',
    );
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // REGLA 5: RENDIMIENTO SOSPECHOSO (TRAMPAS)
  // ─────────────────────────────────────────────────────────────────────────
  // 
  // Situación: Usuario siempre hace exactamente el objetivo (nunca falla)
  //            O de repente hace 20 reps cuando antes hacía 8
  // 
  // ❌ MAL: "¡Trampa detectada! Datos ignorados."
  // ✅ BIEN: Confiar pero ajustar modelo interno silenciosamente
  // 
  // Regla: 
  // - Confiar en el usuario siempre
  // - Si hay saltos imposibles, pedir confirmación suave
  // - Ajustar expectativas internamente sin acusar
  // ─────────────────────────────────────────────────────────────────────────
  
  static SuspiciousPerformanceResult evaluateSuspiciousPerformance({
    required List<int> todayReps,
    required int targetReps,
    required double todayWeight,
    required List<SessionSnapshot> recentSessions,
  }) {
    if (recentSessions.isEmpty) {
      return SuspiciousPerformanceResult.ok;
    }
    
    final avgRecentReps = recentSessions
        .map((s) => s.averageReps)
        .fold(0.0, (a, b) => a + b) / recentSessions.length;
    
    final todayAvg = _averageReps(todayReps).toDouble();
    
    // Salto positivo muy grande (> 50% más reps de lo normal)
    if (todayAvg > avgRecentReps * 1.5 && avgRecentReps > 0) {
      return SuspiciousPerformanceResult(
        isSuspicious: true,
        suspicionType: SuspicionType.tooGood,
        // NO acusar, solo pedir confirmación
        message: '¡Gran sesión! ¿${todayReps.join(', ')} reps es correcto?',
        trustData: true, // Confiar de todos modos
      );
    }
    
    // Rendimiento demasiado consistente (sospecha de datos inventados)
    // Solo detectar si TODAS las sesiones son exactamente iguales
    final allSame = recentSessions.every(
      (s) => s.averageReps == avgRecentReps && s.averageReps == targetReps
    );
    
    if (allSame && recentSessions.length >= 5) {
      // No decir nada, pero ajustar internamente
      return const SuspiciousPerformanceResult(
        isSuspicious: true,
        suspicionType: SuspicionType.tooConsistent,
        message: null, // Silencio - no acusar
        trustData: true,
        internalNote: 'Datos muy consistentes, posible sobre-reporte',
      );
    }
    
    return SuspiciousPerformanceResult.ok;
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // REGLA 6: OVERRIDE MANUAL
  // ─────────────────────────────────────────────────────────────────────────
  // 
  // Situación: El sistema sugiere 80kg, usuario pone 70kg
  // 
  // ❌ MAL: "Ignorando tu cambio. El sistema sabe mejor."
  // ✅ BIEN: "OK. Recordaré que prefieres 70kg."
  // 
  // Regla: El usuario SIEMPRE tiene la última palabra.
  //        El sistema aprende de sus preferencias.
  // ─────────────────────────────────────────────────────────────────────────
  
  static ManualOverrideResult evaluateManualOverride({
    required double suggestedWeight,
    required double userWeight,
    required String exerciseName,
  }) {
    final difference = userWeight - suggestedWeight;
    final percentChange = suggestedWeight > 0 
        ? (difference.abs() / suggestedWeight) * 100 
        : 0.0;
    
    // Usuario aceptó sugerencia
    if (difference.abs() < 0.1) {
      return const ManualOverrideResult(
        accepted: true,
        shouldRemember: false,
      );
    }
    
    // Usuario bajó peso
    if (difference < 0) {
      return ManualOverrideResult(
        accepted: false,
        userPreference: userWeight,
        shouldRemember: true,
        message: 'OK. Usando ${_fmt(userWeight)}kg.',
        internalAction: percentChange > 20 
            ? OverrideAction.adjustBaseline
            : OverrideAction.rememberPreference,
      );
    }
    
    // Usuario subió peso
    return ManualOverrideResult(
      accepted: false,
      userPreference: userWeight,
      shouldRemember: true,
      message: 'OK. Usando ${_fmt(userWeight)}kg.',
      internalAction: OverrideAction.trustUser,
    );
  }
  
  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  
  static double _averageReps(List<int> reps) {
    if (reps.isEmpty) return 0;
    return reps.fold(0, (a, b) => a + b) / reps.length;
  }
  
  static double _getMaxReasonableWeight(ExerciseCategory category) {
    return switch (category) {
      ExerciseCategory.heavyCompound => 400.0, // Récords mundiales
      ExerciseCategory.lightCompound => 200.0,
      ExerciseCategory.isolation => 100.0,
      ExerciseCategory.machine => 500.0, // Máquinas tienen stacks grandes
    };
  }
  
  static double _suggestCorrection(double entered, double lastKnown) {
    // Intentar detectar si es error de dedo (ej: 800 en vez de 80)
    if (entered > lastKnown * 5) {
      // Probablemente un 0 de más
      return entered / 10;
    }
    return lastKnown;
  }
  
  static int _countConsecutiveBadDays(
    List<List<int>> previousSessions,
    int targetReps,
  ) {
    int count = 0;
    for (final session in previousSessions) {
      final total = session.fold(0, (a, b) => a + b);
      final expected = targetReps * session.length;
      if (total / expected < 0.80) {
        count++;
      } else {
        break; // Ya no es consecutivo
      }
    }
    return count;
  }
  
  static String _fmt(double w) {
    return w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// RESULT CLASSES
// ════════════════════════════════════════════════════════════════════════════

class SessionGapResult {
  final double adjustedWeight;
  final ControllerState adjustedState;
  final String? message;
  final bool requiresRecalibration;
  final bool isReductionSuggested;
  final double? originalWeight;
  
  const SessionGapResult({
    required this.adjustedWeight,
    required this.adjustedState,
    this.message,
    this.requiresRecalibration = false,
    this.isReductionSuggested = false,
    this.originalWeight,
  });
}

class BadDayResult {
  final bool isBadDay;
  final bool affectsProgression;
  final String? message;
  final bool suggestDeload;
  
  const BadDayResult({
    required this.isBadDay,
    required this.affectsProgression,
    this.message,
    this.suggestDeload = false,
  });
}

class SuspiciousPerformanceResult {
  final bool isSuspicious;
  final SuspicionType? suspicionType;
  final String? message;
  final bool trustData;
  final String? internalNote;
  
  const SuspiciousPerformanceResult({
    required this.isSuspicious,
    this.suspicionType,
    this.message,
    this.trustData = true,
    this.internalNote,
  });
  
  static const ok = SuspiciousPerformanceResult(
    isSuspicious: false,
    trustData: true,
  );
}

enum SuspicionType {
  tooGood,
  tooConsistent,
  impossible,
}

class SessionSnapshot {
  final DateTime date;
  final double weight;
  final double averageReps;
  
  const SessionSnapshot({
    required this.date,
    required this.weight,
    required this.averageReps,
  });
}

class ManualOverrideResult {
  final bool accepted;
  final double? userPreference;
  final bool shouldRemember;
  final String? message;
  final OverrideAction? internalAction;
  
  const ManualOverrideResult({
    required this.accepted,
    this.userPreference,
    this.shouldRemember = false,
    this.message,
    this.internalAction,
  });
}

enum OverrideAction {
  trustUser,
  adjustBaseline,
  rememberPreference,
}

// ════════════════════════════════════════════════════════════════════════════
// RECOVERY SYSTEM
// ════════════════════════════════════════════════════════════════════════════

/// Sistema de recuperación: Cómo el sistema vuelve a un estado saludable
class RecoverySystem {
  
  /// Recuperación después de sesión(es) mala(s)
  static RecoveryPlan planRecovery({
    required int consecutiveBadSessions,
    required double currentWeight,
    required ExerciseCategory category,
  }) {
    if (consecutiveBadSessions == 0) {
      return RecoveryPlan.none;
    }
    
    if (consecutiveBadSessions == 1) {
      // 1 sesión mala: Solo mensaje de ánimo
      return const RecoveryPlan(
        action: RecoveryAction.encourage,
        message: 'La próxima irá mejor.',
        weightAdjustment: 0,
      );
    }
    
    if (consecutiveBadSessions == 2) {
      // 2 sesiones malas: Sugerir mantener (no forzar)
      return const RecoveryPlan(
        action: RecoveryAction.suggestMaintain,
        message: 'Considera repetir este peso una vez más.',
        weightAdjustment: 0,
      );
    }
    
    // 3+ sesiones malas: Sugerir deload (con opción)
    final deloadAmount = category.getIncrement(currentWeight) * 2;
    return RecoveryPlan(
      action: RecoveryAction.suggestDeload,
      message: 'Te sugerimos bajar a ${_fmt(currentWeight - deloadAmount)}kg para consolidar.',
      weightAdjustment: -deloadAmount,
      isOptional: true,
    );
  }
  
  /// Recuperación después de ausencia larga
  static RecoveryPlan planReturnFromAbsence({
    required int daysAbsent,
    required double lastWeight,
  }) {
    if (daysAbsent < 14) {
      return const RecoveryPlan(
        action: RecoveryAction.welcomeBack,
        message: '¡De vuelta! Continuamos donde lo dejaste.',
        weightAdjustment: 0,
      );
    }
    
    if (daysAbsent < 30) {
      return RecoveryPlan(
        action: RecoveryAction.gentleReturn,
        message: 'Han pasado $daysAbsent días. Empezamos suave.',
        weightAdjustment: -(lastWeight * 0.05), // -5%
        isOptional: true,
      );
    }
    
    return RecoveryPlan(
      action: RecoveryAction.recalibrate,
      message: '¡Bienvenido de nuevo! Te sugerimos recalibrar.',
      weightAdjustment: -(lastWeight * 0.15), // -15%
      isOptional: true,
    );
  }
  
  static String _fmt(double w) {
    return w == w.roundToDouble() ? w.toInt().toString() : w.toStringAsFixed(1);
  }
}

class RecoveryPlan {
  final RecoveryAction action;
  final String message;
  final double weightAdjustment;
  final bool isOptional;
  
  const RecoveryPlan({
    required this.action,
    required this.message,
    required this.weightAdjustment,
    this.isOptional = false,
  });
  
  static const none = RecoveryPlan(
    action: RecoveryAction.none,
    message: '',
    weightAdjustment: 0,
  );
}

enum RecoveryAction {
  none,
  encourage,
  suggestMaintain,
  suggestDeload,
  welcomeBack,
  gentleReturn,
  recalibrate,
}
