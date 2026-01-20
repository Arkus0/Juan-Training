import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/sesion.dart';
import '../models/ejercicio.dart';
import '../models/rutina.dart';

class SessionDetailScreen extends StatelessWidget {
  final Sesion sesion;

  const SessionDetailScreen({super.key, required this.sesion});

  @override
  Widget build(BuildContext context) {
    final previousSession = _findPreviousSession();
    final rutinasBox = Hive.box<Rutina>('rutinas');
    final rutinaName = rutinasBox.get(sesion.rutinaId)?.nombre ?? 'Rutina eliminada';

    final dateFormat = DateFormat('EEE, d MMM yyyy HH:mm', 'es_ES');
    final durationText = sesion.durationSeconds != null
        ? '${(sesion.durationSeconds! / 60).toStringAsFixed(0)} min'
        : 'Duración no registrada';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Sesión'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rutinaName, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16),
                        const SizedBox(width: 4),
                        Text(dateFormat.format(sesion.fecha)),
                        const Spacer(),
                        const Icon(Icons.timer, size: 16),
                        const SizedBox(width: 4),
                        Text(durationText),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Exercises List
            Text('Ejercicios', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...sesion.ejerciciosCompletados.map((ejercicio) {
              return _buildExerciseCard(
                context,
                ejercicio,
                _findExerciseById(sesion.ejerciciosObjetivo, ejercicio.id),
                previousSession != null
                    ? _findExerciseById(previousSession.ejerciciosCompletados, ejercicio.id)
                    : null,
              );
            }).toList(),

            if (sesion.ejerciciosCompletados.isEmpty)
               const Text('No se registraron ejercicios en esta sesión.'),
          ],
        ),
      ),
    );
  }

  Sesion? _findPreviousSession() {
    final box = Hive.box<Sesion>('sesiones');
    // Filter by same routine and date strictly before current session
    final history = box.values.where((s) =>
      s.rutinaId == sesion.rutinaId &&
      s.fecha.isBefore(sesion.fecha)
    ).toList();

    if (history.isEmpty) return null;

    // Sort descending by date (newest first)
    history.sort((a, b) => b.fecha.compareTo(a.fecha));
    return history.first;
  }

  Ejercicio? _findExerciseById(List<Ejercicio> list, String id) {
    try {
      return list.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  Widget _buildExerciseCard(
    BuildContext context,
    Ejercicio real,
    Ejercicio? target,
    Ejercicio? prev
  ) {
    // Determine max sets to display rows
    final maxSets = [
      real.series,
      target?.series ?? 0,
      prev?.series ?? 0
    ].reduce((curr, next) => curr > next ? curr : next);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(real.nombre, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Table(
              columnWidths: const {
                0: FixedColumnWidth(40), // Set #
                1: FlexColumnWidth(),    // Target
                2: FlexColumnWidth(),    // Real
                3: FlexColumnWidth(),    // Prev
              },
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 0.5
                )
              ),
              children: [
                // Header
                TableRow(
                  children: [
                    _buildHeaderCell('#'),
                    _buildHeaderCell('Meta'),
                    _buildHeaderCell('Real'),
                    _buildHeaderCell('Prev'),
                  ]
                ),
                // Rows
                for (int i = 0; i < maxSets; i++)
                  TableRow(
                    children: [
                      _buildCell('${i + 1}'),
                      // Target
                      _buildDataCell(target, i),
                      // Real
                      _buildDataCell(real, i, isReal: true),
                      // Prev
                      _buildDataCell(prev, i, isPrev: true),
                    ]
                  )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDataCell(Ejercicio? ejercicio, int setIndex, {bool isReal = false, bool isPrev = false}) {
    if (ejercicio == null || setIndex >= ejercicio.series) {
      return _buildCell('-');
    }

    // For now, we assume weight/reps are constant across sets for the "Ejercicio" model
    // because Ejercicio has single 'reps' and 'peso' fields, not a list per set.
    // NOTE: The current Ejercicio model seems to imply 3x10 @ 20kg means all sets are the same.
    // If the user wants per-set logging, the model would need to be List<SetLog>.
    // Based on "Ejercicio (series, reps, peso)", it's a summary.
    // So we just show the same values for each set line, or just 1 line?
    // The prompt says "Tabla... peso/reps objetivo vs real".
    // Since the model is simple, we repeat the values.

    final text = '${ejercicio.peso}kg x ${ejercicio.reps}';

    // Simple color coding for Real vs Target could go here (e.g. green if met)
    // For MVP, just text.

    return _buildCell(text);
  }
}
