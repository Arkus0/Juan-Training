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

  SerieLog({
    required this.peso,
    required this.reps,
    this.completed = true,
  });
}
