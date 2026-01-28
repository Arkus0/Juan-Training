import 'ps_serie_log.dart';

class PSEjercicio {
  final String id;
  final String nombre;
  final List<PSSerieLog> logs;

  PSEjercicio({required this.id, required this.nombre, List<PSSerieLog>? logs}) : logs = logs ?? [];

  int completedSetsCount() => logs.where((l) => l.completed).length;

  double maxWeight() => logs.where((l) => l.completed).fold(0.0, (max, l) => (l.peso > max ? l.peso : max));

  @override
  String toString() => 'PSEjercicio(id: $id, nombre: $nombre, logs: $logs)';
}
