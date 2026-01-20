import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/sesion.dart';
import '../models/rutina.dart';
import 'session_detail_screen.dart';
import '../providers/training_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sesionesHistoryStreamProvider);
    final rutinasAsync = ref.watch(rutinasStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LEGADO DE BATALLA'),
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 24),
                  Text(
                    'SIN HISTORIAL',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu leyenda comienza con el primer entreno.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return rutinasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error rutinas: $err')),
            data: (rutinas) {
              final rutinasMap = {for (var r in rutinas) r.id: r};

              return ListView.builder(
                itemCount: sessions.length,
                padding: const EdgeInsets.only(top: 16, bottom: 16),
                itemBuilder: (context, index) {
                  final session = sessions[index];
                  return _SessionTile(session: session, rutinasMap: rutinasMap);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Sesion session;
  final Map<String, Rutina> rutinasMap;

  const _SessionTile({required this.session, required this.rutinasMap});

  @override
  Widget build(BuildContext context) {
    final rutina = rutinasMap[session.rutinaId];
    final rutinaName = rutina?.nombre ?? 'RUTINA ELIMINADA';

    final dateStr = DateFormat('d MMM', 'es_ES').format(session.fecha).toUpperCase();
    final timeStr = DateFormat('HH:mm').format(session.fecha);

    final durationText = session.durationSeconds != null
       ? '${(session.durationSeconds! / 60).toStringAsFixed(0)} MIN'
       : 'N/A';

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SessionDetailScreen(sesion: session),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Column(
                  children: [
                    Text(
                      dateStr.split(' ')[0], // Day
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    Text(
                      dateStr.split(' ')[1], // Month
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.redAccent[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rutinaName.toUpperCase(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          timeStr,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.timer, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          durationText,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.redAccent[700]),
            ],
          ),
        ),
      ),
    );
  }
}
