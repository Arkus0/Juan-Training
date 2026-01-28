import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/library_exercise.dart';

// --- Top-Level Constants (Optimized for Isolate Access) ---

const Map<int, String> _categoryMap = {
  10: 'Abdominales',
  8: 'Brazos',
  12: 'Espalda',
  14: 'Gemelos',
  15: 'Cardio',
  11: 'Pecho',
  9: 'Piernas',
  13: 'Hombros',
};

const Map<int, String> _equipmentMap = {
  1: 'Barra',
  8: 'Banco',
  3: 'Mancuerna',
  4: 'Esterilla',
  9: 'Banco inclinado',
  10: 'Pesa rusa',
  6: 'Barra dominadas',
  11: 'Banda elástica',
  2: 'Barra Z',
  5: 'Pelota suiza',
  7: 'Peso corporal',
};

const Map<int, String> _muscleMap = {
  1: 'Bíceps braquial',
  2: 'Deltoides anterior',
  3: 'Serrato anterior',
  4: 'Pectoral mayor',
  5: 'Tríceps braquial',
  6: 'Recto abdominal',
  7: 'Gemelos',
  8: 'Glúteo mayor',
  9: 'Trapecio',
  10: 'Cuádriceps',
  11: 'Bíceps femoral',
  12: 'Dorsal ancho',
  13: 'Braquial',
  14: 'Oblicuos',
  15: 'Sóleo',
};

// --- Top-Level Isolate Function ---

/// Decodes JSON and ensures strict Map typing in a separate thread.
/// Returns a map with 'results' (list of maps) and 'next' (String? url).
Map<String, dynamic> _decodeJsonBackground(Uint8List responseBytes) {
  // 1. Decode UTF-8
  final jsonStr = utf8.decode(responseBytes);

  // 2. Decode JSON
  final Map<String, dynamic> data = jsonDecode(jsonStr);

  // 3. Strict Type Mapping
  // Ensure that each item in 'results' is explicitly cast to Map<String, dynamic>
  // This prevents 'Map<dynamic, dynamic>' issues that cause key access failures.
  final safeResults = (data['results'] as List)
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  return {
    'results': safeResults,
    'next': data['next'],
  };
}

/// Parses the JSON content into a List of LibraryExercise objects in a separate isolate.
List<LibraryExercise> _parseLibraryExercises(String content) {
  final List<dynamic> jsonList = jsonDecode(content);
  return jsonList.map((e) => LibraryExercise.fromJson(e)).toList();
}

// --- Service Class ---

class ExerciseLibraryService {
  static final ExerciseLibraryService instance = ExerciseLibraryService._();
  ExerciseLibraryService._();

  final _logger = Logger();
  List<LibraryExercise> _exercises = [];

  // Sentinel: Connectivity & Sync State
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;

  // Notifier for real-time updates
  final ValueNotifier<List<LibraryExercise>> exercisesNotifier =
      ValueNotifier([]);

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // --- Fallback Data (Offline/Error) ---
  static final List<LibraryExercise> _fallbackExercises = [
    LibraryExercise(
      id: 1001,
      name: 'Press de Banca',
      muscleGroup: 'Pecho',
      equipment: 'Barra',
      description: 'Press básico de pecho',
      muscles: ['Pectoral mayor'],
      secondaryMuscles: ['Tríceps braquial', 'Deltoides anterior'],
    ),
    LibraryExercise(
      id: 1002,
      name: 'Sentadilla',
      muscleGroup: 'Piernas',
      equipment: 'Barra',
      description: 'Sentadilla clásica',
      muscles: ['Cuádriceps'],
      secondaryMuscles: ['Glúteo mayor', 'Gemelos'],
    ),
    LibraryExercise(
      id: 1003,
      name: 'Peso Muerto',
      muscleGroup: 'Espalda',
      equipment: 'Barra',
      description: 'Peso muerto convencional',
      muscles: ['Erectores', 'Glúteo mayor'],
      secondaryMuscles: ['Isquios', 'Trapecio'],
    ),
    LibraryExercise(
      id: 1004,
      name: 'Dominadas',
      muscleGroup: 'Espalda',
      equipment: 'Barra dominadas',
      description: 'Pull-ups',
      muscles: ['Dorsal ancho'],
      secondaryMuscles: ['Bíceps braquial'],
    ),
    LibraryExercise(
      id: 1005,
      name: 'Press Militar',
      muscleGroup: 'Hombros',
      equipment: 'Barra',
      description: 'Press de hombros de pie',
      muscles: ['Deltoides anterior'],
      secondaryMuscles: ['Tríceps braquial'],
    ),
  ];

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/exercises.json');
  }

  /// Initialize the service: Load local data and start Sentinel listener
  Future<void> init() async {
    await _sanitizeCache();
    // If a bundled exercises JSON exists in assets, copy it to app documents
    // so the rest of the service uses the same local-file-based flow.
    try {
      final bundled = await rootBundle.loadString('assets/data/exercises.json');
      if (bundled.isNotEmpty) {
        final file = await _localFile;
        await file.writeAsString(bundled);
        _logger.i('Copied bundled exercises.json to local storage.');
      }
    } catch (_) {
      // No bundled file: ignore and proceed to load from disk or fallback.
    }

    await loadLibrary();
    _setupConnectivityListener();
    _checkAndSync();
  }

  /// Sanitizes cache by removing corrupt files (0 bytes) to prevent crashes.
  Future<void> _sanitizeCache() async {
    try {
      if (kIsWeb) return;

      final directory = await getApplicationDocumentsDirectory();

      // 1. Sanitize Images
      final imagesDir = Directory('${directory.path}/ejercicios_images');
      if (await imagesDir.exists()) {
        final files = imagesDir.listSync();
        for (final entity in files) {
          if (entity is File) {
            final length = await entity.length();
            if (length == 0) {
              _logger.w('Deleting 0-byte image file: ${entity.path}');
              await entity.delete();
            }
          }
        }
      }

      // 2. Sanitize JSON
      final jsonFile = File('${directory.path}/exercises.json');
      if (await jsonFile.exists()) {
        if (await jsonFile.length() == 0) {
          _logger.w('Deleting 0-byte exercises.json file.');
          await jsonFile.delete();
        }
      }
    } catch (e, s) {
      _logger.e('Error during cache sanitization', error: e, stackTrace: s);
    }
  }

  void _setupConnectivityListener() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (isOnline) {
        _logger.d('Sentinel: Connection restored. Checking sync status...');
        _checkAndSync();
      }
    });
  }

  Future<void> _checkAndSync() async {
    if (_isSyncing) return;

    final prefs = await SharedPreferences.getInstance();
    final initialSyncCompleted =
        prefs.getBool('initial_library_sync_completed') ?? false;

    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline =
        connectivityResult.any((r) => r != ConnectivityResult.none);

    if (!isOnline) {
      _logger.d('Sentinel: Offline. Skipping sync check.');
      return;
    }

    if (!initialSyncCompleted || await shouldSync()) {
      _logger.i('Sentinel: Sync required. Starting sync...');
      await syncLibrary();
    }
  }

  Future<void> loadLibrary() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          // Offload JSON decoding and object creation to background isolate
          _exercises = await compute(_parseLibraryExercises, content);
        }
      }

      if (_exercises.isEmpty) {
        _logger.i('Library empty or not found, loading fallback data...');
        _exercises = List.from(_fallbackExercises);
      }

      _updateNotifier();
      _isLoaded = true;
    } catch (e, s) {
      _logger.e('Error loading library from disk', error: e, stackTrace: s);

      // Critical Fix: Delete corrupt file to force clean sync next time
      try {
        final file = await _localFile;
        if (await file.exists()) {
          _logger.w('Deleting corrupt exercises.json to prevent crash loop.');
          await file.delete();
        }
      } catch (deleteError) {
        _logger.e('Failed to delete corrupt exercises.json',
            error: deleteError,);
      }

      if (_exercises.isEmpty) {
        _exercises = List.from(_fallbackExercises);
        _updateNotifier();
      }
    }
  }

  Future<void> _saveToFile() async {
    try {
      final file = await _localFile;
      final content = jsonEncode(_exercises.map((e) => e.toJson()).toList());
      await file.writeAsString(content);
    } catch (e, s) {
      _logger.e('Error saving library to file', error: e, stackTrace: s);
    }
  }

  void _updateNotifier() {
    exercisesNotifier.value = List.from(_exercises);
  }

  /// Checks if a given name is valid for the exercise library.
  bool _isValidName(String? name) {
    if (name == null || name.trim().isEmpty) return false;
    final lower = name.trim().toLowerCase();
    // Only reject a generic English placeholder 'exercise'.
    // Allow 'Ejercicio sin nombre' because many API entries may lack localized names;
    // we'll keep them to avoid discarding the whole library.
    if (lower == 'exercise') return false;
    return true;
  }

  /// returns true if sync was successful, false otherwise.
  ///
  /// PROTECCIÓN CRÍTICA DE EJERCICIOS CURADOS:
  /// Si la biblioteca contiene ejercicios curados (isCurated = true),
  /// la sincronización está DESHABILITADA para proteger la base de datos.
  /// Solo se descargarán imágenes para ejercicios existentes.
  Future<bool> syncLibrary() async {
    if (_isSyncing) {
      _logger.w('Sync already in progress. Skipping.');
      return false;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // CORTAFUEGOS: Protección de ejercicios curados
    // ═══════════════════════════════════════════════════════════════════════════
    final hasCuratedExercises = _exercises.any((e) => e.isCurated);
    if (hasCuratedExercises) {
      _logger.i('🛡️ CURATED LIBRARY PROTECTION: Biblioteca curada detectada. '
          'Sync con API deshabilitada para proteger ${_exercises.where((e) => e.isCurated).length} ejercicios curados.');

      // Solo descargar imágenes para ejercicios existentes, NO sincronizar con API
      if (!kIsWeb) {
        await _downloadImagesForCuratedLibrary();
      }

      return true; // No es un error, es comportamiento intencionado
    }
    // ═══════════════════════════════════════════════════════════════════════════

    _isSyncing = true;
    _logger.i('Starting exercise library sync...');

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.every((r) => r == ConnectivityResult.none)) {
      _logger.w('Skipping sync: No internet connection.');
      _isSyncing = false;
      return false;
    }

    try {
      String? imagesDirPath;
      if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();
        final imagesDir = Directory('${directory.path}/ejercicios_images');
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        imagesDirPath = imagesDir.path;
      }

      // Initialize map with existing exercises
      final exercisesMap = <int, LibraryExercise>{
        for (final ex in _exercises) ex.id: ex,
      };
      _logger.d(
          'Initialized sync with ${exercisesMap.length} existing exercises.',);

      // --- PARALLEL FETCH ---
      // Fetch both languages concurrently to speed up the process.
      final results = await Future.wait([
        _fetchLanguageExercises(2), // English (Primary)
        _fetchLanguageExercises(4), // Spanish (Secondary)
      ]);

      final englishExercises = results[0];
      final spanishExercises = results[1];

      // --- SEQUENTIAL MERGE ---
      // Apply merges in strict order to ensure Spanish (Language 4) overrides English (Language 2).
      _mergeExercises(exercisesMap, englishExercises, isPrimary: true);
      _mergeExercises(exercisesMap, spanishExercises, isPrimary: false);

      _logger.i(
          'Total exercises in map before final filtering: ${exercisesMap.length}',);

      // Update internal list from the map, filtering for validity
      final originalCount = exercisesMap.length;
      _exercises =
          exercisesMap.values.where((e) => _isValidName(e.name)).toList();

      if (exercisesMap.isNotEmpty && _exercises.isEmpty) {
        _logger.w(
          'CRITICAL WARNING: All $originalCount exercises were discarded after name validation.',
          error: 'Example invalid name: "${exercisesMap.values.first.name}"',
        );
      }
      _logger.i(
        'Total unique, valid exercises after merge: ${_exercises.length}',
      );

      // Phase 3: Parallel Image Downloads
      if (!kIsWeb && imagesDirPath != null) {
        final pendingDownloads = _exercises
            .where(
              (e) =>
                  e.imageUrls.isNotEmpty &&
                  (e.localImagePath == null ||
                      !File(e.localImagePath!).existsSync()),
            )
            .toList();

        _logger.i(
            'Found ${pendingDownloads.length} exercises with images to download.',);
        if (pendingDownloads.isNotEmpty) {
          // Log a few sample URLs to help debugging network/image issues
          final sample = pendingDownloads
              .take(5)
              .map((e) =>
                  e.imageUrls.isNotEmpty ? e.imageUrls.first : '(no-url)',)
              .toList();
          _logger.d('Sample image URLs: $sample');
          await _processImageDownloads(
            pendingDownloads,
            imagesDirPath,
            exercisesMap,
          );
        }
      }

      await _saveToFile();
      await _updateLastSyncDate();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('initial_library_sync_completed', true);
      _logger.i('✅ Sync completed successfully.');

      _updateNotifier();
      return true;
    } catch (e, stacktrace) {
      _logger.e('❌ CRITICAL SYNC ERROR', error: e, stackTrace: stacktrace);
      if (_exercises.isEmpty) {
        _logger
            .w('Sync failed and library is empty. Loading fallback exercises.');
        _exercises = List.from(_fallbackExercises);
        _updateNotifier();
      }
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Descarga imágenes solo para ejercicios existentes en la biblioteca curada.
  /// NO sincroniza con API, solo descarga imágenes faltantes.
  Future<void> _downloadImagesForCuratedLibrary() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.every((r) => r == ConnectivityResult.none)) {
        _logger.d('Offline - skipping image downloads for curated library.');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/ejercicios_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final pendingDownloads = _exercises
          .where(
            (e) =>
                e.imageUrls.isNotEmpty &&
                (e.localImagePath == null ||
                    !File(e.localImagePath!).existsSync()),
          )
          .toList();

      if (pendingDownloads.isEmpty) {
        _logger.d('No images to download for curated library.');
        return;
      }

      _logger.i(
          '🖼️ Downloading ${pendingDownloads.length} images for curated library...',);

      final exercisesMap = {for (final ex in _exercises) ex.id: ex};
      await _processImageDownloads(
          pendingDownloads, imagesDir.path, exercisesMap,);

      _logger.i('✅ Image download for curated library completed.');
    } catch (e, s) {
      _logger.w('Error downloading images for curated library',
          error: e, stackTrace: s,);
    }
  }

  LibraryExercise? _parseExerciseFromApi(Map<String, dynamic> item) {
    if (item['name'] == null) {
      _logger.e(
        'CRITICAL: Found exercise with NULL name. Item keys: ${item.keys.toList()}',
      );
      return null;
    }

    // Helper to extract nested IDs safely
    final int catId = (item['category'] is Map)
        ? item['category']['id']
        : item['category'] ?? 0;

    var equipId = 7; // Default: Body weight
    if (item['equipment'] is List && (item['equipment'] as List).isNotEmpty) {
      final firstEq = (item['equipment'] as List)[0];
      equipId = (firstEq is Map) ? firstEq['id'] : firstEq;
    }

    // Map IDs to Names using Top-Level constants
    final categoryName = _categoryMap[catId] ?? 'Otros';
    final equipmentName = _equipmentMap[equipId] ?? 'Otro';

    List<String> mapMuscles(String key) {
      if (item[key] is List) {
        return (item[key] as List).map((m) {
          final int mId = (m is Map) ? m['id'] : m as int;
          return _muscleMap[mId] ?? 'Músculo $mId';
        }).toList();
      }
      return [];
    }

    return LibraryExercise.fromApi(
      item,
      categoryName,
      equipmentName,
      mapMuscles('muscles'),
      mapMuscles('muscles_secondary'),
    );
  }

  Future<List<LibraryExercise>> _fetchLanguageExercises(int language) async {
    _logger.i('Phase: Fetching language $language...');
    final fetchedExercises = <LibraryExercise>[];
    String? url =
        'https://wger.de/api/v2/exerciseinfo/?language=$language&limit=200';
    var fetchedCount = 0;

    while (url != null && url.isNotEmpty) {
      try {
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 45));
        if (response.statusCode != 200) {
          _logger.e(
            'API Error (lang $language): ${response.statusCode}, Body: ${response.body}',
          );
          break;
        }

        // --- ISOLATE IMPLEMENTATION ---
        final result = await compute(_decodeJsonBackground, response.bodyBytes);

        final rawExercises = result['results'] as List<Map<String, dynamic>>;
        final nextUrl = result['next'] as String?;

        fetchedCount += rawExercises.length;

        for (final item in rawExercises) {
          final exercise = _parseExerciseFromApi(item);
          if (exercise != null) {
            fetchedExercises.add(exercise);
          }
        }
        url = nextUrl;
      } catch (e, s) {
        _logger.e(
          'Failed to fetch page for language $language',
          error: e,
          stackTrace: s,
        );
        break;
      }
    }
    _logger.i('Language $language: Fetched $fetchedCount raw items.');
    return fetchedExercises;
  }

  void _mergeExercises(
    Map<int, LibraryExercise> exercisesMap,
    List<LibraryExercise> newExercises, {
    required bool isPrimary,
  }) {
    var addedCount = 0;
    var mergedCount = 0;
    var protectedCount = 0;

    for (final exercise in newExercises) {
      final existing = exercisesMap[exercise.id];

      if (existing != null) {
        // ═══════════════════════════════════════════════════════════════════════
        // PROTECCIÓN: Ejercicios curados NO se sobrescriben
        // ═══════════════════════════════════════════════════════════════════════
        if (existing.isCurated) {
          protectedCount++;
          // Solo permitir actualizar imageUrls y localImagePath de ejercicios curados
          final uniqueImages = <String>{};
          uniqueImages.addAll(existing.imageUrls);
          uniqueImages.addAll(exercise.imageUrls);

          if (uniqueImages.length > existing.imageUrls.length) {
            // Hay nuevas imágenes - actualizar solo eso
            exercisesMap[exercise.id] = existing.copyWith(
              imageUrls: uniqueImages.toList(),
            );
          }
          continue; // NO sobrescribir otros campos
        }
        // ═══════════════════════════════════════════════════════════════════════

        mergedCount++;
        // --- MERGE LOGIC ---
        // If primary (English), we overwrite (since it comes first in our flow).
        // When processing Lang 4 (Spanish - Secondary):
        // newName should use Lang 4 name (exercise.name) ONLY if it is valid.
        // If Lang 4 name is invalid ("Exercise", "Ejercicio sin nombre"), we keep existing (English).

        final shouldUseNewName = isPrimary || _isValidName(exercise.name);
        final newName = shouldUseNewName ? exercise.name : existing.name;

        // Merge and Deduplicate Images
        final uniqueImages = <String>{};
        uniqueImages.addAll(existing.imageUrls);
        uniqueImages.addAll(exercise.imageUrls);

        exercisesMap[exercise.id] = LibraryExercise(
          id: existing.id,
          name: newName,
          muscleGroup: exercise.muscleGroup,
          equipment: exercise.equipment,
          description: exercise.description?.isNotEmpty == true
              ? exercise.description
              : existing.description,
          license: exercise.license ?? existing.license,
          imageUrls: uniqueImages.toList(),
          localImagePath:
              existing.localImagePath, // Preserve existing local path
          muscles:
              exercise.muscles.isNotEmpty ? exercise.muscles : existing.muscles,
          secondaryMuscles: exercise.secondaryMuscles.isNotEmpty
              ? exercise.secondaryMuscles
              : existing.secondaryMuscles,
        );
      } else {
        addedCount++;
        // --- ADD NEW EXERCISE ---
        // Ejercicios nuevos de la API NO son curados
        exercisesMap[exercise.id] = exercise.copyWith(isCurated: false);
      }
    }
    _logger.i(
      'Merge (isPrimary=$isPrimary): Added $addedCount new, Merged $mergedCount, Protected $protectedCount curated.',
    );
  }

  Future<void> _processImageDownloads(
    List<LibraryExercise> items,
    String dirPath,
    Map<int, LibraryExercise> map,
  ) async {
    const batchSize = 10;
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);

      await Future.wait(
        batch.map((exercise) async {
          for (final imageUrl in exercise.imageUrls) {
            final localPath =
                await _downloadImage(imageUrl, exercise.id.toString(), dirPath);
            if (localPath != null) {
              // Update the map; this will be persisted later.
              map[exercise.id]?.localImagePath = localPath;
              break; // Stop after one successful download for this exercise
            } else {
              // Ensure it is null if failed (though it should be null by default if not set)
              // If it was previously set but validation failed, we might want to clear it?
              // But here we are iterating *pendingDownloads* which means localImagePath was null or missing.
              // So we don't need to explicitly set null.
            }
          }
        }),
      );
    }
    // Persist progress after all batches to reduce I/O
    await _saveToFile();
  }

  Future<String?> _downloadImage(String url, String id, String dirPath) async {
    // Correct extension handling based on URL
    final extension = url.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final filePath = '$dirPath/$id.$extension';
    final file = File(filePath);

    try {
      // Validate existing file
      if (await file.exists()) {
        if (await file.length() > 0) {
          return filePath; // Valid existing file
        } else {
          _logger.w('Found 0-byte image file for $id, deleting and retrying.');
          await file.delete();
        }
      }

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));

      // Validate Response
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        await file.writeAsBytes(response.bodyBytes);

        // Double-check file integrity
        if (await file.length() > 0) {
          _logger.d('Downloaded image: $filePath');
          return filePath;
        } else {
          _logger.e('File write failed (0 bytes) for $filePath');
          if (await file.exists()) await file.delete();
          return null;
        }
      } else {
        _logger.w(
            'Failed to download image $url: status ${response.statusCode}, bytes: ${response.bodyBytes.length}',);
        return null;
      }
    } catch (e) {
      _logger.w('Error downloading image for $id from $url', error: e);
      // Clean up potentially corrupted file
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (_) {}
      }
      return null;
    }
  }

  Future<void> _updateLastSyncDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'last_library_sync', DateTime.now().toIso8601String(),);
  }

  Future<bool> shouldSync() async {
    if (_exercises.isEmpty) return true;

    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString('last_library_sync');
    if (lastSyncStr == null) return true;

    final lastSync = DateTime.parse(lastSyncStr);
    return DateTime.now().difference(lastSync).inHours > 24;
  }

  List<LibraryExercise> getExercises() => List.from(_exercises);
  List<LibraryExercise> get exercises => List.from(_exercises);

  /// Get an exercise by its ID.
  /// Returns null if not found.
  LibraryExercise? getExerciseById(int id) {
    for (final ex in _exercises) {
      if (ex.id == id) return ex;
    }
    return null;
  }

  /// Get all favorite exercises
  List<LibraryExercise> get favorites =>
      _exercises.where((e) => e.isFavorite).toList();

  /// Toggle favorite status for an exercise
  Future<void> toggleFavorite(int exerciseId) async {
    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index == -1) return;

    _exercises[index].isFavorite = !_exercises[index].isFavorite;

    // Save to persist the change
    await _saveToFile();

    // Notify listeners
    _updateNotifier();
  }

  /// Check if an exercise is a favorite
  bool isFavorite(int exerciseId) {
    final exercise = _exercises.firstWhere(
      (e) => e.id == exerciseId,
      orElse: () =>
          LibraryExercise(id: -1, name: '', muscleGroup: '', equipment: ''),
    );
    return exercise.isFavorite;
  }

  /// Añade un ejercicio personalizado a la biblioteca
  /// Los ejercicios custom usan IDs negativos para distinguirlos de los de la API
  Future<LibraryExercise> addCustomExercise({
    required String name,
    required String muscleGroup,
    required String equipment,
    String? description,
    List<String> muscles = const [],
    List<String> secondaryMuscles = const [],
  }) async {
    // Generar ID negativo único para ejercicios custom
    var customId = -1;
    for (final ex in _exercises) {
      if (ex.id < 0 && ex.id <= customId) {
        customId = ex.id - 1;
      }
    }

    final newExercise = LibraryExercise(
      id: customId,
      name: name.trim(),
      muscleGroup: muscleGroup,
      equipment: equipment,
      description: description,
      muscles: muscles,
      secondaryMuscles: secondaryMuscles,
      isFavorite: true, // Los custom empiezan como favoritos
    );

    _exercises.insert(0, newExercise); // Añadir al principio
    await _saveToFile();
    _updateNotifier();

    _logger.i('Added custom exercise: $name (ID: $customId)');
    return newExercise;
  }

  /// Elimina un ejercicio personalizado (solo los custom con ID negativo)
  Future<bool> deleteCustomExercise(int exerciseId) async {
    if (exerciseId >= 0) {
      _logger.w('Cannot delete non-custom exercise (ID: $exerciseId)');
      return false;
    }

    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index == -1) return false;

    _exercises.removeAt(index);
    await _saveToFile();
    _updateNotifier();

    _logger.i('Deleted custom exercise with ID: $exerciseId');
    return true;
  }

  /// Actualiza un ejercicio personalizado
  Future<bool> updateCustomExercise({
    required int exerciseId,
    String? name,
    String? muscleGroup,
    String? equipment,
    String? description,
    List<String>? muscles,
    List<String>? secondaryMuscles,
  }) async {
    if (exerciseId >= 0) {
      _logger.w('Cannot update non-custom exercise (ID: $exerciseId)');
      return false;
    }

    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index == -1) return false;

    final old = _exercises[index];
    _exercises[index] = LibraryExercise(
      id: old.id,
      name: name?.trim() ?? old.name,
      muscleGroup: muscleGroup ?? old.muscleGroup,
      equipment: equipment ?? old.equipment,
      description: description ?? old.description,
      imageUrls: old.imageUrls,
      localImagePath: old.localImagePath,
      muscles: muscles ?? old.muscles,
      secondaryMuscles: secondaryMuscles ?? old.secondaryMuscles,
      isFavorite: old.isFavorite,
    );

    await _saveToFile();
    _updateNotifier();

    _logger.i('Updated custom exercise with ID: $exerciseId');
    return true;
  }

  /// Obtiene todos los ejercicios personalizados
  List<LibraryExercise> get customExercises =>
      _exercises.where((e) => e.id < 0).toList();

  void dispose() {
    _connectivitySubscription?.cancel();
    exercisesNotifier.dispose();
  }
}
