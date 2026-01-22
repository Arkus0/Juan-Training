import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/library_exercise.dart';
import '../../services/exercise_library_service.dart';

/// Diálogo para crear un ejercicio personalizado
class CreateExerciseDialog extends StatefulWidget {
  /// Si se proporciona, edita el ejercicio existente en lugar de crear uno nuevo
  final LibraryExercise? exerciseToEdit;

  const CreateExerciseDialog({
    super.key,
    this.exerciseToEdit,
  });

  /// Muestra el diálogo y retorna el ejercicio creado/editado o null si se cancela
  static Future<LibraryExercise?> show(BuildContext context, {LibraryExercise? exerciseToEdit}) {
    return showDialog<LibraryExercise>(
      context: context,
      builder: (context) => CreateExerciseDialog(exerciseToEdit: exerciseToEdit),
    );
  }

  @override
  State<CreateExerciseDialog> createState() => _CreateExerciseDialogState();
}

class _CreateExerciseDialogState extends State<CreateExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _selectedMuscleGroup = 'Pecho';
  String _selectedEquipment = 'Barra';
  List<String> _selectedMuscles = [];
  
  bool _isLoading = false;

  bool get _isEditing => widget.exerciseToEdit != null;

  static const List<String> _muscleGroups = [
    'Pecho',
    'Espalda',
    'Hombros',
    'Bíceps',
    'Tríceps',
    'Piernas',
    'Glúteos',
    'Core',
    'Cardio',
    'Full Body',
  ];

  static const List<String> _equipmentOptions = [
    'Barra',
    'Mancuernas',
    'Máquina',
    'Cable',
    'Peso corporal',
    'Kettlebell',
    'Banda elástica',
    'Barra dominadas',
    'TRX',
    'Otro',
  ];

  static const Map<String, List<String>> _musclesByGroup = {
    'Pecho': ['Pectoral mayor', 'Pectoral menor'],
    'Espalda': ['Dorsal ancho', 'Trapecio', 'Romboides', 'Erectores'],
    'Hombros': ['Deltoides anterior', 'Deltoides lateral', 'Deltoides posterior'],
    'Bíceps': ['Bíceps braquial', 'Braquial'],
    'Tríceps': ['Tríceps braquial'],
    'Piernas': ['Cuádriceps', 'Isquiotibiales', 'Gemelos', 'Aductores', 'Abductores'],
    'Glúteos': ['Glúteo mayor', 'Glúteo medio', 'Glúteo menor'],
    'Core': ['Recto abdominal', 'Oblicuos', 'Transverso'],
    'Cardio': [],
    'Full Body': [],
  };

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final ex = widget.exerciseToEdit!;
      _nameController.text = ex.name;
      _descriptionController.text = ex.description ?? '';
      _selectedMuscleGroup = _muscleGroups.contains(ex.muscleGroup) 
          ? ex.muscleGroup 
          : 'Pecho';
      _selectedEquipment = _equipmentOptions.contains(ex.equipment)
          ? ex.equipment
          : 'Otro';
      _selectedMuscles = List.from(ex.muscles);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final library = ExerciseLibraryService.instance;
      LibraryExercise result;

      if (_isEditing) {
        await library.updateCustomExercise(
          exerciseId: widget.exerciseToEdit!.id,
          name: _nameController.text.trim(),
          muscleGroup: _selectedMuscleGroup,
          equipment: _selectedEquipment,
          description: _descriptionController.text.trim().isNotEmpty 
              ? _descriptionController.text.trim() 
              : null,
          muscles: _selectedMuscles,
        );
        result = library.getExerciseById(widget.exerciseToEdit!.id)!;
      } else {
        result = await library.addCustomExercise(
          name: _nameController.text.trim(),
          muscleGroup: _selectedMuscleGroup,
          equipment: _selectedEquipment,
          description: _descriptionController.text.trim().isNotEmpty 
              ? _descriptionController.text.trim() 
              : null,
          muscles: _selectedMuscles,
        );
      }

      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Row(
        children: [
          Icon(
            _isEditing ? Icons.edit : Icons.add_circle,
            color: Colors.redAccent[700],
          ),
          const SizedBox(width: 8),
          Text(
            _isEditing ? 'EDITAR EJERCICIO' : 'NUEVO EJERCICIO',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w900,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre del ejercicio
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nombre del ejercicio *',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.fitness_center, color: Colors.grey),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa un nombre';
                    }
                    if (value.trim().length < 3) {
                      return 'Mínimo 3 caracteres';
                    }
                    return null;
                  },
                  textCapitalization: TextCapitalization.words,
                ),

                const SizedBox(height: 16),

                // Grupo muscular
                DropdownButtonFormField<String>(
                  value: _selectedMuscleGroup,
                  dropdownColor: Colors.grey[850],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Grupo muscular',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.category, color: Colors.grey),
                  ),
                  items: _muscleGroups.map((group) {
                    return DropdownMenuItem(
                      value: group,
                      child: Text(group),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedMuscleGroup = value;
                        _selectedMuscles = []; // Reset muscles when group changes
                      });
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Equipamiento
                DropdownButtonFormField<String>(
                  value: _selectedEquipment,
                  dropdownColor: Colors.grey[850],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Equipamiento',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.build, color: Colors.grey),
                  ),
                  items: _equipmentOptions.map((eq) {
                    return DropdownMenuItem(
                      value: eq,
                      child: Text(eq),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedEquipment = value);
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Músculos específicos (opcional)
                if (_musclesByGroup[_selectedMuscleGroup]?.isNotEmpty == true) ...[
                  Text(
                    'Músculos trabajados (opcional)',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _musclesByGroup[_selectedMuscleGroup]!.map((muscle) {
                      final isSelected = _selectedMuscles.contains(muscle);
                      return FilterChip(
                        label: Text(
                          muscle,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[300],
                            fontSize: 12,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedMuscles.add(muscle);
                            } else {
                              _selectedMuscles.remove(muscle);
                            }
                          });
                        },
                        selectedColor: Colors.redAccent[700],
                        backgroundColor: Colors.grey[800],
                        checkmarkColor: Colors.white,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Descripción (opcional)
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Descripción (opcional)',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[850],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.notes, color: Colors.grey),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(
            'CANCELAR',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent[700],
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  _isEditing ? 'GUARDAR' : 'CREAR',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}
