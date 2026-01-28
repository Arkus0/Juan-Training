import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/library_exercise.dart';

/// Servicio singleton que gestiona las alternativas de ejercicios.
/// Mapea IDs de ejercicios (String en JSON) a listas de IDs alternativos (int).
class AlternativasService {
  AlternativasService._internal();
  static final AlternativasService instance = AlternativasService._internal();

  // Mapa: ID del ejercicio (String) -> Lista de IDs de alternativas (int)
  Map<String, List<int>> _alternativasIds = {};
  bool _initialized = false;

  /// Inicializa el servicio cargando el JSON de alternativas.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/alternativas.json',
      );
      final Map<String, dynamic> data = json.decode(jsonString);

      // Convertimos el JSON a un mapa tipado correctamente
      _alternativasIds = data.map((key, value) {
        // Aseguramos que la lista sea de enteros
        final ids = (value as List).map((e) => e as int).toList();
        return MapEntry(key, ids);
      });

      _initialized = true;
    } catch (e) {
      // Fallback silencioso
      _alternativasIds = {};
      _initialized = true;
    }
  }

  /// Obtiene la lista COMPLETA de objetos LibraryExercise alternativos.
  /// Requiere [allExercises] (el catálogo completo) para buscar los objetos por ID.
  List<LibraryExercise> getAlternativas({
    required int exerciseId,
    required List<LibraryExercise> allExercises,
  }) {
    if (!_initialized || _alternativasIds.isEmpty) return [];

    // 1. Buscamos si el ID tiene alternativas registradas.
    // Convertimos el ID de entrada (int) a String porque las claves JSON son strings.
    final key = exerciseId.toString();

    if (!_alternativasIds.containsKey(key)) return [];

    final idsAlternativos = _alternativasIds[key]!;

    // 2. Filtramos el catálogo maestro para encontrar los ejercicios correspondientes
    return allExercises
        .where((ejercicio) => idsAlternativos.contains(ejercicio.id))
        .toList();
  }

  /// Verifica si un ejercicio tiene alternativas disponibles usando su ID.
  bool hasAlternativas(int exerciseId) {
    if (!_initialized) return false;
    return _alternativasIds.containsKey(exerciseId.toString());
  }
}
