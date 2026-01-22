import 'dart:convert';
import 'package:flutter/services.dart';

/// Servicio singleton que gestiona las alternativas de ejercicios.
/// Carga el JSON una vez y proporciona búsqueda por ID.
class AlternativasService {
  AlternativasService._internal();
  static final AlternativasService instance = AlternativasService._internal();

  // Mapa de ID (String) -> Lista de IDs Alternativos (int)
  Map<String, List<int>> _alternativas = {};
  bool _initialized = false;

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
        (key, value) => MapEntry(key, List<int>.from(value))
      );

      _initialized = true;
    } catch (e) {
      // Fallback silencioso: servicio funciona pero sin datos
      _alternativas = {};
      _initialized = true;
    }
  }

  /// Obtiene las alternativas para un ejercicio dado (por ID).
  /// Retorna una lista de IDs de ejercicios alternativos.
  List<int> getAlternativasIds(String exerciseId) {
    if (!_initialized || _alternativas.isEmpty) return [];
    return List<int>.from(_alternativas[exerciseId] ?? []);
  }

  /// Verifica si un ejercicio tiene alternativas disponibles.
  bool hasAlternativas(String exerciseId) {
    return _alternativas.containsKey(exerciseId);
  }
}
