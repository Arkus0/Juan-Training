import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/sesion.dart';
import '../models/rutina.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Sesion>('sesiones').listenable(),
        builder: (context, Box<Sesion> box, _) {
          if (box.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay sesiones registradas.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final sessions = box.values.toList();
          // Sort by date descending (newest first)
          sessions.sort((a, b) => b.fecha.compareTo(a.fecha));

          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return _SessionTile(session: session);
            },
          );
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Sesion session;

  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    // Look up routine name safely
    final rutinaBox = Hive.box<Rutina>('rutinas');
    final rutina = rutinaBox.get(session.rutinaId);
    final rutinaName = rutina?.nombre ?? 'Rutina desconocida';

    // Format Date: e.g., "Lun, 23 Oct"
    // Note: Requires initializeDateFormatting if strictly enforcing locales,
    // but usually works for common locales on modern Flutter.
    final dateStr = DateFormat('EEE, d MMM', 'es_ES').format(session.fecha);
    final timeStr = DateFormat('HH:mm').format(session.fecha);

    // Duration
    final durationText = session.durationSeconds != null
       ? '${(session.durationSeconds! / 60).toStringAsFixed(0)} min'
       : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.check, size: 20),
        ),
        title: Text(
          rutinaName,
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        subtitle: Text(
          '$dateStr • $timeStr${durationText != null ? " • $durationText" : ""}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionDetailScreen(sesion: session),
            ),
          );
        },
      ),
    );
  }
}
