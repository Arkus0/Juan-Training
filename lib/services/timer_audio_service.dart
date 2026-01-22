import 'dart:async';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

/// Servicio singleton para reproducir beeps del timer
/// Genera tonos programáticamente sin necesidad de archivos de audio
class TimerAudioService {
  static final TimerAudioService _instance = TimerAudioService._internal();
  factory TimerAudioService() => _instance;
  TimerAudioService._internal();

  static TimerAudioService get instance => _instance;

  AudioPlayer? _player;
  bool _isInitialized = false;

  /// Frecuencias de beep para diferentes intensidades
  static const double _lowFrequency = 440.0;    // A4 - suave
  static const double _mediumFrequency = 660.0; // E5 - medio
  static const double _highFrequency = 880.0;   // A5 - intenso
  static const double _finalFrequency = 1046.5; // C6 - final

  /// Inicializa el servicio de audio
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _player = AudioPlayer();
      _isInitialized = true;
    } catch (e) {
      // Si falla la inicialización, el servicio queda deshabilitado
      _isInitialized = false;
    }
  }

  /// Reproduce un beep de baja intensidad (últimos 10-6 segundos)
  Future<void> playLowBeep() async {
    await _playTone(_lowFrequency, duration: 100);
  }

  /// Reproduce un beep de media intensidad (últimos 5-3 segundos)
  Future<void> playMediumBeep() async {
    await _playTone(_mediumFrequency, duration: 150);
  }

  /// Reproduce un beep de alta intensidad (últimos 2-1 segundos)
  Future<void> playHighBeep() async {
    await _playTone(_highFrequency, duration: 200);
  }

  /// Reproduce el beep final (doble tono)
  Future<void> playFinalBeep() async {
    await _playTone(_finalFrequency, duration: 250);
    await Future.delayed(const Duration(milliseconds: 150));
    await _playTone(_finalFrequency, duration: 250);
  }

  /// Reproduce un tono simple usando generación de onda
  Future<void> _playTone(double frequency, {int duration = 150}) async {
    if (!_isInitialized || _player == null) return;

    try {
      // Generar onda sinusoidal
      final sampleRate = 44100;
      final numSamples = (sampleRate * duration / 1000).round();
      final samples = Float64List(numSamples);

      for (int i = 0; i < numSamples; i++) {
        final t = i / sampleRate;
        // Envelope simple (fade in/out para evitar clicks)
        double envelope = 1.0;
        final fadeLength = numSamples ~/ 10;
        if (i < fadeLength) {
          envelope = i / fadeLength;
        } else if (i > numSamples - fadeLength) {
          envelope = (numSamples - i) / fadeLength;
        }
        samples[i] = envelope * 0.5 * _sin(2 * 3.14159265359 * frequency * t);
      }

      // Convertir a bytes PCM 16-bit
      final bytes = _float64ToPcm16(samples);

      // Crear fuente de audio desde bytes
      final audioSource = _SineWaveAudioSource(bytes, sampleRate);
      await _player!.setAudioSource(audioSource);
      await _player!.play();
    } catch (e) {
      // Silenciar errores de audio
    }
  }

  double _sin(double x) {
    // Aproximación de seno usando Taylor series (para evitar import math)
    x = x % (2 * 3.14159265359);
    if (x > 3.14159265359) x -= 2 * 3.14159265359;

    double result = x;
    double term = x;
    for (int i = 1; i <= 7; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  Uint8List _float64ToPcm16(Float64List samples) {
    final bytes = Uint8List(samples.length * 2);
    for (int i = 0; i < samples.length; i++) {
      final sample = (samples[i] * 32767).clamp(-32768, 32767).toInt();
      bytes[i * 2] = sample & 0xFF;
      bytes[i * 2 + 1] = (sample >> 8) & 0xFF;
    }
    return bytes;
  }

  /// Libera recursos
  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
    _isInitialized = false;
  }
}

/// Fuente de audio personalizada para ondas sinusoidales
class _SineWaveAudioSource extends StreamAudioSource {
  final Uint8List _bytes;
  final int _sampleRate;

  _SineWaveAudioSource(this._bytes, this._sampleRate);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;

    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/raw',
    );
  }
}
