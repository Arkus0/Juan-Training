import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../models/library_exercise.dart';
import 'exercise_library_service.dart';

/// Servicio para pre-cargar imágenes de ejercicios más usados
///
/// Características:
/// - Carga las imágenes top-N en memoria al iniciar
/// - Prioriza ejercicios favoritos y más usados
/// - Carga en segundo plano sin bloquear UI
/// - Respeta límites de memoria
class ImagePrecacheService {
  static final ImagePrecacheService instance = ImagePrecacheService._();
  ImagePrecacheService._();

  final _logger = Logger();

  /// Número máximo de imágenes a pre-cargar
  static const int _maxPrecacheCount = 50;

  /// Si ya se ejecutó el precache inicial
  bool _hasPrecached = false;

  /// IDs de ejercicios con imágenes pre-cargadas
  final Set<int> _precachedIds = {};

  /// Completer para saber cuando terminó el precache
  Completer<void>? _precacheCompleter;

  /// Verifica si ya se ejecutó el precache
  bool get hasPrecached => _hasPrecached;

  /// Obtiene los IDs de ejercicios pre-cargados
  Set<int> get precachedIds => Set.unmodifiable(_precachedIds);

  /// Inicia el precache de imágenes (llamar después de init de library)
  ///
  /// [context] - BuildContext necesario para precacheImage
  /// [priorityIds] - IDs de ejercicios a priorizar (ej: ejercicios en rutina activa)
  Future<void> precacheTopExercises(
    BuildContext context, {
    List<int>? priorityIds,
  }) async {
    if (_hasPrecached) {
      _logger.d('ImagePrecacheService: Already precached, skipping');
      return;
    }

    if (_precacheCompleter != null) {
      _logger.d('ImagePrecacheService: Precache in progress, waiting');
      await _precacheCompleter!.future;
      return;
    }

    _precacheCompleter = Completer<void>();

    try {
      _logger.i('ImagePrecacheService: Starting precache...');

      // Obtener lista de ejercicios a pre-cargar
      final exercisesToPrecache = _getExercisesToPrecache(priorityIds);

      if (exercisesToPrecache.isEmpty) {
        _logger.w('ImagePrecacheService: No exercises to precache');
        _hasPrecached = true;
        _precacheCompleter!.complete();
        return;
      }

      _logger.i(
          'ImagePrecacheService: Precaching ${exercisesToPrecache.length} images');

      // Pre-cargar en lotes para no saturar
      const batchSize = 10;
      int successCount = 0;

      for (var i = 0; i < exercisesToPrecache.length; i += batchSize) {
        if (!context.mounted) break;

        final end = (i + batchSize).clamp(0, exercisesToPrecache.length);
        final batch = exercisesToPrecache.sublist(i, end);

        // Cargar batch en paralelo
        final results = await Future.wait(
          batch.map((exercise) => _precacheExerciseImage(context, exercise)),
          eagerError: false,
        );

        successCount += results.where((r) => r).length;

        // Pequeña pausa entre batches para no bloquear UI
        await Future.delayed(const Duration(milliseconds: 50));
      }

      _hasPrecached = true;
      _logger.i(
          'ImagePrecacheService: Precached $successCount/${exercisesToPrecache.length} images');

      _precacheCompleter!.complete();
    } catch (e, s) {
      _logger.e('ImagePrecacheService: Error during precache',
          error: e, stackTrace: s);
      _precacheCompleter!.completeError(e);
    } finally {
      _precacheCompleter = null;
    }
  }

  /// Obtiene la lista de ejercicios a pre-cargar, ordenados por prioridad
  List<LibraryExercise> _getExercisesToPrecache(List<int>? priorityIds) {
    final library = ExerciseLibraryService.instance;
    final allExercises = library.exercises;

    if (allExercises.isEmpty) return [];

    // Crear set de prioridad
    final prioritySet = priorityIds?.toSet() ?? {};

    // Separar en categorías
    final prioritized = <LibraryExercise>[];
    final favorites = <LibraryExercise>[];
    final others = <LibraryExercise>[];

    for (final exercise in allExercises) {
      if (prioritySet.contains(exercise.id)) {
        prioritized.add(exercise);
      } else if (exercise.isFavorite) {
        favorites.add(exercise);
      } else {
        others.add(exercise);
      }
    }

    // Combinar en orden de prioridad
    final result = <LibraryExercise>[
      ...prioritized,
      ...favorites,
      ...others,
    ];

    // Limitar al máximo
    return result.take(_maxPrecacheCount).toList();
  }

  /// Pre-carga la imagen de un ejercicio específico
  Future<bool> _precacheExerciseImage(
    BuildContext context,
    LibraryExercise exercise,
  ) async {
    if (!context.mounted) return false;

    try {
      // Construir path de la imagen
      final assetPath = 'assets/img/ejercicios/${exercise.id}.png';
      final imageProvider = AssetImage(assetPath);

      await precacheImage(imageProvider, context);
      _precachedIds.add(exercise.id);
      return true;
    } catch (e) {
      // Imagen no existe o error de carga - no es crítico
      return false;
    }
  }

  /// Pre-carga imagen de un ejercicio específico (para uso on-demand)
  Future<void> precacheExercise(BuildContext context, int exerciseId) async {
    if (_precachedIds.contains(exerciseId)) return;
    if (!context.mounted) return;

    try {
      final assetPath = 'assets/img/ejercicios/$exerciseId.png';
      final imageProvider = AssetImage(assetPath);
      await precacheImage(imageProvider, context);
      _precachedIds.add(exerciseId);
    } catch (e) {
      // Ignorar errores de precache individual
    }
  }

  /// Pre-carga imágenes de una lista de ejercicios (ej: al abrir rutina)
  Future<void> precacheExercises(
      BuildContext context, List<int> exerciseIds) async {
    if (!context.mounted) return;

    for (final id in exerciseIds) {
      if (!context.mounted) break;
      await precacheExercise(context, id);
    }
  }

  /// Verifica si una imagen está pre-cargada
  bool isImagePrecached(int exerciseId) => _precachedIds.contains(exerciseId);

  /// Limpia el cache (llamar en low memory situations)
  void clearCache() {
    _precachedIds.clear();
    _hasPrecached = false;
    PaintingBinding.instance.imageCache.clear();
    _logger.i('ImagePrecacheService: Cache cleared');
  }

  /// Obtiene estadísticas del cache
  Map<String, dynamic> get stats => {
        'precachedCount': _precachedIds.length,
        'maxCount': _maxPrecacheCount,
        'hasPrecached': _hasPrecached,
      };
}

/// Extension para fácil acceso desde BuildContext
extension ImagePrecacheExtension on BuildContext {
  /// Pre-carga imágenes de ejercicios top
  Future<void> precacheTopExerciseImages({List<int>? priorityIds}) {
    return ImagePrecacheService.instance.precacheTopExercises(
      this,
      priorityIds: priorityIds,
    );
  }

  /// Pre-carga imagen de un ejercicio específico
  Future<void> precacheExerciseImage(int exerciseId) {
    return ImagePrecacheService.instance.precacheExercise(this, exerciseId);
  }
}
