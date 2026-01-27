import 'dart:math';

import '../../../models/library_exercise.dart';
import 'exercise_aliases.dart';

String normalize(String input) {
  if (input.trim().isEmpty) return '';

  final lower = input.toLowerCase();
  final buffer = StringBuffer();

  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_diacriticsMap[char] ?? char);
  }

  final withoutDiacritics = buffer.toString();
  final withoutPunctuation =
      withoutDiacritics.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  final normalized =
      withoutPunctuation.replaceAll(RegExp(r'\s+'), ' ').trim();

  return normalized;
}

List<String> tokenize(String input) {
  final normalized = normalize(input);
  if (normalized.isEmpty) return const [];
  final tokens = normalized.split(' ');
  if (tokens.length <= 1) return tokens;
  return tokens.where((t) => !_stopwords.contains(t)).toList();
}

const Map<String, String> _diacriticsMap = {
  'á': 'a',
  'é': 'e',
  'í': 'i',
  'ó': 'o',
  'ú': 'u',
  'ü': 'u',
  'ñ': 'n',
};

const Set<String> _stopwords = {
  'de',
  'la',
  'el',
  'los',
  'las',
  'del',
  'y',
  'en',
  'para',
  'por',
};

class SearchFilters {
  final String? muscleGroup;
  final String? equipment;
  final bool favoritesOnly;

  const SearchFilters({
    this.muscleGroup,
    this.equipment,
    this.favoritesOnly = false,
  });

  SearchFilters copyWith({
    String? muscleGroup,
    String? equipment,
    bool? favoritesOnly,
  }) {
    return SearchFilters(
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    );
  }
}

class ExerciseSearchEntry {
  final LibraryExercise exercise;
  final String nameNorm;
  final List<String> tokens;
  final Set<String> tokenSet;
  final String muscleGroupNorm;
  final String equipmentNorm;
  final Set<String> muscleTokens;

  ExerciseSearchEntry({
    required this.exercise,
    required this.nameNorm,
    required this.tokens,
    required this.tokenSet,
    required this.muscleGroupNorm,
    required this.equipmentNorm,
    required this.muscleTokens,
  });

  factory ExerciseSearchEntry.fromExercise(LibraryExercise exercise) {
    final nameNorm = normalize(exercise.name);
    final tokens = tokenize(nameNorm);
    final muscleTokens = <String>{
      ...tokenize(exercise.muscleGroup),
      ...exercise.muscles.expand(tokenize),
      ...exercise.secondaryMuscles.expand(tokenize),
    };

    return ExerciseSearchEntry(
      exercise: exercise,
      nameNorm: nameNorm,
      tokens: tokens,
      tokenSet: tokens.toSet(),
      muscleGroupNorm: normalize(exercise.muscleGroup),
      equipmentNorm: normalize(exercise.equipment),
      muscleTokens: muscleTokens,
    );
  }
}

class ExerciseSearchIndex {
  final Map<int, ExerciseSearchEntry> entriesById;
  final Map<String, List<int>> invertedIndex;
  final List<LibraryExercise> sortedExercises;

  ExerciseSearchIndex._({
    required this.entriesById,
    required this.invertedIndex,
    required this.sortedExercises,
  });

  factory ExerciseSearchIndex.build(List<LibraryExercise> exercises) {
    final entriesById = <int, ExerciseSearchEntry>{};
    final invertedIndex = <String, List<int>>{};

    for (final exercise in exercises) {
      final entry = ExerciseSearchEntry.fromExercise(exercise);
      entriesById[exercise.id] = entry;
      for (final token in entry.tokens) {
        invertedIndex.putIfAbsent(token, () => <int>[]).add(exercise.id);
      }
      for (final token in entry.muscleTokens) {
        invertedIndex.putIfAbsent(token, () => <int>[]).add(exercise.id);
      }
    }

    final sortedEntries = entriesById.values.toList()
      ..sort((a, b) => a.nameNorm.compareTo(b.nameNorm));

    return ExerciseSearchIndex._(
      entriesById: entriesById,
      invertedIndex: invertedIndex,
      sortedExercises: sortedEntries.map((e) => e.exercise).toList(),
    );
  }

  int get totalCount => entriesById.length;
}

class ExerciseSearchEngine {
  final Map<String, List<String>> aliases;
  final int maxCandidates;
  final int maxFuzzyCandidates;
  final int maxAliasExpansions;

  const ExerciseSearchEngine({
    this.aliases = exerciseAliases,
    this.maxCandidates = 400,
    this.maxFuzzyCandidates = 400,
    this.maxAliasExpansions = 8,
  });

  List<LibraryExercise> search({
    required String query,
    required List<LibraryExercise> allExercises,
    SearchFilters? filters,
    int limit = 50,
  }) {
    final index = ExerciseSearchIndex.build(allExercises);
    return searchWithIndex(
      query,
      index,
      filters: filters,
      limit: limit,
    );
  }

  List<LibraryExercise> searchWithIndex(
    String query,
    ExerciseSearchIndex index, {
    SearchFilters? filters,
    int limit = 50,
  }) {
    final queryInfo = _buildQueryInfo(query);
    if (queryInfo.normalized.isEmpty) {
      return index.sortedExercises.take(limit).toList();
    }

    final candidates = _collectCandidates(queryInfo, index);
    final entries = candidates
        .map((id) => index.entriesById[id])
        .whereType<ExerciseSearchEntry>()
        .where((entry) => _passesFilters(entry, filters))
        .toList();

    final scored = <_ScoredEntry>[];
    for (final entry in entries) {
      final score = _scoreExercise(queryInfo, entry);
      if (score > 0) {
        scored.add(_ScoredEntry(entry: entry, score: score));
      }
    }

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      final nameCompare = a.entry.nameNorm.compareTo(b.entry.nameNorm);
      if (nameCompare != 0) return nameCompare;
      return a.entry.exercise.id.compareTo(b.entry.exercise.id);
    });

    return scored.take(limit).map((e) => e.entry.exercise).toList();
  }

  List<LibraryExercise> suggest(
    String query,
    ExerciseSearchIndex index, {
    SearchFilters? filters,
    int limit = 3,
  }) {
    final queryInfo = _buildQueryInfo(query);
    if (queryInfo.normalized.isEmpty) return const [];

    final candidates = _collectCandidates(queryInfo, index);
    if (candidates.isEmpty) return const [];

    final scored = <_ScoredEntry>[];
    for (final id in candidates.take(maxFuzzyCandidates)) {
      final entry = index.entriesById[id];
      if (entry == null || !_passesFilters(entry, filters)) continue;
      final fuzzyScore = _fuzzyScore(queryInfo.normalized, entry.nameNorm);
      if (fuzzyScore != null) {
        scored.add(_ScoredEntry(entry: entry, score: fuzzyScore));
      }
    }

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return a.entry.nameNorm.compareTo(b.entry.nameNorm);
    });

    return scored.take(limit).map((e) => e.entry.exercise).toList();
  }

  bool _passesFilters(ExerciseSearchEntry entry, SearchFilters? filters) {
    if (filters == null) return true;

    if (filters.favoritesOnly && !entry.exercise.isFavorite) return false;

    if (filters.muscleGroup != null && filters.muscleGroup!.isNotEmpty) {
      final target = normalize(filters.muscleGroup!);
      if (entry.muscleGroupNorm != target) return false;
    }

    if (filters.equipment != null && filters.equipment!.isNotEmpty) {
      final target = normalize(filters.equipment!);
      if (entry.equipmentNorm != target) return false;
    }

    return true;
  }

  _QueryInfo _buildQueryInfo(String query) {
    final normalized = normalize(query);
    final tokens = tokenize(normalized);
    final aliasTokens = <String>{};
    final expandedTokens = <String>{};

    void addAliases(String key) {
      if (expandedTokens.length >= maxAliasExpansions) return;
      final aliasList = aliases[key];
      if (aliasList == null) return;
      for (final alias in aliasList) {
        final aliasNorm = normalize(alias);
        if (aliasNorm.isEmpty) continue;
        for (final token in tokenize(aliasNorm)) {
          if (expandedTokens.length >= maxAliasExpansions) return;
          if (token.isEmpty) continue;
          expandedTokens.add(token);
          aliasTokens.add(token);
        }
      }
    }

    if (normalized.isNotEmpty) {
      addAliases(normalized);
    }
    for (final token in tokens) {
      addAliases(token);
    }

    final allTokens = <String>{...tokens, ...expandedTokens}.toList();

    return _QueryInfo(
      normalized: normalized,
      tokens: tokens,
      allTokens: allTokens,
      aliasTokens: aliasTokens,
    );
  }

  Set<int> _collectCandidates(
    _QueryInfo query,
    ExerciseSearchIndex index,
  ) {
    final candidates = <int>{};

    void addFromToken(String token) {
      final matches = index.invertedIndex[token];
      if (matches != null) {
        candidates.addAll(matches);
      }
    }

    for (final token in query.allTokens) {
      if (token.isEmpty) continue;
      addFromToken(token);
    }

    if (candidates.isEmpty) {
      for (final token in query.tokens) {
        final prefix = token.substring(0, min(3, token.length));
        if (prefix.isEmpty) continue;
        for (final entry in index.invertedIndex.entries) {
          if (entry.key.startsWith(prefix)) {
            candidates.addAll(entry.value);
            if (candidates.length >= maxCandidates) {
              return candidates.take(maxCandidates).toSet();
            }
          }
        }
      }
    }

    if (candidates.length > maxCandidates) {
      final sorted = candidates.toList()
        ..sort((a, b) {
          final aEntry = index.entriesById[a];
          final bEntry = index.entriesById[b];
          if (aEntry == null || bEntry == null) return 0;
          return aEntry.nameNorm.compareTo(bEntry.nameNorm);
        });
      return sorted.take(maxCandidates).toSet();
    }

    return candidates;
  }

  int _scoreExercise(_QueryInfo query, ExerciseSearchEntry entry) {
    final normalized = query.normalized;
    final nameNorm = entry.nameNorm;
    if (normalized == nameNorm) return 100;
    if (normalized.isNotEmpty && nameNorm.startsWith(normalized)) return 80;

    final tokenSet = entry.tokenSet;
    final tokens = query.allTokens;
    if (tokens.isNotEmpty) {
      final matches = tokens.where(tokenSet.contains).toList();
      if (matches.length == tokens.length) {
        return max(10, 60 - _aliasPenalty(matches, query.aliasTokens));
      }

      if (matches.isNotEmpty) {
        final missing = tokens.length - matches.length;
        final penalty = (missing * 5) + _aliasPenalty(matches, query.aliasTokens);
        return max(5, 40 - penalty);
      }
    }

    final fuzzyScore = _fuzzyScore(normalized, nameNorm);
    return fuzzyScore ?? 0;
  }

  int _aliasPenalty(List<String> matches, Set<String> aliasTokens) {
    if (aliasTokens.isEmpty) return 0;
    final aliasMatches = matches.where(aliasTokens.contains).length;
    return aliasMatches * 3;
  }

  int? _fuzzyScore(String query, String name) {
    if (query.isEmpty || name.isEmpty) return null;

    final maxDistance = max(2, (query.length * 0.25).round());
    final distance = _levenshteinDistance(query, name, maxDistance: maxDistance);
    if (distance == null) return null;

    final maxLen = max(query.length, name.length);
    final similarity = 1 - (distance / maxLen);
    if (similarity < 0.74) return null;

    final score = 20 + ((similarity - 0.74) * 30).round();
    return score.clamp(20, 35);
  }
}

class _QueryInfo {
  final String normalized;
  final List<String> tokens;
  final List<String> allTokens;
  final Set<String> aliasTokens;

  _QueryInfo({
    required this.normalized,
    required this.tokens,
    required this.allTokens,
    required this.aliasTokens,
  });
}

class _ScoredEntry {
  final ExerciseSearchEntry entry;
  final int score;

  _ScoredEntry({
    required this.entry,
    required this.score,
  });
}

int? _levenshteinDistance(
  String source,
  String target, {
  int maxDistance = 2,
}) {
  if (source == target) return 0;
  if ((source.length - target.length).abs() > maxDistance) return null;

  final sourceLength = source.length;
  final targetLength = target.length;
  final prev = List<int>.generate(targetLength + 1, (i) => i);
  final curr = List<int>.filled(targetLength + 1, 0);

  for (var i = 1; i <= sourceLength; i++) {
    curr[0] = i;
    var minInRow = curr[0];
    final sourceChar = source.codeUnitAt(i - 1);

    for (var j = 1; j <= targetLength; j++) {
      final targetChar = target.codeUnitAt(j - 1);
      final cost = sourceChar == targetChar ? 0 : 1;
      curr[j] = min(
        min(curr[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
      if (curr[j] < minInRow) {
        minInRow = curr[j];
      }
    }

    if (minInRow > maxDistance) return null;

    for (var j = 0; j <= targetLength; j++) {
      prev[j] = curr[j];
    }
  }

  return prev[targetLength] <= maxDistance ? prev[targetLength] : null;
}
