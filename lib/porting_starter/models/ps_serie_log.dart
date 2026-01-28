class PSSerieLog {
  final double peso;
  final int reps;
  final bool completed;
  final int? rpe;

  const PSSerieLog({required this.peso, required this.reps, this.completed = true, this.rpe});

  Map<String, dynamic> toMap() => {
        'peso': peso,
        'reps': reps,
        'completed': completed,
        'rpe': rpe,
      };

  @override
  String toString() => 'PSSerieLog(peso: $peso, reps: $reps, completed: $completed, rpe: $rpe)';
}
