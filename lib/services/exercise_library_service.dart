import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/library_exercise.dart';

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

  // --- Mappings (Wger ID -> Spanish Name) ---
  static const Map<int, String> _categoryMap = {
    10: 'Abdominales',
    8: 'Brazos',
    12: 'Espalda',
    14: 'Gemelos',
    15: 'Cardio',
    11: 'Pecho',
    9: 'Piernas',
    13: 'Hombros',
  };

  static const Map<int, String> _equipmentMap = {
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
    // Add more as needed
  };

  static const Map<int, String> _muscleMap = {
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
    LibraryExercise(
        id: 1006,
        name: 'Curl de Bíceps',
        muscleGroup: 'Brazos',
        equipment: 'Mancuerna',
        description: 'Curl alterno con mancuernas',
        muscles: ['Bíceps braquial'],
        secondaryMuscles: []),
    LibraryExercise(
        id: 1007,
        name: 'Extensiones de Tríceps',
        muscleGroup: 'Brazos',
        equipment: 'Polea',
        description: 'En polea alta',
        muscles: ['Tríceps braquial'],
        secondaryMuscles: []),
    LibraryExercise(
        id: 1008,
        name: 'Plancha',
        muscleGroup: 'Abdominales',
        equipment: 'Peso corporal',
        description: 'Plancha isométrica',
        muscles: ['Recto abdominal'],
        secondaryMuscles: ['Oblicuos']),
    LibraryExercise(
        id: 1009,
        name: 'Zancadas',
        muscleGroup: 'Piernas',
        equipment: 'Mancuerna',
        description: 'Lunges caminando',
        muscles: ['Cuádriceps', 'Glúteo mayor'],
        secondaryMuscles: []),
    LibraryExercise(
        id: 1010,
        name: 'Elevaciones Laterales',
        muscleGroup: 'Hombros',
        equipment: 'Mancuerna',
        description: 'Para deltoides medio',
        muscles: ['Deltoides medio'],
        secondaryMuscles: []),
  ];

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/exercises.json');
  }

  /// Initialize the service: Load local data and start Sentinel listener
  Future<void> init() async {
    await loadLibrary();
    _setupConnectivityListener();
    // Attempt immediate sync check (in case we start Online)
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

    // Re-check connectivity just to be sure
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult.any((r) => r != ConnectivityResult.none);

    if (!isOnline) {
      _logger.d('Sentinel: Offline. Skipping sync check.');
      return;
    }

    bool triggerSync = false;

    if (!initialSyncCompleted) {
      _logger.i('Sentinel: Initial sync not completed. Starting sync...');
      triggerSync = true;
    } else if (await shouldSync()) {
      _logger.i('Sentinel: Periodic (24h) sync due. Starting sync...');
      triggerSync = true;
    }

    if (triggerSync) {
      await syncLibrary();
    }
  }

  /// Loads the library from local JSON file.
  Future<void> loadLibrary() async {
    try {
      final file = await _localFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _exercises = jsonList.map((e) => LibraryExercise.fromJson(e)).toList();
      }

      if (_exercises.isEmpty) {
        _logger.i('Library empty, loading fallback data...');
        _exercises = List.from(_fallbackExercises);
        // Save fallback to file? Optional, but good for consistency.
        // await _saveToFile();
      }

      _updateNotifier();
      _isLoaded = true;
    } catch (e) {
      _logger.e('Error loading library', error: e);
      // Fallback in case of corruption
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
    } catch (e) {
      _logger.e('Error saving library to file', error: e);
    }
  }

  void _updateNotifier() {
    exercisesNotifier.value = List.from(_exercises);
  }

  /// returns true if sync was successful, false otherwise.
  Future<bool> syncLibrary() async {
    if (_isSyncing) {
      _logger.w('Sync already in progress. Skipping.');
      return false;
    }
    _isSyncing = true;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.any((r) => r != ConnectivityResult.none)) {
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

      final Map<int, LibraryExercise> exercisesById = {
        // Pre-fill with existing exercises to preserve local data like image paths
        for (var ex in _exercises) ex.id: ex
      };

      // Phase 1: Fetch English exercises (Language 2)
      _logger.i('Phase 1: Fetching English exercises (lang=2)...');
      await _fetchAndProcessLanguage(2, exercisesById, isPrimary: true);

      // Phase 2: Fetch Spanish exercises (Language 4) and merge
      _logger.i('Phase 2: Fetching Spanish exercises (lang=4) and merging...');
      await _fetchAndProcessLanguage(4, exercisesById, isPrimary: false);

      // Update internal list from the map
      _exercises = exercisesById.values.toList();
      _logger.i('Total unique exercises after merge: ${_exercises.length}');

      // Phase 3: Parallel Image Downloads
      if (!kIsWeb && imagesDirPath != null) {
        final pendingDownloads = _exercises
            .where((e) =>
                e.imageUrls.isNotEmpty &&
                (e.localImagePath == null ||
                    !File(e.localImagePath!).existsSync()))
            .toList();

        _logger.i('Found ${pendingDownloads.length} exercises with images to download.');

        if (pendingDownloads.isNotEmpty) {
          final Map<int, LibraryExercise> idMap = {
            for (var e in _exercises) e.id: e
          };
          await _processImageDownloads(pendingDownloads, imagesDirPath, idMap);
        }
      }

      // Save everything to file
      await _saveToFile();
      await _updateLastSyncDate();

      // ✅ SUCCESS: Mark initial sync as completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('initial_library_sync_completed', true);
      _logger.i('Sync completed successfully. Sentinel satisfied.');

      _updateNotifier();
      return true;
    } catch (e, stacktrace) {
      _logger.e('Sync Error', error: e, stackTrace: stacktrace);
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _fetchAndProcessLanguage(
      int language, Map<int, LibraryExercise> exercisesById,
      {required bool isPrimary}) async {
    String? url =
        'https://wger.de/api/v2/exerciseinfo/?language=$language&limit=200';
    int fetchedCount = 0;

    while (url != null && url.isNotEmpty) {
      try {
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 45));
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final results = data['results'] as List;
          fetchedCount += results.length;

          for (var item in results) {
            final exercise = _parseExerciseFromApi(item);
            final existing = exercisesById[exercise.id];

            if (existing != null) {
              // --- MERGE LOGIC ---
              // Name Protection Logic
              final newNameRaw = isPrimary ? exercise.name : (exercise.name.trim().isNotEmpty ? exercise.name : existing.name);
              final isInvalidSpanishName = !isPrimary &&
                  (newNameRaw.toLowerCase().contains('sin nombre') ||
                      newNameRaw.toLowerCase() == 'exercise');

              final finalName = isInvalidSpanishName ? existing.name : newNameRaw;

              // Merge other fields
              final allImageUrls = {...existing.imageUrls, ...exercise.imageUrls}.toList();

              exercisesById[exercise.id] = LibraryExercise(
                id: existing.id,
                name: finalName,
                description: exercise.description?.isNotEmpty == true
                    ? exercise.description
                    : existing.description,
                muscleGroup: exercise.muscleGroup,
                equipment: exercise.equipment,
                muscles: exercise.muscles.isNotEmpty
                    ? exercise.muscles
                    : existing.muscles,
                secondaryMuscles: exercise.secondaryMuscles.isNotEmpty
                    ? exercise.secondaryMuscles
                    : existing.secondaryMuscles,
                imageUrls: allImageUrls,
                localImagePath: existing.localImagePath, // Preserve path
                license: exercise.license ?? existing.license,
              );
            } else {
              // --- ADD NEW EXERCISE ---
              final name = exercise.name.trim();
              final isInvalidName = name.isEmpty ||
                  name.toLowerCase().contains('sin nombre') ||
                  name.toLowerCase() == 'exercise';
              
              if (!isInvalidName) {
                exercisesById[exercise.id] = exercise;
              }
            }
          }
          url = data['next'];
        } else {
          _logger.w('API Error (language $language): ${response.statusCode}');
          break;
        }
      } catch (e) {
        _logger.e('Failed to fetch page for language $language: $e');
        break; // Stop fetching this language on error
      }
    }
    _logger.i('Fetched $fetchedCount exercises for language $language.');
  }

  LibraryExercise _parseExerciseFromApi(Map<String, dynamic> item) {

    int catId = 0;
    if (item['category'] is Map) {
      catId = item['category']['id'];
    } else if (item['category'] is int) {
      catId = item['category'];
    }

    int equipId = 7; // Body weight default
    if (item['equipment'] is List && (item['equipment'] as List).isNotEmpty) {
      final first = (item['equipment'] as List).first;
      if (first is Map) {
        equipId = first['id'];
      } else if (first is int) {
        equipId = first;
      }
    }

    final muscles = <String>[];
    if (item['muscles'] is List) {
      for (var m in item['muscles']) {
        int mId = (m is Map) ? m['id'] : m as int;
        muscles.add(_muscleMap[mId] ?? 'Músculo $mId');
      }
    }

    final secondaryMuscles = <String>[];
    if (item['muscles_secondary'] is List) {
      for (var m in item['muscles_secondary']) {
        int mId = (m is Map) ? m['id'] : m as int;
        secondaryMuscles.add(_muscleMap[mId] ?? 'Músculo $mId');
      }
    }

    return LibraryExercise.fromApi(
      item,
      _categoryMap[catId] ?? 'Otro',
      _equipmentMap[equipId] ?? 'Otro',
      muscles,
      secondaryMuscles,
    );
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
            // Check if the component is still mounted before updating state
            if (map.containsKey(exercise.id)) {
                map[exercise.id]!.localImagePath = localPath;
                // No need to update the exercise object directly, map holds the reference
            }
            break;
          }
        }
      }));
       // After each batch, save to persist progress
      await _saveToFile();
    }
  }

  Future<String?> _downloadImage(String url, String id, String dirPath) async {
    // Correctly handle image extensions
    final extension = url.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final filePath = '$dirPath/$id.$extension';
    final file = File(filePath);

    try {
      if (await file.exists()) {
        if (await file.length() > 0) {
          return filePath; // Already exists and is valid
        } else {
          _logger.w('Found 0-byte image for $id, re-downloading...');
          await file.delete(); // Delete corrupted file
        }
      }

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        _logger.d('Downloaded image: $filePath');
        return filePath;
      } else {
         _logger.w('Failed to download image for $id: status code ${response.statusCode}');
      }
    } catch (e) {
      _logger.w('Error downloading image for $id from $url: $e');
    }
    return null;
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
    final difference = DateTime.now().difference(lastSync);
    return difference.inHours > 24;
  }

  List<LibraryExercise> getExercises() {
    return List.from(_exercises);
  }

  /// Getter alias for exercises to support property access
  List<LibraryExercise> get exercises => List.from(_exercises);

  void dispose() {
    _connectivitySubscription?.cancel();
    exercisesNotifier.dispose();
  }
}