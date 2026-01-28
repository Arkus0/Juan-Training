import 'ps_ejercicio.dart';

class PSSesion {
  final String id;
  final DateTime fecha;
  final int? durationSeconds;
  final double totalVolume;
  final List<PSEjercicio> ejerciciosCompletados;
  final String? rutinaId;
  final String? dayName;

  PSSesion({required this.id, required this.fecha, this.durationSeconds, required this.totalVolume, List<PSEjercicio>? ejerciciosCompletados, this.rutinaId, this.dayName})
      : ejerciciosCompletados = ejerciciosCompletados ?? [];

  int get completedSetsCount => ejerciciosCompletados.fold(0, (sum, e) => sum + e.completedSetsCount());

  String get formattedDuration => durationSeconds != null ? '${(durationSeconds! / 60).round()} MIN' : 'N/A';

  @override
  String toString() => 'PSSesion(id: $id, fecha: $fecha, duration: $durationSeconds, totalVolume: $totalVolume)';
}
