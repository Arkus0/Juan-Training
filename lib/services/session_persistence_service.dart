import 'package:logger/logger.dart';
import '../repositories/i_training_repository.dart';
import '../utils/performance_utils.dart';

/// Servicio de persistencia de sesión extraído de TrainingSessionNotifier.
///
/// Responsabilidades:
/// - Save/restore de sesión activa a/desde repositorio
/// - Debouncing de operaciones de guardado
/// - Flush de saves pendientes antes de operaciones críticas
/// - Manejo atómico de finish session
///
/// NO responsable de:
/// - Estado en memoria de la sesión
/// - Timer de descanso
/// - Lógica de ejercicios/sets
class SessionPersistenceService {
  final ITrainingRepository _repository;
  final Logger _logger = Logger();

  /// Debouncer para optimizar saves a BD (evitar saves excesivos durante input)
  final Debouncer _saveDebouncer = Debouncer(
    delay: const Duration(milliseconds: 500),
  );

  /// Flag para saber si hay un save pendiente que debe ejecutarse inmediatamente
  bool _hasPendingSave = false;

  /// Callback para obtener datos actuales de la sesión al momento de guardar
  ActiveSessionData Function()? getSessionData;

  SessionPersistenceService(this._repository);

  /// Guarda el estado con debounce para evitar saves excesivos durante input rápido.
  void saveWithDebounce() {
    _hasPendingSave = true;
    _saveDebouncer.run(() {
      _saveImmediate();
    });
  }

  /// Guarda el estado inmediatamente sin debounce.
  /// Usar para eventos importantes como completar un set.
  Future<void> _saveImmediate() async {
    _hasPendingSave = false;

    final data = getSessionData?.call();
    if (data == null || data.exercises.isEmpty) return;

    try {
      await _repository.saveActiveSession(data);
    } catch (e) {
      _logger.e('Error saving session state', error: e);
    }
  }

  /// Fuerza el save si hay uno pendiente (llamar antes de operaciones críticas)
  Future<void> flushPendingSave() async {
    if (_hasPendingSave) {
      _saveDebouncer.cancel();
      await _saveImmediate();
    }
  }

  /// Limpia la sesión activa del almacenamiento
  Future<void> clearActiveSession() async {
    await _repository.clearActiveSession();
  }

  /// Restaura la sesión desde el almacenamiento
  Future<ActiveSessionData?> restoreSession() async {
    try {
      return await _repository.getActiveSession();
    } catch (e) {
      _logger.e('Error restoring session', error: e);
      // Si hay error crítico, limpiar para evitar crash loop
      await clearActiveSession();
      return null;
    }
  }

  /// Descarta la sesión activa sin guardarla
  Future<void> discardSession() async {
    // Cancelar cualquier save pendiente ANTES de limpiar
    _saveDebouncer.cancel();
    _hasPendingSave = false;

    await clearActiveSession();
    _logger.d('Sesión descartada correctamente');
  }

  void dispose() {
    _saveDebouncer.cancel();
  }
}

// SessionSaveResult se define en training_provider.dart
// para mantener compatibilidad con código existente
