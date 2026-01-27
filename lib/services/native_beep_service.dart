import 'package:flutter/services.dart';

/// Servicio para reproducir beeps usando el sistema nativo de Android.
///
/// Este servicio usa ToneGenerator con un stream configurable para evitar
/// solicitar Audio Focus, permitiendo que los beeps del timer suenen sin
/// pausar la música del usuario (Spotify, YouTube Music, etc.).
///
/// Beneficios:
/// - NO interfiere con aplicaciones de música
/// - Sonidos cortos tipo notificación
/// - No mantiene recursos de audio abiertos
/// - Bajo consumo de batería
class NativeBeepService {
  static final NativeBeepService _instance = NativeBeepService._internal();
  factory NativeBeepService() => _instance;
  NativeBeepService._internal();

  static NativeBeepService get instance => _instance;

  static const _channel = MethodChannel('com.juantraining/beep_sound');

  /// Frecuencias de beep para el timer (Hz)
  static const int freqLow = 440;      // A4 - suave
  static const int freqMedium = 660;   // E5 - medio
  static const int freqHigh = 880;     // A5 - intenso
  static const int freqFinal = 1047;   // C6 - final

  /// Frecuencias para feedback de voz (Hz)
  static const int freqVoiceStart = 523;     // C5 - inicio
  static const int freqVoiceSuccess = 659;   // E5 - éxito
  static const int freqVoiceHighConf = 784;  // G5 - alta confianza
  static const int freqVoiceError = 349;     // F4 - error
  static const int freqVoiceCommand = 880;   // A5 - comando válido

  /// Volumen por defecto (0.0 - 1.0)
  static const double defaultVolume = 0.5;

  /// Reproduce un beep simple.
  ///
  /// @param frequency Frecuencia en Hz
  /// @param durationMs Duración en milisegundos
  /// @param volume Volumen de 0.0 a 1.0
  Future<void> playBeep({
    required int frequency,
    int durationMs = 150,
    double volume = defaultVolume,
    bool useMusicStream = false,
  }) async {
    try {
      await _channel.invokeMethod('playBeep', {
        'frequency': frequency,
        'durationMs': durationMs,
        'volume': volume,
        'useMusicStream': useMusicStream,
      });
    } catch (e) {
      // Silenciar errores de audio para no interrumpir UX
    }
  }

  /// Reproduce un beep doble (para señales de finalización).
  Future<void> playDoubleBeep({
    required int frequency,
    int durationMs = 250,
    int gapMs = 150,
    double volume = defaultVolume,
    bool useMusicStream = false,
  }) async {
    try {
      await _channel.invokeMethod('playDoubleBeep', {
        'frequency': frequency,
        'durationMs': durationMs,
        'gapMs': gapMs,
        'volume': volume,
        'useMusicStream': useMusicStream,
      });
    } catch (e) {
      // Silenciar errores de audio
    }
  }

  /// Reproduce una secuencia de tonos.
  ///
  /// Útil para feedback de voz con patrones complejos.
  Future<void> playSequence({
    required List<int> frequencies,
    required List<int> durations,
    List<int>? gaps,
    double volume = defaultVolume,
    bool useMusicStream = false,
  }) async {
    try {
      await _channel.invokeMethod('playSequence', {
        'frequencies': frequencies,
        'durations': durations,
        'gaps': gaps ?? List.filled(frequencies.length, 50),
        'volume': volume,
        'useMusicStream': useMusicStream,
      });
    } catch (e) {
      // Silenciar errores de audio
    }
  }

  // ============================================================================
  // MÉTODOS DE CONVENIENCIA PARA TIMER
  // ============================================================================

  /// Beep de baja intensidad (últimos 10-6 segundos del timer)
  Future<void> playLowBeep() async {
    await playBeep(frequency: freqLow, durationMs: 100);
  }

  /// Beep de media intensidad (últimos 5-3 segundos del timer)
  Future<void> playMediumBeep() async {
    await playBeep(frequency: freqMedium, durationMs: 150);
  }

  /// Beep de alta intensidad (últimos 2-1 segundos del timer)
  Future<void> playHighBeep() async {
    await playBeep(frequency: freqHigh, durationMs: 200);
  }

  /// Beep final doble (timer terminado)
  /// [useMusicStream] permite mezclar en STREAM_MUSIC si el stream de
  /// notificaciones causa cortes en reproductores externos.
  Future<void> playFinalBeep({bool useMusicStream = false}) async {
    await playDoubleBeep(
      frequency: freqFinal,
      durationMs: 250,
      gapMs: 150,
      useMusicStream: useMusicStream,
    );
  }

  // ============================================================================
  // MÉTODOS DE CONVENIENCIA PARA VOZ
  // ============================================================================

  /// Beep ascendente al iniciar escucha
  Future<void> playStartListening() async {
    await playSequence(
      frequencies: [freqVoiceStart, (freqVoiceStart * 1.2).round()],
      durations: [80, 80],
      gaps: [50],
    );
  }

  /// Beep descendente al detener escucha
  Future<void> playStopListening() async {
    await playSequence(
      frequencies: [(freqVoiceStart * 1.2).round(), freqVoiceStart],
      durations: [80, 80],
      gaps: [50],
    );
  }

  /// Beep de comando reconocido
  Future<void> playCommandRecognized() async {
    await playBeep(frequency: freqVoiceCommand, durationMs: 100);
  }

  /// Beep de match con alta confianza
  Future<void> playHighConfidenceMatch() async {
    await playSequence(
      frequencies: [freqVoiceSuccess, freqVoiceHighConf],
      durations: [80, 100],
      gaps: [40],
    );
  }

  /// Beep de match con confianza media
  Future<void> playMediumConfidenceMatch() async {
    await playBeep(frequency: freqVoiceSuccess, durationMs: 120);
  }

  /// Beep de no match / error
  Future<void> playNoMatch() async {
    await playBeep(frequency: freqVoiceError, durationMs: 150);
  }

  /// Beep de error general
  Future<void> playError() async {
    await playSequence(
      frequencies: [freqVoiceError, (freqVoiceError * 0.8).round()],
      durations: [100, 150],
      gaps: [80],
    );
  }

  /// Beep de corrección aceptada
  Future<void> playCorrectionAccepted() async {
    await playSequence(
      frequencies: [
        (freqVoiceSuccess * 0.9).round(),
        freqVoiceSuccess,
        (freqVoiceSuccess * 1.1).round(),
      ],
      durations: [60, 60, 80],
      gaps: [30, 30],
    );
  }

  /// Libera recursos nativos.
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } catch (e) {
      // Ignorar
    }
  }
}
