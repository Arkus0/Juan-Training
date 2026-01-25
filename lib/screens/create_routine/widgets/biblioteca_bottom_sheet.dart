import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:flutter/services.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/models/analysis_models.dart';
import 'package:juan_training/services/exercise_library_service.dart';
import 'package:juan_training/widgets/common/create_exercise_dialog.dart';

/// Opciones de ordenación para power-users
enum SortOption {
  nameAsc,      // A → Z
  nameDesc,     // Z → A
  muscleGroup,  // Agrupado por músculo
  recentlyUsed, // Últimos usados primero (favoritos primero)
}

/// 🆕 SmartDefaults: valores sugeridos basados en historial
class SmartDefaults {
  final int series;
  final String repsRange;
  
  const SmartDefaults({
    required this.series,
    required this.repsRange,
  });
}

class BibliotecaBottomSheet extends StatefulWidget {
  final Function(LibraryExercise) onAdd;
  
  /// Callback opcional para obtener el PR personal de un ejercicio
  final Future<PersonalRecord?> Function(String exerciseName)? getPersonalRecord;
  
  /// 🆕 Callback para obtener SmartDefaults del historial del usuario
  final Future<SmartDefaults?> Function(String exerciseName)? getSmartDefaults;

  const BibliotecaBottomSheet({
    super.key, 
    required this.onAdd,
    this.getPersonalRecord,
    this.getSmartDefaults,
  });

  @override
  State<BibliotecaBottomSheet> createState() => _BibliotecaBottomSheetState();
}

class _BibliotecaBottomSheetState extends State<BibliotecaBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedMuscle = 'Todos';
  String _selectedEquipment = 'Todos';
  String _query = '';
  bool _showFavoritesOnly = false;
  
  /// 🆕 Ordenación actual
  SortOption _currentSort = SortOption.nameAsc;
  
  /// 🆕 Vista compacta (solo lista) vs grid con imágenes
  bool _compactView = false;
  
  /// 🆕 Último ejercicio añadido (para sugerencias)
  LibraryExercise? _lastAddedExercise;
  
  /// 🆕 Sugerencias basadas en el último ejercicio
  List<LibraryExercise> _suggestions = [];

  /// 🆕 Historial de ejercicios añadidos recientemente (máximo 5)
  /// Static para persistir entre aperturas del bottom sheet
  static final List<LibraryExercise> _recentlyAdded = [];

  /// Añade un ejercicio al historial de recientes
  void _addToRecent(LibraryExercise ex) {
    _recentlyAdded.removeWhere((e) => e.id == ex.id);
    _recentlyAdded.insert(0, ex);
    if (_recentlyAdded.length > 5) _recentlyAdded.removeLast();
  }
  
  /// 🆕 Genera sugerencias de ejercicios complementarios
  void _generateSuggestions(LibraryExercise addedEx) {
    final allExercises = ExerciseLibraryService.instance.exercisesNotifier.value;
    final sameMuscle = allExercises.where((e) => 
      e.id != addedEx.id && 
      e.muscleGroup.toLowerCase() == addedEx.muscleGroup.toLowerCase() &&
      !_recentlyAdded.any((r) => r.id == e.id)
    ).toList();
    
    // Mezclar y tomar 3 sugerencias
    sameMuscle.shuffle();
    _suggestions = sameMuscle.take(3).toList();
    _lastAddedExercise = addedEx;
  }
  
  /// 🆕 Filtro por letra inicial (índice A-Z)
  String? _selectedLetter;
  
  /// Letras disponibles (se calculan dinámicamente)
  List<String> _getAvailableLetters(List<LibraryExercise> exercises) {
    final letters = exercises
        .map((e) => e.name.isNotEmpty ? e.name[0].toUpperCase() : '')
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList();
    letters.sort();
    return letters;
  }

  List<String> get _muscles => ['Todos', 'Pecho', 'Espalda', 'Piernas', 'Brazos', 'Hombros', 'Abdominales', 'Gemelos', 'Cardio'];
  List<String> get _equipment => ['Todos', 'Barra', 'Mancuerna', 'Máquina', 'Polea', 'Peso corporal', 'Banco'];

  /// Helper para construir items del menú de ordenación
  PopupMenuItem<SortOption> _buildSortMenuItem(SortOption option, String label, IconData icon) {
    final isSelected = _currentSort == option;
    return PopupMenuItem<SortOption>(
      value: option,
      child: Row(
        children: [
          Icon(icon, color: isSelected ? Colors.amber : Colors.white70, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.montserrat(
              color: isSelected ? Colors.amber : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isSelected) ...[
            const Spacer(),
            const Icon(Icons.check, color: Colors.amber, size: 18),
          ],
        ],
      ),
    );
  }

  /// Aplica ordenación a la lista de ejercicios
  List<LibraryExercise> _applySorting(List<LibraryExercise> exercises) {
    final sorted = List<LibraryExercise>.from(exercises);
    switch (_currentSort) {
      case SortOption.nameAsc:
        sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortOption.nameDesc:
        sorted.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case SortOption.muscleGroup:
        sorted.sort((a, b) {
          final cmp = a.muscleGroup.compareTo(b.muscleGroup);
          return cmp != 0 ? cmp : a.name.compareTo(b.name);
        });
        break;
      case SortOption.recentlyUsed:
        // Favoritos primero, luego alfabético
        sorted.sort((a, b) {
          if (a.isFavorite && !b.isFavorite) return -1;
          if (!a.isFavorite && b.isFavorite) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }
    return sorted;
  }

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

  /// 🆕 Muestra preview del ejercicio con historial personal
  void _showExercisePreview(BuildContext context, LibraryExercise ex) async {
    // Obtener PR personal si hay callback
    PersonalRecord? personalRecord;
    if (widget.getPersonalRecord != null) {
      try {
        personalRecord = await widget.getPersonalRecord!(ex.name);
      } catch (_) {
        // Ignorar errores
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340, maxHeight: 550),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[700]!, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Imagen grande
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 180,
                  child: _buildImage(ex),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre
                    Text(
                      ex.name.toUpperCase(),
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // 🆕 Historial personal (PR)
                    if (personalRecord != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber[800]!, Colors.orange[700]!],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'TU MEJOR: ${personalRecord.maxWeight.toStringAsFixed(1)}kg × ${personalRecord.repsAtMax}',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    
                    // Grupo muscular + equipo
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red[900]!.withValues(alpha:0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ex.muscleGroup.toUpperCase(),
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.redAccent[100],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          ex.equipment,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Músculos detallados
                    if (ex.muscles.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: ex.muscles.map((m) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            m,
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    
                    // Descripción
                    if (ex.description?.isNotEmpty ?? false)
                      Text(
                        ex.description!,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              
              // Botones de acción
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    // Favorito toggle
                    IconButton(
                      onPressed: () async {
                        await ExerciseLibraryService.instance.toggleFavorite(ex.id);
                        Navigator.pop(ctx);
                        setState(() {});
                      },
                      icon: Icon(
                        ex.isFavorite ? Icons.star : Icons.star_border,
                        color: ex.isFavorite ? Colors.amber : Colors.grey,
                      ),
                    ),
                    const Spacer(),
                    // Cerrar
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'CERRAR',
                        style: GoogleFonts.montserrat(
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Añadir
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onAdd(ex);
                        _addToRecent(ex);
                        _generateSuggestions(ex);
                        _showAddedSnackbar(context, ex.name);
                        setState(() {});
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        'AÑADIR',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[900],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                  'EJERCICIOS',
                  style: GoogleFonts.montserrat(
                    fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const Spacer(),
                // 🆕 Dropdown de ordenación
                PopupMenuButton<SortOption>(
                  icon: const Icon(Icons.sort, color: Colors.white),
                  tooltip: 'Ordenar',
                  color: Colors.grey[850],
                  onSelected: (option) {
                    setState(() => _currentSort = option);
                    try { HapticFeedback.selectionClick(); } catch (_) {}
                  },
                  itemBuilder: (ctx) => [
                    _buildSortMenuItem(SortOption.nameAsc, 'A → Z', Icons.sort_by_alpha),
                    _buildSortMenuItem(SortOption.nameDesc, 'Z → A', Icons.sort_by_alpha),
                    _buildSortMenuItem(SortOption.muscleGroup, 'Por músculo', Icons.fitness_center),
                    _buildSortMenuItem(SortOption.recentlyUsed, 'Favoritos', Icons.star),
                  ],
                ),
                // 🆕 Toggle vista compacta/grid
                IconButton(
                  icon: Icon(
                    _compactView ? Icons.grid_view : Icons.view_list,
                    color: Colors.white,
                  ),
                  tooltip: _compactView ? 'Vista grid' : 'Vista compacta',
                  onPressed: () {
                    setState(() {
                      _compactView = !_compactView;
                    });
                    try { HapticFeedback.selectionClick(); } catch (_) {}
                  },
                ),
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
                // 🆕 Índice alfabético A-Z
                if (_query.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ValueListenableBuilder<List<LibraryExercise>>(
                      valueListenable: ExerciseLibraryService.instance.exercisesNotifier,
                      builder: (context, exercises, _) {
                        final letters = _getAvailableLetters(exercises);
                        return SizedBox(
                          height: 28,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: letters.length + 1, // +1 for "ALL"
                            itemBuilder: (ctx, idx) {
                              if (idx == 0) {
                                // Botón "Todos"
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _selectedLetter = null);
                                      try { HapticFeedback.selectionClick(); } catch (_) {}
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _selectedLetter == null 
                                            ? Colors.blue[700] 
                                            : Colors.grey[800],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'A-Z',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final letter = letters[idx - 1];
                              final isSelected = _selectedLetter == letter;
                              return Padding(
                                padding: const EdgeInsets.only(right: 2),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedLetter = letter);
                                    try { HapticFeedback.selectionClick(); } catch (_) {}
                                  },
                                  child: Container(
                                    width: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blue[700] : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      letter,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                        color: isSelected ? Colors.white : Colors.grey[500],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 🆕 Sección: Añadidos recientemente (si no hay búsqueda activa)
          if (_query.isEmpty && _recentlyAdded.isNotEmpty && !_showFavoritesOnly)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Text(
                        'RECIENTES',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recentlyAdded.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        final ex = _recentlyAdded[idx];
                        return ActionChip(
                          avatar: Icon(Icons.add, size: 16, color: Colors.redAccent[200]),
                          label: Text(
                            ex.name.length > 20 ? '${ex.name.substring(0, 17)}...' : ex.name,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: Colors.grey[850],
                          side: BorderSide(color: Colors.grey[700]!),
                          onPressed: () {
                            try { HapticFeedback.selectionClick(); } catch (_) {}
                            widget.onAdd(ex);
                            _showAddedSnackbar(context, ex.name);
                            // Mover al frente del historial
                            _addToRecent(ex);
                            _generateSuggestions(ex);
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Divider(color: Colors.grey[800], height: 1),
                ],
              ),
            ),
          
          // 🆕 Sección: Sugerencias basadas en último ejercicio añadido
          if (_suggestions.isNotEmpty && _lastAddedExercise != null && _query.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                border: Border(
                  bottom: BorderSide(color: Colors.grey[800]!, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 16, color: Colors.green[400]),
                      const SizedBox(width: 6),
                      Text(
                        'COMPLEMENTA TU ${_lastAddedExercise!.muscleGroup.toUpperCase()}',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.green[400],
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _suggestions = [];
                            _lastAddedExercise = null;
                          });
                        },
                        child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, idx) {
                        final ex = _suggestions[idx];
                        return ActionChip(
                          avatar: Icon(Icons.add, size: 14, color: Colors.green[300]),
                          label: Text(
                            ex.name.length > 18 ? '${ex.name.substring(0, 15)}...' : ex.name,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: Colors.green.withValues(alpha: 0.2),
                          side: BorderSide(color: Colors.green[700]!),
                          onPressed: () {
                            try { HapticFeedback.selectionClick(); } catch (_) {}
                            widget.onAdd(ex);
                            _addToRecent(ex);
                            _showAddedSnackbar(context, ex.name);
                            _generateSuggestions(ex);
                            setState(() {});
                          },
                        );
                      },
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
                
                // 🆕 Filtro por letra inicial (índice A-Z)
                if (_selectedLetter != null) {
                  filtered = filtered.where((e) => 
                    e.name.isNotEmpty && 
                    e.name[0].toUpperCase() == _selectedLetter
                  ).toList();
                }
                
                // 🆕 Aplicar ordenación seleccionada
                filtered = _applySorting(filtered);

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No se encontraron ejercicios.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  );
                }

                // 🆕 Vista compacta (lista) o grid con imágenes
                if (_compactView) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final ex = filtered[index];
                      final isCustom = ex.id < 0;
                      return Card(
                        color: Colors.grey[900],
                        margin: const EdgeInsets.only(bottom: 4),
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  try { HapticFeedback.selectionClick(); } catch (_) {}
                                  await ExerciseLibraryService.instance.toggleFavorite(ex.id);
                                  setState(() {});
                                },
                                child: Icon(
                                  ex.isFavorite ? Icons.star : Icons.star_border,
                                  color: ex.isFavorite ? Colors.amber : Colors.grey[600],
                                  size: 20,
                                ),
                              ),
                              if (isCustom) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.person, size: 16, color: Colors.purple[400]),
                              ],
                            ],
                          ),
                          title: Text(
                            ex.name,
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${ex.muscleGroup} • ${ex.equipment}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.add_circle, color: Colors.red[400]),
                            onPressed: () {
                              try { HapticFeedback.selectionClick(); } catch (_) {}
                              widget.onAdd(ex);
                              _addToRecent(ex);
                              _generateSuggestions(ex);
                              _showAddedSnackbar(context, ex.name);
                              setState(() {});
                            },
                          ),
                          onTap: () {
                            try { HapticFeedback.selectionClick(); } catch (_) {}
                            widget.onAdd(ex);
                            _addToRecent(ex);
                            _generateSuggestions(ex);
                            _showAddedSnackbar(context, ex.name);
                            setState(() {});
                          },
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            if (isCustom) {
                              _showCustomExerciseOptions(context, ex);
                            } else {
                              _showExercisePreview(context, ex);
                            }
                          },
                        ),
                      );
                    },
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
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        if (isCustom) {
                          _showCustomExerciseOptions(context, ex);
                        } else {
                          _showExercisePreview(context, ex); // 🆕 Preview con historial
                        }
                      },
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
                                _addToRecent(ex); // 🆕 Registrar en historial
                                _generateSuggestions(ex); // 🆕 Generar sugerencias
                                _showAddedSnackbar(context, ex.name);
                                setState(() {});
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
