import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/session_progress_provider.dart';
import '../../providers/focus_manager_provider.dart';
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
        // Detectar nuevo milestone
        if (next.newlyReachedMilestone != null) {
          HapticsController.instance.onMilestone(next.newlyReachedMilestone!);
          // Marcar como consumido
          ref.read(sessionProgressProvider.notifier).clearNewlyReachedMilestone();
        }
      },
    );

    // ═══════════════════════════════════════════════════════════════════════
    // OBSERVER: Exercise Completion
    // ═══════════════════════════════════════════════════════════════════════
    ref.listen<ExerciseCompletionInfo?>(
      exerciseCompletionProvider,
      (previous, next) {
        if (next?.needsHapticFeedback == true) {
          HapticsController.instance.onExerciseCompleted();
          // Marcar como consumido
          ref.read(exerciseCompletionProvider.notifier).markHapticConsumed();
        }
      },
    );

    // ═══════════════════════════════════════════════════════════════════════
    // OBSERVER: Focus Changes
    // ═══════════════════════════════════════════════════════════════════════
    ref.listen<FocusManagerState>(
      focusManagerProvider,
      (previous, next) {
        if (next.needsHapticFeedback) {
          HapticsController.instance.trigger(HapticEvent.focusChanged);
          // Marcar como consumido
          ref.read(focusManagerProvider.notifier).markHapticConsumed();
        }
      },
    );

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
