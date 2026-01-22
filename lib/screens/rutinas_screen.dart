import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'create_edit_routine_screen.dart';
import '../models/rutina.dart';
import '../providers/training_provider.dart';
import '../widgets/common/app_widgets.dart';
import '../widgets/routine_import_preview_dialog.dart';

class RutinasScreen extends ConsumerWidget {
  const RutinasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rutinasAsync = ref.watch(rutinasStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MIS RUTINAS'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'import') {
                _showImportFlow(context, ref);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 8),
                    Text('Importar Rutina'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: rutinasAsync.when(
        loading: () => const AppLoadingIndicator(message: 'Cargando rutinas...'),
        error: (err, stack) => ErrorStateWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(rutinasStreamProvider),
        ),
        data: (rutinas) {
          if (rutinas.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.fitness_center,
              title: 'NO HAY RUTINAS',
              subtitle: '¡CREA TU LEGADO AHORA!',
              actionLabel: 'CREAR RUTINA',
              onAction: () => _navigateToCreate(context),
            );
          }

          return ListView.builder(
            itemCount: rutinas.length,
            padding: const EdgeInsets.all(16.0),
            itemBuilder: (context, index) {
              final rutina = rutinas[index];
              return Dismissible(
                key: ValueKey(rutina.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20.0),
                  color: Colors.red[900],
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _deleteRutina(context, ref, rutina),
                child: _RutinaTile(
                  rutina: rutina,
                  onTap: () => _navigateToEdit(context, rutina),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create_rutina_fab',
        onPressed: () => _navigateToCreate(context),
        icon: const Icon(Icons.add),
        label: const Text('NUEVA RUTINA'),
      ),
    );
  }

  void _navigateToCreate(BuildContext context) {
    Vibrate.feedback(FeedbackType.light);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateEditRoutineScreen(),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, dynamic rutina) {
    Vibrate.feedback(FeedbackType.selection);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateEditRoutineScreen(rutina: rutina),
      ),
    );
  }

  void _deleteRutina(BuildContext context, WidgetRef ref, Rutina rutina) {
    ref.read(trainingRepositoryProvider).deleteRutina(rutina.id);
    Vibrate.feedback(FeedbackType.heavy);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'RUTINA ELIMINADA',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red[900],
        action: SnackBarAction(
          label: 'DESHACER',
          textColor: Colors.white,
          onPressed: () {
            ref.read(trainingRepositoryProvider).saveRutina(rutina);
            Vibrate.feedback(FeedbackType.light);
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _showImportFlow(BuildContext context, WidgetRef ref) async {
    Vibrate.feedback(FeedbackType.selection);

    // Step 1: Show JSON input dialog
    final parsedRutina = await showDialog<Rutina>(
      context: context,
      builder: (ctx) => const RoutineImportInputDialog(),
    );

    if (parsedRutina == null || !context.mounted) return;

    // Step 2: Show preview dialog
    final confirmedRutina = await showDialog<Rutina>(
      context: context,
      builder: (ctx) => RoutineImportPreviewDialog(
        rutina: parsedRutina,
        onConfirm: () {
          // This callback is called when user confirms import
        },
      ),
    );

    if (confirmedRutina == null || !context.mounted) return;

    // Step 3: Save the routine to database
    try {
      final repository = ref.read(trainingRepositoryProvider);
      await repository.saveRutina(confirmedRutina);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'RUTINA IMPORTADA: ${confirmedRutina.nombre.toUpperCase()}',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.red[900],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(milliseconds: 2000),
          ),
        );
        Vibrate.feedback(FeedbackType.success);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al guardar: ${e.toString()}',
              style: GoogleFonts.montserrat(color: Colors.white),
            ),
            backgroundColor: Colors.redAccent[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
        Vibrate.feedback(FeedbackType.error);
      }
    }
  }
}

/// Extracted widget for better performance - only rebuilds when its rutina changes
class _RutinaTile extends StatelessWidget {
  final dynamic rutina;
  final VoidCallback onTap;

  const _RutinaTile({
    super.key,
    required this.rutina,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final totalExercises = rutina.dias.fold(0, (sum, day) => sum + day.ejercicios.length);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      rutina.nombre.toUpperCase(),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.edit, color: Colors.redAccent[700]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.calendar_view_week,
                    label: '${rutina.dias.length} DÍAS',
                  ),
                  const SizedBox(width: 16),
                  _InfoChip(
                    icon: Icons.fitness_center,
                    label: '$totalExercises EJERCICIOS',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable info chip for consistent styling
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey[400]),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }
}
