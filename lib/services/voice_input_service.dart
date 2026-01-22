import 'dart:async';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:logger/logger.dart';
import '../models/library_exercise.dart';
import 'exercise_library_service.dart';
import 'exercise_synonyms_service.dart';
import 'voice_audio_feedback_service.dart';

/// Estado del reconocimiento de voz (usado internamente por el servicio)
enum VoiceServiceState {
  idle,          // Esperando para iniciar
  initializing,  // Inicializando el motor de speech
  listening,     // Escuchando activamente
  processing,    // Procesando transcripción
  error,         // Error en el reconocimiento
}

/// Modo de escucha
enum VoiceListeningMode {
  single,     // Escucha única: se detiene automáticamente tras pausa
  continuous, // Escucha continua: sigue escuchando hasta detención manual
}

/// Modelo inmutable de ejercicio parseado desde voz
class VoiceParsedExercise {
  final String rawText;           // Texto original que generó este ejercicio
  final String? matchedName;      // Nombre del ejercicio encontrado en biblioteca
  final int? matchedId;           // ID del ejercicio en biblioteca
  final int series;               // Número de series (default: 3)
  final String repsRange;         // Rango de reps (ej: "8-12", "5", "10")
  final double? weight;           // Peso opcional en kg
  final String? notes;            // Notas adicionales
  final double confidence;        // Confianza del match (0.0 - 1.0)
  final bool isSuperset;          // ¿Es parte de superserie?
  final int supersetGroup;        // Grupo de superserie (0 = no superserie)

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

/// Servicio singleton para reconocimiento de voz y parsing de comandos de rutina
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
  final _synonymsService = ExerciseSynonymsService.instance;
  final _audioFeedback = VoiceAudioFeedbackService.instance;

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
  List<VoiceParsedExercise> get exerciseHistory => List.unmodifiable(_exerciseHistory);

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

  // Cache de ejercicios para fuzzy matching
  List<LibraryExercise>? _exercisesCache;
  Fuzzy<LibraryExercise>? _fuzzyMatcher;

  /// Inicializa el motor de speech recognition
  /// Debe llamarse antes de usar el servicio
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _updateState(VoiceServiceState.initializing);

      // Inicializar audio feedback
      await _audioFeedback.initialize();

      _isInitialized = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
        debugLogging: false,
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

  /// Carga la biblioteca de ejercicios para fuzzy matching
  Future<void> _ensureExercisesLoaded() async {
    if (_exercisesCache != null) return;

    final library = ExerciseLibraryService.instance;
    await library.loadLibrary();
    _exercisesCache = library.exercises;

    // Crear fuzzy matcher con nombres de ejercicios
    // Configuración optimizada para voz en español
    _fuzzyMatcher = Fuzzy<LibraryExercise>(
      _exercisesCache!,
      options: FuzzyOptions(
        keys: [
          WeightedKey(
            name: 'name',
            getter: (ex) => ex.name.toLowerCase(),
            weight: 1.0,
          ),
        ],
        threshold: 0.45, // Un poco más permisivo para errores de voz
        findAllMatches: true,
        isCaseSensitive: false,
      ),
    );
  }

  /// Inicia la escucha de voz
  /// [onPartialResult] se llama con transcripciones parciales en tiempo real
  /// [mode] define si es escucha única o continua
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
      // Vibración de inicio
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}

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
            ? const Duration(minutes: 5) // Mucho más largo para modo continuo
            : listenFor,
        pauseFor: mode == VoiceListeningMode.continuous
            ? const Duration(seconds: 10) // Pausa más larga en continuo
            : const Duration(seconds: 3),
        localeId: 'es_ES', // Español de España (soporta acentos)
        // ignore: deprecated_member_use
        cancelOnError: false,
        // ignore: deprecated_member_use
        partialResults: true,
        // ignore: deprecated_member_use
        listenMode: ListenMode.dictation, // Modo dictado para frases largas
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

  /// Detiene la escucha y devuelve la transcripción final
  Future<String> stopListening() async {
    _continuousActive = false;
    
    if (_speech.isListening) {
      await _speech.stop();
      
      // Audio feedback de parada
      if (_audioFeedbackEnabled) {
        await _audioFeedback.playStopListening();
      }
      
      // Vibración de parada
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
    }

    final transcript = _currentTranscript;
    _updateState(VoiceServiceState.idle);
    return transcript;
  }

  /// Cancela la escucha sin guardar resultado
  Future<void> cancelListening() async {
    _continuousActive = false;
    if (_speech.isListening) {
      await _speech.cancel();
    }
    _currentTranscript = '';
    _updateState(VoiceServiceState.idle);
  }

  /// Reinicia la escucha (para modo continuo después de procesar)
  Future<void> _restartListeningIfContinuous(Function(String)? onPartialResult) async {
    if (_continuousActive && _listeningMode == VoiceListeningMode.continuous) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (_continuousActive) { // Verificar que no se canceló
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
      
      // En modo continuo, reiniciar automáticamente después de resultado final
      if (_continuousActive) {
        _restartListeningIfContinuous(onPartial);
      }
    }
  }

  void _onStatus(String status) {
    _logger.d('Speech status: $status');

    if (status == 'done' || status == 'notListening') {
      if (_state == VoiceServiceState.listening) {
        // En modo continuo, reiniciar automáticamente
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

    // Solo mostrar error si es permanente o severo
    if (error.permanent) {
      _lastError = _translateError(error.errorMsg);
      _updateState(VoiceServiceState.error);
    }
  }

  String _translateError(String errorMsg) {
    // Traducir errores comunes a mensajes amigables
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
  // Soporta patrones como:
  // - "Añade sentadilla 5 series de 5 reps"
  // - "Press banca 4x8-12"
  // - "Luego curl de bíceps 3 series 12 repeticiones"
  // - "Superserie con press militar y elevaciones laterales"
  // - "Peso muerto 5x5 a 100 kilos"
  // - "Nota: usar cinturón"
  // - "No, quise decir press inclinado" (corrección)
  // - "Banco plano" → "Press de banca" (sinónimos)
  // =====================================================

  /// Parsea la transcripción completa y extrae ejercicios
  /// Detecta correcciones y aplica sinónimos automáticamente
  Future<List<VoiceParsedExercise>> parseTranscript(String transcript) async {
    await _ensureExercisesLoaded();
    _updateState(VoiceServiceState.processing);

    try {
      final normalized = _normalizeSpanish(transcript.toLowerCase());
      
      // Primero detectar si es una corrección
      final correctionResult = _detectCorrection(normalized);
      if (correctionResult != null) {
        return correctionResult;
      }
      
      final exercises = <VoiceParsedExercise>[];

      // Detectar si hay superseries
      final supersetMatches = RegExp(
        r'super\s*serie\s+(?:con|de)?\s*([^,]+?)(?:\s+(?:y|con)\s+([^,]+))?',
        caseSensitive: false,
      ).allMatches(normalized);

      int supersetGroup = 0;
      final supersetSegments = <String>[];

      for (final match in supersetMatches) {
        supersetGroup++;
        final ex1 = match.group(1)?.trim();
        final ex2 = match.group(2)?.trim();
        if (ex1 != null) supersetSegments.add(ex1);
        if (ex2 != null) supersetSegments.add(ex2);
      }

      // Separar por conectores de ejercicios
      final segments = _splitByConnectors(normalized);

      for (final segment in segments) {
        final parsed = await _parseSingleExercise(segment);
        if (parsed != null) {
          // Verificar si es parte de superserie
          final isSuperset = supersetSegments.any(
            (ss) => segment.contains(ss) || ss.contains(segment.split(' ').take(3).join(' ')),
          );

          final exercise = parsed.copyWith(
            isSuperset: isSuperset,
            supersetGroup: isSuperset ? supersetGroup : 0,
          );
          
          exercises.add(exercise);
          
          // Guardar en historial para correcciones futuras
          _exerciseHistory.add(exercise);
          
          // Audio feedback según confianza
          if (_audioFeedbackEnabled && parsed.isValid) {
            if (parsed.confidence >= 0.8) {
              await _audioFeedback.playHighConfidenceMatch();
            } else if (parsed.confidence >= 0.5) {
              await _audioFeedback.playMediumConfidenceMatch();
            }
          } else if (_audioFeedbackEnabled && !parsed.isValid) {
            await _audioFeedback.playNoMatch();
          }
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
  /// Si es corrección, actualiza el último ejercicio del historial
  List<VoiceParsedExercise>? _detectCorrection(String normalized) {
    // Patrones de corrección
    final correctionPatterns = [
      RegExp(r'^(?:no[,.]?\s+)?quise\s+decir\s+(.+)$', caseSensitive: false),
      RegExp(r'^(?:no[,.]?\s+)?quería\s+decir\s+(.+)$', caseSensitive: false),
      RegExp(r'^correcci[oó]n[:\s]+(.+)$', caseSensitive: false),
      RegExp(r'^(?:no[,.]?\s+)?era\s+(.+)$', caseSensitive: false),
      RegExp(r'^cambiar?\s+(?:a|por)\s+(.+)$', caseSensitive: false),
      RegExp(r'^(?:no[,.]?\s+)?me\s+equivoqu[eé][,.]?\s*(?:era|es|quise\s+decir)?\s*(.+)$', caseSensitive: false),
    ];
    
    for (final pattern in correctionPatterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null && _exerciseHistory.isNotEmpty) {
        final correctedName = match.group(1)?.trim();
        if (correctedName != null && correctedName.isNotEmpty) {
          _logger.i('Corrección detectada: "$correctedName"');
          
          // Aplicar corrección al último ejercicio
          return _applyCorrectionAsync(correctedName);
        }
      }
    }
    
    return null;
  }
  
  /// Aplica una corrección al último ejercicio
  List<VoiceParsedExercise>? _applyCorrectionAsync(String correctedName) {
    if (_exerciseHistory.isEmpty) return null;
    
    // Resolver sinónimo primero
    final resolvedName = _synonymsService.resolveSynonym(correctedName);
    
    // Buscar el ejercicio corregido
    if (_fuzzyMatcher != null) {
      final results = _fuzzyMatcher!.search(resolvedName.toLowerCase());
      if (results.isNotEmpty) {
        final best = results.first;
        final confidence = 1.0 - best.score;
        
        if (confidence >= 0.4) {
          // Actualizar el último ejercicio en historial
          final lastIndex = _exerciseHistory.length - 1;
          final lastExercise = _exerciseHistory[lastIndex];
          
          final corrected = lastExercise.copyWith(
            matchedName: best.item.name,
            matchedId: best.item.id,
            confidence: 1.0, // Corrección manual = 100% confianza
            rawText: '${lastExercise.rawText} → $correctedName',
          );
          
          _exerciseHistory[lastIndex] = corrected;
          
          // Audio feedback
          if (_audioFeedbackEnabled) {
            _audioFeedback.playCorrectionAccepted();
          }
          
          _logger.i('Ejercicio corregido: ${lastExercise.matchedName} → ${best.item.name}');
          
          // Devolver el ejercicio corregido
          return [corrected];
        }
      }
    }
    
    return null;
  }
  
  /// Limpia el historial de ejercicios (útil al iniciar nueva sesión)
  void clearExerciseHistory() {
    _exerciseHistory.clear();
  }

  /// Normaliza texto en español (acentos, variaciones)
  String _normalizeSpanish(String text) {
    return text
        // Normalizar separadores de ejercicios
        .replaceAll(RegExp(r'\s+'), ' ')
        // Normalizar "x" para series
        .replaceAll('×', 'x')
        .replaceAll('*', 'x')
        // Normalizar números hablados comunes
        .replaceAll('una serie', '1 serie')
        .replaceAll('un set', '1 set')
        .replaceAll('dos series', '2 series')
        .replaceAll('tres series', '3 series')
        .replaceAll('cuatro series', '4 series')
        .replaceAll('cinco series', '5 series')
        .replaceAll('seis series', '6 series')
        // Normalizar "repeticiones" a "reps"
        .replaceAll('repeticiones', 'reps')
        .replaceAll('repeticion', 'rep')
        // Normalizar peso
        .replaceAll('kilogramos', 'kg')
        .replaceAll('kilos', 'kg')
        .replaceAll('libras', 'lb')
        .trim();
  }

  /// Separa la transcripción en segmentos por ejercicio
  List<String> _splitByConnectors(String text) {
    // Patrones de separación
    final connectors = [
      r'\s+luego\s+',
      r'\s+después\s+',
      r'\s+y\s+(?:después|luego)\s+',
      r'\s+seguido\s+de\s+',
      r'\s+también\s+',
      r',\s*(?:después|luego)?\s*',
      r'\.\s+',
    ];

    // Primero separar por conectores
    String working = text;
    for (final connector in connectors) {
      working = working.replaceAll(RegExp(connector, caseSensitive: false), '|||');
    }

    return working
        .split('|||')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 3)
        .toList();
  }

  /// Parsea un segmento individual en un ejercicio
  Future<VoiceParsedExercise?> _parseSingleExercise(String segment) async {
    // Ignorar comandos de control
    if (segment.startsWith('añade') || segment.startsWith('agrega')) {
      segment = segment.replaceFirst(RegExp(r'^(añade|agrega)\s+'), '');
    }

    if (segment.length < 3) return null;

    int series = 3; // Default
    String repsRange = '10'; // Default
    double? weight;
    String? notes;
    String exercisePart = segment;

    // =====================================================
    // ORDEN DE EXTRACCIÓN (similar a OCR pero adaptado a voz)
    // =====================================================

    // 1. Extraer notas (después de "nota:" o "con nota")
    final notesRegex = RegExp(
      r'(?:nota[s]?:?\s*|con\s+nota\s*)(.+)$',
      caseSensitive: false,
    );
    final notesMatch = notesRegex.firstMatch(exercisePart);
    if (notesMatch != null) {
      notes = notesMatch.group(1)?.trim();
      exercisePart = exercisePart.replaceAll(notesRegex, '');
    }

    // 2. Extraer peso (ej: "a 100 kg", "con 50 kilos")
    final weightRegex = RegExp(
      r'(?:a\s+|con\s+)?(\d+(?:[.,]\d+)?)\s*(?:kg|lb)',
      caseSensitive: false,
    );
    final weightMatch = weightRegex.firstMatch(exercisePart);
    if (weightMatch != null) {
      final weightStr = weightMatch.group(1)!.replaceAll(',', '.');
      weight = double.tryParse(weightStr);
      exercisePart = exercisePart.replaceAll(weightRegex, ' ');
    }

    // 3. Patrón NxM o NxM-P (ej: "4x10", "3x8-12")
    final nxmRegex = RegExp(r'(\d+)\s*[xX]\s*(\d+)(?:\s*-\s*(\d+))?');
    final nxmMatch = nxmRegex.firstMatch(exercisePart);
    if (nxmMatch != null) {
      series = int.tryParse(nxmMatch.group(1)!) ?? 3;
      final repsMin = nxmMatch.group(2)!;
      final repsMax = nxmMatch.group(3);
      repsRange = repsMax != null ? '$repsMin-$repsMax' : repsMin;
      exercisePart = exercisePart.replaceAll(nxmRegex, ' ');
    }

    // 4. Patrón "N series de M reps" o "N series M-P reps"
    if (nxmMatch == null) {
      final seriesRepsRegex = RegExp(
        r'(\d+)\s*(?:series?|sets?)\s*(?:de\s*)?(\d+)(?:\s*-\s*(\d+))?\s*(?:reps?)?',
        caseSensitive: false,
      );
      final seriesRepsMatch = seriesRepsRegex.firstMatch(exercisePart);
      if (seriesRepsMatch != null) {
        series = int.tryParse(seriesRepsMatch.group(1)!) ?? 3;
        final repsMin = seriesRepsMatch.group(2)!;
        final repsMax = seriesRepsMatch.group(3);
        repsRange = repsMax != null ? '$repsMin-$repsMax' : repsMin;
        exercisePart = exercisePart.replaceAll(seriesRepsRegex, ' ');
      }
    }

    // 5. Solo "N reps" (series default 3)
    if (nxmMatch == null) {
      final repsOnlyRegex = RegExp(
        r'(\d+)(?:\s*-\s*(\d+))?\s*(?:reps?)',
        caseSensitive: false,
      );
      final repsOnlyMatch = repsOnlyRegex.firstMatch(exercisePart);
      if (repsOnlyMatch != null) {
        final repsMin = repsOnlyMatch.group(1)!;
        final repsMax = repsOnlyMatch.group(2);
        repsRange = repsMax != null ? '$repsMin-$repsMax' : repsMin;
        exercisePart = exercisePart.replaceAll(repsOnlyRegex, ' ');
      }
    }

    // 6. Limpiar nombre del ejercicio
    exercisePart = _cleanExerciseName(exercisePart);

    if (exercisePart.length < 3) return null;

    // 7. Aplicar sinónimos antes de fuzzy matching
    final resolvedExercise = _synonymsService.resolveSynonym(exercisePart);
    final searchTerm = _synonymsService.hasSynonym(exercisePart) 
        ? resolvedExercise 
        : exercisePart;

    // 8. Fuzzy matching contra biblioteca
    String? matchedName;
    int? matchedId;
    double confidence = 0.0;

    if (_fuzzyMatcher != null) {
      final results = _fuzzyMatcher!.search(searchTerm.toLowerCase());

      if (results.isNotEmpty) {
        final best = results.first;
        confidence = 1.0 - best.score;
        
        // Si usamos sinónimo, aumentar confianza
        if (_synonymsService.hasSynonym(exercisePart)) {
          confidence = (confidence + 0.2).clamp(0.0, 1.0);
        }

        // Umbral más bajo para voz (más tolerante a errores)
        if (confidence >= 0.4) {
          matchedName = best.item.name;
          matchedId = best.item.id;
        }
      }
    }

    return VoiceParsedExercise(
      rawText: segment,
      matchedName: matchedName,
      matchedId: matchedId,
      series: series,
      repsRange: repsRange,
      weight: weight,
      notes: notes,
      confidence: confidence,
    );
  }

  /// Limpia el nombre del ejercicio
  String _cleanExerciseName(String text) {
    return text
        .replaceAll(RegExp(r'^\d+\s*'), '') // Números al inicio
        .replaceAll(RegExp(r'\s*\d+$'), '') // Números al final
        .replaceAll(RegExp(r'[•\-–—:,;.!?()[\]{}]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Obtiene un ejercicio de la biblioteca por ID
  Future<LibraryExercise?> getExerciseById(int id) async {
    await _ensureExercisesLoaded();
    try {
      return _exercisesCache?.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Busca ejercicios por nombre (para sugerencias alternativas)
  Future<List<LibraryExercise>> searchExercises(String query, {int limit = 5}) async {
    await _ensureExercisesLoaded();
    if (_fuzzyMatcher == null || query.length < 2) return [];

    final results = _fuzzyMatcher!.search(query.toLowerCase());
    return results.take(limit).map((r) => r.item).toList();
  }

  /// Libera recursos
  void dispose() {
    _stateController.close();
    _transcriptController.close();
    _exercisesCache = null;
    _fuzzyMatcher = null;
  }
}
