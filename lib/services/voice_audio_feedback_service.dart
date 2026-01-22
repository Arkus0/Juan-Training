import 'package:just_audio/just_audio.dart';
import 'package:logger/logger.dart';

/// Servicio de feedback de audio para reconocimiento de voz
/// 
/// Proporciona diferentes sonidos para:
/// - Inicio de escucha
/// - Comando reconocido (beep de confirmación)
/// - Error de reconocimiento
/// - Ejercicio encontrado con alta/baja confianza
class VoiceAudioFeedbackService {
  static final VoiceAudioFeedbackService instance = VoiceAudioFeedbackService._();
  VoiceAudioFeedbackService._();

  final _logger = Logger();
  AudioPlayer? _player;
  bool _isInitialized = false;

  /// Frecuencias de beep
  static const double _startFrequency = 523.25;     // C5 - inicio
  static const double _successFrequency = 659.25;   // E5 - éxito
  static const double _highConfidenceFreq = 783.99; // G5 - alta confianza
  static const double _errorFrequency = 349.23;     // F4 - error
  static const double _commandFrequency = 880.0;    // A5 - comando válido

  /// Habilita/deshabilita feedback de audio
  // ignore: prefer_final_fields
  bool isEnabled = true;

  /// Inicializa el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _player = AudioPlayer();
      _isInitialized = true;
      _logger.d('VoiceAudioFeedbackService inicializado');
    } catch (e) {
      _logger.e('Error inicializando audio feedback', error: e);
      _isInitialized = false;
    }
  }

  /// Beep al iniciar escucha (tono ascendente corto)
  Future<void> playStartListening() async {
    if (!isEnabled) return;
    await _playTone(_startFrequency, duration: 80);
    await Future.delayed(const Duration(milliseconds: 50));
    await _playTone(_startFrequency * 1.2, duration: 80);
  }

  /// Beep al detener escucha (tono descendente)
  Future<void> playStopListening() async {
    if (!isEnabled) return;
    await _playTone(_startFrequency * 1.2, duration: 80);
    await Future.delayed(const Duration(milliseconds: 50));
    await _playTone(_startFrequency, duration: 80);
  }

  /// Beep de comando válido reconocido
  Future<void> playCommandRecognized() async {
    if (!isEnabled) return;
    await _playTone(_commandFrequency, duration: 100);
  }

  /// Beep de ejercicio encontrado con alta confianza (>80%)
  Future<void> playHighConfidenceMatch() async {
    if (!isEnabled) return;
    await _playTone(_successFrequency, duration: 80);
    await Future.delayed(const Duration(milliseconds: 40));
    await _playTone(_highConfidenceFreq, duration: 100);
  }

  /// Beep de ejercicio encontrado con confianza media (50-80%)
  Future<void> playMediumConfidenceMatch() async {
    if (!isEnabled) return;
    await _playTone(_successFrequency, duration: 120);
  }

  /// Beep de ejercicio no encontrado / error
  Future<void> playNoMatch() async {
    if (!isEnabled) return;
    await _playTone(_errorFrequency, duration: 150);
  }

  /// Beep de error general
  Future<void> playError() async {
    if (!isEnabled) return;
    await _playTone(_errorFrequency, duration: 100);
    await Future.delayed(const Duration(milliseconds: 80));
    await _playTone(_errorFrequency * 0.8, duration: 150);
  }

  /// Beep de corrección aceptada ("No, quise decir...")
  Future<void> playCorrectionAccepted() async {
    if (!isEnabled) return;
    await _playTone(_successFrequency * 0.9, duration: 60);
    await Future.delayed(const Duration(milliseconds: 30));
    await _playTone(_successFrequency, duration: 60);
    await Future.delayed(const Duration(milliseconds: 30));
    await _playTone(_successFrequency * 1.1, duration: 80);
  }

  /// Reproduce un tono con la frecuencia y duración especificadas
  Future<void> _playTone(double frequency, {int duration = 100}) async {
    if (!_isInitialized || _player == null) {
      await initialize();
      if (!_isInitialized) return;
    }

    try {
      const sampleRate = 44100;
      final numSamples = (sampleRate * duration / 1000).round();
      final samples = List<double>.filled(numSamples, 0);

      for (int i = 0; i < numSamples; i++) {
        final t = i / sampleRate;
        // Envelope suave (fade in/out)
        double envelope = 1.0;
        final fadeLength = numSamples ~/ 8;
        if (i < fadeLength) {
          envelope = i / fadeLength;
        } else if (i > numSamples - fadeLength) {
          envelope = (numSamples - i) / fadeLength;
        }
        samples[i] = envelope * 0.4 * _sin(2 * 3.14159265359 * frequency * t);
      }

      final pcmBytes = _floatToPcm16(samples);
      final wavBytes = _pcm16ToWav(pcmBytes, sampleRate);

      final audioSource = _WavAudioSource(wavBytes);
      await _player!.setAudioSource(audioSource);
      await _player!.play();
    } catch (e) {
      // Silenciar errores de audio
    }
  }

  double _sin(double x) {
    x = x % (2 * 3.14159265359);
    if (x > 3.14159265359) x -= 2 * 3.14159265359;
    double result = x;
    double term = x;
    for (int n = 1; n <= 7; n++) {
      term *= -x * x / ((2 * n) * (2 * n + 1));
      result += term;
    }
    return result;
  }

  List<int> _floatToPcm16(List<double> samples) {
    final pcm = <int>[];
    for (final sample in samples) {
      int s = (sample * 32767).round().clamp(-32768, 32767);
      pcm.add(s & 0xFF);
      pcm.add((s >> 8) & 0xFF);
    }
    return pcm;
  }

  List<int> _pcm16ToWav(List<int> pcmData, int sampleRate) {
    final dataSize = pcmData.length;
    final fileSize = 44 + dataSize;
    
    final header = <int>[
      // RIFF header
      0x52, 0x49, 0x46, 0x46, // "RIFF"
      (fileSize - 8) & 0xFF,
      ((fileSize - 8) >> 8) & 0xFF,
      ((fileSize - 8) >> 16) & 0xFF,
      ((fileSize - 8) >> 24) & 0xFF,
      0x57, 0x41, 0x56, 0x45, // "WAVE"
      // fmt subchunk
      0x66, 0x6D, 0x74, 0x20, // "fmt "
      16, 0, 0, 0, // Subchunk1Size (16 for PCM)
      1, 0, // AudioFormat (1 = PCM)
      1, 0, // NumChannels (1 = mono)
      sampleRate & 0xFF,
      (sampleRate >> 8) & 0xFF,
      (sampleRate >> 16) & 0xFF,
      (sampleRate >> 24) & 0xFF,
      (sampleRate * 2) & 0xFF, // ByteRate
      ((sampleRate * 2) >> 8) & 0xFF,
      ((sampleRate * 2) >> 16) & 0xFF,
      ((sampleRate * 2) >> 24) & 0xFF,
      2, 0, // BlockAlign
      16, 0, // BitsPerSample
      // data subchunk
      0x64, 0x61, 0x74, 0x61, // "data"
      dataSize & 0xFF,
      (dataSize >> 8) & 0xFF,
      (dataSize >> 16) & 0xFF,
      (dataSize >> 24) & 0xFF,
    ];

    return [...header, ...pcmData];
  }

  void dispose() {
    _player?.dispose();
    _player = null;
    _isInitialized = false;
  }
}

/// Audio source para reproducir bytes WAV
class _WavAudioSource extends StreamAudioSource {
  final List<int> _bytes;

  _WavAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
