import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/voice_input_service.dart';
import '../models/library_exercise.dart';

/// Acción de voz para historial de undo
class VoiceAction {
  final VoiceActionType type;
  final dynamic previousValue;
  final dynamic newValue;
  final String description;
  final DateTime timestamp;

  const VoiceAction({
    required this.type,
    required this.previousValue,
    required this.newValue,
    required this.description,
    required this.timestamp,
  });
}

enum VoiceActionType {
  setWeight,
  setReps,
  setRpe,
  addNote,
  markDone,
  addExercise,
  removeExercise,
}

/// Estado inmutable del input de voz
class VoiceInputState {
  final VoiceInputStatus status;
  final String transcript;
  final String partialTranscript;
  final List<VoiceParsedExercise> parsedExercises;
  final String? errorMessage;
  final bool isAvailable;
  final bool audioFeedbackEnabled;
  final VoiceParsedExercise? lastCorrected;

  // Nuevos campos para Push-To-Talk y Undo
  final List<VoiceAction> actionHistory; // Historial para undo
  final VoiceAction? lastAction; // Última acción ejecutada
  final String? notUnderstoodMessage; // Mensaje cuando no se entiende

  const VoiceInputState({
    this.status = VoiceInputStatus.idle,
    this.transcript = '',
    this.partialTranscript = '',
    this.parsedExercises = const [],
    this.errorMessage,
    this.isAvailable = false,
    this.audioFeedbackEnabled = true,
    this.lastCorrected,
    this.actionHistory = const [],
    this.lastAction,
    this.notUnderstoodMessage,
  });

  VoiceInputState copyWith({
    VoiceInputStatus? status,
    String? transcript,
    String? partialTranscript,
    List<VoiceParsedExercise>? parsedExercises,
    String? errorMessage,
    bool? isAvailable,
    bool? audioFeedbackEnabled,
    VoiceParsedExercise? lastCorrected,
    List<VoiceAction>? actionHistory,
    VoiceAction? lastAction,
    String? notUnderstoodMessage,
  }) {
    return VoiceInputState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      parsedExercises: parsedExercises ?? this.parsedExercises,
      errorMessage: errorMessage,
      isAvailable: isAvailable ?? this.isAvailable,
      audioFeedbackEnabled: audioFeedbackEnabled ?? this.audioFeedbackEnabled,
      lastCorrected: lastCorrected,
      actionHistory: actionHistory ?? this.actionHistory,
      lastAction: lastAction,
      notUnderstoodMessage: notUnderstoodMessage,
    );
  }

  bool get isListening => status == VoiceInputStatus.listening;
  bool get isProcessing => status == VoiceInputStatus.processing;
  bool get hasError => status == VoiceInputStatus.error;
  bool get hasResults => parsedExercises.isNotEmpty;
  bool get notUnderstood => status == VoiceInputStatus.notUnderstood;
  bool get canUndo => actionHistory.isNotEmpty;

  /// Ejercicios válidos con match exitoso
  List<VoiceParsedExercise> get validExercises =>
      parsedExercises.where((e) => e.isValid).toList();
}

/// Estados posibles del input de voz
enum VoiceInputStatus {
  idle,           // Esperando - botón en reposo
  initializing,   // Inicializando motor de voz
  listening,      // Escuchando activamente (botón pulsado)
  processing,     // Procesando transcripción
  results,        // Mostrando resultados parseados
  notUnderstood,  // No se entendió el comando - feedback claro
  error,          // Error técnico
}

/// Provider principal para voice input
/// autoDispose para limpiar recursos cuando no se usa
final voiceInputProvider = StateNotifierProvider.autoDispose<VoiceInputNotifier, VoiceInputState>(
  (ref) => VoiceInputNotifier(),
);

/// Notifier que maneja toda la lógica de voice input
/// Implementa Push-To-Talk obligatorio (sin modo continuo)
class VoiceInputNotifier extends StateNotifier<VoiceInputState> {
  VoiceInputNotifier() : super(const VoiceInputState()) {
    _init();
  }

  final _service = VoiceInputService.instance;

  /// Inicialización async
  Future<void> _init() async {
    state = state.copyWith(status: VoiceInputStatus.initializing);

    final available = await _service.initialize();

    state = state.copyWith(
      isAvailable: available,
      status: available ? VoiceInputStatus.idle : VoiceInputStatus.error,
      errorMessage: available ? null : _service.lastError,
    );
  }

  /// Inicia la escucha de voz - PUSH TO TALK
  /// Solo escucha mientras el botón está pulsado
  Future<bool> startListening() async {
    if (!state.isAvailable) {
      state = state.copyWith(
        status: VoiceInputStatus.error,
        errorMessage: 'Reconocimiento de voz no disponible',
      );
      return false;
    }

    // Limpiar estado anterior
    state = state.copyWith(
      transcript: '',
      partialTranscript: '',
      parsedExercises: [],
      errorMessage: null,
      notUnderstoodMessage: null,
    );

    // SIEMPRE modo single (Push-To-Talk)
    final success = await _service.startListening(
      onPartialResult: (partial) {
        state = state.copyWith(
          partialTranscript: partial,
          status: VoiceInputStatus.listening,
        );
      },
      mode: VoiceListeningMode.single,
    );

    if (success) {
      state = state.copyWith(status: VoiceInputStatus.listening);
    } else {
      state = state.copyWith(
        status: VoiceInputStatus.error,
        errorMessage: _service.lastError ?? 'Error al iniciar escucha',
      );
    }

    return success;
  }

  /// Detiene la escucha y procesa el resultado
  /// Muestra "No entendido" si el transcript está vacío o no se parsea nada útil
  Future<List<VoiceParsedExercise>> stopListening() async {
    final transcript = await _service.stopListening();

    if (transcript.isEmpty) {
      // No se capturó nada - mostrar "No entendido"
      state = state.copyWith(
        status: VoiceInputStatus.notUnderstood,
        transcript: '',
        partialTranscript: '',
        notUnderstoodMessage: 'No se detectó voz. Mantén pulsado el botón mientras hablas.',
      );
      return [];
    }

    state = state.copyWith(
      status: VoiceInputStatus.processing,
      transcript: transcript,
      partialTranscript: '',
    );

    // Parsear la transcripción
    final parsed = await _service.parseTranscript(transcript);

    // Verificar si es una corrección
    final isCorrection = parsed.length == 1 &&
        parsed.first.rawText.contains('→');

    if (isCorrection) {
      // Reemplazar el último ejercicio con la corrección
      final corrected = parsed.first;
      final updatedList = [...state.parsedExercises];
      if (updatedList.isNotEmpty) {
        updatedList[updatedList.length - 1] = corrected;
      } else {
        updatedList.add(corrected);
      }

      state = state.copyWith(
        status: VoiceInputStatus.results,
        parsedExercises: updatedList,
        lastCorrected: corrected,
      );
    } else if (parsed.isEmpty) {
      // Se capturó audio pero no se entendió como ejercicio
      state = state.copyWith(
        status: VoiceInputStatus.notUnderstood,
        notUnderstoodMessage: 'No entendido: "$transcript". Intenta con formato: "Press banca 4x8"',
      );
    } else {
      // Añadir nuevos ejercicios
      state = state.copyWith(
        status: VoiceInputStatus.results,
        parsedExercises: [...state.parsedExercises, ...parsed],
      );
    }

    return parsed;
  }

  /// Cancela la escucha sin procesar
  Future<void> cancelListening() async {
    await _service.cancelListening();
    state = state.copyWith(
      status: VoiceInputStatus.idle,
      transcript: '',
      partialTranscript: '',
      notUnderstoodMessage: null,
    );
  }

  /// Toggle: inicia si está idle, detiene si está escuchando
  /// PUSH TO TALK - simple toggle
  Future<List<VoiceParsedExercise>> toggleListening() async {
    if (state.isListening) {
      return stopListening();
    } else {
      await startListening();
      return [];
    }
  }

  /// Registra una acción para poder deshacerla
  void recordAction(VoiceAction action) {
    final newHistory = [...state.actionHistory, action];
    // Mantener solo las últimas 10 acciones
    if (newHistory.length > 10) {
      newHistory.removeAt(0);
    }
    state = state.copyWith(
      actionHistory: newHistory,
      lastAction: action,
    );
  }

  /// Obtiene la última acción para deshacer
  VoiceAction? getLastAction() {
    if (state.actionHistory.isEmpty) return null;
    return state.actionHistory.last;
  }

  /// Elimina la última acción del historial (después de deshacer)
  void removeLastAction() {
    if (state.actionHistory.isEmpty) return;
    final newHistory = [...state.actionHistory]..removeLast();
    state = state.copyWith(
      actionHistory: newHistory,
      lastAction: newHistory.isNotEmpty ? newHistory.last : null,
    );
  }

  /// Limpia el mensaje de "no entendido"
  void clearNotUnderstood() {
    if (state.notUnderstood) {
      state = state.copyWith(
        status: VoiceInputStatus.idle,
        notUnderstoodMessage: null,
      );
    }
  }

  /// Actualiza un ejercicio parseado (para edición manual)
  void updateParsedExercise(int index, VoiceParsedExercise updated) {
    if (index < 0 || index >= state.parsedExercises.length) return;

    final newList = [...state.parsedExercises];
    newList[index] = updated;
    state = state.copyWith(parsedExercises: newList);
  }

  /// Elimina un ejercicio parseado
  void removeParsedExercise(int index) {
    if (index < 0 || index >= state.parsedExercises.length) return;

    final newList = [...state.parsedExercises]..removeAt(index);
    state = state.copyWith(parsedExercises: newList);
  }

  /// Cambia el ejercicio matcheado por otro (corrección manual)
  Future<void> rematchExercise(int index, LibraryExercise newExercise) async {
    if (index < 0 || index >= state.parsedExercises.length) return;

    final current = state.parsedExercises[index];
    final updated = current.copyWith(
      matchedName: newExercise.name,
      matchedId: newExercise.id,
      confidence: 1.0, // Manual = 100% confianza
    );

    updateParsedExercise(index, updated);
  }

  /// Busca ejercicios alternativos para sugerencias
  Future<List<LibraryExercise>> searchAlternatives(String query) async {
    return _service.searchExercises(query, limit: 5);
  }

  /// Obtiene ejercicio por ID
  Future<LibraryExercise?> getExerciseById(int id) async {
    return _service.getExerciseById(id);
  }

  /// Limpia resultados y vuelve a idle
  void clearResults() {
    _service.clearExerciseHistory();
    state = state.copyWith(
      status: VoiceInputStatus.idle,
      transcript: '',
      partialTranscript: '',
      parsedExercises: [],
      errorMessage: null,
      notUnderstoodMessage: null,
    );
  }

  /// Reinicializa si hubo error
  Future<void> retry() async {
    state = state.copyWith(
      status: VoiceInputStatus.idle,
      errorMessage: null,
      notUnderstoodMessage: null,
    );
    await _init();
  }

  /// Toggle para el feedback de audio
  void toggleAudioFeedback() {
    final newValue = !state.audioFeedbackEnabled;
    _service.audioFeedbackEnabled = newValue;
    state = state.copyWith(audioFeedbackEnabled: newValue);
  }

  /// Limpia historial de acciones (útil al cambiar de contexto)
  void clearActionHistory() {
    state = state.copyWith(
      actionHistory: [],
      lastAction: null,
    );
  }
}

/// Provider para verificar disponibilidad de voz (útil para ocultar/mostrar botón)
final voiceAvailableProvider = FutureProvider<bool>((ref) async {
  final service = VoiceInputService.instance;
  return service.initialize();
});
