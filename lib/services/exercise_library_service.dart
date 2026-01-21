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
  final ValueNotifier<List<LibraryExercise>> exercisesNotifier = ValueNotifier([]);

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
    LibraryExercise(id: 1001, name: 'Press de Banca', muscleGroup: 'Pecho', equipment: 'Barra', description: 'Press básico de pecho', muscles: ['Pectoral mayor'], secondaryMuscles: ['Tríceps braquial', 'Deltoides anterior']),
    LibraryExercise(id: 1002, name: 'Sentadilla', muscleGroup: 'Piernas', equipment: 'Barra', description: 'Sentadilla clásica', muscles: ['Cuádriceps'], secondaryMuscles: ['Glúteo mayor', 'Gemelos']),
    LibraryExercise(id: 1003, name: 'Peso Muerto', muscleGroup: 'Espalda', equipment: 'Barra', description: 'Peso muerto convencional', muscles: ['Erectores', 'Glúteo mayor'], secondaryMuscles: ['Isquios', 'Trapecio']),
    LibraryExercise(id: 1004, name: 'Dominadas', muscleGroup: 'Espalda', equipment: 'Barra dominadas', description: 'Pull-ups', muscles: ['Dorsal ancho'], secondaryMuscles: ['Bíceps braquial']),
    LibraryExercise(id: 1005, name: 'Press Militar', muscleGroup: 'Hombros', equipment: 'Barra', description: 'Press de hombros de pie', muscles: ['Deltoides anterior'], secondaryMuscles: ['Tríceps braquial']),
    LibraryExercise(id: 1006, name: 'Curl de Bíceps', muscleGroup: 'Brazos', equipment: 'Mancuerna', description: 'Curl alterno con mancuernas', muscles: ['Bíceps braquial'], secondaryMuscles: []),
    LibraryExercise(id: 1007, name: 'Extensiones de Tríceps', muscleGroup: 'Brazos', equipment: 'Polea', description: 'En polea alta', muscles: ['Tríceps braquial'], secondaryMuscles: []),
    LibraryExercise(id: 1008, name: 'Plancha', muscleGroup: 'Abdominales', equipment: 'Peso corporal', description: 'Plancha isométrica', muscles: ['Recto abdominal'], secondaryMuscles: ['Oblicuos']),
    LibraryExercise(id: 1009, name: 'Zancadas', muscleGroup: 'Piernas', equipment: 'Mancuerna', description: 'Lunges caminando', muscles: ['Cuádriceps', 'Glúteo mayor'], secondaryMuscles: []),
    LibraryExercise(id: 1010, name: 'Elevaciones Laterales', muscleGroup: 'Hombros', equipment: 'Mancuerna', description: 'Para deltoides medio', muscles: ['Deltoides medio'], secondaryMuscles: []),
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
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
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
    final initialSyncCompleted = prefs.getBool('initial_library_sync_completed') ?? false;

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
      final String content = jsonEncode(_exercises.map((e) => e.toJson()).toList());
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

    // ⚡ Check Connectivity First
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

      List<({LibraryExercise exercise, String imageUrl})> pendingDownloads = [];

      final Map<String, LibraryExercise> mergedMap = {};

      // Seed with existing to preserve local paths?
      final Map<int, String> existingLocalPaths = {
        for (var e in _exercises)
          if (e.localImagePath != null) e.id: e.localImagePath!
      };

      final List<int> languages = [2, 4]; // 2 = English, 4 = Spanish

      for (final lang in languages) {
         String url = 'https://wger.de/api/v2/exerciseinfo/?language=$lang&limit=100';
         _logger.i('Fetching exercises for language $lang...');
         int fetchedCount = 0;

         while (url.isNotEmpty) {
           final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
           if (response.statusCode == 200) {
             final data = jsonDecode(utf8.decode(response.bodyBytes));
             final results = data['results'] as List;
             fetchedCount += results.length;

             for (var item in results) {
               final int id = item['id'];
               final int? variationId = item['variations']; // Can be null or int

               final categoryId = item['category'] is Map ? item['category']['id'] : item['category'] as int?;

               int catId = 0;
               if (item['category'] is Map) {
                 catId = item['category']['id'];
               } else if (item['category'] is int) {
                 catId = item['category'];
               }

               // Equipment
               int equipId = 7; // Body weight default
               if (item['equipment'] is List && (item['equipment'] as List).isNotEmpty) {
                 final first = (item['equipment'] as List).first;
                 if (first is Map) {
                   equipId = first['id'];
                 } else if (first is int) {
                   equipId = first;
                 }
               }

               // Muscles
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

               // Parse Exercise
               final exercise = LibraryExercise.fromApi(
                 item,
                 _categoryMap[catId] ?? 'Otro',
                 _equipmentMap[equipId] ?? 'Otro',
                 muscles,
                 secondaryMuscles,
               );

               // Restore local path if exists (using ID)
               if (existingLocalPaths.containsKey(exercise.id)) {
                 exercise.localImagePath = existingLocalPaths[exercise.id];
               }

               // Determine Merge Key
               String key;
               if (variationId != null) {
                 key = 'v-$variationId';
               } else {
                 key = 'i-$id';
               }

               mergedMap[key] = exercise;

               // Queue images for download
               if (!kIsWeb && exercise.imageUrls.isNotEmpty) {
                 pendingDownloads.add((exercise: exercise, imageUrl: exercise.imageUrls.first));
               }
             }

             if (data['next'] != null) {
               url = data['next'];
             } else {
               url = '';
             }
           } else {
             _logger.w('API Error ($lang): ${response.statusCode}');
             break;
           }
         } // while url
         _logger.i('Fetched $fetchedCount exercises for language $lang');
      } // for languages

      // Update internal list
      _exercises = mergedMap.values.toList();
      _logger.i('Total unique exercises after merge: ${_exercises.length}');

      // Phase 2: Parallel Image Downloads
      if (!kIsWeb && pendingDownloads.isNotEmpty && imagesDirPath != null) {
        final Map<int, LibraryExercise> idMap = {
          for (var e in _exercises) e.id: e
        };

        await _processImageDownloads(pendingDownloads, imagesDirPath, idMap);
      }

      // Save everything to file
      await _saveToFile();

      await _updateLastSyncDate();

      // ✅ SUCCESS: Mark initial sync as completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('initial_library_sync_completed', true);
      _logger.i('Sync completed successfully. Sentinel satisfied.');

      _updateNotifier();
      _isSyncing = false;
      return true;
    } catch (e) {
      _logger.e('Sync Error', error: e);
      _isSyncing = false;
      return false;
    }
  }

  Future<void> _processImageDownloads(
    List<({LibraryExercise exercise, String imageUrl})> items,
    String dirPath,
    Map<int, LibraryExercise> map,
  ) async {
    const int batchSize = 10;
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);

      await Future.wait(batch.map((item) async {
        final localPath = await _downloadImage(item.imageUrl, item.exercise.id.toString(), dirPath);
        if (localPath != null) {
          item.exercise.localImagePath = localPath;
          map[item.exercise.id]?.localImagePath = localPath;
        }
      }));
    }
  }

  Future<String?> _downloadImage(String url, String id, String dirPath) async {
    try {
      final filePath = '$dirPath/$id.jpg';
      final file = File(filePath);
      if (await file.exists()) {
        return filePath; // Already exists
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
    } catch (e) {
      _logger.w('Error downloading image for $id: $e');
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
  }
}
