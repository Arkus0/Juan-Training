import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:flutter/services.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/services/exercise_library_service.dart';
import 'package:juan_training/widgets/common/create_exercise_dialog.dart';

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
  bool _showFavoritesOnly = false;

  List<String> get _muscles => ['Todos', 'Pecho', 'Espalda', 'Piernas', 'Brazos', 'Hombros', 'Abdominales', 'Gemelos', 'Cardio'];
  List<String> get _equipment => ['Todos', 'Barra', 'Mancuerna', 'Máquina', 'Polea', 'Peso corporal', 'Banco'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddedSnackbar(BuildContext context, String exerciseName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$exerciseName añadido',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.red[900],
        duration: const Duration(milliseconds: 1000),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
      ),
    );
  }

  void _showCustomExerciseOptions(BuildContext context, LibraryExercise ex) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              ex.name,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple[700],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'EJERCICIO PERSONALIZADO',
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.edit, color: Colors.blue[400]),
              title: const Text('Editar ejercicio', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await CreateExerciseDialog.show(context, exerciseToEdit: ex);
                if (result != null && mounted) {
                  setState(() {});
                  _showAddedSnackbar(context, '${result.name} actualizado');
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red[400]),
              title: const Text('Eliminar ejercicio', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: Colors.grey[900],
                    title: const Text('¿ELIMINAR EJERCICIO?', style: TextStyle(color: Colors.white)),
                    content: Text(
                      'Se eliminará "${ex.name}" de tu biblioteca. Esta acción no se puede deshacer.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('CANCELAR'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: Text('ELIMINAR', style: TextStyle(color: Colors.red[400])),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ExerciseLibraryService.instance.deleteCustomExercise(ex.id);
                  if (mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${ex.name} eliminado'),
                        backgroundColor: Colors.red[700],
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in Scaffold to have its own ScaffoldMessenger for snackbars
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox(
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
                  'BIBLIOTECA DEL DOLOR',
                  style: GoogleFonts.montserrat(
                    fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const Spacer(),
                // Botón crear ejercicio custom
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.white),
                  tooltip: 'Crear ejercicio',
                  onPressed: () async {
                    final result = await CreateExerciseDialog.show(context);
                    if (result != null && mounted) {
                      HapticFeedback.mediumImpact();
                      _showAddedSnackbar(context, '${result.name} creado');
                    }
                  },
                ),
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
                // Favorites filter at the top
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(
                            _showFavoritesOnly ? Icons.star : Icons.star_border,
                            color: _showFavoritesOnly ? Colors.amber : Colors.white70,
                            size: 18,
                          ),
                          label: const Text('Favoritos'),
                          selected: _showFavoritesOnly,
                          onSelected: (sel) {
                            setState(() {
                              _showFavoritesOnly = sel;
                            });
                          },
                          checkmarkColor: Colors.amber,
                          selectedColor: Colors.amber.withValues(alpha: 0.3),
                          backgroundColor: Colors.grey[800],
                          labelStyle: TextStyle(
                            color: _showFavoritesOnly ? Colors.amber : Colors.white70,
                            fontWeight: _showFavoritesOnly ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
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

                // Favorites filter (first priority)
                if (_showFavoritesOnly) {
                  filtered = filtered.where((e) => e.isFavorite).toList();
                }

                if (_selectedMuscle != 'Todos') {
                  final selectedLower = _selectedMuscle.toLowerCase();

                  // Map Spanish selection to common English synonyms to tolerate both data sources
                  final Map<String, List<String>> muscleSynonyms = {
                    'pecho': ['chest', 'pectoral', 'pectoralis', 'pectorales'],
                    'espalda': ['back', 'dorsal', 'lats', 'latissimus', 'dorsal ancho'],
                    'piernas': ['legs', 'quads', 'quadriceps', 'glutes', 'hamstrings', 'pierna'],
                    'brazos': ['arms', 'biceps', 'triceps', 'arm'],
                    'hombros': ['shoulders', 'deltoid', 'deltoides'],
                    'abdominales': ['abs', 'abdominal', 'obliques', 'rectus'],
                    'gemelos': ['calves', 'gastrocnemius', 'soleus', 'gemelos'],
                    'cardio': ['cardio', 'aerobic']
                  };

                  final synonyms = muscleSynonyms[selectedLower] ?? [];

                  filtered = filtered.where((e) {
                    final mg = e.muscleGroup.toLowerCase();

                    // Direct matches
                    if (mg.contains(selectedLower)) return true;
                    for (final s in synonyms) {
                      if (mg.contains(s)) return true;
                    }

                    // Check detailed muscle names (normalize maps/strings)
                    final musclesLower = e.muscles.map((m) => m.toLowerCase()).toList();
                    if (musclesLower.any((m) => m.contains(selectedLower))) return true;
                    if (musclesLower.any((m) => synonyms.any((s) => m.contains(s)))) return true;

                    return false;
                  }).toList();
                }

                if (_selectedEquipment != 'Todos') {
                  final selectedEq = _selectedEquipment.toLowerCase();

                  final Map<String, List<String>> equipmentSynonyms = {
                    'barra': ['barbell', 'bar'],
                    'mancuerna': ['dumbbell', 'dumbbells'],
                    'máquina': ['machine', 'machine-based'],
                    'polea': ['cable', 'pulley'],
                    'peso corporal': ['bodyweight', 'body weight'],
                    'banco': ['bench', 'bench press']
                  };

                  final synonyms = equipmentSynonyms[selectedEq] ?? [];

                  filtered = filtered.where((e) {
                    final eq = e.equipment.toLowerCase();

                    if (eq.contains(selectedEq)) return true;
                    for (final s in synonyms) {
                      if (eq.contains(s)) return true;
                    }

                    // Some library entries use longer names or multiple words; also check name and description
                    if (e.name.toLowerCase().contains(selectedEq)) return true;
                    for (final s in synonyms) {
                      if (e.name.toLowerCase().contains(s)) return true;
                    }

                    return false;
                  }).toList();
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
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final ex = filtered[index];
                    final isCustom = ex.id < 0; // Ejercicios custom tienen ID negativo
                    return GestureDetector(
                      onLongPress: isCustom ? () => _showCustomExerciseOptions(context, ex) : null,
                      child: Card(
                      color: Colors.grey[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isCustom 
                              ? Colors.purple[400]! 
                              : (ex.isFavorite ? Colors.amber : Colors.grey[800]!),
                          width: (ex.isFavorite || isCustom) ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: SizedBox.expand(child: _buildImage(ex)),
                                ),
                                // Badge CUSTOM para ejercicios personalizados
                                if (isCustom)
                                  Positioned(
                                    top: 4,
                                    left: 4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.purple[700],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'CUSTOM',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Favorite star button
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () async {
                                      try { HapticFeedback.selectionClick(); } catch (_) {}
                                      await ExerciseLibraryService.instance.toggleFavorite(ex.id);
                                      setState(() {}); // Refresh UI
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Icon(
                                        ex.isFavorite ? Icons.star : Icons.star_border,
                                        color: ex.isFavorite ? Colors.amber : Colors.white70,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
                                try { HapticFeedback.selectionClick(); } catch (_) {}
                                widget.onAdd(ex);
                                _showAddedSnackbar(context, ex.name);
                              },
                              child: const Text('AÑADIR'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    );
                  },
                );
              },
            ),
          ),
          ],
        ),
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
      // On mobile: prefer local file, but fall back to network if available
      if (ex.localImagePath != null && File(ex.localImagePath!).existsSync()) {
        return Image.file(
          File(ex.localImagePath!),
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[800], child: const Icon(Icons.broken_image, color: Colors.white24)),
        );
      } else if (ex.imageUrls.isNotEmpty) {
        return Image.network(
          ex.imageUrls.first,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => Image.asset('assets/img/placeholder_exercise.png', fit: BoxFit.cover),
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
