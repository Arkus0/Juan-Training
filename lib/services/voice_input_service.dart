import 'dart:async';

import 'package:logger/logger.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/library_exercise.dart';
import 'exercise_matching_service.dart';
import 'exercise_parsing_service.dart';
import 'haptics_controller.dart';
import 'voice_audio_feedback_service.dart';

/// Estado del reconocimiento de voz (usado internamente por el servicio)
enum VoiceServiceState {
  idle, // Esperando para iniciar
  initializing, // Inicializando el motor de speech
  listening, // Escuchando activamente
  processing, // Procesando transcripción
  error, // Error en el reconocimiento
}

/// Modo de escucha
enum VoiceListeningMode {
  single, // Escucha única: se detiene automáticamente tras pausa
  continuous, // Escucha continua: sigue escuchando hasta detención manual
}

/// Modelo inmutable de ejercicio parseado desde voz.
///
/// NOTA: Esta clase se mantiene por compatibilidad con código existente.
/// Internamente usa [ParsedExercise] de [ExerciseParsingService].
class VoiceParsedExercise {
  final String rawText; // Texto original que generó este ejercicio
  final String? matchedName; // Nombre del ejercicio encontrado en biblioteca
  final int? matchedId; // ID del ejercicio en biblioteca
  final int series; // Número de series (default: 3)
  final String repsRange; // Rango de reps (ej: "8-12", "5", "10")
  final double? weight; // Peso opcional en kg
  final String? notes; // Notas adicionales
  final double confidence; // Confianza del match (0.0 - 1.0)
  final bool isSuperset; // ¿Es parte de superserie?
  final int supersetGroup; // Grupo de superserie (0 = no superserie)

  const VoiceParsedExercise({
    required this.rawText,
    this.matchedName,
    this.matchedId,
    this.series = 3,
    this.repsRange = '10',
    this.weight,
    this.notes,
    this.confidence = 0.0,
    this.isSuperset = false,
    this.supersetGroup = 0,
  });

  bool get isValid => matchedName != null && matchedId != null;

  /// Crea un VoiceParsedExercise desde un ParsedExercise
  factory VoiceParsedExercise.fromParsedExercise(ParsedExercise parsed) {
    return VoiceParsedExercise(
      rawText: parsed.rawText,
      matchedName: parsed.matchedName,
      matchedId: parsed.matchedId,
      series: parsed.series,
      repsRange: parsed.repsRange,
      weight: parsed.weight,
      notes: parsed.notes,
      confidence: parsed.confidence,
      isSuperset: parsed.isSuperset,
      supersetGroup: parsed.supersetGroup,
    );
  }

  VoiceParsedExercise copyWith({
    String? rawText,
    String? matchedName,
    int? matchedId,
    int? series,
    String? repsRange,
    double? weight,
    String? notes,
    double? confidence,
    bool? isSuperset,
    int? supersetGroup,
  }) {
    return VoiceParsedExercise(
      rawText: rawText ?? this.rawText,
      matchedName: matchedName ?? this.matchedName,
      matchedId: matchedId ?? this.matchedId,
      series: series ?? this.series,
      repsRange: repsRange ?? this.repsRange,
      weight: weight ?? this.weight,
      notes: notes ?? this.notes,
      confidence: confidence ?? this.confidence,
      isSuperset: isSuperset ?? this.isSuperset,
      supersetGroup: supersetGroup ?? this.supersetGroup,
    );
  }
}

/// Servicio singleton para reconocimiento de voz y parsing de comandos de rutina.
///
/// Este servicio ahora delega el parsing a [ExerciseParsingService] y el matching
/// a [ExerciseMatchingService] para mantener consistencia con OCR.
///
/// Justificación speech_to_text:
/// - Usa motores nativos on-device (iOS Speech Framework, Android SpeechRecognizer)
/// - Funciona offline sin enviar audio a servidores externos
/// - Privacidad total para el usuario en el gym
/// - Rendimiento estable en ambientes ruidosos
/// - Soporte nativo para español con acentos
class VoiceInputService {
  static final VoiceInputService instance = VoiceInputService._();
  VoiceInputService._();

  final _logger = Logger();
  final _speech = SpeechToText();
  final _audioFeedback = VoiceAudioFeedbackService.instance;

  // Servicios unificados
  final _parsingService = ExerciseParsingService.instance;
  final _matchingService = ExerciseMatchingService.instance;

  // State
  VoiceServiceState _state = VoiceServiceState.idle;
  VoiceServiceState get state => _state;

  String _currentTranscript = '';
  String get currentTranscript => _currentTranscript;

  String? _lastError;
  String? get lastError => _lastError;

  bool _isInitialized = false;
  bool get isAvailable => _isInitialized;

  // Modo continuo
  VoiceListeningMode _listeningMode = VoiceListeningMode.single;
  VoiceListeningMode get listeningMode => _listeningMode;
  bool _continuousActive = false;

  // Historial para correcciones
  final List<VoiceParsedExercise> _exerciseHistory = [];
  List<VoiceParsedExercise> get exerciseHistory =>
      List.unmodifiable(_exerciseHistory);

  // Audio feedback
  bool _audioFeedbackEnabled = true;
  bool get audioFeedbackEnabled => _audioFeedbackEnabled;
  set audioFeedbackEnabled(bool value) {
    _audioFeedbackEnabled = value;
    _audioFeedback.isEnabled = value;
  }

  // Callbacks para streaming
  final _stateController = StreamController<VoiceServiceState>.broadcast();
  Stream<VoiceServiceState> get stateStream => _stateController.stream;

  final _transcriptController = StreamController<String>.broadcast();
  Stream<String> get transcriptStream => _transcriptController.stream;

  /// Inicializa el motor de speech recognition.
  /// Debe llamarse antes de usar el servicio.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _updateState(VoiceServiceState.initializing);

      // Inicializar audio feedback
      await _audioFeedback.initialize();

      // Inicializar servicio de matching
      await _matchingService.initialize();

      _isInitialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );

      if (_isInitialized) {
        _logger.i('VoiceInputService inicializado correctamente');
        _updateState(VoiceServiceState.idle);
      } else {
        _logger.w('Speech recognition no disponible en este dispositivo');
        _lastError = 'Reconocimiento de voz no disponible';
        _updateState(VoiceServiceState.error);
      }

      return _isInitialized;
    } catch (e, s) {
      _logger.e('Error inicializando speech', error: e, stackTrace: s);
      _lastError = 'Error al inicializar: ${e.toString()}';
      _updateState(VoiceServiceState.error);
      return false;
    }
  }

  /// Inicia la escucha de voz.
  /// [onPartialResult] se llama con transcripciones parciales en tiempo real.
  /// [mode] define si es escucha única o continua.
  Future<bool> startListening({
    Function(String)? onPartialResult,
    Duration listenFor = const Duration(seconds: 30),
    VoiceListeningMode mode = VoiceListeningMode.single,
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }

    if (_speech.isListening) {
      await stopListening();
    }

    try {
      // Vibración de inicio via HapticsController (lifecycle-aware)
      HapticsController.instance.onVoiceStarted();

      // Audio feedback de inicio
      if (_audioFeedbackEnabled) {
        await _audioFeedback.playStartListening();
      }

      _currentTranscript = '';
      _lastError = null;
      _listeningMode = mode;
      _continuousActive = mode == VoiceListeningMode.continuous;
      _updateState(VoiceServiceState.listening);

      // ignore: deprecated_member_use
      await _speech.listen(
        onResult: (result) => _onResult(result, onPartialResult),
        listenFor: mode == VoiceListeningMode.continuous
            ? const Duration(minutes: 5)
            : listenFor,
        pauseFor: mode == VoiceListeningMode.continuous
            ? const Duration(seconds: 10)
            : const Duration(seconds: 3),
        localeId: 'es_ES',
        // ignore: deprecated_member_use
        listenMode: ListenMode.dictation,
      );

      _logger.d('Iniciada escucha de voz en modo: $mode');
      return true;
    } catch (e, s) {
      _logger.e('Error iniciando escucha', error: e, stackTrace: s);
      _lastError = 'Error al escuchar: ${e.toString()}';
      _updateState(VoiceServiceState.error);
      return false;
    }
  }

  /// Detiene la escucha y devuelve la transcripción final.
  Future<String> stopListening() async {
    _continuousActive = false;

    if (_speech.isListening) {
      await _speech.stop();

      // Audio feedback de parada
      if (_audioFeedbackEnabled) {
        await _audioFeedback.playStopListening();
      }

      // Vibración de parada via HapticsController (lifecycle-aware)
      HapticsController.instance.onVoiceStopped();
    }

    final transcript = _currentTranscript;
    _updateState(VoiceServiceState.idle);
    return transcript;
  }

  /// Cancela la escucha sin guardar resultado.
  Future<void> cancelListening() async {
    _continuousActive = false;
    if (_speech.isListening) {
      await _speech.cancel();
    }
    _currentTranscript = '';
    _updateState(VoiceServiceState.idle);
  }

  /// Reinicia la escucha (para modo continuo después de procesar).
  Future<void> _restartListeningIfContinuous(
      Function(String)? onPartialResult,) async {
    if (_continuousActive && _listeningMode == VoiceListeningMode.continuous) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (_continuousActive) {
        await startListening(
          onPartialResult: onPartialResult,
          mode: VoiceListeningMode.continuous,
        );
      }
    }
  }

  // --- Callbacks internos ---

  void _onResult(SpeechRecognitionResult result, Function(String)? onPartial) {
    _currentTranscript = result.recognizedWords;
    _transcriptController.add(_currentTranscript);

    if (onPartial != null) {
      onPartial(_currentTranscript);
    }

    if (result.finalResult) {
      _logger.i('Transcripción final: $_currentTranscript');

      if (_continuousActive) {
        _restartListeningIfContinuous(onPartial);
      }
    }
  }

  void _onStatus(String status) {
    _logger.d('Speech status: $status');

    if (status == 'done' || status == 'notListening') {
      if (_state == VoiceServiceState.listening) {
        if (_continuousActive) {
          _restartListeningIfContinuous(null);
        } else {
          _updateState(VoiceServiceState.idle);
        }
      }
    }
  }

  void _onError(SpeechRecognitionError error) {
    _logger.w('Speech error: ${error.errorMsg} (${error.permanent})');

    if (error.permanent) {
      _lastError = _translateError(error.errorMsg);
      _updateState(VoiceServiceState.error);
    }
  }

  String _translateError(String errorMsg) {
    if (errorMsg.contains('no-speech') || errorMsg.contains('no_speech')) {
      return 'No se detectó voz. Intenta de nuevo.';
    }
    if (errorMsg.contains('audio') || errorMsg.contains('microphone')) {
      return 'Error de micrófono. Verifica permisos.';
    }
    if (errorMsg.contains('network')) {
      return 'Error de red. El modo offline debería funcionar.';
    }
    return 'Error: $errorMsg';
  }

  void _updateState(VoiceServiceState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  // =====================================================
  // PARSING DE COMANDOS NATURALES
  // =====================================================
  //
  // Ahora usa ExerciseParsingService para consistencia con OCR.
  //
  // Soporta patrones como:
  // - "Añade sentadilla 5 series de 5 reps"
  // - "Press banca 4x8-12"
  // - "Luego curl de bíceps 3 series 12 repeticiones"
  // - "Superserie con press militar y elevaciones laterales"
  // - "Peso muerto 5x5 a 100 kilos"
  // - "Nota: usar cinturón"
  // - "No, quise decir press inclinado" (corrección)
  // =====================================================

  /// Parsea la transcripción completa y extrae ejercicios.
  /// Detecta correcciones y aplica sinónimos automáticamente.
  Future<List<VoiceParsedExercise>> parseTranscript(String transcript) async {
    _updateState(VoiceServiceState.processing);

    try {
      final normalized = transcript.toLowerCase();

      // Primero detectar si es una corrección
      final correctionResult = await _detectCorrection(normalized);
      if (correctionResult != null) {
        _updateState(VoiceServiceState.idle);
        return correctionResult;
      }

      // Usar el servicio de parsing unificado
      final parsedExercises = await _parsingService.parseText(
        transcript,
        source: ParseSource.voice,
      );

      final exercises = <VoiceParsedExercise>[];

      for (final parsed in parsedExercises) {
        final exercise = VoiceParsedExercise.fromParsedExercise(parsed);
        exercises.add(exercise);

        // Guardar en historial para correcciones futuras
        _exerciseHistory.add(exercise);

        // Audio feedback según confianza
        if (_audioFeedbackEnabled && exercise.isValid) {
          if (exercise.confidence >= 0.8) {
            await _audioFeedback.playHighConfidenceMatch();
          } else if (exercise.confidence >= 0.5) {
            await _audioFeedback.playMediumConfidenceMatch();
          }
        } else if (_audioFeedbackEnabled && !exercise.isValid) {
          await _audioFeedback.playNoMatch();
        }
      }

      _updateState(VoiceServiceState.idle);
      return exercises;
    } catch (e, s) {
      _logger.e('Error parseando transcripción', error: e, stackTrace: s);
      _updateState(VoiceServiceState.idle);
      return [];
    }
  }

  /// Detecta si el texto es una corrección ("No, quise decir...", "Corrección:...")
  /// Si es corrección, actualiza el último ejercicio del historial.
  Future<List<VoiceParsedExercise>?> _detectCorrection(
      String normalized,) async {
    // Patrones de corrección
    final correctionPatterns = [
      RegExp(r'^(?:no[,.]?\s+)?quise\s+decir\s+(.+)$', caseSensitive: false),
      RegExp(r'^(?:no[,.]?\s+)?quería\s+decir\s+(.+)$', caseSensitive: false),
      RegExp(r'^correcci[oó]n[:\s]+(.+)$', caseSensitive: false),
      RegExp(r'^(?:no[,.]?\s+)?era\s+(.+)$', caseSensitive: false),
      RegExp(r'^cambiar?\s+(?:a|por)\s+(.+)$', caseSensitive: false),
      RegExp(
          r'^(?:no[,.]?\s+)?me\s+equivoqu[eé][,.]?\s*(?:era|es|quise\s+decir)?\s*(.+)$',
          caseSensitive: false,),
    ];

    for (final pattern in correctionPatterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null && _exerciseHistory.isNotEmpty) {
        final correctedName = match.group(1)?.trim();
        if (correctedName != null && correctedName.isNotEmpty) {
          _logger.i('Corrección detectada: "$correctedName"');
          return _applyCorrection(correctedName);
        }
      }
    }

    return null;
  }

  /// Aplica una corrección al último ejercicio.
  Future<List<VoiceParsedExercise>?> _applyCorrection(
      String correctedName,) async {
    if (_exerciseHistory.isEmpty) return null;

    // Buscar el ejercicio corregido usando el servicio unificado
    final matchResult = await _matchingService.match(correctedName);

    if (matchResult.isValid) {
      // Actualizar el último ejercicio en historial
      final lastIndex = _exerciseHistory.length - 1;
      final lastExercise = _exerciseHistory[lastIndex];

      final corrected = lastExercise.copyWith(
        matchedName: matchResult.exercise!.name,
        matchedId: matchResult.exercise!.id,
        confidence: 1.0, // Corrección manual = 100% confianza
        rawText: '${lastExercise.rawText} → $correctedName',
      );

      _exerciseHistory[lastIndex] = corrected;

      // Audio feedback
      if (_audioFeedbackEnabled) {
        _audioFeedback.playCorrectionAccepted();
      }

      _logger.i(
          'Ejercicio corregido: ${lastExercise.matchedName} → ${matchResult.exercise!.name}',);

      return [corrected];
    }

    return null;
  }

  /// Limpia el historial de ejercicios (útil al iniciar nueva sesión).
  void clearExerciseHistory() {
    _exerciseHistory.clear();
  }

  /// Obtiene un ejercicio de la biblioteca por ID.
  Future<LibraryExercise?> getExerciseById(int id) async {
    return _matchingService.getById(id);
  }

  /// Busca ejercicios por nombre (para sugerencias alternativas).
  Future<List<LibraryExercise>> searchExercises(String query,
      {int limit = 5,}) async {
    final results = await _matchingService.matchMultiple(query, limit: limit);
    return results
        .where((r) => r.exercise != null)
        .map((r) => r.exercise!)
        .toList();
  }

  /// Libera recursos.
  void dispose() {
    _stateController.close();
    _transcriptController.close();
  }
}
