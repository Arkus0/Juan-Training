import 'package:uuid/uuid.dart';

class SerieLog {
  final String id;
  final double peso;
  final int reps;
  bool completed;
  final int? rpe;
  final String? notas;
  final int? restSeconds;
  final bool isFailure;
  final bool isDropset;
  final bool isWarmup;

  SerieLog({
    String? id,
    required this.peso,
    required this.reps,
    this.completed = true,
    this.rpe,
    this.notas,
    this.restSeconds,
    this.isFailure = false,
    this.isDropset = false,
    this.isWarmup = false,
  }) : id = id ?? const Uuid().v4();
}
