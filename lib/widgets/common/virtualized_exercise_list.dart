import '../../utils/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/library_exercise.dart';
import '../../providers/paginated_exercises_provider.dart';
import 'optimized_exercise_image.dart';

/// Lista virtualizada de ejercicios para la biblioteca (700+ items)
///
/// Optimizaciones:
/// - Solo renderiza items visibles (ListView.builder)
/// - Lazy loading automático al hacer scroll
/// - Placeholder skeleton durante carga
/// - RepaintBoundary por item
/// - Cache de items renderizados
class VirtualizedExerciseList extends ConsumerStatefulWidget {
  /// Callback cuando se selecciona un ejercicio
  final ValueChanged<LibraryExercise>? onExerciseSelected;

  /// Si permite selección múltiple
  final bool multiSelect;

  /// Ejercicios ya seleccionados (para multiSelect)
  final Set<int>? selectedIds;

  /// Callback cuando cambia la selección (multiSelect)
  final ValueChanged<Set<int>>? onSelectionChanged;

  /// Altura de cada item
  final double itemHeight;

  /// Mostrar indicador de favoritos
  final bool showFavorites;

  /// Callback para toggle favorite
  final ValueChanged<int>? onToggleFavorite;

  const VirtualizedExerciseList({
    super.key,
    this.onExerciseSelected,
    this.multiSelect = false,
    this.selectedIds,
    this.onSelectionChanged,
    this.itemHeight = 72,
    this.showFavorites = true,
    this.onToggleFavorite,
  });

  @override
  ConsumerState<VirtualizedExerciseList> createState() =>
      _VirtualizedExerciseListState();
}

class _VirtualizedExerciseListState
    extends ConsumerState<VirtualizedExerciseList> {
  final ScrollController _scrollController = ScrollController();
  Set<int> _localSelectedIds = {};

  @override
  void initState() {
    super.initState();
    _localSelectedIds = widget.selectedIds?.toSet() ?? {};
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(VirtualizedExerciseList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIds != oldWidget.selectedIds) {
      _localSelectedIds = widget.selectedIds?.toSet() ?? {};
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Cargar más cuando estamos cerca del final
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedExercisesProvider.notifier).loadMore();
    }
  }

  void _handleTap(LibraryExercise exercise) {
    if (widget.multiSelect) {
      setState(() {
        if (_localSelectedIds.contains(exercise.id)) {
          _localSelectedIds.remove(exercise.id);
        } else {
          _localSelectedIds.add(exercise.id);
        }
      });
      widget.onSelectionChanged?.call(_localSelectedIds);
    } else {
      widget.onExerciseSelected?.call(exercise);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paginatedExercisesProvider);

    if (state.visibleExercises.isEmpty && !state.isLoading) {
      return const _EmptyState();
    }

    return Column(
      children: [
        // Header con conteo
        _ListHeader(
          total: state.totalCount,
          loaded: state.loadedCount,
          hasMore: state.hasMore,
        ),

        // Lista virtualizada
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              decelerationRate: ScrollDecelerationRate.fast,
            ),
            cacheExtent: 250, // Pre-renderizar items fuera de vista
            itemCount: state.visibleExercises.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Item de carga al final
              if (index >= state.visibleExercises.length) {
                return const _LoadingIndicator();
              }

              final exercise = state.visibleExercises[index];
              final isSelected = _localSelectedIds.contains(exercise.id);

              return RepaintBoundary(
                child: _ExerciseListItem(
                  key: ValueKey(exercise.id),
                  exercise: exercise,
                  height: widget.itemHeight,
                  isSelected: isSelected,
                  showFavorite: widget.showFavorites,
                  onTap: () => _handleTap(exercise),
                  onFavoriteTap: widget.onToggleFavorite != null
                      ? () => widget.onToggleFavorite!(exercise.id)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Header de la lista con conteo
class _ListHeader extends StatelessWidget {
  final int total;
  final int loaded;
  final bool hasMore;

  const _ListHeader({
    required this.total,
    required this.loaded,
    required this.hasMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.bgElevated,
      child: Row(
        children: [
          Text(
            '$loaded de $total ejercicios',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hasMore) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Item individual de ejercicio
class _ExerciseListItem extends StatelessWidget {
  final LibraryExercise exercise;
  final double height;
  final bool isSelected;
  final bool showFavorite;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;

  const _ExerciseListItem({
    super.key,
    required this.exercise,
    required this.height,
    required this.isSelected,
    required this.showFavorite,
    required this.onTap,
    this.onFavoriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.neonPrimary.withValues(alpha: 0.2)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.bgElevated),
            ),
          ),
          child: Row(
            children: [
              // Imagen del ejercicio
              ExerciseListImage(
                exerciseId: exercise.id,
                size: height - 16,
                borderRadius: BorderRadius.circular(8),
              ),

              const SizedBox(width: 12),

              // Info del ejercicio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      exercise.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _InfoChip(
                          text: exercise.muscleGroup,
                          color: AppColors.neonPrimary,
                        ),
                        const SizedBox(width: 6),
                        _InfoChip(
                          text: exercise.equipment,
                          color: AppColors.border,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Indicador de selección o favorito
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.neonPrimary,
                  size: 24,
                )
              else if (showFavorite)
                IconButton(
                  onPressed: onFavoriteTap,
                  icon: Icon(
                    exercise.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color:
                        exercise.isFavorite ? AppColors.neonPrimary : AppColors.textTertiary,
                    size: 22,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de información pequeño
class _InfoChip extends StatelessWidget {
  final String text;
  final Color color;

  const _InfoChip({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Indicador de carga al final de la lista
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

/// Estado vacío
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: AppColors.border,
          ),
          SizedBox(height: 16),
          Text(
            'No se encontraron ejercicios',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Intenta con otros filtros',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de búsqueda optimizada para la biblioteca
class ExerciseSearchBar extends ConsumerStatefulWidget {
  final String? initialQuery;

  const ExerciseSearchBar({
    super.key,
    this.initialQuery,
  });

  @override
  ConsumerState<ExerciseSearchBar> createState() => _ExerciseSearchBarState();
}

class _ExerciseSearchBarState extends ConsumerState<ExerciseSearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          ref.read(paginatedExercisesProvider.notifier).search(value);
        },
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar ejercicio...',
          hintStyle: const TextStyle(color: AppColors.textTertiary),
          prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textTertiary),
                  onPressed: () {
                    _controller.clear();
                    ref.read(paginatedExercisesProvider.notifier).search('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.bgElevated,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}

/// Chips de filtro para la biblioteca
class ExerciseFilterChips extends ConsumerWidget {
  const ExerciseFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paginatedExercisesProvider);
    final notifier = ref.read(paginatedExercisesProvider.notifier);

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Favoritos
          _FilterChip(
            label: 'Favoritos',
            icon: Icons.favorite,
            isSelected: state.favoritesOnly,
            onTap: () => notifier.setFavoritesOnly(!state.favoritesOnly),
          ),
          const SizedBox(width: 8),
          // Grupos musculares
          ...notifier.availableMuscleGroups.take(5).map((muscle) {
            final isSelected = state.muscleFilter == muscle;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: muscle,
                isSelected: isSelected,
                onTap: () =>
                    notifier.setMuscleFilter(isSelected ? null : muscle),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.neonPrimary : AppColors.bgElevated,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
