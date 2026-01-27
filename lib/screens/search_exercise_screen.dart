import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/library_exercise.dart';
import '../providers/exercise_search_providers.dart';

class SearchExerciseScreen extends ConsumerStatefulWidget {
  const SearchExerciseScreen({super.key});

  @override
  ConsumerState<SearchExerciseScreen> createState() =>
      _SearchExerciseScreenState();
}

class _SearchExerciseScreenState extends ConsumerState<SearchExerciseScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    ref.read(exerciseSearchQueryProvider.notifier).state =
        _searchController.text;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(exerciseSearchResultsProvider);
    final suggestionsAsync = ref.watch(exerciseSearchSuggestionsProvider);
    final query = ref.watch(exerciseSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BUSCAR EJERCICIO'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontWeight: FontWeight.bold),
              onChanged: (value) {
                ref.read(exerciseSearchQueryProvider.notifier).state = value;
              },
              decoration: InputDecoration(
                hintText: 'Buscar ejercicio...',
                prefixIcon: Icon(Icons.search, color: Colors.redAccent[700]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              data: (displayedExercises) {
                if (displayedExercises.isEmpty) {
                  final suggestions = suggestionsAsync.value ?? const <LibraryExercise>[];
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 60, color: Colors.grey[800]),
                        const SizedBox(height: 16),
                        const Text(
                          'NO SE ENCONTRÓ EL EJERCICIO',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (suggestions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            '¿Quisiste decir...?',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          ...suggestions.map(
                            (exercise) => Text(
                              exercise.name,
                              style: TextStyle(
                                color: Colors.redAccent[100],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                final topMatches =
                    query.trim().isEmpty ? const <LibraryExercise>[] : displayedExercises.take(5).toList();
                final remaining =
                    query.trim().isEmpty ? displayedExercises : displayedExercises.skip(5).toList();

                final rows = <_SearchRow>[];
                if (topMatches.isNotEmpty) {
                  rows.add(const _SearchRow.header('TOP MATCHES'));
                  rows.addAll(topMatches.map(_SearchRow.exercise));
                }
                if (remaining.isNotEmpty) {
                  if (query.trim().isNotEmpty) {
                    rows.add(const _SearchRow.header('RESULTADOS'));
                  }
                  rows.addAll(remaining.map(_SearchRow.exercise));
                }

                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (context, index) =>
                      Divider(height: 1, color: Colors.grey[800]),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    if (row.isHeader) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          row.header!,
                          style: TextStyle(
                            color: Colors.redAccent[100],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }

                    final exercise = row.exercise!;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(
                        exercise.name.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[900]?.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.red[900]!.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              exercise.muscleGroup.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.redAccent[100],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            exercise.equipment,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.add_circle_outline,
                        color: Colors.redAccent[700],
                      ),
                      onTap: () {
                        Navigator.of(context).pop(exercise);
                      },
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Center(
                child: Text(
                  'Error al buscar ejercicios: $error',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchRow {
  final String? header;
  final LibraryExercise? exercise;

  const _SearchRow._({this.header, this.exercise});

  const _SearchRow.header(String header) : this._(header: header);

  const _SearchRow.exercise(LibraryExercise exercise)
      : this._(exercise: exercise);

  bool get isHeader => header != null;
}
