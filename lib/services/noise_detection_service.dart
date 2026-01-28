import 'package:logger/logger.dart';

/// Niveles de calidad de audio para el ambiente
enum AudioQuality {
  excellent, // SNR > 20dB - Procesar normal
  good, // SNR 15-20dB - Procesar con warning
  fair, // SNR 10-15dB - Sugerir acercarse
  poor, // SNR < 10dB - Forzar fallback
}

/// Servicio de detección de ruido de fondo.
///
/// Proporciona sugerencias proactivas al usuario cuando el ambiente
/// es demasiado ruidoso para una captura de voz efectiva.
///
/// NOTA: La detección real de SNR requiere acceso al audio raw,
/// que no está disponible directamente en speech_to_text.
/// Esta implementación usa heurísticas basadas en:
/// - Tasa de errores de reconocimiento
/// - Tiempo hasta primera palabra detectada
/// - Confianza de transcripción
class NoiseDetectionService {
  static final NoiseDetectionService instance = NoiseDetectionService._();
  NoiseDetectionService._();

  final _logger = Logger();

  // Historial de calidad para promediar
  final List<AudioQuality> _recentQuality = [];
  static const int _historySize = 5;

  // Contadores para heurísticas
  int _consecutiveFailures = 0;
  int _lowConfidenceCount = 0;

  /// Analiza la calidad del ambiente basado en métricas recientes.
  ///
  /// Retorna la calidad estimada del audio ambiente.
  AudioQuality analyzeEnvironment() {
    if (_consecutiveFailures >= 3) {
      return AudioQuality.poor;
    }

    if (_consecutiveFailures >= 2 || _lowConfidenceCount >= 3) {
      return AudioQuality.fair;
    }

    if (_lowConfidenceCount >= 1 || _consecutiveFailures >= 1) {
      return AudioQuality.good;
    }

    return AudioQuality.excellent;
  }

  /// Registra un resultado de transcripción para ajustar la detección.
  void recordTranscriptionResult({
    required bool success,
    required double confidence,
    required Duration recognitionTime,
  }) {
    if (!success) {
      _consecutiveFailures++;
      _logger.d('NoiseDetection: Fallo #$_consecutiveFailures');
    } else {
      _consecutiveFailures = 0;
    }

    if (confidence < 0.6 && confidence > 0) {
      _lowConfidenceCount++;
      _logger.d(
          'NoiseDetection: Confianza baja #$_lowConfidenceCount ($confidence)',);
    } else if (confidence >= 0.8) {
      _lowConfidenceCount = (_lowConfidenceCount - 1).clamp(0, 10);
    }

    // Estimar calidad basada en tiempo de reconocimiento
    AudioQuality quality;
    if (recognitionTime > const Duration(seconds: 5) && !success) {
      quality = AudioQuality.poor;
    } else if (confidence >= 0.8) {
      quality = AudioQuality.excellent;
    } else if (confidence >= 0.6) {
      quality = AudioQuality.good;
    } else if (confidence >= 0.4) {
      quality = AudioQuality.fair;
    } else {
      quality = AudioQuality.poor;
    }

    _recentQuality.add(quality);
    if (_recentQuality.length > _historySize) {
      _recentQuality.removeAt(0);
    }

    _logger.d(
        'NoiseDetection: Calidad registrada $quality, ambiente actual: ${analyzeEnvironment()}',);
  }

  /// Obtiene sugerencia para el usuario basada en la calidad actual.
  String? getSuggestion() {
    final quality = analyzeEnvironment();

    switch (quality) {
      case AudioQuality.excellent:
      case AudioQuality.good:
        return null;
      case AudioQuality.fair:
        return 'Ambiente ruidoso. Habla más cerca del micro.';
      case AudioQuality.poor:
        return 'Demasiado ruido. Usa texto o entrada manual.';
    }
  }

  /// Determina si se debe ofrecer fallback automáticamente.
  bool shouldOfferFallback() {
    final quality = analyzeEnvironment();
    return quality == AudioQuality.poor || _consecutiveFailures >= 2;
  }

  /// Determina si se debe forzar fallback (no permitir voz).
  bool shouldForceFallback() {
    return _consecutiveFailures >= 4;
  }

  /// Resetea los contadores (ej: al cambiar de pantalla).
  void reset() {
    _consecutiveFailures = 0;
    _lowConfidenceCount = 0;
    _recentQuality.clear();
    _logger.d('NoiseDetection: Reset');
  }

  /// Obtiene información de debug sobre el estado actual.
  Map<String, dynamic> getDebugInfo() {
    return {
      'quality': analyzeEnvironment().name,
      'consecutiveFailures': _consecutiveFailures,
      'lowConfidenceCount': _lowConfidenceCount,
      'recentQuality': _recentQuality.map((q) => q.name).toList(),
      'shouldOfferFallback': shouldOfferFallback(),
      'shouldForceFallback': shouldForceFallback(),
    };
  }
}

extension AudioQualityExtension on AudioQuality {
  /// Color asociado a la calidad (para UI).
  /// Retorna código de color hex.
  int get colorCode {
    switch (this) {
      case AudioQuality.excellent:
        return 0xFF4CAF50; // Verde
      case AudioQuality.good:
        return 0xFF8BC34A; // Verde claro
      case AudioQuality.fair:
        return 0xFFFFC107; // Amarillo
      case AudioQuality.poor:
        return 0xFFFF5722; // Naranja/rojo
    }
  }

  /// Icono asociado (codepoint de Material Icons).
  int get iconCode {
    switch (this) {
      case AudioQuality.excellent:
        return 0xe31d; // mic
      case AudioQuality.good:
        return 0xe31d; // mic
      case AudioQuality.fair:
        return 0xe029; // warning
      case AudioQuality.poor:
        return 0xe000; // error
    }
  }

  /// Nombre legible.
  String get displayName {
    switch (this) {
      case AudioQuality.excellent:
        return 'Excelente';
      case AudioQuality.good:
        return 'Buena';
      case AudioQuality.fair:
        return 'Regular';
      case AudioQuality.poor:
        return 'Mala';
    }
  }
}
