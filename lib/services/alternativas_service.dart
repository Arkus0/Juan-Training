import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:fuzzy/fuzzy.dart';

/// Servicio singleton que gestiona las alternativas de ejercicios.
/// Carga el JSON una vez y proporciona búsqueda fuzzy eficiente.
class AlternativasService {
  AlternativasService._internal();
  static final AlternativasService instance = AlternativasService._internal();

  Map<String, List<String>> _alternativas = {};
  bool _initialized = false;
  Fuzzy<String>? _fuzzy;

  /// Inicializa el servicio cargando el JSON de alternativas.
  /// Se llama una vez al iniciar la app.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final String jsonString = await rootBundle.loadString(
        'assets/data/alternativas.json'
      );
      final Map<String, dynamic> data = json.decode(jsonString);

      _alternativas = data.map(
        (key, value) => MapEntry(key, List<String>.from(value))
      );

      // Pre-computar índice fuzzy para búsqueda
      final allKeys = _alternativas.keys.toList();
      _fuzzy = Fuzzy<String>(
        allKeys,
        options: FuzzyOptions(threshold: 0.4),
      );

      _initialized = true;
    } catch (e) {
      // Fallback silencioso: servicio funciona pero sin datos
      _alternativas = {};
      _initialized = true;
    }
  }

  /// Obtiene las alternativas para un ejercicio dado.
  /// Usa búsqueda fuzzy para encontrar coincidencias cercanas si no hay exacta.
  List<String> getAlternativas(String ejercicioNombre) {
    if (!_initialized || _alternativas.isEmpty) return [];

    // 1. Búsqueda exacta (case-insensitive)
    final lowerName = ejercicioNombre.toLowerCase().trim();

    for (final entry in _alternativas.entries) {
      if (entry.key.toLowerCase() == lowerName) {
        return List<String>.from(entry.value);
      }
    }

    // 2. Búsqueda fuzzy si no hay coincidencia exacta
    if (_fuzzy != null) {
      final results = _fuzzy!.search(ejercicioNombre);
      if (results.isNotEmpty && results.first.score < 0.3) {
        final bestMatch = results.first.item;
        return List<String>.from(_alternativas[bestMatch] ?? []);
      }
    }

    return [];
  }

  /// Verifica si un ejercicio tiene alternativas disponibles.
  bool hasAlternativas(String ejercicioNombre) {
    return getAlternativas(ejercicioNombre).isNotEmpty;
  }

  /// Busca ejercicios que contengan la query en su nombre.
  /// Útil para sugerir alternativas basadas en búsqueda.
  List<String> searchAlternativas(String query) {
    if (!_initialized || _fuzzy == null) return [];

    return _fuzzy!
        .search(query)
        .take(5)
        .map((r) => r.item)
        .toList();
  }

  /// Obtiene todos los nombres de ejercicios que tienen alternativas.
  List<String> get allExercisesWithAlternatives {
    return _alternativas.keys.toList();
  }
}
