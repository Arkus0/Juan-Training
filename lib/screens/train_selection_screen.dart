import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/rutina.dart';
import '../providers/training_provider.dart';
import '../widgets/common/app_widgets.dart';
import 'training_session_screen.dart';

class TrainSelectionScreen extends ConsumerWidget {
  const TrainSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSessionAsync = ref.watch(activeSessionStreamProvider);
    final rutinasAsync = ref.watch(rutinasStreamProvider);
    final suggestionAsync = ref.watch(smartSuggestionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SELECCIONAR ENTRENO'),
      ),
      body: activeSessionAsync.when(
        loading: () => const AppLoadingIndicator(message: 'Cargando...'),
        error: (err, stack) => ErrorStateWidget(message: err.toString()),
        data: (activeSessionData) {
          if (activeSessionData != null && activeSessionData.activeRutina != null) {
            final Rutina activeRutina = activeSessionData.activeRutina!;
            final startTime = activeSessionData.startTime;

            // Mostrar una barra discreta en la parte superior con acciones rápidas.
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    color: Colors.red[900],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.fitness_center, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('SESIÓN ACTIVA', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white70)),
                                const SizedBox(height: 2),
                                Text(activeRutina.nombre.toUpperCase(), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                                if (startTime != null) Text('Iniciada hace ${DateTime.now().difference(startTime).inMinutes} min', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              Vibrate.feedback(FeedbackType.medium);
                              ref.read(trainingSessionProvider.notifier).restoreFromStorage();
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const TrainingSessionScreen()));
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red[900]),
                            child: const Text('CONTINUAR'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white70),
                            tooltip: 'Descartar sesión',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('¿Descartar sesión?'),
                                  content: const Text('Se perderá el progreso actual.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        ref.read(trainingSessionProvider.notifier).clearStorage();
                                      },
                                      child: const Text('DESCARTAR', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // After the banner, continue to show the normal routines list
                rutinasAsync.when(
                  loading: () => const AppLoadingIndicator(),
                  error: (err, stack) => ErrorStateWidget(message: 'Error cargando rutinas: $err'),
                  data: (rutinas) {
                    if (rutinas.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.warning_amber_rounded,
                        title: 'SIN RUTINAS',
                        subtitle: 'Ve a Rutinas y crea tu plan de batalla.',
                      );
                    }

                    return Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            'TODAS LAS RUTINAS',
                            style: GoogleFonts.montserrat(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Lista de rutinas
                          ...rutinas.map((rutina) => _RutinaCard(
                            key: ValueKey(rutina.id),
                            rutina: rutina,
                            onDaySelected: (dayIndex) => _startSession(context, ref, rutina, dayIndex),
                          )),
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          }

          return rutinasAsync.when(
            loading: () => const AppLoadingIndicator(),
            error: (err, stack) => ErrorStateWidget(message: 'Error cargando rutinas: $err'),
            data: (rutinas) {
              if (rutinas.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.warning_amber_rounded,
                  title: 'SIN RUTINAS',
                  subtitle: 'Ve a Rutinas y crea tu plan de batalla.',
                );
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Sugerencia inteligente
                  suggestionAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (suggestion) {
                      if (suggestion == null) return const SizedBox.shrink();
                      return _SmartSuggestionCard(
                        suggestion: suggestion,
                        onStart: () => _startSession(context, ref, suggestion.rutina, suggestion.dayIndex),
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'TODAS LAS RUTINAS',
                    style: GoogleFonts.montserrat(
                      color: Colors.grey[500],
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Lista de rutinas
                  ...rutinas.map((rutina) => _RutinaCard(
                    key: ValueKey(rutina.id),
                    rutina: rutina,
                    onDaySelected: (dayIndex) => _startSession(context, ref, rutina, dayIndex),
                  )),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _startSession(BuildContext context, WidgetRef ref, Rutina rutina, int dayIndex) {
    if (rutina.dias.isEmpty || dayIndex >= rutina.dias.length) return;

    final day = rutina.dias[dayIndex];
    Vibrate.feedback(FeedbackType.heavy);

    ref.read(trainingSessionProvider.notifier).startSession(
      rutina,
      day.ejercicios,
      dayName: day.nombre,
      dayIndex: dayIndex,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrainingSessionScreen()),
    );
  }
}

/// Card de sugerencia inteligente destacada.
class _SmartSuggestionCard extends StatelessWidget {
  final SmartWorkoutSuggestion suggestion;
  final VoidCallback onStart;

  const _SmartSuggestionCard({
    required this.suggestion,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.red[900],
      elevation: 8,
      child: InkWell(
        onTap: onStart,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.yellow[600], size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'SUGERENCIA',
                    style: GoogleFonts.montserrat(
                      color: Colors.yellow[600],
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'START',
                      style: GoogleFonts.montserrat(
                        color: Colors.red[900],
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                suggestion.dayName.toUpperCase(),
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                suggestion.rutina.nombre,
                style: GoogleFonts.montserrat(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                suggestion.reason,
                style: GoogleFonts.montserrat(
                  color: Colors.white54,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card de rutina con selector de día.
class _RutinaCard extends StatelessWidget {
  final Rutina rutina;
  final void Function(int dayIndex) onDaySelected;

  const _RutinaCard({
    super.key,
    required this.rutina,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          if (rutina.dias.isEmpty) return;
          Vibrate.feedback(FeedbackType.selection);

          if (rutina.dias.length == 1) {
            onDaySelected(0);
          } else {
            _showDaySelector(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rutina.nombre.toUpperCase(),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red[900],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'START',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${rutina.dias.length} DÍAS',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.redAccent[700],
                ),
              ),
              const SizedBox(height: 8),
              if (rutina.dias.isNotEmpty)
                Text(
                  rutina.dias.take(3).map((d) => d.nombre).join(' • ').toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDaySelector(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(
          'ELIGE DÍA',
          style: GoogleFonts.montserrat(
            color: Colors.red[900],
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.grey[900],
        children: rutina.dias.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          return SimpleDialogOption(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.red[900],
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    day.nombre,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${day.ejercicios.length} ej.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              onDaySelected(index);
            },
          );
        }).toList(),
      ),
    );
  }
}
