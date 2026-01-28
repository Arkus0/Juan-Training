import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/porting_starter/repositories/in_memory_training_repository.dart';
import 'package:juan_training/porting_starter/models/ps_sesion.dart';

void main() {
  test('InMemory repo emits saved sessions', () async {
    final repo = InMemoryTrainingRepositoryPS();
    final collected = <PSSesion>[];
    final sub = repo.watchSessions().listen((list) => collected.addAll(list));

    final s = PSSesion(id: 's1', fecha: DateTime.now(), totalVolume: 100.0);
    await repo.saveSession(s);

    // allow async microtask
    await Future.delayed(Duration(milliseconds: 10));

    expect(collected.any((e) => e.id == 's1'), true);

    await sub.cancel();
    repo.dispose();
  });
}
