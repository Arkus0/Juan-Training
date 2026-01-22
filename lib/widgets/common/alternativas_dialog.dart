import 'package:flutter/material.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/alternativas_service.dart';

/// Dialog que muestra las alternativas para un ejercicio.
/// Permite seleccionar una alternativa para reemplazar el ejercicio actual.
///
/// [ejercicioNombre]: Nombre del ejercicio actual.
/// [onReplace]: Callback con el nombre de la alternativa seleccionada.
/// [onCancel]: Callback opcional cuando se cancela.
class AlternativasDialog extends StatelessWidget {
  final String ejercicioNombre;
  final void Function(String alternativaNombre) onReplace;
  final VoidCallback? onCancel;

  const AlternativasDialog({
    super.key,
    required this.ejercicioNombre,
    required this.onReplace,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final alternativas = AlternativasService.instance.getAlternativas(ejercicioNombre);

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
            ejercicioNombre.toUpperCase(),
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

  Widget _buildAlternativasList(BuildContext context, List<String> alternativas) {
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
          nombre: alternativa,
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
  final String nombre;
  final bool isFirst;
  final VoidCallback onTap;

  const _AlternativaItem({
    required this.nombre,
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
                    nombre.toUpperCase(),
                    style: GoogleFonts.montserrat(
                      // Primera alternativa destacada, resto en gris suave
                      color: isFirst ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (isFirst)
                    Text(
                      'RECOMENDADA',
                      style: GoogleFonts.montserrat(
                        color: Colors.redAccent[700],
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
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
  required String ejercicioNombre,
  required void Function(String alternativaNombre) onReplace,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => AlternativasDialog(
      ejercicioNombre: ejercicioNombre,
      onReplace: onReplace,
    ),
  );
}
