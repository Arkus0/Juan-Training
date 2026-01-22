import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:juan_training/models/ejercicio_en_rutina.dart';
import 'package:juan_training/models/library_exercise.dart';
import 'package:juan_training/services/exercise_library_service.dart';
import 'package:juan_training/services/alternativas_service.dart';
import 'package:juan_training/widgets/common/alternativas_dialog.dart';

/// Payload passed through drag events so the parent knows which item is moving.
class SupersetDragData {
  final int visualIndex;
  final int flatIndex;
  final String? supersetId;

  const SupersetDragData({
    required this.visualIndex,
    required this.flatIndex,
    this.supersetId,
  });
}

/// Payload for simple reorder drags (single exercise)
class ReorderDragData {
  final int flatIndex;

  const ReorderDragData({required this.flatIndex});
}

class EjercicioCard extends StatefulWidget {
  final EjercicioEnRutina ejercicio;
  final Function() onRemove;
  final Function(EjercicioEnRutina) onUpdate;
  final Function(String alternativaNombre)? onReplace;
  final Function()? onUnlink;

  const EjercicioCard({
    super.key,
    required this.ejercicio,
    required this.onRemove,
    required this.onUpdate,
    this.onReplace,
    this.onUnlink,
  });

  @override
  State<EjercicioCard> createState() => _EjercicioCardState();
}

class _EjercicioCardState extends State<EjercicioCard> {
  late TextEditingController _seriesController;
  late TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _seriesController = TextEditingController(text: widget.ejercicio.series.toString());
    _repsController = TextEditingController(text: widget.ejercicio.repsRange);
  }

  @override
  void didUpdateWidget(EjercicioCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update if the value changed externally AND differs from current controller text
    // This prevents cursor jumping when the user is actively typing
    if (oldWidget.ejercicio.series != widget.ejercicio.series) {
      final currentText = _seriesController.text;
      final newText = widget.ejercicio.series.toString();
      if (currentText != newText) {
        final selection = _seriesController.selection;
        _seriesController.text = newText;
        // Restore cursor position if valid
        if (selection.isValid && selection.end <= newText.length) {
          _seriesController.selection = selection;
        }
      }
    }
    if (oldWidget.ejercicio.repsRange != widget.ejercicio.repsRange) {
      final currentText = _repsController.text;
      final newText = widget.ejercicio.repsRange;
      if (currentText != newText) {
        final selection = _repsController.selection;
        _repsController.text = newText;
        // Restore cursor position if valid
        if (selection.isValid && selection.end <= newText.length) {
          _repsController.selection = selection;
        }
      }
    }
  }

  @override
  void dispose() {
    _seriesController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  void _showAlternativasDialog(BuildContext context) {
    showAlternativasDialog(
      context: context,
      exerciseId: widget.ejercicio.id,
      exerciseName: widget.ejercicio.nombre,
      onReplace: (alternativa) {
        Vibrate.feedback(FeedbackType.success);
        if (widget.onReplace != null) {
          widget.onReplace!(alternativa.name);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reemplazado por ${alternativa.name}',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.red[900],
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  void _showProOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OPCIONES: ${widget.ejercicio.nombre}',
                style: GoogleFonts.montserrat(
                  fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 16),

              if (widget.onUnlink != null)
                ListTile(
                  leading: const Icon(Icons.link_off, color: Colors.orange),
                  title: const Text('DESVINCULAR (ROMPER SUPERSERIE)', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    widget.onUnlink!();
                  },
                ),

              TextFormField(
                initialValue: widget.ejercicio.notas,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Notas / RPE / Tempo'),
                onChanged: (val) {
                  widget.onUpdate(widget.ejercicio.copyWith(notas: val));
                },
              ),
              const SizedBox(height: 16),
              // Rest Time
              Row(
                children: [
                  const Text('Descanso (seg): ', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: TextFormField(
                      initialValue: widget.ejercicio.descansoSugerido?.inSeconds.toString() ?? '60',
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) {
                        final sec = int.tryParse(val);
                        if (sec != null) {
                          widget.onUpdate(widget.ejercicio.copyWith(descansoSugerido: Duration(seconds: sec)));
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  widget.onRemove();
                },
                icon: const Icon(Icons.delete, color: Colors.white),
                label: const Text('ELIMINAR EJERCICIO'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lookup library exercise by library ID (more reliable than matching by name)
    final int? libId = int.tryParse(widget.ejercicio.id);
    final libraryExercise = libId == null
        ? null
        : ExerciseLibraryService.instance.exercises
            .cast<LibraryExercise?>()
            .firstWhere((e) => e?.id == libId, orElse: () => null);

    final imageWidget = _buildImage(libraryExercise);

    final card = Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            // Drag Handle (reorder handled by parent)
            Icon(Icons.drag_indicator, color: Colors.grey[700]),
            const SizedBox(width: 8),

            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: imageWidget,
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.ejercicio.nombre.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.ejercicio.musculosPrincipales.join(', '),
                    style: GoogleFonts.montserrat(
                      fontSize: 10, color: Colors.redAccent[700], fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Series x Reps Inputs with controllers to prevent focus loss
                  Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: TextField(
                          controller: _seriesController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.montserrat(
                              fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w800),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                          ),
                          onChanged: (val) {
                            final s = int.tryParse(val);
                            if (s != null) widget.onUpdate(widget.ejercicio.copyWith(series: s));
                          },
                        ),
                      ),
                      Text(' x ', style: TextStyle(color: Colors.grey[600])),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _repsController,
                          style: GoogleFonts.montserrat(
                              fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w800),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                          ),
                          onChanged: (val) {
                            widget.onUpdate(widget.ejercicio.copyWith(repsRange: val));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Alternatives button
            if (AlternativasService.instance.hasAlternativas(widget.ejercicio.id))
              IconButton(
                icon: Icon(Icons.swap_horiz, color: Colors.redAccent[700], size: 20),
                onPressed: () => _showAlternativasDialog(context),
                visualDensity: VisualDensity.compact,
                tooltip: 'Ver alternativas',
              ),

            // Info Icon / Menu
            IconButton(
              icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
              onPressed: () => _showProOptions(context),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );

    return card;
  }

  Widget _buildImage(LibraryExercise? libExercise) {
    if (kIsWeb) {
      if (libExercise != null && libExercise.imageUrls.isNotEmpty) {
        return Image.network(
          libExercise.imageUrls.first,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => const Icon(Icons.fitness_center, color: Colors.white24, size: 30),
        );
      }
      return Image.asset(
        'assets/img/placeholder_exercise.png',
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => const Icon(Icons.fitness_center, color: Colors.white24, size: 30),
      );
    }

    try {
      if (widget.ejercicio.localImagePath != null) {
        final f = File(widget.ejercicio.localImagePath!);
        if (f.existsSync() && f.lengthSync() > 0) {
          return Image.file(
            f,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => const Icon(Icons.fitness_center, color: Colors.white24, size: 30),
          );
        }
      }
    } catch (e) {
      // Any filesystem error: fall back to network/placeholder silently
    }
    // Fallback: if library has network image URLs, show network image (helps when local file not yet downloaded)
    if (libExercise != null && libExercise.imageUrls.isNotEmpty) {
      return Image.network(
        libExercise.imageUrls.first,
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => const Icon(Icons.fitness_center, color: Colors.white24, size: 30),
      );
    }

    return Image.asset(
      'assets/img/placeholder_exercise.png',
      width: 60,
      height: 60,
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, stack) => const Icon(Icons.fitness_center, color: Colors.white24, size: 30),
    );
  }
}
