import 'exercise_parsing_service.dart';

/// Resultado de validación
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  factory ValidationResult.valid() => const ValidationResult(isValid: true);

  factory ValidationResult.invalid(List<String> errors,
          [List<String> warnings = const [],]) =>
      ValidationResult(isValid: false, errors: errors, warnings: warnings);

  @override
  String toString() =>
      'ValidationResult(valid: $isValid, errors: $errors, warnings: $warnings)';
}

/// Configuración de límites de validación
class ValidationConfig {
  final int minSeries;
  final int maxSeries;
  final int minReps;
  final int maxReps;
  final double minWeight;
  final double maxWeight;
  final int maxRepsRange; // Diferencia máxima entre min y max reps

  const ValidationConfig({
    this.minSeries = 1,
    this.maxSeries = 20,
    this.minReps = 1,
    this.maxReps = 100,
    this.minWeight = 0.0,
    this.maxWeight = 500.0,
    this.maxRepsRange = 10,
  });

  /// Configuración por defecto para entrenamientos normales
  static const normal = ValidationConfig();

  /// Configuración más permisiva (para usuarios avanzados)
  static const permissive = ValidationConfig(
    maxSeries: 30,
    maxReps: 200,
    maxWeight: 800.0,
    maxRepsRange: 20,
  );
}

/// Servicio de validación de ejercicios parseados.
///
/// Valida que los valores extraídos (series, reps, peso) estén dentro
/// de rangos razonables para evitar errores de OCR/voz.
///
/// Ejemplo de uso:
/// ```dart
/// final result = ExerciseValidationService.instance.validate(parsedExercise);
/// if (!result.isValid) {
///   print('Errores: ${result.errors}');
/// }
/// ```
class ExerciseValidationService {
  static final ExerciseValidationService instance =
      ExerciseValidationService._();
  ExerciseValidationService._();

  ValidationConfig _config = ValidationConfig.normal;

  /// Actualiza la configuración de validación
  void configure(ValidationConfig config) {
    _config = config;
  }

  /// Valida un ejercicio parseado
  ValidationResult validate(ParsedExercise exercise) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validar series
    if (exercise.series < _config.minSeries) {
      errors.add(
          'Series debe ser al menos ${_config.minSeries} (recibido: ${exercise.series})',);
    } else if (exercise.series > _config.maxSeries) {
      errors.add(
          'Series no puede ser mayor a ${_config.maxSeries} (recibido: ${exercise.series})',);
    }

    // Validar reps
    final minReps = exercise.minReps;
    final maxReps = exercise.maxReps;

    if (minReps < _config.minReps) {
      errors.add(
          'Reps debe ser al menos ${_config.minReps} (recibido: $minReps)',);
    }
    if (maxReps > _config.maxReps) {
      errors.add(
          'Reps no puede ser mayor a ${_config.maxReps} (recibido: $maxReps)',);
    }
    if (maxReps < minReps) {
      errors.add(
          'Rango de reps inválido: $minReps-$maxReps (máximo menor que mínimo)',);
    }
    if (maxReps - minReps > _config.maxRepsRange) {
      warnings.add(
          'Rango de reps muy amplio: $minReps-$maxReps (diferencia > ${_config.maxRepsRange})',);
    }

    // Validar peso
    if (exercise.weight != null) {
      if (exercise.weight! < _config.minWeight) {
        errors
            .add('Peso no puede ser negativo (recibido: ${exercise.weight}kg)');
      }
      if (exercise.weight! > _config.maxWeight) {
        errors.add(
            'Peso excede el máximo permitido de ${_config.maxWeight}kg (recibido: ${exercise.weight}kg)',);
      }
    }

    // Validar que haya match de ejercicio
    if (exercise.matchedId == null) {
      warnings.add('No se encontró ejercicio coincidente en la biblioteca');
    }

    // Validar confianza del match
    if (exercise.matchedId != null && exercise.confidence < 0.5) {
      warnings.add(
          'Confianza del match baja (${(exercise.confidence * 100).toInt()}%)',);
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Valida múltiples ejercicios
  List<ValidationResult> validateAll(List<ParsedExercise> exercises) {
    return exercises.map(validate).toList();
  }

  /// Valida y filtra solo los ejercicios válidos
  List<ParsedExercise> filterValid(List<ParsedExercise> exercises) {
    return exercises
        .where((e) => validate(e).isValid && e.matchedId != null)
        .toList();
  }

  /// Intenta corregir valores fuera de rango a valores razonables
  ParsedExercise autoCorrect(ParsedExercise exercise) {
    var corrected = exercise;

    // Corregir series
    if (exercise.series < _config.minSeries) {
      corrected = corrected.copyWith(series: _config.minSeries);
    } else if (exercise.series > _config.maxSeries) {
      // Probablemente un error de parseo, usar default
      corrected = corrected.copyWith(series: 3);
    }

    // Corregir reps si es un número muy alto (probablemente error de parseo)
    final minReps = exercise.minReps;
    final maxReps = exercise.maxReps;

    if (minReps > _config.maxReps || maxReps > _config.maxReps) {
      // Probablemente se confundió peso con reps
      corrected = corrected.copyWith(repsRange: '10');
    }

    // Corregir peso absurdo
    if (exercise.weight != null && exercise.weight! > _config.maxWeight) {
      // Probablemente error de parseo, remover peso
      corrected = corrected.copyWith();
    }

    return corrected;
  }

  /// Detecta si los valores parecen ser un error de parseo común
  /// (ej: confundir peso con reps)
  List<String> detectPotentialParseErrors(ParsedExercise exercise) {
    final issues = <String>[];

    // Si reps es un múltiplo de 5 mayor a 50, probablemente es peso
    if (exercise.minReps > 50 && exercise.minReps % 5 == 0) {
      issues.add('Las reps (${exercise.minReps}) parecen ser un peso en kg');
    }

    // Si peso es menor a 10 y no es decimal, podría ser reps
    if (exercise.weight != null &&
        exercise.weight! < 10 &&
        exercise.weight! == exercise.weight!.roundToDouble()) {
      issues.add('El peso (${exercise.weight}kg) podría ser número de reps');
    }

    // Si series es mayor a 10, probablemente es reps
    if (exercise.series > 10) {
      issues
          .add('Las series (${exercise.series}) parecen ser un número de reps');
    }

    return issues;
  }
}
