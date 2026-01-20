import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import '../models/rutina.dart';
import '../models/sesion.dart';
import '../repositories/drift_training_repository.dart';

class MigrationService {
  final DriftTrainingRepository driftRepo;
  final Box<Rutina> rutinasBox;
  final Box<Sesion> sesionesBox;
  final Box exerciseNotesBox;
  final Box settingsBox;
  final Logger _logger = Logger();

  MigrationService({
    required this.driftRepo,
    required this.rutinasBox,
    required this.sesionesBox,
    required this.exerciseNotesBox,
    required this.settingsBox,
  });

  Future<void> migrate() async {
    final isMigrated = settingsBox.get('is_drift_migrated', defaultValue: false) as bool;

    if (isMigrated) {
      _logger.i('Migration already completed.');
      return;
    }

    _logger.i('Starting Hive to Drift migration...');

    try {
      // 1. Migrate Rutinas
      final rutinas = rutinasBox.values.toList();
      _logger.i('Migrating ${rutinas.length} rutinas...');
      for (final rutina in rutinas) {
        await driftRepo.saveRutina(rutina);
      }

      // 2. Migrate Sesiones (History)
      final sesiones = sesionesBox.values.toList();
      _logger.i('Migrating ${sesiones.length} sessions...');
      for (final sesion in sesiones) {
        await driftRepo.saveSesion(sesion);
      }

      // 3. Migrate Notes
      _logger.i('Migrating exercise notes...');
      for (final key in exerciseNotesBox.keys) {
        if (key is String) {
          final note = exerciseNotesBox.get(key) as String?;
          if (note != null && note.isNotEmpty) {
            await driftRepo.saveNote(key, note);
          }
        }
      }

      // Mark as migrated
      await settingsBox.put('is_drift_migrated', true);
      _logger.i('Migration completed successfully.');

    } catch (e, stack) {
      _logger.e('Migration failed!', error: e, stackTrace: stack);
      // We do not set the flag so it retries next time.
      // Ideally we should have a way to alert the user.
      rethrow;
    }
  }
}
