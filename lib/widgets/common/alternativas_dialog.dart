import 'package:flutter/material.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/alternativas_service.dart';
import '../../services/exercise_library_service.dart';
import '../../models/library_exercise.dart';

/// Dialog que muestra las alternativas para un ejercicio.
/// Permite seleccionar una alternativa para reemplazar el ejercicio actual.
///
/// [exerciseId]: ID del ejercicio actual (para buscar alternativas).
/// [exerciseName]: Nombre del ejercicio actual (para mostrar en el título).
/// [onReplace]: Callback con el objeto LibraryExercise seleccionado.
/// [onCancel]: Callback opcional cuando se cancela.
class AlternativasDialog extends StatelessWidget {
  final String exerciseId;
  final String exerciseName;
  final void Function(LibraryExercise alternativa) onReplace;
  final VoidCallback? onCancel;

  const AlternativasDialog({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.onReplace,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Obtener IDs de alternativas
    final ids = AlternativasService.instance.getAlternativasIds(exerciseId);

    // 2. Resolver IDs a objetos LibraryExercise
    final List<LibraryExercise> alternativas = ids
        .map((id) => ExerciseLibraryService.instance.getExerciseById(id))
        .whereType<LibraryExercise>() // Filtrar nulos
        .toList();

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red[900]!.withValues(alpha: 0.5)),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz, color: Colors.redAccent[700], size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ALTERNATIVAS',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            exerciseName.toUpperCase(),
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.redAccent[700],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: alternativas.isEmpty
            ? _buildEmptyState()
            : _buildAlternativasList(context, alternativas),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onCancel?.call();
          },
          child: Text(
            'CERRAR',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              color: Colors.grey[400],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey[700]),
          const SizedBox(height: 12),
          Text(
            'Sin alternativas registradas',
            style: GoogleFonts.montserrat(
              color: Colors.white38,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Prueba buscando en la biblioteca',
            style: GoogleFonts.montserrat(
              color: Colors.white24,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativasList(BuildContext context, List<LibraryExercise> alternativas) {
    return ListView.separated(
      shrinkWrap: true,
      itemCount: alternativas.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Colors.grey[800],
      ),
      itemBuilder: (context, index) {
        final alternativa = alternativas[index];
        return _AlternativaItem(
          exercise: alternativa,
          isFirst: index == 0,
          onTap: () {
            Vibrate.feedback(FeedbackType.selection);
            Navigator.pop(context);
            onReplace(alternativa);
          },
        );
      },
    );
  }
}

class _AlternativaItem extends StatelessWidget {
  final LibraryExercise exercise;
  final bool isFirst;
  final VoidCallback onTap;

  const _AlternativaItem({
    required this.exercise,
    required this.isFirst,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      // Primera alternativa destacada, resto en gris suave
                      color: isFirst ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (exercise.equipment.isNotEmpty)
                    Text(
                      exercise.equipment,
                      style: GoogleFonts.montserrat(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (isFirst)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'RECOMENDADA',
                        style: GoogleFonts.montserrat(
                          color: Colors.redAccent[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red[900]?.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.red[900]!.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                'REEMPLAZAR',
                style: GoogleFonts.montserrat(
                  color: Colors.redAccent[100],
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Función helper para mostrar el dialog de alternativas fácilmente.
Future<void> showAlternativasDialog({
  required BuildContext context,
  required String exerciseId,
  required String exerciseName,
  required void Function(LibraryExercise alternativa) onReplace,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => AlternativasDialog(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      onReplace: onReplace,
    ),
  );
}
