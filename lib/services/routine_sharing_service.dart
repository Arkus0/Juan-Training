import 'dart:convert';

import 'package:fuzzy/fuzzy.dart';
import 'package:share_plus/share_plus.dart';

import '../models/ejercicio_en_rutina.dart';
import '../models/library_exercise.dart';
import '../models/rutina.dart';
import 'exercise_library_service.dart';

/// Service for exporting and importing routines as JSON.
class RoutineSharingService {
  static final RoutineSharingService instance = RoutineSharingService._();
  RoutineSharingService._();

  /// Exports a routine to a formatted JSON string.
  String exportRoutineToJson(Rutina rutina) {
    return const JsonEncoder.withIndent('  ').convert(rutina.toJson());
  }

  /// Shares a routine using the system share dialog.
  Future<void> shareRoutine(Rutina rutina) async {
    final jsonStr = exportRoutineToJson(rutina);
    await SharePlus.instance.share(
      ShareParams(
        text: jsonStr,
        subject: 'Juan Training - ${rutina.nombre}',
      ),
    );
  }

  /// Parses a JSON string into a RoutineImportResult.
  /// Returns error message if parsing fails.
  RoutineImportResult parseRoutineJson(String jsonStr) {
    try {
      // Clean up the JSON string (remove potential BOM, trim whitespace)
      final cleanJson = jsonStr.trim();
      if (cleanJson.isEmpty) {
        return RoutineImportResult.error('El JSON está vacío');
      }

      // Attempt to parse JSON
      final dynamic decoded = jsonDecode(cleanJson);
      if (decoded is! Map<String, dynamic>) {
        return RoutineImportResult.error(
            'Formato JSON inválido: se esperaba un objeto',);
      }

      // Validate structure
      final validationError = Rutina.validateJson(decoded);
      if (validationError != null) {
        return RoutineImportResult.error(validationError);
      }

      // Parse the routine
      final rutina = Rutina.fromJson(decoded);

      // Match exercises with library
      final matchedRutina = _matchExercisesWithLibrary(rutina);

      return RoutineImportResult.success(matchedRutina);
    } on FormatException catch (e) {
      return RoutineImportResult.error('Error de formato JSON: ${e.message}');
    } catch (e) {
      return RoutineImportResult.error('Error al parsear: ${e.toString()}');
    }
  }

  /// Matches imported exercises with the local exercise library using fuzzy matching.
  /// Updates exercise metadata (muscles, equipment, images) from library matches.
  Rutina _matchExercisesWithLibrary(Rutina rutina) {
    final library = ExerciseLibraryService.instance.exercises;
    if (library.isEmpty) return rutina;

    // Create fuzzy matcher for exercise names
    final fuzzy = Fuzzy<LibraryExercise>(
      library,
      options: FuzzyOptions(
        keys: [
          WeightedKey(
            name: 'name',
            getter: (ex) => ex.name,
            weight: 1.0,
          ),
        ],
        threshold: 0.4, // Allow moderate fuzzy matching
      ),
    );

    final updatedDias = rutina.dias.map((dia) {
      final updatedEjercicios = dia.ejercicios.map((ejercicio) {
        // Try exact match first
        var match = _findExactMatch(library, ejercicio.nombre);

        // If no exact match, try fuzzy match
        if (match == null) {
          final results = fuzzy.search(ejercicio.nombre);
          if (results.isNotEmpty && results.first.score < 0.4) {
            match = results.first.item;
          }
        }

        if (match != null) {
          // Update exercise with library data while preserving routine-specific data
          return EjercicioEnRutina(
            id: match.id.toString(),
            nombre: match.name, // Use library name for consistency
            descripcion: match.description ?? ejercicio.descripcion,
            musculosPrincipales: match.muscles.isNotEmpty
                ? match.muscles
                : ejercicio.musculosPrincipales,
            musculosSecundarios: match.secondaryMuscles.isNotEmpty
                ? match.secondaryMuscles
                : ejercicio.musculosSecundarios,
            equipo:
                match.equipment.isNotEmpty ? match.equipment : ejercicio.equipo,
            localImagePath: match.localImagePath,
            // Preserve routine-specific data
            series: ejercicio.series,
            repsRange: ejercicio.repsRange,
            descansoSugerido: ejercicio.descansoSugerido,
            notas: ejercicio.notas,
            instanceId: ejercicio.instanceId, // Keep new instance ID
            supersetId: ejercicio.supersetId, // Keep superset linkage
            progressionType: ejercicio.progressionType,
            weightIncrement: ejercicio.weightIncrement,
            targetRpe: ejercicio.targetRpe,
          );
        }

        // No match found - keep original exercise data
        return ejercicio;
      }).toList();

      return dia.copyWith(ejercicios: updatedEjercicios);
    }).toList();

    return rutina.copyWith(dias: updatedDias);
  }

  /// Finds an exact match for an exercise name in the library (case-insensitive).
  LibraryExercise? _findExactMatch(List<LibraryExercise> library, String name) {
    final lowerName = name.toLowerCase().trim();
    for (final ex in library) {
      if (ex.name.toLowerCase().trim() == lowerName) {
        return ex;
      }
    }
    return null;
  }

  /// Gets statistics about an imported routine for preview.
  RoutineImportStats getImportStats(Rutina rutina) {
    var totalExercises = 0;
    var totalSeries = 0;
    final muscleGroups = <String>{};
    var supersetsCount = 0;
    final supersetIds = <String>{};

    for (final dia in rutina.dias) {
      for (final ejercicio in dia.ejercicios) {
        totalExercises++;
        totalSeries += ejercicio.series;
        muscleGroups.addAll(ejercicio.musculosPrincipales);
        if (ejercicio.supersetId != null &&
            !supersetIds.contains(ejercicio.supersetId)) {
          supersetIds.add(ejercicio.supersetId!);
          supersetsCount++;
        }
      }
    }

    return RoutineImportStats(
      daysCount: rutina.dias.length,
      exercisesCount: totalExercises,
      totalSeries: totalSeries,
      muscleGroups: muscleGroups.toList(),
      supersetsCount: supersetsCount,
    );
  }
}

/// Result of a routine import attempt.
class RoutineImportResult {
  final Rutina? rutina;
  final String? error;
  final bool isSuccess;

  RoutineImportResult._({
    this.rutina,
    this.error,
    required this.isSuccess,
  });

  factory RoutineImportResult.success(Rutina rutina) {
    return RoutineImportResult._(
      rutina: rutina,
      isSuccess: true,
    );
  }

  factory RoutineImportResult.error(String message) {
    return RoutineImportResult._(
      error: message,
      isSuccess: false,
    );
  }
}

/// Statistics about an imported routine.
class RoutineImportStats {
  final int daysCount;
  final int exercisesCount;
  final int totalSeries;
  final List<String> muscleGroups;
  final int supersetsCount;

  const RoutineImportStats({
    required this.daysCount,
    required this.exercisesCount,
    required this.totalSeries,
    required this.muscleGroups,
    required this.supersetsCount,
  });
}
