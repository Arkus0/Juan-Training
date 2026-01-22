import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'create_edit_routine_screen.dart';
import '../providers/training_provider.dart';
import '../widgets/common/app_widgets.dart';

class RutinasScreen extends ConsumerWidget {
  const RutinasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rutinasAsync = ref.watch(rutinasStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MIS RUTINAS'),
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
              return _RutinaTile(
                key: ValueKey(rutina.id),
                rutina: rutina,
                onTap: () => _navigateToEdit(context, rutina),
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
