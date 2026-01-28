import '../models/ps_sesion.dart';
import '../models/ps_rutina.dart';

abstract class ITrainingRepositoryPS {
  Future<void> saveSession(PSSesion s);
  Stream<List<PSSesion>> watchSessions();
  Future<void> deleteSession(String id);
  Future<List<PSRutina>> getRutinas();
}
