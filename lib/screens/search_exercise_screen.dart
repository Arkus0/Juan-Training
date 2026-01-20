import 'package:flutter/material.dart';
import 'package:fuzzy/fuzzy.dart';
import '../models/library_exercise.dart';
import '../services/exercise_library_service.dart';

class SearchExerciseScreen extends StatefulWidget {
  const SearchExerciseScreen({super.key});

  @override
  State<SearchExerciseScreen> createState() => _SearchExerciseScreenState();
}

class _SearchExerciseScreenState extends State<SearchExerciseScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Trigger rebuild on text change to re-filter the list inside the ValueListenableBuilder
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de Ejercicios'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar ejercicio...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<LibraryExercise>>(
              valueListenable: ExerciseLibraryService.instance.exercisesNotifier,
              builder: (context, exercises, child) {
                List<LibraryExercise> displayedExercises;
                final query = _searchController.text;

                if (query.isEmpty) {
                  displayedExercises = exercises;
                } else {
                  final fuse = Fuzzy(
                    exercises,
                    options: FuzzyOptions(
                      keys: [
                        WeightedKey(
                          name: 'name',
                          getter: (LibraryExercise x) => x.name,
                          weight: 1,
                        ),
                      ],
                    ),
                  );
                  displayedExercises = fuse.search(query).map((r) => r.item).toList();
                }

                if (displayedExercises.isEmpty) {
                  return const Center(child: Text('No se encontraron ejercicios'));
                }

                return ListView.builder(
                  itemCount: displayedExercises.length,
                  itemBuilder: (context, index) {
                    final exercise = displayedExercises[index];
                    return ListTile(
                      title: Text(exercise.name),
                      subtitle: Text('${exercise.muscleGroup} • ${exercise.equipment}'),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: () {
                        Navigator.of(context).pop(exercise);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
