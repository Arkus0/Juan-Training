import 'package:flutter_test/flutter_test.dart';
import 'package:juan_training/models/rutina.dart';
import 'package:juan_training/models/sesion.dart';
import 'package:juan_training/repositories/i_training_repository.dart';

class FakeTrainingRepository extends Fake implements ITrainingRepository {
  @override
  Stream<List<Rutina>> watchRutinas() {
    return Stream.value([]);
  }

  @override
  Stream<List<Sesion>> watchSesionesHistory() {
    return Stream.value([]);
  }

  @override
  Stream<ActiveSessionData?> watchActiveSession() {
    return Stream.value(null);
  }

  @override
  Future<ActiveSessionData?> getActiveSession() async {
    return null;
  }
}
