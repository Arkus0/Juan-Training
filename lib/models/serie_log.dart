import 'package:hive/hive.dart';

part 'serie_log.g.dart';

@HiveType(typeId: 3)
class SerieLog extends HiveObject {
  @HiveField(0)
  final double peso;

  @HiveField(1)
  final int reps;

  @HiveField(2)
  bool completed;

  @HiveField(3)
  final int? rpe;

  @HiveField(4)
  final String? notas;

  @HiveField(5)
  final int? restSeconds;

  @HiveField(6)
  final bool isFailure;

  @HiveField(7)
  final bool isDropset;

  @HiveField(8)
  final bool isWarmup;

  SerieLog({
    required this.peso,
    required this.reps,
    this.completed = true,
    this.rpe,
    this.notas,
    this.restSeconds,
    this.isFailure = false,
    this.isDropset = false,
    this.isWarmup = false,
  });
}
