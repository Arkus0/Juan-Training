import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/voice_input_service.dart';
import '../models/library_exercise.dart';

/// Estado inmutable del input de voz
class VoiceInputState {
  final VoiceInputStatus status;
  final String transcript;
  final String partialTranscript;
  final List<VoiceParsedExercise> parsedExercises;
  final String? errorMessage;
  final bool isAvailable;
  final bool isContinuousMode;
  final bool audioFeedbackEnabled;
  final VoiceParsedExercise? lastCorrected; // Último ejercicio corregido

  const VoiceInputState({
    this.status = VoiceInputStatus.idle,
    this.transcript = '',
    this.partialTranscript = '',
    this.parsedExercises = const [],
    this.errorMessage,
    this.isAvailable = false,
    this.isContinuousMode = false,
    this.audioFeedbackEnabled = true,
    this.lastCorrected,
  });

  VoiceInputState copyWith({
    VoiceInputStatus? status,
    String? transcript,
    String? partialTranscript,
    List<VoiceParsedExercise>? parsedExercises,
    String? errorMessage,
    bool? isAvailable,
    bool? isContinuousMode,
    bool? audioFeedbackEnabled,
    VoiceParsedExercise? lastCorrected,
  }) {
    return VoiceInputState(
      status: status ?? this.status,
      transcript: transcript ?? this.transcript,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      parsedExercises: parsedExercises ?? this.parsedExercises,
      errorMessage: errorMessage,
      isAvailable: isAvailable ?? this.isAvailable,
      isContinuousMode: isContinuousMode ?? this.isContinuousMode,
      audioFeedbackEnabled: audioFeedbackEnabled ?? this.audioFeedbackEnabled,
      lastCorrected: lastCorrected,
    );
  }

  bool get isListening => status == VoiceInputStatus.listening;
  bool get isProcessing => status == VoiceInputStatus.processing;
  bool get hasError => status == VoiceInputStatus.error;
  bool get hasResults => parsedExercises.isNotEmpty;
  
  /// Ejercicios válidos con match exitoso
  List<VoiceParsedExercise> get validExercises => 
      parsedExercises.where((e) => e.isValid).toList();
}

/// Estados posibles del input de voz
enum VoiceInputStatus {
  idle,           // Esperando
  initializing,   // Inicializando motor
  listening,      // Escuchando activamente
  processing,     // Procesando transcripción
  results,        // Mostrando resultados
  error,          // Error
}

/// Provider principal para voice input
/// autoDispose para limpiar recursos cuando no se usa
final voiceInputProvider = StateNotifierProvider.autoDispose<VoiceInputNotifier, VoiceInputState>(
  (ref) => VoiceInputNotifier(),
);

/// Notifier que maneja toda la lógica de voice input
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

  /// Inicia la escucha de voz
  /// [continuous] activa modo continuo (no se detiene automáticamente)
  Future<bool> startListening({bool continuous = false}) async {
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
      isContinuousMode: continuous,
    );

    final success = await _service.startListening(
      onPartialResult: (partial) {
        state = state.copyWith(
          partialTranscript: partial,
          status: VoiceInputStatus.listening,
        );
      },
      mode: continuous ? VoiceListeningMode.continuous : VoiceListeningMode.single,
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
  Future<List<VoiceParsedExercise>> stopListening() async {
    final transcript = await _service.stopListening();

    if (transcript.isEmpty) {
      state = state.copyWith(
        status: VoiceInputStatus.idle,
        transcript: '',
        partialTranscript: '',
        isContinuousMode: false,
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
    );
  }

  /// Toggle: inicia si está idle, detiene si está escuchando
  Future<List<VoiceParsedExercise>> toggleListening() async {
    if (state.isListening) {
      return stopListening();
    } else {
      await startListening();
      return [];
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
      isContinuousMode: false,
    );
  }

  /// Reinicializa si hubo error
  Future<void> retry() async {
    await _init();
  }
  
  /// Toggle para el feedback de audio
  void toggleAudioFeedback() {
    final newValue = !state.audioFeedbackEnabled;
    _service.audioFeedbackEnabled = newValue;
    state = state.copyWith(audioFeedbackEnabled: newValue);
  }
  
  /// Activa/desactiva modo continuo
  Future<void> setContinuousMode(bool enabled) async {
    if (state.isContinuousMode == enabled) return;
    
    if (state.isListening) {
      await stopListening();
    }
    
    state = state.copyWith(isContinuousMode: enabled);
    
    if (enabled) {
      await startListening(continuous: true);
    }
  }
  
  /// Procesa transcripción acumulada en modo continuo
  /// Útil para procesar mientras sigue escuchando
  Future<List<VoiceParsedExercise>> processCurrentTranscript() async {
    if (state.partialTranscript.isEmpty) return [];
    
    state = state.copyWith(status: VoiceInputStatus.processing);
    
    final parsed = await _service.parseTranscript(state.partialTranscript);
    
    // Añadir a lista acumulada
    state = state.copyWith(
      status: state.isContinuousMode ? VoiceInputStatus.listening : VoiceInputStatus.results,
      parsedExercises: [...state.parsedExercises, ...parsed],
    );
    
    return parsed;
  }
}

/// Provider para verificar disponibilidad de voz (útil para ocultar/mostrar botón)
final voiceAvailableProvider = FutureProvider<bool>((ref) async {
  final service = VoiceInputService.instance;
  return service.initialize();
});
