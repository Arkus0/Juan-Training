import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/ejercicio_en_rutina.dart';
import '../../../models/library_exercise.dart';
import '../../../services/exercise_library_service.dart';

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

class EjercicioCard extends StatelessWidget {
  final EjercicioEnRutina ejercicio;
  final Function() onRemove;
  final Function(EjercicioEnRutina) onUpdate;
  final Function()? onLink;
  final Function()? onUnlink;
  final SupersetDragData? linkDragData;
  final VoidCallback? onLinkDragStart;
  final VoidCallback? onLinkDragEnd;
  final VoidCallback? onLinkDragCancel;
  final bool disableSwipe;

  const EjercicioCard({
    super.key,
    required this.ejercicio,
    required this.onRemove,
    required this.onUpdate,
    this.onLink,
    this.onUnlink,
    this.linkDragData,
    this.onLinkDragStart,
    this.onLinkDragEnd,
    this.onLinkDragCancel,
    this.disableSwipe = false,
  });

  void _showProOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'OPCIONES PRO: ${ejercicio.nombre}',
                style: GoogleFonts.montserrat(
                  fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 16),

              if (onUnlink != null)
                ListTile(
                  leading: const Icon(Icons.link_off, color: Colors.orange),
                  title: const Text('DESVINCULAR (ROMPER SUPERSERIE)', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    onUnlink!();
                  },
                ),

              TextFormField(
                initialValue: ejercicio.notas,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Notas / RPE / Tempo'),
                onChanged: (val) {
                  onUpdate(ejercicio.copyWith(notas: val));
                },
              ),
              const SizedBox(height: 16),
              // Rest Time
              Row(
                children: [
                  const Text('Descanso (seg): ', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: TextFormField(
                      initialValue: ejercicio.descansoSugerido?.inSeconds.toString() ?? '60',
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) {
                        final sec = int.tryParse(val);
                        if (sec != null) {
                          onUpdate(ejercicio.copyWith(descansoSugerido: Duration(seconds: sec)));
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  onRemove();
                  Navigator.pop(context);
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
    final int? libId = int.tryParse(ejercicio.id);
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
            // Drag Handle (visual only)
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
                    ejercicio.nombre.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ejercicio.musculosPrincipales.join(', '),
                    style: GoogleFonts.montserrat(
                      fontSize: 10, color: Colors.redAccent[700], fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  // Series x Reps Inputs
                  Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: TextFormField(
                          initialValue: ejercicio.series.toString(),
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
                            if (s != null) onUpdate(ejercicio.copyWith(series: s));
                          },
                        ),
                      ),
                      Text(' x ', style: TextStyle(color: Colors.grey[600])),
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          initialValue: ejercicio.repsRange,
                          style: GoogleFonts.montserrat(
                              fontSize: 14, color: Colors.redAccent, fontWeight: FontWeight.w800),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
                          ),
                          onChanged: (val) {
                            onUpdate(ejercicio.copyWith(repsRange: val));
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            if (onLink != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(Icons.link, color: Colors.white70), // hint only, drag is on long press of card
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

    if (onLink != null) {
      return LongPressDraggable<SupersetDragData>(
        data: linkDragData,
        onDragStarted: onLinkDragStart,
        onDragEnd: (_) => onLinkDragEnd?.call(),
        onDraggableCanceled: (_, __) => onLinkDragCancel?.call(),
        feedback: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Opacity(
              opacity: 0.9,
              child: card,
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: card,
          ),
        ),
        child: card,
      );
    }

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
      if (ejercicio.localImagePath != null) {
        final f = File(ejercicio.localImagePath!);
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
