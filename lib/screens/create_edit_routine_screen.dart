import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:juan_training/models/rutina.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/providers/create_routine_provider.dart';
import 'package:juan_training/screens/create_routine/widgets/dia_expansion_tile.dart';
import 'package:juan_training/screens/create_routine/widgets/biblioteca_bottom_sheet.dart';
import 'package:juan_training/services/routine_sharing_service.dart';
import 'package:juan_training/services/routine_ocr_service.dart';
import 'package:juan_training/services/voice_input_service.dart';
import 'package:juan_training/widgets/routine_import_dialog.dart';
import 'package:juan_training/widgets/voice/voice_input_sheet.dart';
import 'package:juan_training/widgets/smart_import_sheet.dart';

class CreateEditRoutineScreen extends ConsumerStatefulWidget {
  final Rutina? rutina; // Null for Create, existing for Edit

  const CreateEditRoutineScreen({super.key, this.rutina});

  @override
  ConsumerState<CreateEditRoutineScreen> createState() => _CreateEditRoutineScreenState();
}

class _CreateEditRoutineScreenState extends ConsumerState<CreateEditRoutineScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    // 🎯 P2: Nombre por defecto para nuevas rutinas
    final defaultName = widget.rutina?.nombre ?? _generateDefaultName();
    _nameController = TextEditingController(text: defaultName);
  }

  /// Genera un nombre por defecto basado en la fecha
  String _generateDefaultName() {
    final now = DateTime.now();
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return 'Rutina ${months[now.month - 1]} ${now.year}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveRoutine() async {
    final notifier = ref.read(createRoutineProvider(widget.rutina).notifier);

    // Attempt Save
    try {
      final error = await notifier.saveRoutine();

      if (!mounted) return;

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent[700],
          ),
        );
        try { HapticFeedback.vibrate(); } catch (_) {}
        return;
      }

      // Success Feedback
      if (!mounted) return;

      // Flash
      final overlay = Overlay.of(context);
      final entry = OverlayEntry(builder: (context) {
        return Container(
          color: Colors.red[900]!.withValues(alpha: 0.4),
        );
      });
      overlay.insert(entry);

      // Vibrate approximation using HapticFeedback
      try {
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 50));
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (_) {} // best-effort haptic feedback


      // SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('RUTINA FORJADA',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.white)),
          backgroundColor: Colors.red[900],
        ),
      );

      // Wait 300ms for flash then remove and pop
      final navigator = Navigator.of(context);
      await Future.delayed(const Duration(milliseconds: 300));
      entry.remove();

      if (mounted) navigator.pop();

    } catch (e, s) {
      // Unexpected error: show friendly message and log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado al guardar: ${e.toString()}', style: const TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent[700],
        ),
      );
      try { HapticFeedback.vibrate(); } catch (_) {}
      final logger = Logger();
      logger.e('Unexpected error in _saveRoutine', error: e, stackTrace: s);
      return;
    }
  }
  void _addExercise(int dayIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => BibliotecaBottomSheet(
        onAdd: (LibraryExercise ex) {
          ref
              .read(createRoutineProvider(widget.rutina).notifier)
              .addExerciseToDay(dayIndex, ex);
          try { HapticFeedback.lightImpact(); } catch (_) {}
          // Snackbar is now shown inside BibliotecaBottomSheet
        },
      ),
    );
  }

  void _exportRoutine(Rutina rutina) {
    // Validate that routine has content worth exporting
    if (rutina.nombre.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ponle nombre a tu rutina antes de compartir',
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (rutina.dias.isEmpty ||
        !rutina.dias.any((d) => d.ejercicios.isNotEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Añade ejercicios antes de compartir',
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try { HapticFeedback.selectionClick(); } catch (_) {}
    RoutineSharingService.instance.shareRoutine(rutina);
  }

  /// Importa ejercicios desde imagen usando OCR
  void _importFromOcr() {
    final routineState = ref.read(createRoutineProvider(widget.rutina));
    
    // Verificar que hay al menos un día
    if (routineState.dias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Primero añade un día a tu rutina',
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Mostrar selector de día si hay más de uno
    final targetDayIndex = routineState.dias.length == 1 
        ? 0 
        : ref.read(createRoutineProvider(widget.rutina).notifier).expandedDayIndex;

    // Si no hay día expandido y hay múltiples días, preguntar
    if (targetDayIndex < 0 && routineState.dias.length > 1) {
      _showDaySelectorForImport();
      return;
    }

    final dayIndex = targetDayIndex < 0 ? 0 : targetDayIndex;

    RoutineImportDialog.show(
      context,
      onConfirm: (candidates) async {
        await _processOcrCandidates(dayIndex, candidates);
      },
    );
  }

  /// Muestra selector de día para importar
  void _showDaySelectorForImport() {
    final routineState = ref.read(createRoutineProvider(widget.rutina));
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿A qué día importar?',
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ...routineState.dias.asMap().entries.map((entry) {
              final index = entry.key;
              final dia = entry.value;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red[700],
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                title: Text(
                  dia.nombre,
                  style: GoogleFonts.montserrat(color: Colors.white),
                ),
                subtitle: Text(
                  '${dia.ejercicios.length} ejercicio${dia.ejercicios.length == 1 ? '' : 's'}',
                  style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  RoutineImportDialog.show(
                    context,
                    onConfirm: (candidates) async {
                      await _processOcrCandidates(index, candidates);
                    },
                  );
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Procesa los candidatos de OCR y los añade al día
  Future<void> _processOcrCandidates(int dayIndex, List<ParsedExerciseCandidate> candidates) async {
    final ocrService = RoutineOcrService.instance;
    final notifier = ref.read(createRoutineProvider(widget.rutina).notifier);

    final exercises = <LibraryExercise>[];
    final seriesList = <int>[];
    final repsRangeList = <String>[];

    for (final candidate in candidates) {
      if (candidate.matchedExerciseId == null) continue;
      
      final exercise = await ocrService.getExerciseById(candidate.matchedExerciseId!);
      if (exercise != null) {
        exercises.add(exercise);
        seriesList.add(candidate.series);
        repsRangeList.add(candidate.reps.toString());
      }
    }

    if (exercises.isNotEmpty) {
      notifier.addExercisesFromOcr(dayIndex, exercises, seriesList, repsRangeList);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡${exercises.length} ejercicio${exercises.length == 1 ? '' : 's'} importado${exercises.length == 1 ? '' : 's'}!',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        try { HapticFeedback.heavyImpact(); } catch (_) {}
      }
    }
  }

  /// Importa ejercicios usando dictado por voz
  /// Se mantiene para compatibilidad aunque el flujo principal usa _showUnifiedImportSheet
  // ignore: unused_element
  void _importFromVoice() {
    final routineState = ref.read(createRoutineProvider(widget.rutina));

    // Verificar que hay al menos un día
    if (routineState.dias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Primero añade un día a tu rutina',
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Determinar día objetivo
    final targetDayIndex = routineState.dias.length == 1
        ? 0
        : ref.read(createRoutineProvider(widget.rutina).notifier).expandedDayIndex;

    // Si no hay día expandido y hay múltiples días, preguntar
    if (targetDayIndex < 0 && routineState.dias.length > 1) {
      _showDaySelectorForVoice();
      return;
    }

    final dayIndex = targetDayIndex < 0 ? 0 : targetDayIndex;
    _showVoiceInputSheet(dayIndex);
  }

  /// Muestra selector de día para importar por voz
  void _showDaySelectorForVoice() {
    final routineState = ref.read(createRoutineProvider(widget.rutina));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mic, color: Colors.red[400]),
                const SizedBox(width: 8),
                Text(
                  '¿A qué día añadir?',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...routineState.dias.asMap().entries.map((entry) {
              final index = entry.key;
              final dia = entry.value;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red[700],
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                title: Text(
                  dia.nombre,
                  style: GoogleFonts.montserrat(color: Colors.white),
                ),
                subtitle: Text(
                  '${dia.ejercicios.length} ejercicio${dia.ejercicios.length == 1 ? '' : 's'}',
                  style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showVoiceInputSheet(index);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Muestra el sheet de input por voz
  void _showVoiceInputSheet(int dayIndex) {
    VoiceInputSheet.show(
      context,
      onConfirm: (parsedExercises) async {
        await _processVoiceExercises(dayIndex, parsedExercises);
      },
    );
  }

  /// Procesa los ejercicios del dictado por voz y los añade al día
  Future<void> _processVoiceExercises(
    int dayIndex,
    List<VoiceParsedExercise> parsedExercises,
  ) async {
    final voiceService = VoiceInputService.instance;
    final notifier = ref.read(createRoutineProvider(widget.rutina).notifier);

    final exercises = <LibraryExercise>[];
    final seriesList = <int>[];
    final repsRangeList = <String>[];

    for (final parsed in parsedExercises) {
      if (parsed.matchedId == null) continue;

      final exercise = await voiceService.getExerciseById(parsed.matchedId!);
      if (exercise != null) {
        exercises.add(exercise);
        seriesList.add(parsed.series);
        repsRangeList.add(parsed.repsRange);
      }
    }

    if (exercises.isNotEmpty) {
      // Reutilizamos el método existente de OCR ya que tienen la misma estructura
      notifier.addExercisesFromOcr(dayIndex, exercises, seriesList, repsRangeList);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mic, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  '¡${exercises.length} ejercicio${exercises.length == 1 ? '' : 's'} añadido${exercises.length == 1 ? '' : 's'}!',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        try {
          HapticFeedback.heavyImpact();
        } catch (_) {}
      }
    }
  }
  
  /// 🎯 UX ALTO: Sheet unificado para todas las formas de añadir ejercicios
  void _showUnifiedImportSheet() {
    final routineState = ref.read(createRoutineProvider(widget.rutina));

    // Verificar que hay al menos un día
    if (routineState.dias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Primero añade un día a tu rutina',
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try { HapticFeedback.selectionClick(); } catch (_) {}

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[700],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'AÑADIR EJERCICIOS',
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              // Opción 1: Biblioteca (principal y más usada)
              _ImportOptionTile(
                icon: Icons.search,
                iconColor: Colors.redAccent[400]!,
                title: 'Buscar en Biblioteca',
                subtitle: 'Busca ejercicios por nombre o músculo',
                onTap: () {
                  Navigator.pop(ctx);
                  _handleAddFromLibrary();
                },
              ),
              const SizedBox(height: 12),
              // Opción 2: Smart Import (detecta automático)
              _ImportOptionTile(
                icon: Icons.auto_awesome,
                iconColor: Colors.amber[400]!,
                title: 'Import Inteligente',
                subtitle: 'Pega texto o dicta tus ejercicios',
                onTap: () {
                  Navigator.pop(ctx);
                  _showSmartImport();
                },
              ),
              const SizedBox(height: 12),
              // Opción 3: Escanear imagen
              _ImportOptionTile(
                icon: Icons.document_scanner,
                iconColor: Colors.blue[400]!,
                title: 'Escanear Imagen',
                subtitle: 'Importa desde foto de rutina',
                onTap: () {
                  Navigator.pop(ctx);
                  _importFromOcr();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Añade ejercicio desde biblioteca (determina día automáticamente)
  void _handleAddFromLibrary() {
    final routineState = ref.read(createRoutineProvider(widget.rutina));
    final targetDayIndex = routineState.dias.length == 1
        ? 0
        : ref.read(createRoutineProvider(widget.rutina).notifier).expandedDayIndex;

    if (targetDayIndex < 0 && routineState.dias.length > 1) {
      // Mostrar selector de día y luego biblioteca
      _showDaySelectorThenLibrary();
    } else {
      _addExercise(targetDayIndex < 0 ? 0 : targetDayIndex);
    }
  }
  
  /// Selector de día antes de mostrar biblioteca
  void _showDaySelectorThenLibrary() {
    final routineState = ref.read(createRoutineProvider(widget.rutina));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text(
            '¿A qué día añadir?',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(routineState.dias.length, (index) {
            final dia = routineState.dias[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red[700],
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                dia.nombre,
                style: GoogleFonts.montserrat(color: Colors.white),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _addExercise(index);
              },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// Muestra el sheet de Smart Import (Voz + OCR unificado)
  void _showSmartImport() {
    final routineState = ref.read(createRoutineProvider(widget.rutina));

    // Verificar que hay al menos un día
    if (routineState.dias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Primero añade un día a tu rutina',
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: Colors.redAccent[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Determinar día objetivo
    final targetDayIndex = routineState.dias.length == 1
        ? 0
        : ref.read(createRoutineProvider(widget.rutina).notifier).expandedDayIndex;

    // Si no hay día expandido y hay múltiples días, preguntar
    if (targetDayIndex < 0 && routineState.dias.length > 1) {
      _showDaySelectorForSmartImport();
      return;
    }

    final dayIndex = targetDayIndex < 0 ? 0 : targetDayIndex;
    _showSmartImportSheet(dayIndex);
  }
  
  /// Muestra selector de día para smart import
  void _showDaySelectorForSmartImport() {
    final routineState = ref.read(createRoutineProvider(widget.rutina));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text(
            '¿A qué día añadir ejercicios?',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(routineState.dias.length, (index) {
            final dia = routineState.dias[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red[700],
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                dia.nombre,
                style: GoogleFonts.montserrat(color: Colors.white),
              ),
              subtitle: Text(
                '${dia.ejercicios.length} ejercicios',
                style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _showSmartImportSheet(index);
              },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  /// Muestra el sheet de smart import para un día específico
  void _showSmartImportSheet(int dayIndex) {
    SmartImportSheet.show(
      context,
      onConfirm: (importedExercises) async {
        await _processSmartImportExercises(dayIndex, importedExercises);
      },
    );
  }
  
  /// Procesa los ejercicios del smart import y los añade al día
  Future<void> _processSmartImportExercises(
    int dayIndex,
    List<SmartImportedExercise> importedExercises,
  ) async {
    final voiceService = VoiceInputService.instance;
    final notifier = ref.read(createRoutineProvider(widget.rutina).notifier);

    final exercises = <LibraryExercise>[];
    final seriesList = <int>[];
    final repsRangeList = <String>[];

    for (final imported in importedExercises) {
      if (imported.matchedId == null) continue;

      final exercise = await voiceService.getExerciseById(imported.matchedId!);
      if (exercise != null) {
        exercises.add(exercise);
        seriesList.add(imported.series);
        repsRangeList.add(imported.repsRange);
      }
    }

    if (exercises.isNotEmpty) {
      notifier.addExercisesFromOcr(dayIndex, exercises, seriesList, repsRangeList);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  '${exercises.length} ejercicio${exercises.length == 1 ? '' : 's'} importado${exercises.length == 1 ? '' : 's'}',
                  style: GoogleFonts.montserrat(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        try {
          HapticFeedback.heavyImpact();
        } catch (_) {}
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final routineState = ref.watch(createRoutineProvider(widget.rutina));
    final notifier = ref.read(createRoutineProvider(widget.rutina).notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.rutina == null ? 'CREA TU RUTINA' : 'EDITAR: ${routineState.nombre.toUpperCase()}',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 22),
        ),
        backgroundColor: Colors.red[900],
        actions: [
          // 🎯 UX ALTO: Un solo botón Smart Import (consolida voz + OCR + smart)
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            tooltip: 'Añadir ejercicios',
            onPressed: _showUnifiedImportSheet,
          ),
          // Export button - only show when editing an existing routine with content
          if (widget.rutina != null || routineState.dias.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'export') {
                  _exportRoutine(routineState);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 20),
                      SizedBox(width: 8),
                      Text('Compartir Rutina'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100), // Space for FAB/Button
        child: Column(
          children: [
            // Routine Name Input
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _nameController,
                style: GoogleFonts.montserrat(
                  fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Nombre que motive miedo',
                  hintStyle: GoogleFonts.montserrat(color: Colors.red[900]!.withValues(alpha: 0.5)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red[900]!)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent[700]!, width: 2)),
                ),
                onChanged: (val) => notifier.updateName(val),
              ),
            ),

            // Days List (Reorderable)
            // Using ReorderableColumn to handle list of Days
            if (routineState.dias.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Center(
                  child: Text(
                    'AÑADE TU PRIMER DÍA',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white24,
                    ),
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                key: ValueKey(routineState.dias.length),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) {
                  // Detectamos el inicio del arrastre y colapsamos cualquier día abierto para evitar glitches visuales
                  Future.microtask(() {
                    final notifier = ref.read(createRoutineProvider(widget.rutina).notifier);
                    if (notifier.expandedDayIndex != -1) {
                      notifier.collapseAllDays();
                    }
                  });

                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      return Material(
                        elevation: animation.value * 8,
                        color: Colors.transparent,
                        shadowColor: Colors.red[900],
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
                onReorder: notifier.reorderDays,
                itemCount: routineState.dias.length,
                itemBuilder: (context, index) {
                  final dia = routineState.dias[index];
                  return Container(
                    key: Key(dia.id),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: DiaExpansionTile(
                      dayIndex: index,
                      dia: dia,
                      // Ensure this item rebuilds when routine state changes (watch),
                      // but read the notifier to get the UI-only expanded index.
                      initiallyExpanded: ref.read(createRoutineProvider(widget.rutina).notifier).expandedDayIndex == index,
                      onExpansionChanged: (val) {
                        if (val) {
                          ref.read(createRoutineProvider(widget.rutina).notifier).setExpandedDay(index);
                        } else {
                          ref.read(createRoutineProvider(widget.rutina).notifier).collapseAllDays();
                        }
                      },
                      onUpdateName: (val) => notifier.updateDayName(index, val),
                      onUpdateProgression: (val) =>
                          notifier.updateDayProgression(index, val),
                      onAddExercise: () => _addExercise(index),
                      onReorderExercises: (oldIdx, newIdx) =>
                          notifier.reorderVisualExercises(index, oldIdx, newIdx),
                      onRemoveExercise: (exIdx) =>
                          notifier.removeExercise(index, exIdx),
                      onUndoRemove: (exIdx, ex) =>
                          notifier.insertExercise(index, exIdx, ex),
                      onUpdateExercise: (exIdx, updated) =>
                          notifier.updateExercise(index, exIdx, updated),
                      onReplaceExercise: (exIdx, alternativaNombre) =>
                          notifier.replaceExercise(index, exIdx, alternativaNombre),
                      onRemoveDay: () => notifier.removeDay(index),
                      onDuplicateDay: () => notifier.duplicateDay(index),
                      onCreateSuperset: (idxA, idxB) =>
                          notifier.createSuperset(index, idxA, idxB),
                      onMoveSuperset: (supersetId, toFlat) => notifier.moveSuperset(index, supersetId, toFlat),
                      onMoveExercise: (fromFlat, toFlat) => notifier.reorderExercises(index, fromFlat, toFlat),
                      onRemoveFromSuperset: (exIdx) =>
                          notifier.removeFromSuperset(index, exIdx),
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            // FAB Add Day (Inline or actual FAB? Requirements: "Floating big red FAB... Below list: big red FAB")
            // "Below list: big red FAB 'AÑADIR DÍA'"
            Center(
              child: FloatingActionButton.extended(
                heroTag: 'add_day_fab',
                onPressed: () {
                  notifier.addDay();
                  try { HapticFeedback.lightImpact(); } catch (_) {}
                },
                icon: const Icon(Icons.add, size: 32),
                label: Text('AÑADIR DÍA', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16)),
                backgroundColor: Colors.red[900],
                elevation: 8,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [BoxShadow(color: Colors.red[900]!.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: ElevatedButton(
          onPressed: _saveRoutine,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent[700],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shadowColor: Colors.redAccent,
            elevation: 10,
          ),
          child: Text(
            'GUARDAR RUTINA',
            style: GoogleFonts.montserrat(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
        ),
      ),
    );
  }
}

/// Widget reutilizable para opciones de importación
class _ImportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ImportOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[850],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}
