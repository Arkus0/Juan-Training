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

  // Notifier for real-time updates
  final ValueNotifier<List<LibraryExercise>> exercisesNotifier = ValueNotifier([]);

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  bool _isSyncing = false;
  static const String _prefsKeySynced = 'library_fully_synced';

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
    if (_isSyncing) return false;
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

      // Create a temporary map to update exercises efficiently.
      // We will re-build this map from scratch (or merge) depending on strategy.
      // If we want to keep old custom exercises, we should seed it with them.
      // For now, let's assume we want a fresh sync but preserving local paths if ID matches.

      // We need a way to map 'variations' ID to our LibraryExercise.
      // But we also need to handle exercises without variations.
      // Strategy: Key = variations ID (if present) OR exercise ID (if not).
      // This means we might have collisions if an ID equals a Variation ID, but statistically unlikely or we can use negative for one.
      // Better: Key = 'V_{variation_id}' or 'I_{id}' string keys?
      // Or just keep a map of `int` and assume no collision between ID and Variation ID?
      // Actually, 'variations' is an ID of a 'Variation' object/group in Wger. Exercise IDs are distinct.
      // Let's use a String key for safety: "v-$vid" vs "i-$id".

      final Map<String, LibraryExercise> mergedMap = {};

      // Seed with existing to preserve local paths?
      // Actually, if we re-fetch, we can just check against _exercises list for local paths.
      // Let's build a lookup for existing local paths.
      final Map<int, String> existingLocalPaths = {
        for (var e in _exercises)
          if (e.localImagePath != null) e.id: e.localImagePath!
      };

      // Also, if we are merging English and Spanish, we need to know if we already have an entry for a given variation.
      // So 'mergedMap' is the accumulator.

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

               // Equipment is usually a list of objects in exerciseinfo or list of ints?
               // In exerciseinfo, it seems to be list of objects based on docs, but let's check parsing.
               // 'LibraryExercise.fromApi' expects 'category' and 'equipment' as IDs in the raw JSON?
               // Wait, 'LibraryExercise.fromApi' was built for '/exercise/' endpoint.
               // '/exerciseinfo/' structure might be slightly different.
               // Let's re-verify the structure in 'fromApi' or adjust it.

               // In '/exercise/', 'category' is an int ID.
               // In '/exerciseinfo/', 'category' is an object: {id: 10, name: "Abs" ...}
               // Let's handle both or adjust parsing here.

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
               // We need to construct LibraryExercise manually or adapt fromApi.
               // LibraryExercise.fromApi handles 'images' extraction from JSON.
               // But it expects 'category' and 'equipment' to be passed as strings.

               final exercise = LibraryExercise.fromApi(
                 item,
                 _categoryMap[catId] ?? 'Otro',
                 _equipmentMap[equipId] ?? 'Otro',
                 muscles,
                 secondaryMuscles,
               );

               // Restore local path if exists (using ID)
               // Note: If we merge via variation, the ID might change (e.g. English ID vs Spanish ID).
               // The 'existingLocalPaths' is keyed by ID.
               // If we overwrite English (ID=X) with Spanish (ID=Y), we lose access to X's local path?
               // But wait, the image URL will be the same (Wger uses same image for variations usually, or we download new).
               // If image URL is same, we might want to check if file exists by name.
               // However, `_downloadImage` checks `await file.exists()`.
               // So if we preserve the naming convention (ID based), we might re-download if ID changes.
               // But we can't easily link ID X file to ID Y exercise without mapping.
               // For now, let's just allow re-download (or check by URL hash? No, too complex).
               // Just rely on `localImagePath` being null initially for new ID.

               // Attempt to restore path if ID matches exactly (e.g. same lang update)
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

               // Merge Logic:
               // If key exists, we overwrite.
               // Since we iterate [English, Spanish], Spanish (Language 4) will overwrite English (Language 2).
               // This satisfies "Prefer Spanish".

               // ONE CATCH: If we have an existing entry from English, and now we process Spanish.
               // The Spanish entry might have images, or NOT.
               // If Spanish has NO images, but English DID, do we want to lose images?
               // The 'exerciseinfo' endpoint usually includes images for both if they are linked.
               // But if not, we might want to merge images?
               // Prompt said "Complete Object Replacement".
               // So we overwrite. If Spanish is missing images, so be it (or Wger usually shares them).

               mergedMap[key] = exercise;

               // Queue images for download
               if (!kIsWeb && exercise.imageUrls.isNotEmpty) {
                 // For now, just take the first one or all?
                 // The code below takes the first one.
                 // "simply add the result to this list... Process... to handle local caching."
                 // existing logic queues `exercise.imageUrls.first`.
                 // Let's stick to first image for offline cache to save space, or all?
                 // The `pendingDownloads` uses `imageUrls.first` in the original code.
                 // We'll stick to that for now unless needed.
                 // Wait, `fromApi` extracts ALL images.
                 // `pendingDownloads` is a list of (exercise, url).
                 // If we want multiple images, we iterate.
                 // Original code: `pendingDownloads.add((exercise: exercise, imageUrl: exercise.imageUrls.first));`
                 // Let's just download the first one for the thumbnail/preview.
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
             // Don't abort entire sync, just this language?
             // Or maybe abort to be safe.
             // Let's stop this language loop.
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
        // We need to map our merged exercises back to ID for the `updatedMap` param of `_processImageDownloads`
        // Actually `_processImageDownloads` takes a Map<int, LibraryExercise> to update the object in the map.
        // We can just pass a map keyed by ID.
        final Map<int, LibraryExercise> idMap = {
          for (var e in _exercises) e.id: e
        };

        await _processImageDownloads(pendingDownloads, imagesDirPath, idMap);
      }

      // Save everything to file
      await _saveToFile();

      await _updateLastSyncDate();
      _updateNotifier();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeySynced, true);

      return true;
    } catch (e) {
      _logger.e('Sync Error', error: e);
      return false;
    } finally {
      _isSyncing = false;
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
        // Use the ID of the exercise object.
        // Note: item.exercise is a reference to the object in mergedMap.
        final localPath = await _downloadImage(item.imageUrl, item.exercise.id.toString(), dirPath);
        if (localPath != null) {
          item.exercise.localImagePath = localPath;
          // Update the object in the map (reference is the same, but good to be explicit if structure changes)
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
    // If local file is missing, we must sync
    final file = await _localFile;
    if (!await file.exists()) return true;

    // If never fully synced, we must sync
    final prefs = await SharedPreferences.getInstance();
    final isSynced = prefs.getBool(_prefsKeySynced) ?? false;

    return !isSynced;
  }

  List<LibraryExercise> getExercises() {
    return List.from(_exercises);
  }

  /// Getter alias for exercises to support property access
  List<LibraryExercise> get exercises => List.from(_exercises);
}
