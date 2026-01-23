import 'package:uuid/uuid.dart';

/// Representa una serie loggeada durante el entrenamiento.
///
/// Implementa `==` y `hashCode` para optimizar comparaciones en Riverpod selectors,
/// evitando rebuilds innecesarios cuando los valores no han cambiado.
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

  /// Copia de la serie con valores modificados.
  SerieLog copyWith({
    String? id,
    double? peso,
    int? reps,
    bool? completed,
    int? rpe,
    String? notas,
    int? restSeconds,
    bool? isFailure,
    bool? isDropset,
    bool? isWarmup,
  }) {
    return SerieLog(
      id: id ?? this.id,
      peso: peso ?? this.peso,
      reps: reps ?? this.reps,
      completed: completed ?? this.completed,
      rpe: rpe ?? this.rpe,
      notas: notas ?? this.notas,
      restSeconds: restSeconds ?? this.restSeconds,
      isFailure: isFailure ?? this.isFailure,
      isDropset: isDropset ?? this.isDropset,
      isWarmup: isWarmup ?? this.isWarmup,
    );
  }

  /// Compara por valor para optimizar rebuilds.
  /// Dos SerieLog son iguales si todos sus campos visibles en UI son iguales.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SerieLog) return false;
    return id == other.id &&
        peso == other.peso &&
        reps == other.reps &&
        completed == other.completed &&
        rpe == other.rpe &&
        isFailure == other.isFailure &&
        isDropset == other.isDropset &&
        isWarmup == other.isWarmup;
  }

  @override
  int get hashCode => Object.hash(
        id,
        peso,
        reps,
        completed,
        rpe,
        isFailure,
        isDropset,
        isWarmup,
      );
}
