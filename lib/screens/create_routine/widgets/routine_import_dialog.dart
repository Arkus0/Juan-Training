import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/models/ejercicio_en_rutina.dart';
import 'package:juan_training/services/routine_ocr_service.dart';
import 'package:juan_training/screens/create_routine/widgets/biblioteca_bottom_sheet.dart';

class RoutineImportDialog extends ConsumerStatefulWidget {
  const RoutineImportDialog({super.key});

  @override
  ConsumerState<RoutineImportDialog> createState() => _RoutineImportDialogState();
}

class _RoutineImportDialogState extends ConsumerState<RoutineImportDialog> {
  List<ParsedExerciseCandidate> _candidates = [];
  bool _isLoading = false;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSourceSelection();
    });
  }

  void _showSourceSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¿CÓMO QUIERES IMPORTAR?',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.redAccent, size: 30),
              title: Text('Hacer una Foto', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16)),
              onTap: () {
                Navigator.pop(ctx);
                _scan(ImageSource.camera);
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.redAccent, size: 30),
              title: Text('Elegir de Galería', style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16)),
              onTap: () {
                Navigator.pop(ctx);
                _scan(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    ).then((_) {
      // If user dismissed sheet without picking (isLoading false and hasScanned false)
      if (!_isLoading && !_hasScanned) {
         if (mounted) Navigator.pop(context); // Cancel the whole dialog
      }
    });
  }

  Future<void> _scan(ImageSource source) async {
    setState(() {
      _isLoading = true;
      _hasScanned = true;
    });

    try {
      final lines = await RoutineOcrService.instance.pickAndScanImage(source);

      // If user cancelled picker, lines is empty
      if (lines.isEmpty) {
         if (mounted) Navigator.pop(context);
         return;
      }

      final candidates = await RoutineOcrService.instance.parseLines(lines);

      if (mounted) {
        setState(() {
          _candidates = candidates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error: $e', style: const TextStyle(color: Colors.white)),
                backgroundColor: Colors.red,
            )
        );
        Navigator.pop(context);
      }
    }
  }

  void _updateCandidateExercise(int index, LibraryExercise ex) {
    setState(() {
      final old = _candidates[index];
      _candidates[index] = ParsedExerciseCandidate(
        originalText: old.originalText,
        matchedExercise: ex,
        series: old.series,
        reps: old.reps,
        weight: old.weight,
      );
    });
  }

  void _updateSeries(int index, String val) {
    final s = int.tryParse(val);
    if (s != null) {
        final old = _candidates[index];
        setState(() {
            _candidates[index] = ParsedExerciseCandidate(
                originalText: old.originalText,
                matchedExercise: old.matchedExercise,
                series: s,
                reps: old.reps,
                weight: old.weight
            );
        });
    }
  }

  void _updateReps(int index, String val) {
    final old = _candidates[index];
    setState(() {
        _candidates[index] = ParsedExerciseCandidate(
            originalText: old.originalText,
            matchedExercise: old.matchedExercise,
            series: old.series,
            reps: val,
            weight: old.weight
        );
    });
  }

  void _removeCandidate(int index) {
      setState(() {
          _candidates.removeAt(index);
      });
  }

  void _confirm() {
    final valid = _candidates.where((c) => c.matchedExercise != null).toList();

    final result = valid.map((c) {
      return EjercicioEnRutina(
        id: c.matchedExercise!.id.toString(),
        nombre: c.matchedExercise!.name,
        descripcion: c.matchedExercise!.description,
        musculosPrincipales: c.matchedExercise!.muscles,
        musculosSecundarios: c.matchedExercise!.secondaryMuscles,
        equipo: c.matchedExercise!.equipment,
        localImagePath: c.matchedExercise!.localImagePath,
        series: c.series,
        repsRange: c.reps,
        notas: c.weight, // Store detected weight in notes
      );
    }).toList();

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    // If we have candidates but no valid exercises, disable button
    final hasValid = _candidates.any((c) => c.matchedExercise != null);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('IMPORTACIÓN INTELIGENTE', style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
        backgroundColor: Colors.red[900],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
        ? Center(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    const CircularProgressIndicator(color: Colors.red),
                    const SizedBox(height: 20),
                    Text('ANALIZANDO IMAGEN...', style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold))
                ]
            )
          )
        : Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Revisa los ejercicios detectados antes de confirmar.',
                style: GoogleFonts.montserrat(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: ListView.builder(
                  itemCount: _candidates.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                     final c = _candidates[index];
                     final isMatch = c.matchedExercise != null;

                     return Container(
                       margin: const EdgeInsets.only(bottom: 12),
                       decoration: BoxDecoration(
                           color: Colors.grey[900],
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: isMatch ? Colors.transparent : Colors.redAccent.withValues(alpha: 0.5))
                       ),
                       child: Padding(
                         padding: const EdgeInsets.all(12.0),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                              // Header: Original Text & Delete
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                      Flexible(
                                        child: Text(
                                            'Texto: "${c.originalText}"',
                                            style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                                            overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      InkWell(
                                          onTap: () => _removeCandidate(index),
                                          child: const Icon(Icons.close, color: Colors.white30, size: 20),
                                      )
                                  ]
                              ),
                              const SizedBox(height: 8),

                              // Exercise Match Selector
                              InkWell(
                                  onTap: () {
                                      showModalBottomSheet(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) => BibliotecaBottomSheet(
                                              onAdd: (ex) {
                                                  _updateCandidateExercise(index, ex);
                                                  Navigator.pop(context); // Close sheet
                                              }
                                          )
                                      );
                                  },
                                  child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: Colors.black,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: isMatch ? Colors.white12 : Colors.redAccent)
                                      ),
                                      child: Row(
                                          children: [
                                              Expanded(
                                                  child: Text(
                                                      isMatch ? c.matchedExercise!.name : 'Toca para seleccionar ejercicio...',
                                                      style: GoogleFonts.montserrat(
                                                          color: isMatch ? Colors.white : Colors.redAccent,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16
                                                      )
                                                  )
                                              ),
                                              const Icon(Icons.search, color: Colors.white54),
                                          ]
                                      ),
                                  ),
                              ),

                              const SizedBox(height: 12),

                              // Metrics Inputs
                              Row(
                                  children: [
                                      // Series
                                      Expanded(
                                          child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                                              child: TextFormField(
                                                  initialValue: c.series.toString(),
                                                  keyboardType: TextInputType.number,
                                                  style: const TextStyle(color: Colors.white),
                                                  decoration: const InputDecoration(
                                                      labelText: 'Series',
                                                      labelStyle: TextStyle(color: Colors.grey),
                                                      border: InputBorder.none
                                                  ),
                                                  onChanged: (val) => _updateSeries(index, val),
                                              ),
                                          )
                                      ),
                                      const SizedBox(width: 12),
                                      // Reps
                                      Expanded(
                                          child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
                                              child: TextFormField(
                                                  initialValue: c.reps,
                                                  style: const TextStyle(color: Colors.white),
                                                  decoration: const InputDecoration(
                                                      labelText: 'Reps',
                                                      labelStyle: TextStyle(color: Colors.grey),
                                                      border: InputBorder.none
                                                  ),
                                                  onChanged: (val) => _updateReps(index, val),
                                              ),
                                          )
                                      ),
                                      // Weight (ReadOnly)
                                      if (c.weight != null) ...[
                                          const SizedBox(width: 12),
                                          Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(color: Colors.blueGrey[900], borderRadius: BorderRadius.circular(4)),
                                              child: Text(
                                                  c.weight!,
                                                  style: GoogleFonts.montserrat(color: Colors.white, fontSize: 10),
                                              )
                                          )
                                      ]
                                  ]
                              )
                           ],
                         ),
                       ),
                     );
                  },
              ),
            ),
          ],
        ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
            onPressed: hasValid ? _confirm : null,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[900],
                disabledBackgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
                'CONFIRM IMPORTACIÓN (${_candidates.where((c) => c.matchedExercise != null).length})',
                style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)
            ),
        ),
      ),
    );
  }
}
