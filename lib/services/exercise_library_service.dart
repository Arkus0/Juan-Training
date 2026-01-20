import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import '../models/library_exercise.dart';

class ExerciseLibraryService {
  static final ExerciseLibraryService instance = ExerciseLibraryService._();
  ExerciseLibraryService._();

  final _logger = Logger();
  late Box<LibraryExercise> _box;

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

  /// Loads the library from Hive.
  Future<void> loadLibrary() async {
    try {
      if (!Hive.isBoxOpen('library_exercises')) {
        _box = await Hive.openBox<LibraryExercise>('library_exercises');
      } else {
        _box = Hive.box<LibraryExercise>('library_exercises');
      }

      if (_box.isEmpty) {
        _logger.i('Library empty, loading fallback data...');
        await _box.addAll(_fallbackExercises);
      }

      _updateNotifier();
      _isLoaded = true;
    } catch (e) {
      _logger.e('Error loading library', error: e);
    }
  }

  void _updateNotifier() {
    exercisesNotifier.value = _box.values.toList();
  }

  /// returns true if sync was successful, false otherwise.
  Future<bool> syncLibrary() async {
    // ⚡ Check Connectivity First
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.any((r) => r != ConnectivityResult.none)) {
      _logger.w('Skipping sync: No internet connection.');
      return false;
    }

    try {
      String url = 'https://wger.de/api/v2/exercise/?language=4&limit=50'; // Limit 50 for MVP speed

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

      // Phase 1: Fetch Text Data
      while (url.isNotEmpty) {
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final results = data['results'] as List;

          for (var item in results) {
            final categoryId = item['category'] as int?;
            final equipmentIds = item['equipment'] as List?;
            final equipmentId = (equipmentIds != null && equipmentIds.isNotEmpty)
                ? equipmentIds.first as int
                : 7; // none

            final muscles = (item['muscles'] as List?)?.map((id) => _muscleMap[id] ?? 'Músculo $id').toList() ?? [];
            final secondaryMuscles = (item['muscles_secondary'] as List?)?.map((id) => _muscleMap[id] ?? 'Músculo $id').toList() ?? [];

            final exercise = LibraryExercise.fromApi(
              item,
              _categoryMap[categoryId] ?? 'Otro',
              _equipmentMap[equipmentId] ?? 'Otro',
              List<String>.from(muscles),
              List<String>.from(secondaryMuscles),
            );

            // Check if we already have this exercise and it has a local path
            final existing = _box.get('exercise_${exercise.id}');
            if (existing?.localImagePath != null) {
              exercise.localImagePath = existing!.localImagePath;
            }

            // Save/Update in Hive (Text only first)
            await _box.put('exercise_${exercise.id}', exercise);

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
          _logger.w('API Error: ${response.statusCode}');
          return false;
        }
      }

      // Phase 2: Parallel Image Downloads
      if (!kIsWeb && pendingDownloads.isNotEmpty && imagesDirPath != null) {
        await _processImageDownloads(pendingDownloads, imagesDirPath);
      }

      await _updateLastSyncDate();
      _updateNotifier();
      return true;
    } catch (e) {
      _logger.e('Sync Error', error: e);
      return false;
    }
  }

  Future<void> _processImageDownloads(List<({LibraryExercise exercise, String imageUrl})> items, String dirPath) async {
    const int batchSize = 10;
    for (var i = 0; i < items.length; i += batchSize) {
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final batch = items.sublist(i, end);

      await Future.wait(batch.map((item) async {
        final localPath = await _downloadImage(item.imageUrl, item.exercise.id.toString(), dirPath);
        if (localPath != null) {
          item.exercise.localImagePath = localPath;
          await _box.put('exercise_${item.exercise.id}', item.exercise);
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
    final box = await Hive.openBox('settings');
    await box.put('last_library_sync', DateTime.now().toIso8601String());
  }

  Future<bool> shouldSync() async {
    if (_box.isEmpty) return true;

    final box = await Hive.openBox('settings');
    final lastSyncStr = box.get('last_library_sync') as String?;
    if (lastSyncStr == null) return true;

    final lastSync = DateTime.parse(lastSyncStr);
    final difference = DateTime.now().difference(lastSync);
    return difference.inHours > 24;
  }

  List<LibraryExercise> getExercises() {
    return _box.values.toList();
  }

  /// Getter alias for exercises to support property access
  List<LibraryExercise> get exercises => _box.values.toList();
}
