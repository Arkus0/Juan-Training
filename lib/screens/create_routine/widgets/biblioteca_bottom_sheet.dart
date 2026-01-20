import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import '../../../models/library_exercise.dart';
import '../../../services/exercise_library_service.dart';

class BibliotecaBottomSheet extends StatefulWidget {
  final Function(LibraryExercise) onAdd;

  const BibliotecaBottomSheet({super.key, required this.onAdd});

  @override
  State<BibliotecaBottomSheet> createState() => _BibliotecaBottomSheetState();
}

class _BibliotecaBottomSheetState extends State<BibliotecaBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedMuscle = 'Todos';
  String _selectedEquipment = 'Todos';
  String _query = '';

  List<String> get _muscles => ['Todos', 'Pecho', 'Espalda', 'Piernas', 'Brazos', 'Hombros', 'Abdominales', 'Gemelos', 'Cardio'];
  List<String> get _equipment => ['Todos', 'Barra', 'Mancuerna', 'Máquina', 'Polea', 'Peso corporal', 'Banco'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[900],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.library_books, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'BIBLIOTECA DE DOLOR',
                  style: GoogleFonts.montserrat(
                    fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search & Filters
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: Colors.white54),
                    hintText: 'Buscar ejercicio...',
                  ),
                  onChanged: (val) {
                    setState(() {
                      _query = val;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ..._muscles.map((m) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(m),
                          selected: _selectedMuscle == m,
                          onSelected: (sel) {
                            setState(() {
                              _selectedMuscle = sel ? m : 'Todos';
                            });
                          },
                          checkmarkColor: Colors.white,
                          selectedColor: Colors.redAccent[700],
                          backgroundColor: Colors.grey[800],
                          labelStyle: TextStyle(color: _selectedMuscle == m ? Colors.white : Colors.white70),
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                       ..._equipment.map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(e),
                          selected: _selectedEquipment == e,
                          onSelected: (sel) {
                            setState(() {
                              _selectedEquipment = sel ? e : 'Todos';
                            });
                          },
                           checkmarkColor: Colors.white,
                          selectedColor: Colors.redAccent[700],
                          backgroundColor: Colors.grey[800],
                          labelStyle: TextStyle(color: _selectedEquipment == e ? Colors.white : Colors.white70),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: ValueListenableBuilder<List<LibraryExercise>>(
              valueListenable: ExerciseLibraryService.instance.exercisesNotifier,
              builder: (context, exercises, _) {
                // Filter
                var filtered = exercises;

                if (_selectedMuscle != 'Todos') {
                  filtered = filtered.where((e) => e.muscleGroup.contains(_selectedMuscle) || e.muscles.contains(_selectedMuscle)).toList();
                }
                if (_selectedEquipment != 'Todos') {
                  filtered = filtered.where((e) => e.equipment.contains(_selectedEquipment)).toList();
                }

                if (_query.isNotEmpty) {
                  final fuse = Fuzzy(
                    filtered,
                    options: FuzzyOptions(
                      keys: [
                        WeightedKey(name: 'name', getter: (LibraryExercise x) => x.name, weight: 1.0),
                        WeightedKey(name: 'muscleGroup', getter: (LibraryExercise x) => x.muscleGroup, weight: 0.5),
                      ],
                    ),
                  );
                  filtered = fuse.search(_query).map((r) => r.item).toList();
                }

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No se encontraron ejercicios.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final ex = filtered[index];
                    return Card(
                      color: Colors.grey[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[800]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: _buildImage(ex),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex.name,
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ex.muscleGroup,
                                  style: TextStyle(color: Colors.redAccent[700], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[900],
                                minimumSize: const Size(double.infinity, 36),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () {
                                Vibrate.feedback(FeedbackType.selection);
                                widget.onAdd(ex);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${ex.name} añadido'), duration: const Duration(seconds: 1)),
                                );
                              },
                              child: const Text('AÑADIR'),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildImage(LibraryExercise ex) {
    if (kIsWeb) {
      if (ex.imageUrls.isNotEmpty) {
        return Image.network(
          ex.imageUrls.first,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.white24)),
        );
      } else {
        return Image.asset(
          'assets/img/placeholder_exercise.png',
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.white24)),
        );
      }
    } else {
      if (ex.localImagePath != null && File(ex.localImagePath!).existsSync()) {
        return Image.file(
          File(ex.localImagePath!),
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.white24)),
        );
      } else {
        return Image.asset(
          'assets/img/placeholder_exercise.png',
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.white24)),
        );
      }
    }
  }
}
