import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/exercises/search/exercise_search_engine.dart';
import '../models/library_exercise.dart';
import '../services/exercise_library_service.dart';

final exerciseSearchEngineProvider = Provider<ExerciseSearchEngine>((ref) {
  return const ExerciseSearchEngine();
});

final exercisesProvider = StreamProvider<List<LibraryExercise>>((ref) {
  final controller = StreamController<List<LibraryExercise>>.broadcast();
  final notifier = ExerciseLibraryService.instance.exercisesNotifier;

  void listener() {
    controller.add(List<LibraryExercise>.from(notifier.value));
  }

  notifier.addListener(listener);
  controller.add(List<LibraryExercise>.from(notifier.value));

  ref.onDispose(() {
    notifier.removeListener(listener);
    controller.close();
  });

  return controller.stream;
});

final exerciseSearchIndexProvider = Provider.autoDispose<ExerciseSearchIndex>((ref) {
  ref.keepAlive();
  final exercises = ref.watch(exercisesProvider).value ?? const <LibraryExercise>[];
  return ExerciseSearchIndex.build(exercises);
});

final exerciseSearchQueryProvider = StateProvider<String>((ref) => '');

class ExerciseSearchFiltersState {
  final String? muscleGroup;
  final String? equipment;
  final bool favoritesOnly;

  const ExerciseSearchFiltersState({
    this.muscleGroup,
    this.equipment,
    this.favoritesOnly = false,
  });

  ExerciseSearchFiltersState copyWith({
    String? muscleGroup,
    String? equipment,
    bool? favoritesOnly,
  }) {
    return ExerciseSearchFiltersState(
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    );
  }
}

class ExerciseSearchFiltersNotifier
    extends StateNotifier<ExerciseSearchFiltersState> {
  ExerciseSearchFiltersNotifier() : super(const ExerciseSearchFiltersState());

  void setMuscleGroup(String? value) {
    state = state.copyWith(muscleGroup: value);
  }

  void setEquipment(String? value) {
    state = state.copyWith(equipment: value);
  }

  void setFavoritesOnly(bool value) {
    state = state.copyWith(favoritesOnly: value);
  }

  void clear() {
    state = const ExerciseSearchFiltersState();
  }
}

final exerciseSearchFiltersProvider =
    StateNotifierProvider<ExerciseSearchFiltersNotifier, ExerciseSearchFiltersState>(
  (ref) => ExerciseSearchFiltersNotifier(),
);

final availableMuscleGroupsProvider = Provider<List<String>>((ref) {
  final exercises = ref.watch(exercisesProvider).value ?? const <LibraryExercise>[];
  final groups = exercises.map((e) => e.muscleGroup).toSet().toList();
  groups.sort();
  return groups;
});

final availableEquipmentProvider = Provider<List<String>>((ref) {
  final exercises = ref.watch(exercisesProvider).value ?? const <LibraryExercise>[];
  final equipment = exercises.map((e) => e.equipment).toSet().toList();
  equipment.sort();
  return equipment;
});

final exerciseSearchResultsProvider =
    FutureProvider.autoDispose<List<LibraryExercise>>((ref) async {
  final query = ref.watch(exerciseSearchQueryProvider);
  final filtersState = ref.watch(exerciseSearchFiltersProvider);
  final index = ref.watch(exerciseSearchIndexProvider);
  final engine = ref.watch(exerciseSearchEngineProvider);

  var cancelled = false;
  ref.onDispose(() {
    cancelled = true;
  });

  await Future.delayed(const Duration(milliseconds: 200));
  if (cancelled) return const <LibraryExercise>[];

  final limit = query.trim().isEmpty ? index.totalCount : 200;

  return engine.searchWithIndex(
    query,
    index,
    filters: SearchFilters(
      muscleGroup: filtersState.muscleGroup,
      equipment: filtersState.equipment,
      favoritesOnly: filtersState.favoritesOnly,
    ),
    limit: limit,
  );
});

final exerciseSearchSuggestionsProvider =
    FutureProvider.autoDispose<List<LibraryExercise>>((ref) async {
  final query = ref.watch(exerciseSearchQueryProvider);
  if (query.trim().isEmpty) return const <LibraryExercise>[];

  final results = await ref.watch(exerciseSearchResultsProvider.future);
  if (results.isNotEmpty) return const <LibraryExercise>[];

  final filtersState = ref.watch(exerciseSearchFiltersProvider);
  final index = ref.watch(exerciseSearchIndexProvider);
  final engine = ref.watch(exerciseSearchEngineProvider);

  return engine.suggest(
    query,
    index,
    filters: SearchFilters(
      muscleGroup: filtersState.muscleGroup,
      equipment: filtersState.equipment,
      favoritesOnly: filtersState.favoritesOnly,
    ),
    limit: 3,
  );
});
