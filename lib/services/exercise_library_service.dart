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
    final lower = name.toLowerCase();
    // These are often placeholder names in the API
    if (lower.contains('sin nombre') || lower == 'exercise') return false;
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

      // Correctly initialize the map with existing data to merge, not overwrite.
      final Map<int, LibraryExercise> exercisesMap = {
        for (var ex in _exercises) ex.id: ex
      };

      // Phase 1: Fetch English exercises (Language 2 - Primary)
      await _fetchAndProcessLanguage(2, exercisesMap, isPrimary: true);

      // Phase 2: Fetch Spanish exercises (Language 4 - Secondary) and merge
      await _fetchAndProcessLanguage(4, exercisesMap, isPrimary: false);

      // Update internal list from the map
      _exercises = exercisesMap.values.where((e) => _isValidName(e.name)).toList();
      _logger.i('Total unique, valid exercises after merge: ${_exercises.length}');

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
           await _processImageDownloads(pendingDownloads, imagesDirPath, exercisesMap);
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
      // FAIL-SAFE: If sync fails and we have no exercises, use fallback.
      if (_exercises.isEmpty) {
        _logger.w('Sync failed and library is empty. Loading fallback exercises.');
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

    while (url != null && url.isNotEmpty) {
      try {
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 45));
        if (response.statusCode != 200) {
           _logger.e('API Error (lang $language): ${response.statusCode}, Body: ${response.body}');
           break;
        }

        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final results = data['results'] as List;
        fetchedCount += results.length;

        for (var item in results) {
          final exercise = _parseExerciseFromApi(item);
          final existing = exercisesMap[exercise.id];

          if (existing != null) {
            // --- MERGE LOGIC ---
            final newName = isPrimary || _isValidName(exercise.name)
                ? exercise.name
                : existing.name;

            final allImageUrls = {...existing.imageUrls, ...exercise.imageUrls}.toList();

            exercisesMap[exercise.id] = LibraryExercise(
              id: existing.id,
              name: newName,
              muscleGroup: exercise.muscleGroup,
              equipment: exercise.equipment,
              description: exercise.description?.isNotEmpty == true
                  ? exercise.description
                  : existing.description,
              license: exercise.license ?? existing.license,
              imageUrls: allImageUrls,
              localImagePath: existing.localImagePath, // Preserve existing local path
              muscles: exercise.muscles.isNotEmpty ? exercise.muscles : existing.muscles,
              secondaryMuscles: exercise.secondaryMuscles.isNotEmpty
                  ? exercise.secondaryMuscles
                  : existing.secondaryMuscles,
            );
          } else if (_isValidName(exercise.name)) {
            // --- ADD NEW EXERCISE ---
            exercisesMap[exercise.id] = exercise;
          }
        }
        url = data['next'];
      } catch (e, s) {
        _logger.e('Failed to fetch or process page for language $language', error: e, stackTrace: s);
        break; // Stop fetching this language on error
      }
    }
     _logger.i('Fetched $fetchedCount exercises for language $language.');
  }

  LibraryExercise _parseExerciseFromApi(Map<String, dynamic> item) {

    int catId = (item['category'] is Map) ? item['category']['id'] : item['category'] ?? 0;
    int equipId = 7; // Body weight default
    if (item['equipment'] is List && (item['equipment'] as List).isNotEmpty) {
       equipId = (item['equipment'][0] is Map) ? item['equipment'][0]['id'] : item['equipment'][0];
    }

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
      item,
      _categoryMap[catId] ?? 'Otro',
      _equipmentMap[equipId] ?? 'Otro',
      mapMuscles('muscles'),
      mapMuscles('muscles_secondary'),
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
            // Update the map; this will be persisted later.
            map[exercise.id]?.localImagePath = localPath;
            break; // Stop after one successful download for this exercise
          }
        }
      }));
       // Persist progress after each batch to avoid data loss on failure
      await _saveToFile();
    }
  }

  Future<String?> _downloadImage(String url, String id, String dirPath) async {
    // Force .jpg or .png extension
    final extension = url.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final filePath = '$dirPath/$id.$extension';
    final file = File(filePath);

    try {
      if (await file.exists() && await file.length() > 0) {
        return filePath; // Already exists and is valid
      }

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        _logger.d('Downloaded image: $filePath');
        return filePath;
      } else {
         _logger.w('Failed to download image $url: status code ${response.statusCode}');
      }
    } catch (e) {
      _logger.w('Error downloading image for $id from $url', error: e);
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
    return DateTime.now().difference(lastSync).inHours > 24;
  }

  List<LibraryExercise> getExercises() => List.from(_exercises);
  List<LibraryExercise> get exercises => List.from(_exercises);

  void dispose() {
    _connectivitySubscription?.cancel();
    exercisesNotifier.dispose();
  }
}
