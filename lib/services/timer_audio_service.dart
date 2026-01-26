import 'native_beep_service.dart';

/// Servicio singleton para reproducir beeps del timer.
///
/// 🔇 AUDIO FOCUS FIX:
/// Este servicio ahora delega al NativeBeepService que usa ToneGenerator
/// de Android con STREAM_NOTIFICATION. Esto permite que los beeps del timer
/// suenen SIN pausar la música del usuario (Spotify, YouTube Music, etc.).
///
/// Antes:
/// - Usaba just_audio (ExoPlayer/Media3) que solicita Audio Focus
/// - Al reproducir un beep, pausaba la música del usuario
///
/// Ahora:
/// - Usa ToneGenerator nativo con STREAM_NOTIFICATION
/// - NO solicita Audio Focus
/// - Los beeps son tipo "notificación" - cortos y no intrusivos
/// - La música del usuario continúa sin interrupción
class TimerAudioService {
  static final TimerAudioService _instance = TimerAudioService._internal();
  factory TimerAudioService() => _instance;
  TimerAudioService._internal();

  static TimerAudioService get instance => _instance;

  final NativeBeepService _nativeBeep = NativeBeepService.instance;
  bool _isInitialized = false;

  /// Inicializa el servicio de audio.
  /// Ahora es un no-op ya que el servicio nativo no requiere inicialización.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
  }

  /// Reproduce un beep de baja intensidad (últimos 10-6 segundos)
  Future<void> playLowBeep() async {
    await _nativeBeep.playLowBeep();
  }

  /// Reproduce un beep de media intensidad (últimos 5-3 segundos)
  Future<void> playMediumBeep() async {
    await _nativeBeep.playMediumBeep();
  }

  /// Reproduce un beep de alta intensidad (últimos 2-1 segundos)
  Future<void> playHighBeep() async {
    await _nativeBeep.playHighBeep();
  }

  /// Reproduce el beep final (doble tono)
  Future<void> playFinalBeep() async {
    await _nativeBeep.playFinalBeep();
  }

  /// Libera recursos
  Future<void> dispose() async {
    await _nativeBeep.dispose();
    _isInitialized = false;
  }
}
