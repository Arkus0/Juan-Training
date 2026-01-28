import 'package:fuzzy/fuzzy.dart';
import 'package:logger/logger.dart';
import '../models/library_exercise.dart';
import 'exercise_library_service.dart';
import 'exercise_synonyms_service.dart';

/// Resultado de matching de ejercicio
class ExerciseMatchResult {
  final LibraryExercise? exercise;
  final double confidence;
  final MatchSource source;
  final String normalizedQuery;
  final String? resolvedSynonym;

  const ExerciseMatchResult({
    this.exercise,
    required this.confidence,
    required this.source,
    required this.normalizedQuery,
    this.resolvedSynonym,
  });

  bool get isValid => exercise != null && confidence >= minValidConfidence;

  /// Umbral mínimo para considerar un match válido
  static const double minValidConfidence = 0.5;

  /// Umbral para match de alta confianza (no requiere confirmación)
  static const double highConfidenceThreshold = 0.8;

  bool get isHighConfidence => confidence >= highConfidenceThreshold;

  @override
  String toString() =>
      'ExerciseMatchResult(exercise: ${exercise?.name}, confidence: ${(confidence * 100).toStringAsFixed(1)}%, source: $source)';
}

/// Fuente del match (para debugging y analytics)
enum MatchSource {
  exactMatch, // Match exacto por nombre normalizado
  synonym, // Match via diccionario de sinónimos
  keyword, // Match por palabras clave contenidas
  fuzzy, // Match por similitud fuzzy
  noMatch, // Sin match
}

/// Servicio UNIFICADO para matching de ejercicios.
///
/// Este servicio centraliza TODA la lógica de matching que antes estaba
/// duplicada entre [RoutineOcrService] y [VoiceInputService].
///
/// Estrategia de matching (4 niveles, en orden de prioridad):
/// 1. **Exacto**: Búsqueda directa en mapa normalizado → confidence 1.0
/// 2. **Sinónimos**: Resolución via ExerciseSynonymsService → confidence 0.95
/// 3. **Keywords**: Palabras clave contenidas en nombre → confidence variable
/// 4. **Fuzzy**: Fuzzy matching como fallback → confidence basada en score
///
/// Uso:
/// ```dart
/// final result = await ExerciseMatchingService.instance.match('press banca');
/// if (result.isValid) {
///   print('Encontrado: ${result.exercise!.name}');
/// }
/// ```
class ExerciseMatchingService {
  static final ExerciseMatchingService instance = ExerciseMatchingService._();
  ExerciseMatchingService._();

  final _logger = Logger();
  final _synonymsService = ExerciseSynonymsService.instance;

  // Cache de ejercicios
  List<LibraryExercise>? _exercisesCache;
  Map<String, LibraryExercise>? _normalizedNameMap;
  Fuzzy<LibraryExercise>? _fuzzyMatcher;

  // Configuración consistente
  static const double _fuzzyThreshold = 0.4; // Balance entre precisión y recall
  static const int _minKeywordLength = 4; // Palabras mínimas para keyword match

  /// Inicializa el cache de ejercicios. Llamar antes de usar match().
  Future<void> initialize() async {
    if (_exercisesCache != null) return;

    final library = ExerciseLibraryService.instance;
    await library.loadLibrary();
    _exercisesCache = library.exercises;

    // Construir mapa de nombres normalizados
    _normalizedNameMap = {};
    for (final ex in _exercisesCache!) {
      final normalized = normalizeText(ex.name);
      _normalizedNameMap![normalized] = ex;

      // También indexar por palabras clave significativas
      final words =
          normalized.split(' ').where((w) => w.length >= _minKeywordLength);
      for (final word in words) {
        _normalizedNameMap!.putIfAbsent(word, () => ex);
      }
    }

    // Construir fuzzy matcher
    _fuzzyMatcher = Fuzzy<LibraryExercise>(
      _exercisesCache!,
      options: FuzzyOptions(
        keys: [
          WeightedKey(
            name: 'name',
            getter: (ex) => normalizeText(ex.name),
            weight: 1.0,
          ),
        ],
        threshold: _fuzzyThreshold,
        findAllMatches: true,
      ),
    );

    _logger.i(
        'ExerciseMatchingService inicializado con ${_exercisesCache!.length} ejercicios',);
  }

  /// Invalida el cache (llamar si la biblioteca de ejercicios cambia)
  void invalidateCache() {
    _exercisesCache = null;
    _normalizedNameMap = null;
    _fuzzyMatcher = null;
    _logger.d('Cache de ejercicios invalidado');
  }

  /// Busca un ejercicio por texto, aplicando la estrategia de matching multi-nivel.
  ///
  /// [query] Texto a buscar (nombre de ejercicio, posiblemente con errores)
  /// [boostSynonyms] Si true, aumenta confianza cuando se resuelve via sinónimo
  ///
  /// Retorna [ExerciseMatchResult] con el ejercicio encontrado (o null) y metadatos.
  Future<ExerciseMatchResult> match(String query,
      {bool boostSynonyms = true,}) async {
    await initialize();

    final normalizedQuery = normalizeText(query);

    if (normalizedQuery.isEmpty || normalizedQuery.length < 2) {
      return ExerciseMatchResult(
        confidence: 0.0,
        source: MatchSource.noMatch,
        normalizedQuery: normalizedQuery,
      );
    }

    // NIVEL 1: Match exacto
    if (_normalizedNameMap!.containsKey(normalizedQuery)) {
      final exercise = _normalizedNameMap![normalizedQuery]!;
      _logger.d('Match exacto: "$normalizedQuery" → "${exercise.name}"');
      return ExerciseMatchResult(
        exercise: exercise,
        confidence: 1.0,
        source: MatchSource.exactMatch,
        normalizedQuery: normalizedQuery,
      );
    }

    // NIVEL 2: Resolución de sinónimos
    String? resolvedSynonym;
    if (_synonymsService.hasSynonym(query)) {
      resolvedSynonym = _synonymsService.resolveSynonym(query);
      final normalizedSynonym = normalizeText(resolvedSynonym);

      // Buscar el sinónimo resuelto en el mapa
      if (_normalizedNameMap!.containsKey(normalizedSynonym)) {
        final exercise = _normalizedNameMap![normalizedSynonym]!;
        _logger.d(
            'Match por sinónimo: "$query" → "$resolvedSynonym" → "${exercise.name}"',);
        return ExerciseMatchResult(
          exercise: exercise,
          confidence: 0.95,
          source: MatchSource.synonym,
          normalizedQuery: normalizedQuery,
          resolvedSynonym: resolvedSynonym,
        );
      }

      // Si el sinónimo no matchea exacto, hacer fuzzy con el sinónimo resuelto
      final fuzzyResult = await _fuzzyMatch(normalizedSynonym);
      if (fuzzyResult.isValid) {
        final boostedConfidence = boostSynonyms
            ? (fuzzyResult.confidence + 0.15).clamp(0.0, 1.0)
            : fuzzyResult.confidence;
        return ExerciseMatchResult(
          exercise: fuzzyResult.exercise,
          confidence: boostedConfidence,
          source: MatchSource.synonym,
          normalizedQuery: normalizedQuery,
          resolvedSynonym: resolvedSynonym,
        );
      }
    }

    // NIVEL 3: Match por palabras clave
    final keywordResult = _findByKeywords(normalizedQuery);
    if (keywordResult != null) {
      _logger.d(
          'Match por keywords: "$normalizedQuery" → "${keywordResult.exercise.name}" (${(keywordResult.confidence * 100).toInt()}%)',);
      return ExerciseMatchResult(
        exercise: keywordResult.exercise,
        confidence: keywordResult.confidence,
        source: MatchSource.keyword,
        normalizedQuery: normalizedQuery,
        resolvedSynonym: resolvedSynonym,
      );
    }

    // NIVEL 4: Fuzzy matching
    final fuzzyResult = await _fuzzyMatch(normalizedQuery);
    if (fuzzyResult.exercise != null) {
      _logger.d(
          'Match fuzzy: "$normalizedQuery" → "${fuzzyResult.exercise!.name}" (${(fuzzyResult.confidence * 100).toInt()}%)',);
    }

    return ExerciseMatchResult(
      exercise: fuzzyResult.exercise,
      confidence: fuzzyResult.confidence,
      source: fuzzyResult.exercise != null
          ? MatchSource.fuzzy
          : MatchSource.noMatch,
      normalizedQuery: normalizedQuery,
      resolvedSynonym: resolvedSynonym,
    );
  }

  /// Busca múltiples candidatos para una query (útil para mostrar alternativas)
  Future<List<ExerciseMatchResult>> matchMultiple(String query,
      {int limit = 5,}) async {
    await initialize();

    final normalizedQuery = normalizeText(query);
    if (normalizedQuery.isEmpty || _fuzzyMatcher == null) return [];

    final results = _fuzzyMatcher!.search(normalizedQuery);
    return results.take(limit).map((r) {
      final confidence = 1.0 - r.score;
      return ExerciseMatchResult(
        exercise: r.item,
        confidence: confidence,
        source: MatchSource.fuzzy,
        normalizedQuery: normalizedQuery,
      );
    }).toList();
  }

  /// Obtiene un ejercicio por ID
  Future<LibraryExercise?> getById(int id) async {
    await initialize();
    try {
      return _exercisesCache?.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  // --- Métodos privados ---

  Future<ExerciseMatchResult> _fuzzyMatch(String normalizedQuery) async {
    if (_fuzzyMatcher == null) {
      return ExerciseMatchResult(
        confidence: 0.0,
        source: MatchSource.noMatch,
        normalizedQuery: normalizedQuery,
      );
    }

    final results = _fuzzyMatcher!.search(normalizedQuery);
    if (results.isEmpty) {
      return ExerciseMatchResult(
        confidence: 0.0,
        source: MatchSource.noMatch,
        normalizedQuery: normalizedQuery,
      );
    }

    final best = results.first;
    // Score en Fuzzy: 0 = perfecto, 1 = sin match
    final confidence = 1.0 - best.score;

    return ExerciseMatchResult(
      exercise: confidence >= 0.3
          ? best.item
          : null, // Umbral mínimo para retornar algo
      confidence: confidence,
      source: MatchSource.fuzzy,
      normalizedQuery: normalizedQuery,
    );
  }

  _KeywordMatchResult? _findByKeywords(String normalizedQuery) {
    if (_exercisesCache == null) return null;

    final searchWords = normalizedQuery
        .split(' ')
        .where((w) => w.length >= _minKeywordLength)
        .toList();
    if (searchWords.isEmpty) return null;

    LibraryExercise? bestMatch;
    var bestScore = 0;

    for (final ex in _exercisesCache!) {
      final exName = normalizeText(ex.name);
      final exWords = exName.split(' ');

      var matchCount = 0;
      for (final searchWord in searchWords) {
        for (final exWord in exWords) {
          if (exWord.contains(searchWord) || searchWord.contains(exWord)) {
            matchCount++;
            break;
          }
        }
      }

      // Bonus si el nombre completo está contenido
      if (exName.contains(normalizedQuery) ||
          normalizedQuery.contains(exName)) {
        matchCount += 2;
      }

      if (matchCount > bestScore) {
        bestScore = matchCount;
        bestMatch = ex;
      }
    }

    if (bestMatch != null && bestScore >= 1) {
      final confidence =
          (bestScore / (searchWords.length + 1)).clamp(0.5, 0.85);
      return _KeywordMatchResult(bestMatch, confidence);
    }

    return null;
  }

  /// Normaliza texto para búsqueda: minúsculas, sin acentos, sin caracteres especiales
  ///
  /// IMPORTANTE: Esta es la ÚNICA función de normalización que debe usarse
  /// en todo el codebase para consistencia.
  static String normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _KeywordMatchResult {
  final LibraryExercise exercise;
  final double confidence;

  _KeywordMatchResult(this.exercise, this.confidence);
}
