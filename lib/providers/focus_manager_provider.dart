import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../utils/performance_utils.dart';

/// Estado inmutable que representa el target de focus actual
class FocusTarget {
  final int exerciseIndex;
  final int setIndex;
  final FocusField field;
  final DateTime timestamp;

  const FocusTarget({
    required this.exerciseIndex,
    required this.setIndex,
    required this.field,
    required this.timestamp,
  });

  FocusTarget copyWith({
    int? exerciseIndex,
    int? setIndex,
    FocusField? field,
    DateTime? timestamp,
  }) {
    return FocusTarget(
      exerciseIndex: exerciseIndex ?? this.exerciseIndex,
      setIndex: setIndex ?? this.setIndex,
      field: field ?? this.field,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FocusTarget &&
        other.exerciseIndex == exerciseIndex &&
        other.setIndex == setIndex &&
        other.field == field;
  }

  @override
  int get hashCode => Object.hash(exerciseIndex, setIndex, field);
}

/// Campo que debe recibir focus
enum FocusField {
  weight,
  reps,
}

/// Estado del FocusManager
class FocusManagerState {
  final FocusTarget? currentTarget;
  final bool isKeyboardVisible;
  final bool vibrateOnFocus;

  const FocusManagerState({
    this.currentTarget,
    this.isKeyboardVisible = false,
    this.vibrateOnFocus = true,
  });

  FocusManagerState copyWith({
    FocusTarget? currentTarget,
    bool? isKeyboardVisible,
    bool? vibrateOnFocus,
    bool clearTarget = false,
  }) {
    return FocusManagerState(
      currentTarget: clearTarget ? null : (currentTarget ?? this.currentTarget),
      isKeyboardVisible: isKeyboardVisible ?? this.isKeyboardVisible,
      vibrateOnFocus: vibrateOnFocus ?? this.vibrateOnFocus,
    );
  }
}

/// Notifier para gestionar el auto-focus inteligente durante la sesión
///
/// Funcionalidades:
/// - Auto-focus al siguiente input cuando timer termina
/// - Auto-focus al siguiente input cuando se completa una serie
/// - Vibración suave como feedback
/// - Gestión del estado del teclado
class FocusManagerNotifier extends StateNotifier<FocusManagerState> {
  FocusManagerNotifier() : super(const FocusManagerState());

  /// Solicita focus en un campo específico
  /// Se usa cuando el timer termina o se completa una serie
  void requestFocus({
    required int exerciseIndex,
    required int setIndex,
    FocusField field = FocusField.weight,
    bool vibrate = true,
  }) {
    state = state.copyWith(
      currentTarget: FocusTarget(
        exerciseIndex: exerciseIndex,
        setIndex: setIndex,
        field: field,
        timestamp: DateTime.now(),
      ),
    );

    // Vibración suave como feedback
    if (vibrate && state.vibrateOnFocus) {
      _triggerFocusVibration();
    }
  }

  /// Limpia el target de focus actual (después de que el widget lo consume)
  void clearFocus() {
    state = state.copyWith(clearTarget: true);
  }

  /// Avanza al siguiente campo (KG -> REPS)
  void advanceToNextField({
    required int exerciseIndex,
    required int setIndex,
    required FocusField currentField,
  }) {
    if (currentField == FocusField.weight) {
      requestFocus(
        exerciseIndex: exerciseIndex,
        setIndex: setIndex,
        field: FocusField.reps,
        vibrate: false, // Sin vibración para transición suave
      );
    }
  }

  /// Actualiza el estado de visibilidad del teclado
  void setKeyboardVisible(bool visible) {
    state = state.copyWith(isKeyboardVisible: visible);
  }

  /// Habilita/deshabilita vibración en focus
  void setVibrateOnFocus(bool enabled) {
    state = state.copyWith(vibrateOnFocus: enabled);
  }

  /// Vibración suave para feedback de focus
  Future<void> _triggerFocusVibration() async {
    if (!PerformanceMode.instance.reduceVibrations) {
      try { HapticFeedback.selectionClick(); } catch (_) {}
    }
  }
}

/// Provider global para el FocusManager
final focusManagerProvider = StateNotifierProvider<FocusManagerNotifier, FocusManagerState>(
  (ref) => FocusManagerNotifier(),
);

/// Provider de conveniencia para obtener solo el target actual
final currentFocusTargetProvider = Provider<FocusTarget?>((ref) {
  return ref.watch(focusManagerProvider).currentTarget;
});

/// Helper para verificar si un campo específico debe recibir focus
bool shouldFieldFocus({
  required FocusTarget? target,
  required int exerciseIndex,
  required int setIndex,
  required FocusField field,
}) {
  if (target == null) return false;
  return target.exerciseIndex == exerciseIndex &&
      target.setIndex == setIndex &&
      target.field == field;
}
