import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/library_exercise.dart';
import '../services/exercise_library_service.dart';
import '../utils/performance_utils.dart';

/// Estado de la lista paginada de ejercicios
class PaginatedExercisesState {
  /// Ejercicios actualmente visibles
  final List<LibraryExercise> visibleExercises;

  /// Total de ejercicios disponibles (después de filtrar)
  final int totalCount;

  /// Número de ejercicios cargados
  final int loadedCount;

  /// Si hay más ejercicios por cargar
  final bool hasMore;

  /// Si está cargando más
  final bool isLoading;

  /// Query de búsqueda actual
  final String searchQuery;

  /// Filtro de grupo muscular
  final String? muscleFilter;

  /// Filtro de equipamiento
  final String? equipmentFilter;

  /// Si solo mostrar favoritos
  final bool favoritesOnly;

  const PaginatedExercisesState({
    this.visibleExercises = const [],
    this.totalCount = 0,
    this.loadedCount = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.searchQuery = '',
    this.muscleFilter,
    this.equipmentFilter,
    this.favoritesOnly = false,
  });

  PaginatedExercisesState copyWith({
    List<LibraryExercise>? visibleExercises,
    int? totalCount,
    int? loadedCount,
    bool? hasMore,
    bool? isLoading,
    String? searchQuery,
    String? muscleFilter,
    String? equipmentFilter,
    bool? favoritesOnly,
  }) {
    return PaginatedExercisesState(
      visibleExercises: visibleExercises ?? this.visibleExercises,
      totalCount: totalCount ?? this.totalCount,
      loadedCount: loadedCount ?? this.loadedCount,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      muscleFilter: muscleFilter,
      equipmentFilter: equipmentFilter,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    );
  }
}

/// Notifier para gestionar la paginación de ejercicios
///
/// Optimizaciones:
/// - Carga inicial pequeña (20 items)
/// - Carga incremental (20 más al hacer scroll)
/// - Búsqueda con debounce
/// - Filtros en memoria (no queries DB)
/// - Memoization de resultados filtrados
class PaginatedExercisesNotifier extends StateNotifier<PaginatedExercisesState> {
  static const int _pageSize = 20;
  static const int _initialLoad = 20;

  List<LibraryExercise> _allExercises = [];
  List<LibraryExercise> _filteredExercises = [];
  final Debouncer _searchDebouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );

  // Cache de resultados de filtrado
  final MemoCache<String, List<LibraryExercise>> _filterCache = MemoCache(
    expiration: const Duration(minutes: 5),
  );

  PaginatedExercisesNotifier() : super(const PaginatedExercisesState()) {
    _initialize();
  }

  void _initialize() {
    _allExercises = ExerciseLibraryService.instance.exercises;
    _filteredExercises = _allExercises;
    _loadInitial();

    // Escuchar cambios en la biblioteca
    ExerciseLibraryService.instance.exercisesNotifier.addListener(_onLibraryUpdate);
  }

  void _onLibraryUpdate() {
    _allExercises = ExerciseLibraryService.instance.exercises;
    _applyFilters();
  }

  void _loadInitial() {
    final initialItems = _filteredExercises.take(_initialLoad).toList();
    state = state.copyWith(
      visibleExercises: initialItems,
      totalCount: _filteredExercises.length,
      loadedCount: initialItems.length,
      hasMore: _filteredExercises.length > _initialLoad,
      isLoading: false,
    );
  }

  /// Cargar más ejercicios (lazy loading)
  void loadMore() {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    // Simular carga async para no bloquear UI
    Future.microtask(() {
      final currentCount = state.loadedCount;
      final nextBatch = _filteredExercises
          .skip(currentCount)
          .take(_pageSize)
          .toList();

      final newList = [...state.visibleExercises, ...nextBatch];

      state = state.copyWith(
        visibleExercises: newList,
        loadedCount: newList.length,
        hasMore: newList.length < _filteredExercises.length,
        isLoading: false,
      );
    });
  }

  /// Buscar ejercicios con debounce
  void search(String query) {
    _searchDebouncer.run(() {
      state = state.copyWith(searchQuery: query);
      _applyFilters();
    });
  }

  /// Buscar inmediatamente (sin debounce)
  void searchImmediate(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  /// Filtrar por grupo muscular
  void setMuscleFilter(String? muscle) {
    state = state.copyWith(muscleFilter: muscle);
    _applyFilters();
  }

  /// Filtrar por equipamiento
  void setEquipmentFilter(String? equipment) {
    state = state.copyWith(equipmentFilter: equipment);
    _applyFilters();
  }

  /// Mostrar solo favoritos
  void setFavoritesOnly(bool value) {
    state = state.copyWith(favoritesOnly: value);
    _applyFilters();
  }

  /// Limpiar todos los filtros
  void clearFilters() {
    state = PaginatedExercisesState();
    _filteredExercises = _allExercises;
    _loadInitial();
  }

  void _applyFilters() {
    // Crear key para cache
    final cacheKey = '${state.searchQuery}_${state.muscleFilter}_'
        '${state.equipmentFilter}_${state.favoritesOnly}';

    _filteredExercises = _filterCache.getOrCompute(cacheKey, () {
      var result = _allExercises;

      // Filtrar por búsqueda
      if (state.searchQuery.isNotEmpty) {
        final queryLower = state.searchQuery.toLowerCase();
        result = result.where((e) {
          return e.name.toLowerCase().contains(queryLower) ||
              e.muscleGroup.toLowerCase().contains(queryLower) ||
              (e.muscles.any((m) => m.toLowerCase().contains(queryLower)));
        }).toList();
      }

      // Filtrar por grupo muscular
      if (state.muscleFilter != null && state.muscleFilter!.isNotEmpty) {
        result = result.where((e) =>
            e.muscleGroup.toLowerCase() == state.muscleFilter!.toLowerCase()
        ).toList();
      }

      // Filtrar por equipamiento
      if (state.equipmentFilter != null && state.equipmentFilter!.isNotEmpty) {
        result = result.where((e) =>
            e.equipment.toLowerCase() == state.equipmentFilter!.toLowerCase()
        ).toList();
      }

      // Filtrar favoritos
      if (state.favoritesOnly) {
        result = result.where((e) => e.isFavorite).toList();
      }

      return result;
    });

    _loadInitial();
  }

  /// Obtener grupos musculares disponibles (para filtros)
  List<String> get availableMuscleGroups {
    final groups = _allExercises.map((e) => e.muscleGroup).toSet().toList();
    groups.sort();
    return groups;
  }

  /// Obtener equipamientos disponibles (para filtros)
  List<String> get availableEquipment {
    final equipment = _allExercises.map((e) => e.equipment).toSet().toList();
    equipment.sort();
    return equipment;
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    ExerciseLibraryService.instance.exercisesNotifier.removeListener(_onLibraryUpdate);
    super.dispose();
  }
}

/// Provider principal para ejercicios paginados
final paginatedExercisesProvider = StateNotifierProvider<
    PaginatedExercisesNotifier, PaginatedExercisesState>(
  (ref) => PaginatedExercisesNotifier(),
);

/// Provider de conveniencia para el total de ejercicios
final totalExercisesCountProvider = Provider<int>((ref) {
  return ref.watch(paginatedExercisesProvider).totalCount;
});

/// Provider de conveniencia para verificar si hay más
final hasMoreExercisesProvider = Provider<bool>((ref) {
  return ref.watch(paginatedExercisesProvider).hasMore;
});

/// Provider de conveniencia para verificar si está cargando
final isLoadingExercisesProvider = Provider<bool>((ref) {
  return ref.watch(paginatedExercisesProvider).isLoading;
});
