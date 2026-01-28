import 'native_beep_service.dart';

/// Servicio de feedback de audio para reconocimiento de voz.
///
/// 🔇 AUDIO FOCUS FIX:
/// Este servicio ahora delega al NativeBeepService que usa ToneGenerator
/// de Android con STREAM_NOTIFICATION. Los beeps de feedback de voz
/// NO pausan la música del usuario.
///
/// Proporciona diferentes sonidos para:
/// - Inicio de escucha
/// - Comando reconocido (beep de confirmación)
/// - Error de reconocimiento
/// - Ejercicio encontrado con alta/baja confianza
class VoiceAudioFeedbackService {
  static final VoiceAudioFeedbackService instance =
      VoiceAudioFeedbackService._();
  VoiceAudioFeedbackService._();

  final NativeBeepService _nativeBeep = NativeBeepService.instance;

  /// Habilita/deshabilita feedback de audio
  bool isEnabled = true;

  /// Inicializa el servicio.
  /// Ahora es un no-op ya que el servicio nativo no requiere inicialización.
  Future<void> initialize() async {
    // No-op - NativeBeepService no requiere inicialización
  }

  /// Beep al iniciar escucha (tono ascendente corto)
  Future<void> playStartListening() async {
    if (!isEnabled) return;
    await _nativeBeep.playStartListening();
  }

  /// Beep al detener escucha (tono descendente)
  Future<void> playStopListening() async {
    if (!isEnabled) return;
    await _nativeBeep.playStopListening();
  }

  /// Beep de comando válido reconocido
  Future<void> playCommandRecognized() async {
    if (!isEnabled) return;
    await _nativeBeep.playCommandRecognized();
  }

  /// Beep de ejercicio encontrado con alta confianza (>80%)
  Future<void> playHighConfidenceMatch() async {
    if (!isEnabled) return;
    await _nativeBeep.playHighConfidenceMatch();
  }

  /// Beep de ejercicio encontrado con confianza media (50-80%)
  Future<void> playMediumConfidenceMatch() async {
    if (!isEnabled) return;
    await _nativeBeep.playMediumConfidenceMatch();
  }

  /// Beep de ejercicio no encontrado / error
  Future<void> playNoMatch() async {
    if (!isEnabled) return;
    await _nativeBeep.playNoMatch();
  }

  /// Beep de error general
  Future<void> playError() async {
    if (!isEnabled) return;
    await _nativeBeep.playError();
  }

  /// Beep de corrección aceptada ("No, quise decir...")
  Future<void> playCorrectionAccepted() async {
    if (!isEnabled) return;
    await _nativeBeep.playCorrectionAccepted();
  }

  void dispose() {
    // No-op - NativeBeepService maneja su propio ciclo de vida
  }
}
