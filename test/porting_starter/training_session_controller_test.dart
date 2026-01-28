import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juan_training/porting_starter/providers/training_session_controller.dart';

void main() {
  test('start and finish a session', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(psTrainingControllerProvider.notifier);

    notifier.startSession(id: 's1');
    final state1 = container.read(psTrainingControllerProvider);
    expect(state1.active, true);
    expect(state1.activeSession?.id, 's1');

    notifier.addSet(ejercicioId: 'e1', peso: 100.0, reps: 5);
    final state2 = container.read(psTrainingControllerProvider);
    expect(state2.activeSession?.completedSetsCount, greaterThanOrEqualTo(1));

    notifier.finishSession();
    final state3 = container.read(psTrainingControllerProvider);
    expect(state3.active, false);
    expect(state3.lastSession, isNotNull);
  });
}
