import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/sesion.dart';
import '../models/rutina.dart';
import 'session_detail_screen.dart';
import '../providers/training_provider.dart';
import '../widgets/common/app_widgets.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sesionesHistoryStreamProvider);
    final rutinasAsync = ref.watch(rutinasStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HISTORIAL'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'export_all') {
                final sessions = sessionsAsync.valueOrNull ?? [];
                _exportAllSessions(context, sessions);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'export_all',
                child: Row(
                  children: [
                    Icon(Icons.file_download, size: 20),
                    SizedBox(width: 8),
                    Text('Exportar Todo'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const AppLoadingIndicator(message: 'Cargando historial...'),
        error: (err, stack) => ErrorStateWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(sesionesHistoryStreamProvider),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.history_toggle_off,
              title: 'SIN ENTRENAMIENTOS',
              subtitle: 'Completa tu primer entrenamiento para ver el historial.',
            );
          }

          return rutinasAsync.when(
            loading: () => const AppLoadingIndicator(),
            error: (err, stack) => ErrorStateWidget(message: 'Error cargando rutinas: $err'),
            data: (rutinas) {
              final rutinasMap = {for (var r in rutinas) r.id: r};

              // Agrupar sesiones por semana
              final groupedSessions = _groupSessionsByWeek(sessions);

              return ListView.builder(
                itemCount: groupedSessions.length,
                padding: const EdgeInsets.only(top: 16, bottom: 80),
                itemBuilder: (context, index) {
                  final weekEntry = groupedSessions.entries.elementAt(index);
                  return _WeekSection(
                    weekLabel: weekEntry.key,
                    sessions: weekEntry.value,
                    rutinasMap: rutinasMap,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<Sesion>> _groupSessionsByWeek(List<Sesion> sessions) {
    final grouped = <String, List<Sesion>>{};
    final now = DateTime.now();

    for (final session in sessions) {
      final diff = now.difference(session.fecha).inDays;
      String label;

      if (diff < 7) {
        label = 'ESTA SEMANA';
      } else if (diff < 14) {
        label = 'SEMANA PASADA';
      } else if (diff < 30) {
        label = 'ESTE MES';
      } else {
        final monthLabel = DateFormat('MMMM yyyy', 'es_ES').format(session.fecha).toUpperCase();
        label = monthLabel;
      }

      grouped.putIfAbsent(label, () => []).add(session);
    }

    return grouped;
  }

  void _exportAllSessions(BuildContext context, List<Sesion> sessions) {
    if (sessions.isEmpty) return;

    final data = sessions.map((s) => _sessionToMap(s)).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

    Share.share(
      jsonStr,
      subject: 'Juan Training - Historial Completo',
    );
  }

  Map<String, dynamic> _sessionToMap(Sesion session) {
    return {
      'id': session.id,
      'fecha': session.fecha.toIso8601String(),
      'duracionMin': session.durationSeconds != null ? (session.durationSeconds! / 60).round() : null,
      'volumenTotal': session.totalVolume,
      'seriesCompletadas': session.completedSetsCount,
      'ejercicios': session.ejerciciosCompletados.map((e) => {
        'nombre': e.nombre,
        'series': e.logs.map((l) => {
          'peso': l.peso,
          'reps': l.reps,
          'completado': l.completed,
          'rpe': l.rpe,
        }).toList(),
      }).toList(),
    };
  }
}

class _WeekSection extends StatelessWidget {
  final String weekLabel;
  final List<Sesion> sessions;
  final Map<String, Rutina> rutinasMap;

  const _WeekSection({
    required this.weekLabel,
    required this.sessions,
    required this.rutinasMap,
  });

  @override
  Widget build(BuildContext context) {
    // Calcular estadísticas de la semana
    final totalVolume = sessions.fold(0.0, (sum, s) => sum + s.totalVolume);
    final totalSessions = sessions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                weekLabel,
                style: GoogleFonts.montserrat(
                  color: Colors.redAccent[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$totalSessions sesiones • ${(totalVolume / 1000).toStringAsFixed(1)}t vol',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ],
          ),
        ),
        ...sessions.map((session) => _SessionTile(
          key: ValueKey(session.id),
          session: session,
          rutinasMap: rutinasMap,
        )),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SessionTile extends StatefulWidget {
  final Sesion session;
  final Map<String, Rutina> rutinasMap;

  const _SessionTile({super.key, required this.session, required this.rutinasMap});

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final rutina = widget.rutinasMap[widget.session.rutinaId];
    final rutinaName = rutina?.nombre ?? 'RUTINA ELIMINADA';

    final dateStr = DateFormat('d MMM', 'es_ES').format(widget.session.fecha).toUpperCase();
    final timeStr = DateFormat('HH:mm').format(widget.session.fecha);

    final durationText = widget.session.durationSeconds != null
       ? '${(widget.session.durationSeconds! / 60).toStringAsFixed(0)} MIN'
       : 'N/A';

    return Card(
      child: Column(
        children: [
          InkWell(
            onTap: () {
              try { HapticFeedback.selectionClick(); } catch (_) {}
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            onLongPress: () {
              try { HapticFeedback.mediumImpact(); } catch (_) {}
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SessionDetailScreen(sesion: widget.session),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    width: 55,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Column(
                      children: [
                        Text(
                          dateStr.split(' ')[0],
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        Text(
                          dateStr.split(' ').length > 1 ? dateStr.split(' ')[1] : '',
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                rutinaName.toUpperCase(),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.session.dayName != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red[900]?.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  widget.session.dayName!,
                                  style: TextStyle(
                                    color: Colors.redAccent[100],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(timeStr, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(width: 12),
                            Icon(Icons.timer, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(durationText, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(width: 12),
                            Icon(Icons.fitness_center, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              '${(widget.session.totalVolume / 1000).toStringAsFixed(1)}t',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.redAccent[700],
                  ),
                ],
              ),
            ),
          ),
          // Detalle expandible
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.grey[800]),
          const SizedBox(height: 8),
          // Lista de ejercicios resumida
          ...widget.session.ejerciciosCompletados.take(5).map((ejercicio) {
            final completedSets = ejercicio.logs.where((l) => l.completed).length;
            final maxWeight = ejercicio.logs
                .where((l) => l.completed)
                .fold(0.0, (max, l) => l.peso > max ? l.peso : max);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ejercicio.nombre,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '$completedSets series',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${maxWeight}kg max',
                    style: TextStyle(color: Colors.redAccent[100], fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
          if (widget.session.ejerciciosCompletados.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${widget.session.ejerciciosCompletados.length - 5} ejercicios más',
                style: TextStyle(color: Colors.grey[600], fontSize: 11),
              ),
            ),
          const SizedBox(height: 12),
          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SessionDetailScreen(sesion: widget.session),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility, size: 18),
                  label: const Text('VER DETALLE'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: Colors.grey[700]!),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _exportSession(context, widget.session),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('EXPORT'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent[100],
                  side: BorderSide(color: Colors.red[900]!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _exportSession(BuildContext context, Sesion session) {
    try { HapticFeedback.selectionClick(); } catch (_) {}

    final buffer = StringBuffer();
    buffer.writeln('=== JUAN TRAINING ===');
    buffer.writeln('Fecha: ${DateFormat('dd/MM/yyyy HH:mm', 'es_ES').format(session.fecha)}');
    if (session.dayName != null) buffer.writeln('Día: ${session.dayName}');
    buffer.writeln('Duración: ${session.formattedDuration}');
    buffer.writeln('Volumen Total: ${(session.totalVolume / 1000).toStringAsFixed(1)} toneladas');
    buffer.writeln('');
    buffer.writeln('--- EJERCICIOS ---');

    for (final ejercicio in session.ejerciciosCompletados) {
      buffer.writeln('');
      buffer.writeln('${ejercicio.nombre}:');
      for (var i = 0; i < ejercicio.logs.length; i++) {
        final log = ejercicio.logs[i];
        if (log.completed) {
          final rpeStr = log.rpe != null ? ' RPE:${log.rpe}' : '';
          buffer.writeln('  Serie ${i + 1}: ${log.peso}kg x ${log.reps}$rpeStr');
        }
      }
    }

    Share.share(buffer.toString(), subject: 'Juan Training - Sesión ${DateFormat('dd/MM').format(session.fecha)}');
  }
}
