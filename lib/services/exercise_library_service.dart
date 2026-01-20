import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import '../models/library_exercise.dart';

class ExerciseLibraryService {
  static final ExerciseLibraryService instance = ExerciseLibraryService._();
  ExerciseLibraryService._();

  List<LibraryExercise> _exercises = [];
  List<LibraryExercise> get exercises => List.unmodifiable(_exercises);

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
  };

  // --- Fallback Data (Offline/Error) ---
  static final List<LibraryExercise> _fallbackExercises = [
    LibraryExercise(id: 1001, name: 'Press de Banca', muscleGroup: 'Pecho', equipment: 'Barra', description: 'Press básico de pecho'),
    LibraryExercise(id: 1002, name: 'Sentadilla', muscleGroup: 'Piernas', equipment: 'Barra', description: 'Sentadilla clásica'),
    LibraryExercise(id: 1003, name: 'Peso Muerto', muscleGroup: 'Espalda', equipment: 'Barra', description: 'Peso muerto convencional'),
    LibraryExercise(id: 1004, name: 'Dominadas', muscleGroup: 'Espalda', equipment: 'Barra dominadas', description: 'Pull-ups'),
    LibraryExercise(id: 1005, name: 'Press Militar', muscleGroup: 'Hombros', equipment: 'Barra', description: 'Press de hombros de pie'),
    LibraryExercise(id: 1006, name: 'Curl de Bíceps', muscleGroup: 'Brazos', equipment: 'Mancuerna', description: 'Curl alterno con mancuernas'),
    LibraryExercise(id: 1007, name: 'Extensiones de Tríceps', muscleGroup: 'Brazos', equipment: 'Polea', description: 'En polea alta'),
    LibraryExercise(id: 1008, name: 'Plancha', muscleGroup: 'Abdominales', equipment: 'Peso corporal', description: 'Plancha isométrica'),
    LibraryExercise(id: 1009, name: 'Zancadas', muscleGroup: 'Piernas', equipment: 'Mancuerna', description: 'Lunges caminando'),
    LibraryExercise(id: 1010, name: 'Elevaciones Laterales', muscleGroup: 'Hombros', equipment: 'Mancuerna', description: 'Para deltoides medio'),
    LibraryExercise(id: 1011, name: 'Remo con Barra', muscleGroup: 'Espalda', equipment: 'Barra', description: 'Remo inclinado'),
    LibraryExercise(id: 1012, name: 'Press Inclinado', muscleGroup: 'Pecho', equipment: 'Banco inclinado', description: 'Press con mancuernas'),
    LibraryExercise(id: 1013, name: 'Crunch', muscleGroup: 'Abdominales', equipment: 'Peso corporal', description: 'Abdominales básicos'),
    LibraryExercise(id: 1014, name: 'Fondos', muscleGroup: 'Pecho', equipment: 'Peso corporal', description: 'Dips en paralelas'),
    LibraryExercise(id: 1015, name: 'Prensa de Piernas', muscleGroup: 'Piernas', equipment: 'Máquina', description: 'Leg press'),
    LibraryExercise(id: 1016, name: 'Curl Femoral', muscleGroup: 'Piernas', equipment: 'Máquina', description: 'Curl tumbado'),
    LibraryExercise(id: 1017, name: 'Elevación de Gemelos', muscleGroup: 'Gemelos', equipment: 'Máquina', description: 'De pie o sentado'),
    LibraryExercise(id: 1018, name: 'Face Pull', muscleGroup: 'Hombros', equipment: 'Polea', description: 'Para deltoides posterior'),
    LibraryExercise(id: 1019, name: 'Hip Thrust', muscleGroup: 'Piernas', equipment: 'Barra', description: 'Empuje de cadera'),
    LibraryExercise(id: 1020, name: 'Burpees', muscleGroup: 'Cardio', equipment: 'Peso corporal', description: 'Ejercicio metabólico'),
  ];

  /// Loads the library from local JSON file.
  /// Should be called before runApp in main.dart.
  Future<void> loadLibrary() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/exercises.json');

      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _exercises = jsonList.map((e) => LibraryExercise.fromJson(e)).toList();
      } else {
        // No local file? We don't load fallback into persistent list here to avoid "contaminating" cache.
        // The list remains empty, prompting a sync.
      }
      _isLoaded = true;
    } catch (e) {
      print('Error loading local library: $e');
      // If load fails, we stay empty, sync will fix.
    }
  }

  /// returns true if sync was successful, false otherwise.
  Future<bool> syncLibrary() async {
    try {
      // Wger API: Language 4 is Spanish.
      String url = 'https://wger.de/api/v2/exercise/?language=4&limit=100';
      List<LibraryExercise> fetchedExercises = [];

      while (url.isNotEmpty) {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          final results = data['results'] as List;

          for (var item in results) {
            final categoryId = item['category'] as int?;
            // Equipment is a list, take first or null
            final equipmentIds = item['equipment'] as List?;
            final equipmentId = (equipmentIds != null && equipmentIds.isNotEmpty)
                ? equipmentIds.first as int
                : 7; // 7 is 'none'

            fetchedExercises.add(LibraryExercise.fromApi(
              item,
              _categoryMap[categoryId] ?? 'Otro',
              _equipmentMap[equipmentId] ?? 'Otro',
            ));
          }

          if (data['next'] != null) {
            url = data['next'];
          } else {
            url = '';
          }
        } else {
          print('API Error: ${response.statusCode}');
          return false;
        }
      }

      if (fetchedExercises.isNotEmpty) {
        _exercises = fetchedExercises;
        await _saveLibraryToLocal();
        await _updateLastSyncDate();
        return true;
      }
      return false;
    } catch (e) {
      print('Sync Error: $e');
      return false;
    }
  }

  /// Returns the current list of exercises.
  /// If empty (and sync failed), returns fallback list temporarily.
  List<LibraryExercise> getExercises() {
    if (_exercises.isNotEmpty) {
      return _exercises;
    }
    return _fallbackExercises;
  }

  Future<void> _saveLibraryToLocal() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/exercises.json');
      final jsonList = _exercises.map((e) => e.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Error saving library: $e');
    }
  }

  Future<void> _updateLastSyncDate() async {
    final box = await Hive.openBox('settings'); // Generic settings box
    await box.put('last_library_sync', DateTime.now().toIso8601String());
  }

  Future<bool> shouldSync() async {
    if (_exercises.isEmpty) return true;

    final box = await Hive.openBox('settings');
    final lastSyncStr = box.get('last_library_sync') as String?;
    if (lastSyncStr == null) return true;

    final lastSync = DateTime.parse(lastSyncStr);
    final difference = DateTime.now().difference(lastSync);
    return difference.inHours > 24; // Sync if older than 24h
  }
}
