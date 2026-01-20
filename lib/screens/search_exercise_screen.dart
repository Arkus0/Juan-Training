import 'package:flutter/material.dart';
import '../models/library_exercise.dart';
import '../services/exercise_library_service.dart';

class SearchExerciseScreen extends StatefulWidget {
  const SearchExerciseScreen({super.key});

  @override
  State<SearchExerciseScreen> createState() => _SearchExerciseScreenState();
}

class _SearchExerciseScreenState extends State<SearchExerciseScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<LibraryExercise> _allExercises = [];
  List<LibraryExercise> _filteredExercises = [];

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _searchController.addListener(_filterExercises);
  }

  void _loadExercises() {
    // Get exercises from service (already loaded/synced/fallback)
    setState(() {
      _allExercises = ExerciseLibraryService.instance.getExercises();
      _filteredExercises = _allExercises;
    });
  }

  void _filterExercises() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredExercises = _allExercises;
      } else {
        _filteredExercises = _allExercises.where((ex) {
          return ex.name.toLowerCase().contains(query);
        }).toList();
      }
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
                          // Listener triggers filter
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _filteredExercises.isEmpty
                ? const Center(child: Text('No se encontraron ejercicios'))
                : ListView.builder(
                    itemCount: _filteredExercises.length,
                    itemBuilder: (context, index) {
                      final exercise = _filteredExercises[index];
                      return ListTile(
                        title: Text(exercise.name),
                        subtitle: Text('${exercise.muscleGroup} • ${exercise.equipment}'),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () {
                          Navigator.of(context).pop(exercise);
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
