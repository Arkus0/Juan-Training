import 'package:flutter/foundation.dart';

/// Fase 1 del pipeline defensivo: Captura bruta sin semántica
///
/// PRINCIPIO FUNDAMENTAL:
/// OCR y Voz NO interpretan, NO deciden, SOLO capturan tokens.
/// La app es quien valida, acota, corrige y decide.
///
/// Este modelo representa el output CRUDO de OCR/Voz ANTES de
/// cualquier interpretación semántica.
@immutable
class RawInputCapture {
  /// Tokens detectados en orden de aparición
  /// Ejemplo OCR: ["press", "banca", "4x8", "60kg"]
  /// Ejemplo voz: ["sentadilla", "tres", "series", "de", "cinco"]
  final List<RawToken> tokens;

  /// Fuente de la captura
  final CaptureSource source;

  /// Timestamp de la captura
  final DateTime capturedAt;

  /// Texto original completo (para debug)
  final String rawText;

  /// Confianza general de la captura (calidad de imagen/audio)
  final double overallConfidence;

  /// Metadata específica de la fuente
  final CaptureMetadata metadata;

  const RawInputCapture({
    required this.tokens,
    required this.source,
    required this.capturedAt,
    required this.rawText,
    required this.overallConfidence,
    required this.metadata,
  });

  /// Factory para crear desde output de OCR
  factory RawInputCapture.fromOcr({
    required String rawText,
    required List<OcrLine> lines,
    required double imageQuality,
  }) {
    final tokens = <RawToken>[];
    var position = 0;

    for (final line in lines) {
      for (final word in line.words) {
        tokens.add(
          RawToken(
            text: word.text,
            confidence: word.confidence,
            position: position++,
            boundingBox: word.boundingBox,
            tokenType: _classifyToken(word.text),
          ),
        );
      }
    }

    return RawInputCapture(
      tokens: tokens,
      source: CaptureSource.ocr,
      capturedAt: DateTime.now(),
      rawText: rawText,
      overallConfidence: imageQuality,
      metadata: CaptureMetadata.ocr(
        lineCount: lines.length,
        wordCount: tokens.length,
        imageQuality: imageQuality,
      ),
    );
  }

  /// Factory para crear desde output de voz
  factory RawInputCapture.fromVoice({
    required String transcript,
    required double confidence,
    required bool isFinal,
    Duration? audioDuration,
  }) {
    final words = transcript.split(RegExp(r'\s+'));
    final tokens = <RawToken>[];

    for (var i = 0; i < words.length; i++) {
      final word = words[i].trim();
      if (word.isEmpty) continue;

      tokens.add(
        RawToken(
          text: word,
          confidence: confidence,
          position: i,
          tokenType: _classifyToken(word),
        ),
      );
    }

    return RawInputCapture(
      tokens: tokens,
      source: CaptureSource.voice,
      capturedAt: DateTime.now(),
      rawText: transcript,
      overallConfidence: confidence,
      metadata: CaptureMetadata.voice(
        isFinal: isFinal,
        audioDuration: audioDuration,
        wordCount: tokens.length,
      ),
    );
  }

  /// Clasifica un token sin interpretarlo semánticamente
  static RawTokenType _classifyToken(String text) {
    final normalized = text.toLowerCase().trim();

    // Solo clasificación sintáctica, NO semántica
    if (RegExp(r'^\d+$').hasMatch(normalized)) {
      return RawTokenType.number;
    }
    if (RegExp(r'^\d+[xX×*]\d+').hasMatch(normalized)) {
      return RawTokenType.setRepPattern;
    }
    if (RegExp(r'^\d+(?:[.,]\d+)?(?:kg|lb)$', caseSensitive: false)
        .hasMatch(normalized)) {
      return RawTokenType.weightWithUnit;
    }
    if (RegExp(r'^(?:kg|lb|kilos?|libras?)$', caseSensitive: false)
        .hasMatch(normalized)) {
      return RawTokenType.unit;
    }

    return RawTokenType.word;
  }

  /// Obtiene solo los tokens con confianza >= umbral
  List<RawToken> getConfidentTokens({double minConfidence = 0.7}) {
    return tokens.where((t) => t.confidence >= minConfidence).toList();
  }

  /// Verifica si la captura tiene calidad suficiente para procesar
  bool get hasAcceptableQuality => overallConfidence >= 0.5;

  /// Número de tokens detectados
  int get tokenCount => tokens.length;

  @override
  String toString() =>
      'RawInputCapture(source: $source, tokens: $tokenCount, confidence: ${(overallConfidence * 100).toInt()}%)';
}

/// Token individual detectado (sin interpretación)
@immutable
class RawToken {
  /// Texto del token tal como se detectó
  final String text;

  /// Confianza de esta detección específica (0.0 - 1.0)
  final double confidence;

  /// Posición en la secuencia original
  final int position;

  /// Bounding box si viene de OCR (null para voz)
  final BoundingBox? boundingBox;

  /// Tipo sintáctico del token (NO semántico)
  final RawTokenType tokenType;

  const RawToken({
    required this.text,
    required this.confidence,
    required this.position,
    this.boundingBox,
    required this.tokenType,
  });

  /// Token tiene confianza alta
  bool get isHighConfidence => confidence >= 0.8;

  /// Token tiene confianza media
  bool get isMediumConfidence => confidence >= 0.5 && confidence < 0.8;

  /// Token tiene confianza baja
  bool get isLowConfidence => confidence < 0.5;

  @override
  String toString() =>
      'RawToken("$text", ${tokenType.name}, ${(confidence * 100).toInt()}%)';
}

/// Tipo sintáctico de token (clasificación sin semántica)
enum RawTokenType {
  /// Palabra de texto
  word,

  /// Número solo (ej: "4", "10", "100")
  number,

  /// Patrón NxM (ej: "4x10", "3x8")
  setRepPattern,

  /// Número con unidad de peso (ej: "60kg", "135lb")
  weightWithUnit,

  /// Unidad de medida sola (ej: "kg", "lb")
  unit,
}

/// Fuente de la captura
enum CaptureSource {
  /// Reconocimiento óptico de caracteres
  ocr,

  /// Reconocimiento de voz
  voice,
}

/// Metadata específica según la fuente
@immutable
class CaptureMetadata {
  // Campos comunes
  final int wordCount;

  // Campos específicos de OCR
  final int? lineCount;
  final double? imageQuality;

  // Campos específicos de voz
  final bool? isFinal;
  final Duration? audioDuration;

  const CaptureMetadata._({
    required this.wordCount,
    this.lineCount,
    this.imageQuality,
    this.isFinal,
    this.audioDuration,
  });

  factory CaptureMetadata.ocr({
    required int lineCount,
    required int wordCount,
    required double imageQuality,
  }) {
    return CaptureMetadata._(
      wordCount: wordCount,
      lineCount: lineCount,
      imageQuality: imageQuality,
    );
  }

  factory CaptureMetadata.voice({
    required bool isFinal,
    Duration? audioDuration,
    required int wordCount,
  }) {
    return CaptureMetadata._(
      wordCount: wordCount,
      isFinal: isFinal,
      audioDuration: audioDuration,
    );
  }
}

/// Línea de texto detectada por OCR
class OcrLine {
  final List<OcrWord> words;
  final BoundingBox? lineBoundingBox;

  const OcrLine({
    required this.words,
    this.lineBoundingBox,
  });
}

/// Palabra detectada por OCR
class OcrWord {
  final String text;
  final double confidence;
  final BoundingBox? boundingBox;

  const OcrWord({
    required this.text,
    required this.confidence,
    this.boundingBox,
  });
}

/// Bounding box para elementos visuales
@immutable
class BoundingBox {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const BoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;
}
