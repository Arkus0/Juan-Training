import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/detected_exercise_draft.dart';
import '../models/library_exercise.dart';
import '../services/exercise_matching_service.dart';
import '../services/routine_ocr_service.dart';
import '../services/voice_input_service.dart';

/// Estado del proceso de importación inteligente
enum SmartImportStatus {
  /// Esperando selección de método (voz/cámara/galería)
  idle,

  /// Procesando entrada (OCR o reconocimiento de voz)
  processing,

  /// Escuchando voz activamente
  listening,

  /// Mostrando resultados para edición
  editing,

  /// Error durante el proceso
  error,
}

/// Estado inmutable del Smart Import
class SmartImportState {
  final SmartImportStatus status;
  final List<DetectedExerciseDraft> drafts;
  final String? errorMessage;
  final String? processingMessage;

  // Estado de voz
  final String partialTranscript;
  final bool isContinuousMode;
  final bool isVoiceAvailable;

  // Historial para undo
  final List<List<DetectedExerciseDraft>> undoStack;

  const SmartImportState({
    this.status = SmartImportStatus.idle,
    this.drafts = const [],
    this.errorMessage,
    this.processingMessage,
    this.partialTranscript = '',
    this.isContinuousMode = false,
    this.isVoiceAvailable = false,
    this.undoStack = const [],
  });

  SmartImportState copyWith({
    SmartImportStatus? status,
    List<DetectedExerciseDraft>? drafts,
    String? errorMessage,
    String? processingMessage,
    String? partialTranscript,
    bool? isContinuousMode,
    bool? isVoiceAvailable,
    List<List<DetectedExerciseDraft>>? undoStack,
  }) {
    return SmartImportState(
      status: status ?? this.status,
      drafts: drafts ?? this.drafts,
      errorMessage: errorMessage,
      processingMessage: processingMessage,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      isContinuousMode: isContinuousMode ?? this.isContinuousMode,
      isVoiceAvailable: isVoiceAvailable ?? this.isVoiceAvailable,
      undoStack: undoStack ?? this.undoStack,
    );
  }

  // Computed
  bool get isProcessing => status == SmartImportStatus.processing;
  bool get isListening => status == SmartImportStatus.listening;
  bool get isEditing => status == SmartImportStatus.editing;
  bool get hasError => status == SmartImportStatus.error;
  bool get hasDrafts => drafts.isNotEmpty;
  bool get canUndo => undoStack.isNotEmpty;

  /// Drafts válidos (con match exitoso)
  List<DetectedExerciseDraft> get validDrafts =>
      drafts.where((d) => d.isValid).toList();

  /// Drafts que necesitan revisión
  List<DetectedExerciseDraft> get draftsNeedingReview =>
      drafts.where((d) => d.needsReview).toList();

  /// Conteo de drafts válidos
  int get validCount => validDrafts.length;

  /// Conteo de drafts que fueron editados
  int get editedCount => drafts.where((d) => d.wasManuallyEdited).length;
}

/// Provider para gestionar el flujo completo de importación inteligente
final smartImportProvider =
    StateNotifierProvider.autoDispose<SmartImportNotifier, SmartImportState>(
  (ref) => SmartImportNotifier(),
);

/// Notifier que maneja toda la lógica de importación inteligente
class SmartImportNotifier extends StateNotifier<SmartImportState> {
  SmartImportNotifier() : super(const SmartImportState()) {
    _init();
  }

  final _ocrService = RoutineOcrService.instance;
  final _voiceService = VoiceInputService.instance;
  final _matchingService = ExerciseMatchingService.instance;

  Future<void> _init() async {
    // Inicializar servicios
    await _matchingService.initialize();
    final voiceAvailable = await _voiceService.initialize();

    state = state.copyWith(
      isVoiceAvailable: voiceAvailable,
    );
  }

  // ============================================
  // CAPTURA: OCR
  // ============================================

  /// Inicia escaneo OCR desde cámara o galería
  Future<void> startOcrImport(ImageSource source) async {
    state = state.copyWith(
      status: SmartImportStatus.processing,
      processingMessage: source == ImageSource.camera
          ? 'Escaneando imagen...'
          : 'Procesando imagen...',
      errorMessage: null,
    );

    try {
      // 1. Escanear imagen
      final lines = await _ocrService.scanImage(source);

      if (lines.isEmpty) {
        state = state.copyWith(
          status: SmartImportStatus.idle,
          processingMessage: null,
        );
        return;
      }

      state = state.copyWith(
        processingMessage: 'Detectando ejercicios...',
      );

      // 2. Parsear líneas
      final candidates = await _ocrService.parseLines(lines);

      // 3. Convertir a drafts
      final drafts = <DetectedExerciseDraft>[];
      for (var i = 0; i < candidates.length; i++) {
        drafts.add(DetectedExerciseDraft.fromOcrCandidate(
          candidates[i],
          orderIndex: i,
        ));
      }

      state = state.copyWith(
        status: drafts.isEmpty ? SmartImportStatus.idle : SmartImportStatus.editing,
        drafts: drafts,
        processingMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: SmartImportStatus.error,
        errorMessage: 'Error procesando imagen: ${e.toString()}',
        processingMessage: null,
      );
    }
  }

  // ============================================
  // CAPTURA: VOZ
  // ============================================

  /// Inicia escucha de voz
  Future<bool> startVoiceListening({bool continuous = false}) async {
    if (!state.isVoiceAvailable) {
      state = state.copyWith(
        status: SmartImportStatus.error,
        errorMessage: 'Reconocimiento de voz no disponible',
      );
      return false;
    }

    state = state.copyWith(
      status: SmartImportStatus.listening,
      isContinuousMode: continuous,
      partialTranscript: '',
      errorMessage: null,
    );

    final success = await _voiceService.startListening(
      onPartialResult: (partial) {
        state = state.copyWith(
          partialTranscript: partial,
        );
      },
      mode: continuous ? VoiceListeningMode.continuous : VoiceListeningMode.single,
    );

    if (!success) {
      state = state.copyWith(
        status: SmartImportStatus.error,
        errorMessage: _voiceService.lastError ?? 'Error al iniciar escucha',
      );
    }

    return success;
  }

  /// Detiene la escucha de voz y procesa el resultado
  Future<List<DetectedExerciseDraft>> stopVoiceListening() async {
    final transcript = await _voiceService.stopListening();

    if (transcript.isEmpty) {
      state = state.copyWith(
        status: state.drafts.isEmpty
            ? SmartImportStatus.idle
            : SmartImportStatus.editing,
        partialTranscript: '',
        isContinuousMode: false,
      );
      return [];
    }

    state = state.copyWith(
      status: SmartImportStatus.processing,
      processingMessage: 'Procesando voz...',
    );

    // Parsear transcripción
    final parsed = await _voiceService.parseTranscript(transcript);

    // Convertir a drafts
    final newDrafts = <DetectedExerciseDraft>[];
    final currentCount = state.drafts.length;

    for (var i = 0; i < parsed.length; i++) {
      newDrafts.add(DetectedExerciseDraft.fromVoiceParsed(
        parsed[i],
        orderIndex: currentCount + i,
      ));
    }

    // Agregar a lista existente
    state = state.copyWith(
      status: SmartImportStatus.editing,
      drafts: [...state.drafts, ...newDrafts],
      partialTranscript: '',
      processingMessage: null,
    );

    return newDrafts;
  }

  /// Cancela la escucha de voz
  Future<void> cancelVoiceListening() async {
    await _voiceService.cancelListening();
    state = state.copyWith(
      status: state.drafts.isEmpty
          ? SmartImportStatus.idle
          : SmartImportStatus.editing,
      partialTranscript: '',
      isContinuousMode: false,
    );
  }

  /// Toggle modo continuo de voz
  void toggleContinuousMode() {
    state = state.copyWith(
      isContinuousMode: !state.isContinuousMode,
    );
  }

  // ============================================
  // EDICIÓN: Operaciones sobre drafts
  // ============================================

  /// Guarda estado actual para undo
  void _saveForUndo() {
    final newStack = [...state.undoStack, List<DetectedExerciseDraft>.from(state.drafts)];
    // Limitar historial a 10 estados
    if (newStack.length > 10) {
      newStack.removeAt(0);
    }
    state = state.copyWith(undoStack: newStack);
  }

  /// Deshace última operación
  void undo() {
    if (!state.canUndo) return;

    final newStack = [...state.undoStack];
    final previousState = newStack.removeLast();

    state = state.copyWith(
      drafts: previousState,
      undoStack: newStack,
    );
  }

  /// Actualiza el ejercicio matcheado de un draft
  Future<void> changeDraftExercise(int index, LibraryExercise newExercise) async {
    if (index < 0 || index >= state.drafts.length) return;

    _saveForUndo();

    final newDrafts = [...state.drafts];
    newDrafts[index] = newDrafts[index].withNewMatch(
      newName: newExercise.name,
      newId: newExercise.id,
    );

    state = state.copyWith(drafts: newDrafts);
  }

  /// Actualiza series de un draft
  void updateDraftSeries(int index, int newSeries) {
    if (index < 0 || index >= state.drafts.length) return;
    if (newSeries <= 0) return;

    _saveForUndo();

    final newDrafts = [...state.drafts];
    newDrafts[index] = newDrafts[index].withSeries(newSeries);

    state = state.copyWith(drafts: newDrafts);
  }

  /// Actualiza reps de un draft
  void updateDraftReps(int index, String newReps) {
    if (index < 0 || index >= state.drafts.length) return;
    if (newReps.isEmpty) return;

    _saveForUndo();

    final newDrafts = [...state.drafts];
    newDrafts[index] = newDrafts[index].withRepsRange(newReps);

    state = state.copyWith(drafts: newDrafts);
  }

  /// Actualiza peso de un draft
  void updateDraftWeight(int index, double? newWeight) {
    if (index < 0 || index >= state.drafts.length) return;

    _saveForUndo();

    final newDrafts = [...state.drafts];
    newDrafts[index] = newDrafts[index].withWeight(newWeight);

    state = state.copyWith(drafts: newDrafts);
  }

  /// Elimina un draft
  void removeDraft(int index) {
    if (index < 0 || index >= state.drafts.length) return;

    _saveForUndo();

    final newDrafts = [...state.drafts]..removeAt(index);
    // Reindexar
    for (var i = 0; i < newDrafts.length; i++) {
      newDrafts[i] = newDrafts[i].withOrderIndex(i);
    }

    state = state.copyWith(
      drafts: newDrafts,
      status: newDrafts.isEmpty ? SmartImportStatus.idle : SmartImportStatus.editing,
    );
  }

  /// Duplica un draft
  void duplicateDraft(int index) {
    if (index < 0 || index >= state.drafts.length) return;

    _saveForUndo();

    final newDrafts = [...state.drafts];
    final toDuplicate = newDrafts[index];
    final duplicate = toDuplicate.duplicate(newOrderIndex: newDrafts.length);

    newDrafts.add(duplicate);

    state = state.copyWith(drafts: newDrafts);
  }

  /// Reordena drafts (drag & drop)
  void reorderDrafts(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= state.drafts.length) return;
    if (newIndex < 0 || newIndex > state.drafts.length) return;

    _saveForUndo();

    final newDrafts = [...state.drafts];
    final item = newDrafts.removeAt(oldIndex);

    // Ajustar índice si se mueve hacia abajo
    final adjustedIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    newDrafts.insert(adjustedIndex, item);

    // Reindexar todos
    for (var i = 0; i < newDrafts.length; i++) {
      newDrafts[i] = newDrafts[i].withOrderIndex(i);
    }

    state = state.copyWith(drafts: newDrafts);
  }

  /// Marca un draft como verificado
  void verifyDraft(int index) {
    if (index < 0 || index >= state.drafts.length) return;

    _saveForUndo();

    final newDrafts = [...state.drafts];
    newDrafts[index] = newDrafts[index].markAsVerified();

    state = state.copyWith(drafts: newDrafts);
  }

  /// Resetea un draft a sus valores originales
  void resetDraft(int index) {
    if (index < 0 || index >= state.drafts.length) return;

    _saveForUndo();

    final newDrafts = [...state.drafts];
    newDrafts[index] = newDrafts[index].resetToOriginal();

    state = state.copyWith(drafts: newDrafts);
  }

  // ============================================
  // BÚSQUEDA DE ALTERNATIVAS
  // ============================================

  /// Busca ejercicios alternativos para un draft
  Future<List<LibraryExercise>> searchAlternatives(String query) async {
    if (query.length < 2) return [];
    return _voiceService.searchExercises(query, limit: 10);
  }

  /// Busca ejercicio por ID
  Future<LibraryExercise?> getExerciseById(int id) async {
    return _matchingService.getById(id);
  }

  // ============================================
  // FINALIZACIÓN
  // ============================================

  /// Obtiene los drafts válidos listos para importar
  List<DetectedExerciseDraft> getValidDraftsForImport() {
    return state.validDrafts;
  }

  /// Limpia todo el estado
  void clear() {
    _voiceService.clearExerciseHistory();
    state = const SmartImportState();
    _init(); // Re-inicializar
  }

  /// Vuelve al estado idle manteniendo drafts
  void backToIdle() {
    state = state.copyWith(
      status: state.drafts.isEmpty
          ? SmartImportStatus.idle
          : SmartImportStatus.editing,
      errorMessage: null,
      processingMessage: null,
    );
  }
}

/// Provider de solo lectura para ejercicios válidos
final validDraftsProvider = Provider<List<DetectedExerciseDraft>>((ref) {
  return ref.watch(smartImportProvider).validDrafts;
});

/// Provider de solo lectura para conteo
final validDraftsCountProvider = Provider<int>((ref) {
  return ref.watch(smartImportProvider).validCount;
});
