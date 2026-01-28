import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/session_progress_provider.dart';
import '../../services/haptics_controller.dart';

/// Widget que observa eventos de la sesión y dispara haptics apropiados.
///
/// Este widget debe colocarse en el árbol de widgets de la pantalla de
/// entrenamiento para que observe los providers y dispare feedback háptico
/// cuando corresponda.
///
/// ARQUITECTURA CORRECTA:
/// ```
/// Provider (lógica) → emite evento con flag needsHapticFeedback
/// HapticsObserver (UI) → observa flag → llama HapticsController
/// HapticsController → verifica lifecycle → ejecuta vibración
/// ```
///
/// ARQUITECTURA INCORRECTA:
/// ```
/// Provider → llama HapticFeedback directamente  ❌
/// (Puede ejecutarse cuando app está en background, Android ignora)
/// ```
///
/// USO:
/// ```dart
/// // En la pantalla de entrenamiento
/// @override
/// Widget build(BuildContext context) {
///   return HapticsObserver(
///     child: Scaffold(...),
///   );
/// }
/// ```
class HapticsObserver extends ConsumerStatefulWidget {
  final Widget child;

  const HapticsObserver({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<HapticsObserver> createState() => _HapticsObserverState();
}

class _HapticsObserverState extends ConsumerState<HapticsObserver> {
  @override
  void initState() {
    super.initState();
    // Asegurar que HapticsController está inicializado
    HapticsController.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    // ═══════════════════════════════════════════════════════════════════════
    // OBSERVER: Session Progress Milestones
    // ═══════════════════════════════════════════════════════════════════════
    ref.listen<SessionProgress>(
      sessionProgressProvider,
      (previous, next) {
        // Detectar nuevo milestone comparando con el anterior
        final prevMilestone = previous?.lastMilestone ?? 0;
        final newMilestone = next.lastMilestone;
        if (newMilestone > prevMilestone && newMilestone > 0) {
          HapticsController.instance.onMilestone(newMilestone);
        }
      },
    );

    // ═══════════════════════════════════════════════════════════════════════
    // OBSERVER: Exercise Completion
    // ═══════════════════════════════════════════════════════════════════════
    ref.listen<ExerciseCompletionInfo?>(
      exerciseCompletionProvider,
      (previous, next) {
        if (next != null) {
          HapticsController.instance.onExerciseCompleted();
          // Marcar como consumido / dismissed para que no vuelva a disparar
          ref.read(exerciseCompletionProvider.notifier).dismiss();
        }
      },
    );

    // ═══════════════════════════════════════════════════════════════════════
    // OBSERVER: Focus Changes
    // ═══════════════════════════════════════════════════════════════════════
    // FocusManager ya realiza su propia vibración cuando solicita focus
    // (requestFocus()): no necesitamos escuchar aquí para evitar duplicados.

    return widget.child;
  }
}

/// Extension para facilitar el uso de HapticsController desde widgets
extension HapticsExtension on BuildContext {
  /// Dispara un evento háptico
  void haptic(HapticEvent event) {
    HapticsController.instance.trigger(event);
  }

  /// Haptic para tap en botón
  void hapticTap() {
    HapticsController.instance.trigger(HapticEvent.buttonTap);
  }

  /// Haptic para submit de input
  void hapticSubmit() {
    HapticsController.instance.trigger(HapticEvent.inputSubmit);
  }
}
