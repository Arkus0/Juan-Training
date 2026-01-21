import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
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

/// Decodes JSON and maps results to LibraryExercise objects in a separate thread.
/// Returns a Map with 'exercises' (List<LibraryExercise>) and 'next' (String? url).
Map<String, dynamic> parseLibraryExercises(Uint8List responseBytes) {
  // 1. Decode UTF-8 (cpu intensive for large strings)
  final String jsonStr = utf8.decode(responseBytes);

  // 2. Decode JSON
  final Map<String, dynamic> data = jsonDecode(jsonStr);
  final List<dynamic> results = data['results'] as List<dynamic>;

  // 3. Map to Domain Objects
  final exercises = results.map((item) {
    // Helper to extract nested IDs safely
    int catId = (item['category'] is Map) ? item['category']['id'] : item['category'] ?? 0;

    int equipId = 7; // Default: Body weight
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
          int mId = (m is Map) ? m['id'] : m as int;
          return _muscleMap[mId] ?? 'Músculo $mId';
        }).toList();
      }
      return [];
    }

    return LibraryExercise.fromApi(
      item as Map<String, dynamic>,
      categoryName,
      equipmentName,
      mapMuscles('muscles'),
      mapMuscles('muscles_secondary'),
    );
  }).toList();

  return {
    'exercises': exercises,
    'next': data['next'],
  };
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
        secondaryMuscles: ['Tríceps braquial', 'Deltoides anterior']),
    LibraryExercise(
        id: 1002,
        name: 'Sentadilla',
        muscleGroup: 'Piernas',
        equipment: 'Barra',
        description: 'Sentadilla clásica',
        muscles: ['Cuádriceps'],
        secondaryMuscles: ['Glúteo mayor', 'Gemelos']),
    LibraryExercise(
        id: 1003,
        name: 'Peso Muerto',
        muscleGroup: 'Espalda',
        equipment: 'Barra',
        description: 'Peso muerto convencional',
        muscles: ['Erectores', 'Glúteo mayor'],
        secondaryMuscles: ['Isquios', 'Trapecio']),
    LibraryExercise(
        id: 1004,
        name: 'Dominadas',
        muscleGroup: 'Espalda',
        equipment: 'Barra dominadas',
        description: 'Pull-ups',
        muscles: ['Dorsal ancho'],
        secondaryMuscles: ['Bíceps braquial']),
    LibraryExercise(
        id: 1005,
        name: 'Press Militar',
        muscleGroup: 'Hombros',
        equipment: 'Barra',
        description: 'Press de hombros de pie',
        muscles: ['Deltoides anterior'],
        secondaryMuscles: ['Tríceps braquial']),
  ];

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/exercises.json');
  }

  /// Initialize the service: Load local data and start Sentinel listener
  Future<void> init() async {
    await loadLibrary();
    _setupConnectivityListener();
    _checkAndSync();
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
    final isOnline = connectivityResult.any((r) => r != ConnectivityResult.none);

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
          final List<dynamic> jsonList = jsonDecode(content);
          _exercises = jsonList.map((e) => LibraryExercise.fromJson(e)).toList();
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
      if (_exercises.isEmpty) {
        _exercises = List.from(_fallbackExercises);
        _updateNotifier();
      }
    }
  }

  Future<void> _saveToFile() async {
    try {
      final file = await _localFile;
      final String content =
          jsonEncode(_exercises.map((e) => e.toJson()).toList());
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
    if (lower == 'exercise') return false;
    if (lower == 'ejercicio sin nombre') return false;
    return true;
  }

  /// returns true if sync was successful, false otherwise.
  Future<bool> syncLibrary() async {
    if (_isSyncing) {
      _logger.w('Sync already in progress. Skipping.');
      return false;
    }
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
      final Map<int, LibraryExercise> exercisesMap = {
        for (var ex in _exercises) ex.id: ex
      };
      _logger.d('Initialized sync with ${exercisesMap.length} existing exercises.');

      // Phase 1: Fetch English exercises (Language 2 - Primary)
      await _fetchAndProcessLanguage(2, exercisesMap, isPrimary: true);

      // Phase 2: Fetch Spanish exercises (Language 4 - Secondary) and merge
      await _fetchAndProcessLanguage(4, exercisesMap, isPrimary: false);

      _logger.i('Total exercises in map before final filtering: ${exercisesMap.length}');

      // Update internal list from the map, filtering for validity
      final originalCount = exercisesMap.length;
      _exercises =
          exercisesMap.values.where((e) => _isValidName(e.name)).toList();

      if (exercisesMap.isNotEmpty && _exercises.isEmpty) {
        _logger.w(
            'CRITICAL WARNING: All $originalCount exercises were discarded after name validation.',
            error:
                'Example invalid name: "${exercisesMap.values.first.name}"');
      }
      _logger.i(
          'Total unique, valid exercises after merge: ${_exercises.length}');

      // Phase 3: Parallel Image Downloads
      if (!kIsWeb && imagesDirPath != null) {
        final pendingDownloads = _exercises
            .where((e) =>
                e.imageUrls.isNotEmpty &&
                (e.localImagePath == null ||
                    !File(e.localImagePath!).existsSync()))
            .toList();

        _logger
            .i('Found ${pendingDownloads.length} exercises with images to download.');
        if (pendingDownloads.isNotEmpty) {
          await _processImageDownloads(
              pendingDownloads, imagesDirPath, exercisesMap);
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

  Future<void> _fetchAndProcessLanguage(
      int language, Map<int, LibraryExercise> exercisesMap,
      {required bool isPrimary}) async {
    _logger.i('Phase: Fetching language $language (isPrimary: $isPrimary)');
    String? url =
        'https://wger.de/api/v2/exerciseinfo/?language=$language&limit=200';
    int fetchedCount = 0;
    int addedCount = 0;
    int mergedCount = 0;

    while (url != null && url.isNotEmpty) {
      try {
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 45));
        if (response.statusCode != 200) {
          _logger.e(
              'API Error (lang $language): ${response.statusCode}, Body: ${response.body}');
          break;
        }

        // --- ISOLATE IMPLEMENTATION ---
        // Offload decoding and parsing to background thread.
        // We pass bodyBytes to allow UTF8 decoding in the isolate.
        final Map<String, dynamic> result =
            await compute(parseLibraryExercises, response.bodyBytes);

        final List<LibraryExercise> pageExercises =
            result['exercises'] as List<LibraryExercise>;
        final String? nextUrl = result['next'] as String?;

        fetchedCount += pageExercises.length;

        for (var exercise in pageExercises) {
          final existing = exercisesMap[exercise.id];

          if (existing != null) {
            mergedCount++;
            // --- MERGE LOGIC ---
            // If primary (English), we overwrite (since it comes first in our flow).
            // When processing Lang 4 (Spanish - Secondary):
            // newName should use Lang 4 name (exercise.name) ONLY if it is valid.
            // If Lang 4 name is invalid ("Exercise", "Ejercicio sin nombre"), we keep existing (English).

            final bool shouldUseNewName = isPrimary || _isValidName(exercise.name);
            final newName = shouldUseNewName ? exercise.name : existing.name;

            // Merge and Deduplicate Images
            final Set<String> uniqueImages = {};
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
              muscles: exercise.muscles.isNotEmpty
                  ? exercise.muscles
                  : existing.muscles,
              secondaryMuscles: exercise.secondaryMuscles.isNotEmpty
                  ? exercise.secondaryMuscles
                  : existing.secondaryMuscles,
            );
          } else {
            addedCount++;
            // --- ADD NEW EXERCISE ---
            exercisesMap[exercise.id] = exercise;
          }
        }
        url = nextUrl;
      } catch (e, s) {
        _logger.e('Failed to fetch or process page for language $language',
            error: e, stackTrace: s);
        break; // Stop fetching this language on error
      }
    }
    _logger.i(
        'Language $language: Fetched $fetchedCount, added $addedCount new, merged $mergedCount existing.');
  }

  Future<void> _processImageDownloads(
    List<LibraryExercise> items,
    String dirPath,
    Map<int, LibraryExercise> map,
  ) async {
    const int batchSize = 10;
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);

      await Future.wait(batch.map((exercise) async {
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
      }));
       // Persist progress after each batch to avoid data loss on failure
      await _saveToFile();
    }
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
         _logger.w('Failed to download image $url: status ${response.statusCode}, bytes: ${response.bodyBytes.length}');
         return null;
      }
    } catch (e) {
      _logger.w('Error downloading image for $id from $url', error: e);
      // Clean up potentially corrupted file
      if (await file.exists()) {
         try { await file.delete(); } catch (_) {}
      }
      return null;
    }
  }

  Future<void> _updateLastSyncDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_library_sync', DateTime.now().toIso8601String());
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

  void dispose() {
    _connectivitySubscription?.cancel();
    exercisesNotifier.dispose();
  }
}
