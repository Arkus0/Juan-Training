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
        ? '${(sesion.durationSeconds! / 60).toStringAsFixed(0)} MIN'
        : 'N/A';

    return Scaffold(
      appBar: AppBar(
        title: const Text('INFORME DE COMBATE'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rutinaName.toUpperCase(),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Text(
                          dateFormat.format(sesion.fecha).toUpperCase(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.timer, size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 6),
                        Text(
                          'DURACIÓN: $durationText',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Exercises List
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                'EJERCICIOS EJECUTADOS',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.redAccent[700],
                ),
              ),
            ),
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
               const Padding(
                 padding: EdgeInsets.all(16.0),
                 child: Text('No se registraron ejercicios en esta sesión.'),
               ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              real.nombre.toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Table(
              columnWidths: const {
                0: FixedColumnWidth(30), // Set #
                1: FlexColumnWidth(),    // Target
                2: FlexColumnWidth(),    // Real
                3: FlexColumnWidth(),    // Prev
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                // Header
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.redAccent[700]!, width: 2)),
                  ),
                  children: [
                    _buildHeaderCell(context, '#'),
                    _buildHeaderCell(context, 'META'),
                    _buildHeaderCell(context, 'REAL'),
                    _buildHeaderCell(context, 'PREV'),
                  ]
                ),
                const TableRow(children: [SizedBox(height: 8), SizedBox(height: 8), SizedBox(height: 8), SizedBox(height: 8)]),
                // Rows
                for (int i = 0; i < maxSets; i++)
                  TableRow(
                    children: [
                      _buildCell('${i + 1}'),
                      // Target
                      _buildDataCell(context, target, i),
                      // Real
                      _buildDataCell(context, real, i, isReal: true),
                      // Prev
                      _buildDataCell(context, prev, i, isPrev: true),
                    ]
                  )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.redAccent[700],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Colors.white),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDataCell(BuildContext context, Ejercicio? ejercicio, int setIndex, {bool isReal = false, bool isPrev = false}) {
    if (ejercicio == null || setIndex >= ejercicio.series) {
      return _buildCell('-');
    }

    final text = '${ejercicio.peso}kg x ${ejercicio.reps}';

    // Highlight Real if it meets/exceeds Target (Logic simulation for visual polish)
    // Here we just style "Real" boldly
    if (isReal) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
        textAlign: TextAlign.center,
      ),
    );
  }
}
