import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/error_tolerance_system.dart';
import '../services/progression_controller.dart';
import 'analysis_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
// SESSION TOLERANCE PROVIDER
// ════════════════════════════════════════════════════════════════════════════
//
// Maneja el feedback empático al usuario basado en ERROR_TOLERANCE_DESIGN.md:
// - Mensaje de bienvenida tras días sin entrenar
// - Detección de días malos
// - Sugerencias de deload
//
// ════════════════════════════════════════════════════════════════════════════

/// Estado del feedback de tolerancia para la sesión actual
class SessionToleranceState {
  /// Resultado del análisis de gap de sesión (días sin entrenar)
  final SessionGapResult? sessionGapResult;
  
  /// ¿Ya se mostró el mensaje de bienvenida?
  final bool welcomeMessageShown;
  
  /// Resultado del día malo (si aplica)
  final BadDayResult? badDayResult;
  
  /// Ejercicios con rendimiento difícil en esta sesión
  final Set<String> difficultExercises;

  const SessionToleranceState({
    this.sessionGapResult,
    this.welcomeMessageShown = false,
    this.badDayResult,
    this.difficultExercises = const {},
  });

  SessionToleranceState copyWith({
    SessionGapResult? sessionGapResult,
    bool? welcomeMessageShown,
    BadDayResult? badDayResult,
    Set<String>? difficultExercises,
  }) {
    return SessionToleranceState(
      sessionGapResult: sessionGapResult ?? this.sessionGapResult,
      welcomeMessageShown: welcomeMessageShown ?? this.welcomeMessageShown,
      badDayResult: badDayResult ?? this.badDayResult,
      difficultExercises: difficultExercises ?? this.difficultExercises,
    );
  }

  /// ¿Debería mostrar mensaje de bienvenida?
  bool get shouldShowWelcome => 
      sessionGapResult != null && 
      sessionGapResult!.message != null && 
      !welcomeMessageShown;
  
  /// ¿Es una vuelta después de muchos días?
  bool get isComingBack => 
      sessionGapResult != null && 
      sessionGapResult!.message != null;
  
  /// Días desde la última sesión
  int get daysSinceLastSession {
    if (sessionGapResult == null) return 0;
    // Inferir de los datos
    if (sessionGapResult!.requiresRecalibration) return 30;
    if (sessionGapResult!.isReductionSuggested) return 14;
    return 7;
  }
}

/// Provider para el estado de tolerancia de la sesión
class SessionToleranceNotifier extends StateNotifier<SessionToleranceState> {
  final Ref _ref;

  SessionToleranceNotifier(this._ref) : super(const SessionToleranceState());

  /// Evalúa el gap desde la última sesión
  Future<void> evaluateSessionGap() async {
    try {
      final streakData = await _ref.read(streakDataProvider.future);
      
      if (streakData.lastTrainingDate == null) {
        // Primera sesión, no hay gap
        return;
      }

      // Obtener el último estado del controlador (simplificado a progressing)
      const lastState = ControllerState.progressing;
      
      // Usar un peso de referencia (se ajustará por ejercicio)
      const lastWeight = 0.0; // Se maneja por ejercicio individual

      final result = ErrorToleranceRules.evaluateSessionGap(
        lastSessionDate: streakData.lastTrainingDate!,
        currentDate: DateTime.now(),
        lastWeight: lastWeight,
        lastState: lastState,
      );

      state = state.copyWith(sessionGapResult: result);
    } catch (e) {
      // Silenciosamente ignorar errores - no bloquear la sesión
    }
  }

  /// Marca que el mensaje de bienvenida fue mostrado
  void markWelcomeShown() {
    state = state.copyWith(welcomeMessageShown: true);
  }

  /// Evalúa si un ejercicio tuvo un día malo
  void evaluateExerciseCompletion({
    required String exerciseName,
    required List<int> todayReps,
    required int targetReps,
    required List<List<int>> previousSessionsReps,
  }) {
    final result = ErrorToleranceRules.evaluateBadDay(
      todayReps: todayReps,
      targetReps: targetReps,
      previousSessionsReps: previousSessionsReps,
    );

    if (result.isBadDay) {
      final newDifficult = Set<String>.from(state.difficultExercises)
        ..add(exerciseName);
      state = state.copyWith(
        badDayResult: result,
        difficultExercises: newDifficult,
      );
    }
  }
  
  /// Limpia el resultado de día malo (después de mostrar feedback)
  void clearBadDayResult() {
    state = state.copyWith(badDayResult: null);
  }

  /// Limpia el estado al terminar sesión
  void reset() {
    state = const SessionToleranceState();
  }
}

final sessionToleranceProvider = 
    StateNotifierProvider<SessionToleranceNotifier, SessionToleranceState>((ref) {
  return SessionToleranceNotifier(ref);
});

/// Provider que evalúa automáticamente el gap al iniciar
final sessionGapEvaluatedProvider = FutureProvider<SessionGapResult?>((ref) async {
  final notifier = ref.read(sessionToleranceProvider.notifier);
  await notifier.evaluateSessionGap();
  return ref.read(sessionToleranceProvider).sessionGapResult;
});

// ════════════════════════════════════════════════════════════════════════════
// SUSPICIOUS DATA PROVIDER
// ════════════════════════════════════════════════════════════════════════════

/// Datos sospechosos pendientes de confirmación
class SuspiciousDataState {
  final String? exerciseName;
  final double? enteredWeight;
  final double? suggestedWeight;
  final int? exerciseIndex;
  final int? setIndex;
  
  const SuspiciousDataState({
    this.exerciseName,
    this.enteredWeight,
    this.suggestedWeight,
    this.exerciseIndex,
    this.setIndex,
  });
  
  bool get hasSuspiciousData => exerciseName != null && enteredWeight != null;
  
  SuspiciousDataState clear() => const SuspiciousDataState();
}

class SuspiciousDataNotifier extends StateNotifier<SuspiciousDataState> {
  SuspiciousDataNotifier() : super(const SuspiciousDataState());
  
  /// Registra datos sospechosos para mostrar diálogo
  void setSuspiciousData({
    required String exerciseName,
    required double enteredWeight,
    required double suggestedWeight,
    required int exerciseIndex,
    required int setIndex,
  }) {
    state = SuspiciousDataState(
      exerciseName: exerciseName,
      enteredWeight: enteredWeight,
      suggestedWeight: suggestedWeight,
      exerciseIndex: exerciseIndex,
      setIndex: setIndex,
    );
  }
  
  /// Limpia los datos sospechosos
  void clear() {
    state = state.clear();
  }
}

final suspiciousDataProvider = 
    StateNotifierProvider<SuspiciousDataNotifier, SuspiciousDataState>((ref) {
  return SuspiciousDataNotifier();
});
