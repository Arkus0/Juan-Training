import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/detected_exercise_draft.dart';
import '../models/library_exercise.dart';
import '../providers/smart_import_provider.dart';
import '../utils/design_system.dart';
import 'voice/voice_mic_button.dart';

/// Sheet unificado para importación inteligente (Voz + OCR) - V2
///
/// Mejoras sobre V1:
/// - Edición de nombre del ejercicio (no solo series/reps)
/// - Reordenación con drag & drop
/// - Duplicación de ejercicios
/// - Visualización de confianza con estado de edición
/// - Undo para deshacer cambios
/// - Flujo unificado para OCR y Voz
class SmartImportSheetV2 extends ConsumerStatefulWidget {
  final Function(List<DetectedExerciseDraft>) onConfirm;
  final VoidCallback? onCancel;

  const SmartImportSheetV2({
    super.key,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  ConsumerState<SmartImportSheetV2> createState() => _SmartImportSheetV2State();

  /// Muestra el sheet modal de import inteligente
  static Future<void> show(
    BuildContext context, {
    required Function(List<DetectedExerciseDraft>) onConfirm,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SmartImportSheetV2(
        onConfirm: onConfirm,
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

class _SmartImportSheetV2State extends ConsumerState<SmartImportSheetV2> {
  // Controllers para edición inline
  final Map<int, TextEditingController> _seriesControllers = {};
  final Map<int, TextEditingController> _repsControllers = {};

  @override
  void dispose() {
    for (final c in _seriesControllers.values) {
      c.dispose();
    }
    for (final c in _repsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _getSeriesController(int index, int initialValue) {
    return _seriesControllers.putIfAbsent(
      index,
      () => TextEditingController(text: initialValue.toString()),
    );
  }

  TextEditingController _getRepsController(int index, String initialValue) {
    return _repsControllers.putIfAbsent(
      index,
      () => TextEditingController(text: initialValue),
    );
  }

  void _onConfirm() {
    final notifier = ref.read(smartImportProvider.notifier);
    final validDrafts = notifier.getValidDraftsForImport();

    if (validDrafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay ejercicios válidos para añadir',
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    widget.onConfirm(validDrafts);
    notifier.clear();
    Navigator.of(context).pop();
  }

  void _onCancel() {
    ref.read(smartImportProvider.notifier).clear();
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(smartImportProvider);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header con título y acciones
            _buildHeader(state),
            const SizedBox(height: 16),

            // Contenido según estado
            Flexible(
              child: _buildContent(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(SmartImportState state) {
    final notifier = ref.read(smartImportProvider.notifier);
    final showBackButton =
        state.isEditing || state.isListening || state.isProcessing;

    return Row(
      children: [
        // Botón atrás
        if (showBackButton) ...[
          IconButton(
            onPressed: () {
              if (state.isListening) {
                notifier.cancelVoiceListening();
              } else {
                notifier.backToIdle();
              }
            },
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
        ],

        // Título
        Expanded(
          child: Column(
            crossAxisAlignment: showBackButton
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Text(
                _getTitle(state),
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              if (state.isEditing && state.drafts.isNotEmpty)
                Text(
                  '${state.validCount} válidos, ${state.editedCount} editados',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
            ],
          ),
        ),

        // Acciones
        if (state.isEditing) ...[
          // Undo
          if (state.canUndo)
            IconButton(
              onPressed: notifier.undo,
              icon: const Icon(Icons.undo, color: Colors.white54, size: 22),
              tooltip: 'Deshacer',
            ),
        ],
      ],
    );
  }

  String _getTitle(SmartImportState state) {
    switch (state.status) {
      case SmartImportStatus.idle:
        return 'IMPORT SMART';
      case SmartImportStatus.processing:
        return 'PROCESANDO...';
      case SmartImportStatus.listening:
        return 'ESCUCHANDO';
      case SmartImportStatus.editing:
        return 'REVISAR EJERCICIOS';
      case SmartImportStatus.error:
        return 'ERROR';
    }
  }

  Widget _buildContent(SmartImportState state) {
    switch (state.status) {
      case SmartImportStatus.idle:
        return _buildSelectionView();
      case SmartImportStatus.processing:
        return _buildProcessingView(state);
      case SmartImportStatus.listening:
        return _buildVoiceListeningView(state);
      case SmartImportStatus.editing:
        return _buildEditingView(state);
      case SmartImportStatus.error:
        return _buildErrorView(state);
    }
  }

  // ============================================
  // VISTA DE SELECCIÓN INICIAL
  // ============================================

  Widget _buildSelectionView() {
    final notifier = ref.read(smartImportProvider.notifier);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono central
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.live.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 44,
              color: AppColors.neonPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Elige cómo añadir ejercicios',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 24),

          // Opciones
          _ImportOptionCard(
            icon: Icons.mic,
            title: 'Dictar por Voz',
            subtitle: '"Press banca 4x10, luego sentadilla 5x5"',
            color: Colors.blue,
            onTap: () => notifier.startVoiceListening(),
          ),
          const SizedBox(height: 10),
          _ImportOptionCard(
            icon: Icons.camera_alt,
            title: 'Escanear con Cámara',
            subtitle: 'Toma foto de una rutina escrita',
            color: Colors.green,
            onTap: () => notifier.startOcrImport(ImageSource.camera),
          ),
          const SizedBox(height: 10),
          _ImportOptionCard(
            icon: Icons.photo_library,
            title: 'Importar de Galería',
            subtitle: 'Selecciona imagen con ejercicios',
            color: Colors.orange,
            onTap: () => notifier.startOcrImport(ImageSource.gallery),
          ),
        ],
      ),
    );
  }

  // ============================================
  // VISTA DE PROCESAMIENTO
  // ============================================

  Widget _buildProcessingView(SmartImportState state) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.neonPrimary),
        ),
        const SizedBox(height: 24),
        Text(
          state.processingMessage ?? 'Procesando...',
          style: GoogleFonts.montserrat(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ============================================
  // VISTA DE ESCUCHA DE VOZ
  // ============================================

  Widget _buildVoiceListeningView(SmartImportState state) {
    final notifier = ref.read(smartImportProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Modo continuo toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ModeToggleChip(
              icon: Icons.all_inclusive,
              label: 'Continuo',
              isActive: state.isContinuousMode,
              onTap: notifier.toggleContinuousMode,
              activeColor: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Botón de micrófono
        VoiceMicButton(
          onTap: () async {
            await notifier.stopVoiceListening();
          },
          size: 80,
        ),
        const SizedBox(height: 16),

        // Transcripción parcial
        if (state.partialTranscript.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.bgDeep,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.format_quote, color: Colors.white38, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.partialTranscript,
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Drafts acumulados
        if (state.drafts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.neonCyanSubtle.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${state.validCount} ejercicios detectados',
              style: GoogleFonts.montserrat(
                color: AppColors.neonCyan,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Sugerencias
        _buildVoiceSuggestions(),
      ],
    );
  }

  Widget _buildVoiceSuggestions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  size: 16, color: AppColors.warning,),
              const SizedBox(width: 6),
              Text(
                'Ejemplos:',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSuggestionChip('Press banca 4x10'),
          _buildSuggestionChip('Sentadilla 5 series de 5'),
          _buildSuggestionChip('Curl bíceps 3x12 a 15 kilos'),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '"$text"',
        style: GoogleFonts.montserrat(
          color: Colors.white38,
          fontSize: 11,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  // ============================================
  // VISTA DE EDICIÓN
  // ============================================

  Widget _buildEditingView(SmartImportState state) {
    final notifier = ref.read(smartImportProvider.notifier);

    return Column(
      children: [
        // Info bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgDeep,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                state.validCount == state.drafts.length
                    ? Icons.check_circle
                    : Icons.info_outline,
                size: 18,
                color: state.validCount == state.drafts.length
                    ? AppColors.neonCyan
                    : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.validCount == state.drafts.length
                      ? 'Todos los ejercicios tienen match'
                      : '${state.drafts.length - state.validCount} sin match - toca para corregir',
                  style: GoogleFonts.montserrat(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
              // Botón agregar más
              TextButton.icon(
                onPressed: () => notifier.startVoiceListening(),
                icon: const Icon(Icons.add, size: 16),
                label: Text(
                  'MÁS',
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold, fontSize: 11,),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.neonCyan,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Lista de ejercicios (reordenable)
        Expanded(
          child: ReorderableListView.builder(
            shrinkWrap: true,
            itemCount: state.drafts.length,
            onReorder: notifier.reorderDrafts,
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                elevation: 4,
                shadowColor: AppColors.neonPrimary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                child: child,
              );
            },
            itemBuilder: (ctx, index) {
              final draft = state.drafts[index];
              return _DraftExerciseCard(
                key: ValueKey(
                    'draft_${draft.orderIndex}_${draft.originalRawText}',),
                draft: draft,
                index: index,
                seriesController: _getSeriesController(index, draft.series),
                repsController: _getRepsController(index, draft.repsRange),
                onSeriesChanged: (v) {
                  final series = int.tryParse(v);
                  if (series != null && series > 0) {
                    notifier.updateDraftSeries(index, series);
                  }
                },
                onRepsChanged: (v) {
                  if (v.isNotEmpty) {
                    notifier.updateDraftReps(index, v);
                  }
                },
                onRemove: () => notifier.removeDraft(index),
                onDuplicate: () => notifier.duplicateDraft(index),
                onChangeExercise: () => _showExerciseSearchSheet(index, draft),
                onVerify: () => notifier.verifyDraft(index),
                onReset: draft.wasManuallyEdited
                    ? () => notifier.resetDraft(index)
                    : null,
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // Botones de acción
        _buildActionButtons(state),
      ],
    );
  }

  Widget _buildActionButtons(SmartImportState state) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white30),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: state.validCount > 0 ? _onConfirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.bgDeep,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'AÑADIR ${state.validCount} EJERCICIO${state.validCount == 1 ? '' : 'S'}',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================
  // VISTA DE ERROR
  // ============================================

  Widget _buildErrorView(SmartImportState state) {
    final notifier = ref.read(smartImportProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
        const SizedBox(height: 16),
        Text(
          state.errorMessage ?? 'Error desconocido',
          style: GoogleFonts.montserrat(
            color: Colors.white70,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: notifier.backToIdle,
          icon: const Icon(Icons.refresh),
          label: const Text('REINTENTAR'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white30),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  // ============================================
  // SHEET DE BÚSQUEDA DE EJERCICIOS
  // ============================================

  Future<void> _showExerciseSearchSheet(
      int index, DetectedExerciseDraft draft,) async {
    final notifier = ref.read(smartImportProvider.notifier);

    // Buscar alternativas iniciales
    final initialResults = await notifier.searchAlternatives(
      draft.currentMatchedName ?? draft.originalRawText,
    );

    if (!mounted) return;

    final selected = await showModalBottomSheet<LibraryExercise>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ExerciseSearchSheet(
        initialQuery: draft.currentMatchedName ?? draft.originalRawText,
        initialResults: initialResults,
        onSearch: notifier.searchAlternatives,
      ),
    );

    if (selected != null) {
      notifier.changeDraftExercise(index, selected);
      // Limpiar controller de este índice para que se actualice
      _seriesControllers.remove(index);
      _repsControllers.remove(index);
    }
  }
}

// ============================================
// WIDGETS AUXILIARES
// ============================================

/// Card de opción de importación
class _ImportOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ImportOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card para un ejercicio draft con todas las opciones de edición
class _DraftExerciseCard extends StatelessWidget {
  final DetectedExerciseDraft draft;
  final int index;
  final TextEditingController seriesController;
  final TextEditingController repsController;
  final Function(String) onSeriesChanged;
  final Function(String) onRepsChanged;
  final VoidCallback onRemove;
  final VoidCallback onDuplicate;
  final VoidCallback onChangeExercise;
  final VoidCallback onVerify;
  final VoidCallback? onReset;

  const _DraftExerciseCard({
    super.key,
    required this.draft,
    required this.index,
    required this.seriesController,
    required this.repsController,
    required this.onSeriesChanged,
    required this.onRepsChanged,
    required this.onRemove,
    required this.onDuplicate,
    required this.onChangeExercise,
    required this.onVerify,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = draft.isValid;
    final sourceIcon = draft.source == DetectionSource.voice
        ? Icons.mic
        : Icons.document_scanner;
    final sourceColor =
        draft.source == DetectionSource.voice ? Colors.blue : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:
            isValid ? AppColors.bgDeep : AppColors.live.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid
              ? (draft.wasManuallyEdited
                  ? AppColors.neonCyan.withValues(alpha: 0.5)
                  : AppColors.border)
              : AppColors.error.withValues(alpha: 0.7),
          width: draft.wasManuallyEdited ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con nombre y confianza
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
            child: Row(
              children: [
                // Handle de reordenación
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_handle,
                    color: Colors.white30,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),

                // Indicador de fuente
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: sourceColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(sourceIcon, size: 12, color: sourceColor),
                ),
                const SizedBox(width: 8),

                // Nombre del ejercicio (tappable para cambiar)
                Expanded(
                  child: GestureDetector(
                    onTap: onChangeExercise,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                draft.currentMatchedName ?? 'Sin match',
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.bold,
                                  color: isValid
                                      ? Colors.white
                                      : AppColors.neonPrimary,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.edit,
                              size: 12,
                              color: Colors.white38,
                            ),
                          ],
                        ),
                        Text(
                          '"${draft.originalRawText}"',
                          style: GoogleFonts.montserrat(
                            color: Colors.white30,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),

                // Badge de confianza/estado
                _ConfidenceBadge(draft: draft, onVerify: onVerify),
                const SizedBox(width: 4),

                // Menú de acciones
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'duplicate':
                        onDuplicate();
                        break;
                      case 'reset':
                        onReset?.call();
                        break;
                      case 'remove':
                        onRemove();
                        break;
                    }
                  },
                  icon: const Icon(Icons.more_vert,
                      color: Colors.white54, size: 20,),
                  color: AppColors.bgElevated,
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          const Icon(Icons.copy,
                              size: 18, color: Colors.white70,),
                          const SizedBox(width: 8),
                          Text('Duplicar',
                              style:
                                  GoogleFonts.montserrat(color: Colors.white),),
                        ],
                      ),
                    ),
                    if (draft.wasManuallyEdited)
                      PopupMenuItem(
                        value: 'reset',
                        child: Row(
                          children: [
                            const Icon(Icons.restore,
                                size: 18, color: Colors.white70,),
                            const SizedBox(width: 8),
                            Text('Restaurar original',
                                style: GoogleFonts.montserrat(
                                    color: Colors.white,),),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline,
                              size: 18, color: AppColors.error,),
                          const SizedBox(width: 8),
                          Text('Eliminar',
                              style: GoogleFonts.montserrat(
                                  color: AppColors.error,),),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Campos de edición
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                // Series
                Expanded(
                  child: _CompactField(
                    label: 'Series',
                    controller: seriesController,
                    onChanged: onSeriesChanged,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                // Reps
                Expanded(
                  child: _CompactField(
                    label: 'Reps',
                    controller: repsController,
                    onChanged: onRepsChanged,
                    keyboardType: TextInputType.text,
                  ),
                ),
                // Peso (si existe)
                if (draft.weight != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Peso',
                          style: GoogleFonts.montserrat(
                            color: Colors.white38,
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          '${draft.weight!.toStringAsFixed(0)}kg',
                          style: GoogleFonts.montserrat(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge de confianza con indicador visual
class _ConfidenceBadge extends StatelessWidget {
  final DetectedExerciseDraft draft;
  final VoidCallback onVerify;

  const _ConfidenceBadge({
    required this.draft,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final colorHint = draft.confidenceColorHint;
    final Color bgColor;
    final Color textColor;
    final IconData? icon;

    switch (colorHint) {
      case 'verified':
        bgColor = AppColors.neonCyan.withValues(alpha: 0.2);
        textColor = AppColors.neonCyan;
        icon = Icons.check;
        break;
      case 'edited':
        bgColor = Colors.blue.withValues(alpha: 0.2);
        textColor = Colors.blue;
        icon = Icons.edit;
        break;
      case 'high':
        bgColor = Colors.green.withValues(alpha: 0.2);
        textColor = Colors.green;
        icon = null;
        break;
      case 'medium':
        bgColor = Colors.yellow.withValues(alpha: 0.2);
        textColor = Colors.yellow.shade700;
        icon = null;
        break;
      default:
        bgColor = Colors.orange.withValues(alpha: 0.2);
        textColor = Colors.orange;
        icon = Icons.warning_amber;
    }

    return GestureDetector(
      onTap: draft.isVerified ? null : onVerify,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: textColor),
              const SizedBox(width: 2),
            ],
            Text(
              draft.confidenceLabel,
              style: GoogleFonts.montserrat(
                color: textColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo compacto de edición
class _CompactField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Function(String) onChanged;
  final TextInputType keyboardType;

  const _CompactField({
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.montserrat(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Toggle chip para modos
class _ModeToggleChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;

  const _ModeToggleChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isActive ? activeColor.withValues(alpha: 0.2) : AppColors.bgDeep,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.6)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isActive ? activeColor : AppColors.textTertiary,),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? activeColor : AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet de búsqueda de ejercicios
class _ExerciseSearchSheet extends StatefulWidget {
  final String initialQuery;
  final List<LibraryExercise> initialResults;
  final Future<List<LibraryExercise>> Function(String) onSearch;

  const _ExerciseSearchSheet({
    required this.initialQuery,
    required this.initialResults,
    required this.onSearch,
  });

  @override
  State<_ExerciseSearchSheet> createState() => _ExerciseSearchSheetState();
}

class _ExerciseSearchSheetState extends State<_ExerciseSearchSheet> {
  late TextEditingController _searchController;
  List<LibraryExercise> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _results = widget.initialResults;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) return;

    setState(() => _isSearching = true);
    final results = await widget.onSearch(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Seleccionar ejercicio',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),

              // Barra de búsqueda
              TextField(
                controller: _searchController,
                onChanged: _search,
                autofocus: true,
                style: GoogleFonts.montserrat(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar ejercicio...',
                  hintStyle: GoogleFonts.montserrat(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                  suffixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.bgDeep,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Resultados
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          'No se encontraron ejercicios',
                          style: GoogleFonts.montserrat(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _results.length,
                        itemBuilder: (ctx, index) {
                          final exercise = _results[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.live,
                              radius: 18,
                              child: Text(
                                exercise.name[0].toUpperCase(),
                                style: GoogleFonts.montserrat(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            title: Text(
                              exercise.name,
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              exercise.muscleGroup,
                              style: GoogleFonts.montserrat(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white38,
                            ),
                            onTap: () {
                              try {
                                HapticFeedback.selectionClick();
                              } catch (_) {}
                              Navigator.of(context).pop(exercise);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
