import 'dart:async';

import '../models/ps_sesion.dart';
import '../models/ps_rutina.dart';
import 'i_training_repository.dart';

/// Implementación simple en memoria útil para pruebas y como plantilla inicial.
class InMemoryTrainingRepositoryPS implements ITrainingRepositoryPS {
  final _controller = StreamController<List<PSSesion>>.broadcast();
  final List<PSSesion> _storage = [];

  InMemoryTrainingRepositoryPS() {
    _emit();
  }

  void _emit() => _controller.add(List.unmodifiable(_storage));

  @override
  Future<void> deleteSession(String id) async {
    _storage.removeWhere((s) => s.id == id);
    _emit();
  }

  @override
  Stream<List<PSSesion>> watchSessions() => _controller.stream;

  @override
  Future<void> saveSession(PSSesion s) async {
    _storage.removeWhere((e) => e.id == s.id);
    _storage.add(s);
    _emit();
  }

  @override
  Future<List<PSRutina>> getRutinas() async => [PSRutina(id: 'r1', nombre: 'Rutina ejemplo')];

  void dispose() {
    _controller.close();
  }
}
