import 'dart:ui';

/// Activity data for a single day - used in heatmap
class DailyActivity {
  final DateTime date;
  final int sessionsCount;
  final double totalVolume; // kg * reps
  final int durationMinutes;

  const DailyActivity({
    required this.date,
    required this.sessionsCount,
    required this.totalVolume,
    required this.durationMinutes,
  });

  /// Intensity level 0-4 for heatmap coloring
  /// Based on volume thresholds (in kg)
  int get intensityLevel {
    if (sessionsCount == 0) return 0;
    if (totalVolume < 2000) return 1; // Light session
    if (totalVolume < 5000) return 2; // Normal session
    if (totalVolume < 10000) return 3; // Heavy session
    return 4; // Beast mode
  }

  /// Create empty activity for a specific date
  factory DailyActivity.empty(DateTime date) {
    return DailyActivity(
      date: date,
      sessionsCount: 0,
      totalVolume: 0,
      durationMinutes: 0,
    );
  }
}

/// Recovery status for muscle groups
enum RecoveryStatus {
  recovering(0, 2, 'Recuperando', Color(0xFFFF1744)), // Red - needs rest
  ready(3, 4, 'Listo', Color(0xFFFFEB3B)), // Yellow - can train
  fresh(5, 999, 'Fresco', Color(0xFF4CAF50)); // Green - fully recovered

  final int minDays;
  final int maxDays;
  final String label;
  final Color color;

  const RecoveryStatus(this.minDays, this.maxDays, this.label, this.color);

  static RecoveryStatus fromDaysSinceTraining(int days) {
    if (days <= 2) return recovering;
    if (days <= 4) return ready;
    return fresh;
  }

  /// Icon for status display
  String get emoji {
    switch (this) {
      case RecoveryStatus.recovering:
        return '🔴';
      case RecoveryStatus.ready:
        return '🟡';
      case RecoveryStatus.fresh:
        return '🟢';
    }
  }
}

/// Muscle recovery tracking
class MuscleRecovery {
  final String muscleName;
  final String displayName; // Spanish localized name
  final DateTime? lastTrained;
  final RecoveryStatus status;
  final int daysSinceTraining;

  const MuscleRecovery({
    required this.muscleName,
    required this.displayName,
    this.lastTrained,
    required this.status,
    required this.daysSinceTraining,
  });

  factory MuscleRecovery.fromLastTrained({
    required String muscleName,
    required String displayName,
    DateTime? lastTrained,
  }) {
    final now = DateTime.now();
    final days = lastTrained != null
        ? now.difference(lastTrained).inDays
        : 999; // Never trained

    return MuscleRecovery(
      muscleName: muscleName,
      displayName: displayName,
      lastTrained: lastTrained,
      status: RecoveryStatus.fromDaysSinceTraining(days),
      daysSinceTraining: days,
    );
  }
}

/// Muscle volume for symmetry analysis
class MuscleVolume {
  final String muscleName;
  final String displayName;
  final double totalVolume; // kg * reps over period
  final int setsCount;
  final DateTime? lastTrained;

  const MuscleVolume({
    required this.muscleName,
    required this.displayName,
    required this.totalVolume,
    required this.setsCount,
    this.lastTrained,
  });

  /// Normalized value (0-1) for radar chart
  double normalizedTo(double maxVolume) {
    if (maxVolume <= 0) return 0;
    return (totalVolume / maxVolume).clamp(0.0, 1.0);
  }
}

/// Personal Record for an exercise
class PersonalRecord {
  final String exerciseName;
  final double maxWeight;
  final int repsAtMax;
  final double estimated1RM;
  final DateTime achievedAt;
  final double? previousBest; // For comparison

  const PersonalRecord({
    required this.exerciseName,
    required this.maxWeight,
    required this.repsAtMax,
    required this.estimated1RM,
    required this.achievedAt,
    this.previousBest,
  });

  /// Check if this is a new PR compared to previous
  bool get isNewRecord => previousBest == null || maxWeight > previousBest!;

  /// Format weight for display
  String get formattedWeight => '${maxWeight.toStringAsFixed(1)}kg';

  /// Format 1RM for display
  String get formattedEstimated1RM => '${estimated1RM.toStringAsFixed(1)}kg';
}

/// Data point for strength trend chart
class StrengthDataPoint {
  final DateTime date;
  final double estimated1RM;
  final double actualMax;
  final int repsAtMax;

  const StrengthDataPoint({
    required this.date,
    required this.estimated1RM,
    required this.actualMax,
    required this.repsAtMax,
  });
}

/// Streak tracking data
class StreakData {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastTrainingDate;
  final List<DateTime> recentDates; // Last 7 days for display

  const StreakData({
    required this.currentStreak,
    required this.longestStreak,
    this.lastTrainingDate,
    this.recentDates = const [],
  });

  static const empty = StreakData(
    currentStreak: 0,
    longestStreak: 0,
  );

  /// Check if trained today
  bool get trainedToday {
    if (lastTrainingDate == null) return false;
    final now = DateTime.now();
    return lastTrainingDate!.year == now.year &&
        lastTrainingDate!.month == now.month &&
        lastTrainingDate!.day == now.day;
  }
}

/// Daily snapshot for calendar selection
class DailySnapshot {
  final DateTime date;
  final String? routineName;
  final String? dayName;
  final double totalVolume;
  final int durationMinutes;
  final int setsCompleted;
  final BestSetInfo? bestSet;
  final List<String> exerciseNames;

  const DailySnapshot({
    required this.date,
    this.routineName,
    this.dayName,
    required this.totalVolume,
    required this.durationMinutes,
    required this.setsCompleted,
    this.bestSet,
    this.exerciseNames = const [],
  });

  /// Format volume as tons
  String get formattedVolume {
    if (totalVolume >= 1000) {
      return '${(totalVolume / 1000).toStringAsFixed(1)}t';
    }
    return '${totalVolume.toStringAsFixed(0)}kg';
  }

  /// Format duration
  String get formattedDuration {
    if (durationMinutes < 60) {
      return '${durationMinutes}min';
    }
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return '${hours}h ${mins}min';
  }
}

/// Best set info for daily snapshot
class BestSetInfo {
  final String exerciseName;
  final double weight;
  final int reps;
  final int? rpe;

  const BestSetInfo({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    this.rpe,
  });

  String get formatted {
    final rpeStr = rpe != null ? ' @ RPE $rpe' : '';
    return '$exerciseName: ${weight.toStringAsFixed(1)}kg x $reps$rpeStr';
  }
}

// =============================================================================
// MUSCLE GROUP MAPPING
// =============================================================================

/// Mapping from database muscle names to Spanish display names
const Map<String, String> kMuscleDisplayNames = {
  // Major groups
  'chest': 'Pecho',
  'pectoralis major': 'Pecho',
  'pectoralis minor': 'Pecho',

  'back': 'Espalda',
  'latissimus dorsi': 'Espalda',
  'lats': 'Espalda',
  'trapezius': 'Espalda',
  'rhomboids': 'Espalda',
  'erector spinae': 'Espalda',

  'quadriceps': 'Piernas',
  'quads': 'Piernas',
  'hamstrings': 'Piernas',
  'glutes': 'Piernas',
  'gluteus maximus': 'Piernas',
  'calves': 'Piernas',
  'gastrocnemius': 'Piernas',
  'soleus': 'Piernas',
  'legs': 'Piernas',

  'shoulders': 'Hombros',
  'deltoids': 'Hombros',
  'anterior deltoid': 'Hombros',
  'lateral deltoid': 'Hombros',
  'posterior deltoid': 'Hombros',

  'biceps': 'Brazos',
  'biceps brachii': 'Brazos',
  'triceps': 'Brazos',
  'triceps brachii': 'Brazos',
  'forearms': 'Brazos',
  'brachialis': 'Brazos',
  'arms': 'Brazos',

  'abs': 'Core',
  'abdominals': 'Core',
  'rectus abdominis': 'Core',
  'obliques': 'Core',
  'core': 'Core',
  'transverse abdominis': 'Core',
};

/// Main muscle group categories for analysis
const List<String> kMuscleGroups = [
  'Pecho',
  'Espalda',
  'Piernas',
  'Hombros',
  'Brazos',
  'Core',
];

/// Get display name for a muscle
String getMuscleDisplayName(String muscle) {
  final lower = muscle.toLowerCase().trim();
  return kMuscleDisplayNames[lower] ?? muscle;
}

/// Normalize muscle name to main category
String normalizeMuscleGroup(String muscle) {
  return getMuscleDisplayName(muscle);
}

// =============================================================================
// 1RM ESTIMATION
// =============================================================================

/// Estimate 1 Rep Max using Brzycki formula
/// Formula: weight × (36 / (37 - reps))
///
/// PROTECCIÓN ANTI-OUTLIER: El resultado tiene un techo de 600kg para
/// evitar que errores de entrada arruinen las gráficas de tendencia.
/// (El récord mundial de peso muerto es ~501kg)
double estimateOneRepMax(double weight, int reps) {
  // Constante: Máximo 1RM razonable en el mundo real
  const max1RMCeiling = 600.0;

  if (reps <= 0 || weight <= 0) return 0;
  if (reps == 1) return weight.clamp(0, max1RMCeiling);

  // FIX: Limitar reps para evitar cálculos absurdos
  // Reps > 30 no tiene sentido para calcular 1RM
  final clampedReps = reps.clamp(1, 30);

  double estimated;
  if (clampedReps > 12) {
    // Brzycki becomes inaccurate above 12 reps
    // Use a conservative estimate
    estimated = weight * 1.33;
  } else {
    estimated = weight * (36 / (37 - clampedReps));
  }

  // Aplicar techo para evitar outliers que arruinen gráficas
  return estimated.clamp(0, max1RMCeiling);
}

// =============================================================================
// HEATMAP COLOR CONSTANTS — Aggressive Red Palette
// =============================================================================

/// Heatmap colors from inactive to maximum intensity
/// Gradiente rojo: de vacío (#1A1A1A) a lleno (#FF3333 fire)
const List<Color> kHeatmapColors = [
  Color(0xFF1A1A1A), // Level 0 - No activity (dark background)
  Color(0xFF3D0A0A), // Level 1 - Low (very dark red)
  Color(0xFF6E1515), // Level 2 - Medium-low (dark red blend)
  Color(0xFFC41E3A), // Level 3 - Medium-high (bloodRed/Ferrari)
  Color(0xFFFF3333), // Level 4 - High (fireRed "on fire")
];

/// Get color for intensity level
Color getHeatmapColor(int level) {
  return kHeatmapColors[level.clamp(0, 4)];
}

// =============================================================================
// BIG LIFTS FOR HALL OF FAME
// =============================================================================

/// Key compound exercises for tracking PRs
const List<String> kBigLifts = [
  'Press de Banca',
  'Press Banca',
  'Bench Press',
  'Sentadilla',
  'Squat',
  'Peso Muerto',
  'Deadlift',
  'Press Militar',
  'Overhead Press',
  'OHP',
  'Dominadas',
  'Pull-ups',
  'Chin-ups',
  'Remo con Barra',
  'Barbell Row',
  'Bent Over Row',
];

/// Normalized big lift names for matching
const Map<String, String> kBigLiftNormalized = {
  'press de banca': 'Press de Banca',
  'press banca': 'Press de Banca',
  'bench press': 'Press de Banca',
  'flat bench': 'Press de Banca',
  'sentadilla': 'Sentadilla',
  'squat': 'Sentadilla',
  'back squat': 'Sentadilla',
  'peso muerto': 'Peso Muerto',
  'deadlift': 'Peso Muerto',
  'conventional deadlift': 'Peso Muerto',
  'press militar': 'Press Militar',
  'overhead press': 'Press Militar',
  'ohp': 'Press Militar',
  'military press': 'Press Militar',
  'dominadas': 'Dominadas',
  'pull-ups': 'Dominadas',
  'pullups': 'Dominadas',
  'chin-ups': 'Dominadas',
  'chinups': 'Dominadas',
  'remo con barra': 'Remo con Barra',
  'barbell row': 'Remo con Barra',
  'bent over row': 'Remo con Barra',
  'pendlay row': 'Remo con Barra',
};

/// Normalize exercise name to standard big lift name
String? normalizeBigLift(String exerciseName) {
  final lower = exerciseName.toLowerCase().trim();
  return kBigLiftNormalized[lower];
}

/// Check if exercise is a big lift
bool isBigLift(String exerciseName) {
  return normalizeBigLift(exerciseName) != null;
}
