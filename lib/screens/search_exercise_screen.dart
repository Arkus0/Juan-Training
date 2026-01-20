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
        title: const Text('ARSENAL DE EJERCICIOS'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'BUSCAR ARMA...',
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 60, color: Colors.grey[800]),
                        const SizedBox(height: 16),
                        const Text(
                          'NO SE ENCONTRÓ EL EJERCICIO',
                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: displayedExercises.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[800]),
                  itemBuilder: (context, index) {
                    final exercise = displayedExercises[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(
                        exercise.name.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red[900]?.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.red[900]!.withOpacity(0.5)),
                            ),
                            child: Text(
                              exercise.muscleGroup.toUpperCase(),
                              style: TextStyle(fontSize: 10, color: Colors.redAccent[100]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            exercise.equipment,
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                      trailing: Icon(Icons.add_circle_outline, color: Colors.redAccent[700]),
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
