import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/library_exercise.dart';
import '../../providers/voice_input_provider.dart';
import '../../services/voice_input_service.dart';
import '../../utils/design_system.dart';
import 'voice_mic_button.dart';

/// Sheet modal para dictado de ejercicios por voz
/// 
/// Flujo:
/// 1. Usuario pulsa mic → empieza a escuchar
/// 2. Transcripción en tiempo real (gris clarito)
/// 3. Al soltar o pausar → procesa y muestra ejercicios detectados
/// 4. Preview editable de ejercicios
/// 5. Confirmar para añadir a rutina
class VoiceInputSheet extends ConsumerStatefulWidget {
  final Function(List<VoiceParsedExercise>) onConfirm;
  final VoidCallback? onCancel;

  const VoiceInputSheet({
    super.key,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  ConsumerState<VoiceInputSheet> createState() => _VoiceInputSheetState();

  /// Muestra el sheet modal de input de voz
  static Future<void> show(
    BuildContext context, {
    required Function(List<VoiceParsedExercise>) onConfirm,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VoiceInputSheet(
        onConfirm: onConfirm,
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

class _VoiceInputSheetState extends ConsumerState<VoiceInputSheet> {
  // Controllers para edición manual de series/reps
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

  Future<void> _onMicTap() async {
    final notifier = ref.read(voiceInputProvider.notifier);
    final state = ref.read(voiceInputProvider);

    // Limpiar estado "no entendido" si existe
    if (state.notUnderstood) {
      notifier.clearNotUnderstood();
    }

    if (state.isListening) {
      // Parar y procesar - PUSH TO TALK
      await notifier.stopListening();
    } else {
      // Empezar a escuchar - PUSH TO TALK (siempre modo single)
      await notifier.startListening();
    }
  }

  void _onConfirm() {
    final state = ref.read(voiceInputProvider);
    final validExercises = state.validExercises;

    if (validExercises.isEmpty) {
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

    widget.onConfirm(validExercises);
    Navigator.of(context).pop();
  }

  void _onRemoveExercise(int index) {
    ref.read(voiceInputProvider.notifier).removeParsedExercise(index);
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  Future<void> _onChangeExercise(int index, VoiceParsedExercise exercise) async {
    // Mostrar búsqueda de alternativas
    final alternatives = await ref
        .read(voiceInputProvider.notifier)
        .searchAlternatives(exercise.rawText);

    if (!mounted) return;

    final selected = await showModalBottomSheet<LibraryExercise>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AlternativeExerciseSheet(
        query: exercise.rawText,
        alternatives: alternatives,
        onSearch: (q) => ref.read(voiceInputProvider.notifier).searchAlternatives(q),
      ),
    );

    if (selected != null) {
      ref.read(voiceInputProvider.notifier).rematchExercise(index, selected);
    }
  }

  void _updateExerciseSeries(int index, String value) {
    final series = int.tryParse(value);
    if (series == null || series <= 0) return;

    final state = ref.read(voiceInputProvider);
    if (index >= state.parsedExercises.length) return;

    final updated = state.parsedExercises[index].copyWith(series: series);
    ref.read(voiceInputProvider.notifier).updateParsedExercise(index, updated);
  }

  void _updateExerciseReps(int index, String value) {
    if (value.isEmpty) return;

    final state = ref.read(voiceInputProvider);
    if (index >= state.parsedExercises.length) return;

    final updated = state.parsedExercises[index].copyWith(repsRange: value);
    ref.read(voiceInputProvider.notifier).updateParsedExercise(index, updated);
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceInputProvider);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
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
            const SizedBox(height: 16),

            // Título
            Text(
              'DICTADO POR VOZ',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),

            // Banner de capacidades - SIEMPRE VISIBLE
            const _VoiceCapabilitiesBanner(),
            const SizedBox(height: 16),

            // Botón de micrófono - PUSH TO TALK
            VoiceMicButton(
              onTap: _onMicTap,
              size: 80,
            ),

            // Indicador de estado bajo el botón
            const SizedBox(height: 12),
            _buildStatusIndicator(voiceState),
            const SizedBox(height: 16),

            // Preview de transcripción
            const VoiceTranscriptPreview(
              
            ),
            const SizedBox(height: 16),

            // Estado de error técnico
            if (voiceState.hasError) ...[
              _buildErrorState(voiceState.errorMessage ?? 'Error desconocido'),
              const SizedBox(height: 16),
            ],

            // Estado "No entendido" - feedback claro
            if (voiceState.notUnderstood) ...[
              _buildNotUnderstoodState(voiceState.notUnderstoodMessage ?? 'No entendido'),
              const SizedBox(height: 16),
            ],

            // Procesando
            if (voiceState.isProcessing) ...[
              const LinearProgressIndicator(
                backgroundColor: Colors.grey,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
              const SizedBox(height: 8),
              Text(
                'Procesando...',
                style: GoogleFonts.montserrat(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Lista de ejercicios parseados
            if (voiceState.hasResults) ...[
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: voiceState.parsedExercises.length,
                  itemBuilder: (ctx, index) {
                    final exercise = voiceState.parsedExercises[index];
                    return _ParsedExerciseCard(
                      exercise: exercise,
                      index: index,
                      seriesController: _getSeriesController(index, exercise.series),
                      repsController: _getRepsController(index, exercise.repsRange),
                      onSeriesChanged: (v) => _updateExerciseSeries(index, v),
                      onRepsChanged: (v) => _updateExerciseReps(index, v),
                      onRemove: () => _onRemoveExercise(index),
                      onChangeExercise: () => _onChangeExercise(index, exercise),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ref.read(voiceInputProvider.notifier).clearResults();
                        widget.onCancel?.call();
                      },
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
                      onPressed: voiceState.validExercises.isNotEmpty ? _onConfirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.bgDeep,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'AÑADIR ${voiceState.validExercises.length} EJERCICIO${voiceState.validExercises.length == 1 ? '' : 'S'}',
                        style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Sugerencias cuando no hay resultados
            if (!voiceState.hasResults && !voiceState.isListening && !voiceState.isProcessing) ...[
              const SizedBox(height: 16),
              _buildSuggestions(),
            ],
          ],
        ),
      ),
    );
  }
  
  /// Indicador de estado actual de la voz
  Widget _buildStatusIndicator(VoiceInputState voiceState) {
    if (voiceState.isListening) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _PulsingDot(color: Colors.red),
          const SizedBox(width: 8),
          Text(
            'ESCUCHANDO...',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.neonPrimary,
            ),
          ),
        ],
      );
    }

    if (voiceState.isProcessing) {
      return Text(
        'Procesando...',
        style: GoogleFonts.montserrat(
          fontSize: 14,
          color: Colors.white54,
        ),
      );
    }

    // Estado idle - instrucciones
    return Text(
      'Mantén pulsado para hablar',
      style: GoogleFonts.montserrat(
        fontSize: 13,
        color: Colors.white38,
      ),
    );
  }

  /// Estado de error técnico
  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.live.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.neonPrimary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.montserrat(
                color: AppColors.neonPrimary,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: () => ref.read(voiceInputProvider.notifier).retry(),
            child: Text(
              'REINTENTAR',
              style: GoogleFonts.montserrat(
                color: AppColors.neonPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Estado "No entendido" - feedback claro y accionable
  Widget _buildNotUnderstoodState(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'NO ENTENDIDO',
                style: GoogleFonts.montserrat(
                  color: Colors.orange,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.montserrat(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(voiceInputProvider.notifier).clearNotUnderstood();
                    _onMicTap();
                  },
                  icon: const Icon(Icons.mic, size: 18),
                  label: const Text('REINTENTAR'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ejemplos de comandos:',
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          _buildSuggestionChip('Añade sentadilla 5x5'),
          _buildSuggestionChip('Press banca 4 series de 8 a 12 reps'),
          _buildSuggestionChip('Curl de bíceps 3x12 a 15 kilos'),
          _buildSuggestionChip('Luego peso muerto rumano 4x10'),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.format_quote, size: 16, color: AppColors.neonPrimary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '"$text"',
              style: GoogleFonts.montserrat(
                color: Colors.white54,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card para mostrar un ejercicio parseado con opciones de edición
class _ParsedExerciseCard extends StatelessWidget {
  final VoiceParsedExercise exercise;
  final int index;
  final TextEditingController seriesController;
  final TextEditingController repsController;
  final Function(String) onSeriesChanged;
  final Function(String) onRepsChanged;
  final VoidCallback onRemove;
  final VoidCallback onChangeExercise;

  const _ParsedExerciseCard({
    required this.exercise,
    required this.index,
    required this.seriesController,
    required this.repsController,
    required this.onSeriesChanged,
    required this.onRepsChanged,
    required this.onRemove,
    required this.onChangeExercise,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = exercise.isValid;
    final confidenceColor = _getConfidenceColor(exercise.confidence);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid ? AppColors.bgElevated : AppColors.live.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? AppColors.border : AppColors.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con nombre y confianza
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isValid)
                      Text(
                        exercise.matchedName!,
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      )
                    else
                      Text(
                        'No encontrado',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonPrimary,
                          fontSize: 15,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '"${exercise.rawText}"',
                      style: GoogleFonts.montserrat(
                        color: Colors.white38,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Indicador de confianza
              if (isValid) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: confidenceColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(exercise.confidence * 100).toInt()}%',
                    style: GoogleFonts.montserrat(
                      color: confidenceColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              // Botón cambiar ejercicio
              IconButton(
                onPressed: onChangeExercise,
                icon: const Icon(
                  Icons.swap_horiz,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                tooltip: 'Cambiar ejercicio',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              // Botón eliminar
              IconButton(
                onPressed: onRemove,
                icon: const Icon(
                  Icons.close,
                  color: AppColors.neonPrimary,
                  size: 20,
                ),
                tooltip: 'Eliminar',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Campos de series y reps
          Row(
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
              const SizedBox(width: 12),
              // Reps
              Expanded(
                child: _CompactField(
                  label: 'Reps',
                  controller: repsController,
                  onChanged: onRepsChanged,
                  keyboardType: TextInputType.text, // Para soportar "8-12"
                ),
              ),
              // Peso (si existe)
              if (exercise.weight != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgDeep,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${exercise.weight!.toStringAsFixed(1)} kg',
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // Superserie indicator
          if (exercise.isSuperset) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.goldAccent.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.goldAccent.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link, size: 14, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Superserie',
                    style: GoogleFonts.montserrat(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Notas
          if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Nota: ${exercise.notes}',
              style: GoogleFonts.montserrat(
                color: Colors.white38,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return AppColors.neonCyan;
    if (confidence >= 0.6) return Colors.yellow[600]!;
    return AppColors.warning;
  }
}

/// Campo compacto para edición inline
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
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          textAlign: TextAlign.center,
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.bgDeep,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sheet para buscar ejercicio alternativo
class _AlternativeExerciseSheet extends StatefulWidget {
  final String query;
  final List<LibraryExercise> alternatives;
  final Future<List<LibraryExercise>> Function(String) onSearch;

  const _AlternativeExerciseSheet({
    required this.query,
    required this.alternatives,
    required this.onSearch,
  });

  @override
  State<_AlternativeExerciseSheet> createState() => _AlternativeExerciseSheetState();
}

class _AlternativeExerciseSheetState extends State<_AlternativeExerciseSheet> {
  late TextEditingController _searchController;
  List<LibraryExercise> _results = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
    _results = widget.alternatives;
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
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Seleccionar ejercicio',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: _search,
            autofocus: true,
            style: GoogleFonts.montserrat(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar ejercicio...',
              hintStyle: GoogleFonts.montserrat(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: AppColors.bgDeep,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isSearching)
            const Center(child: CircularProgressIndicator())
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (ctx, index) {
                  final exercise = _results[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.live,
                      child: Text(
                        exercise.name[0].toUpperCase(),
                        style: GoogleFonts.montserrat(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      exercise.name,
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      exercise.muscleGroup,
                      style: GoogleFonts.montserrat(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
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
  }
}

/// Banner informativo sobre capacidades de voz
/// Siempre visible para que el usuario sepa qué puede dictar
class _VoiceCapabilitiesBanner extends StatelessWidget {
  const _VoiceCapabilitiesBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neonCyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.neonCyan.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Text(
                'La voz captura:',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neonCyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _CapabilityChip(label: 'Ejercicio', icon: Icons.fitness_center),
              _CapabilityChip(label: 'Series', icon: Icons.repeat),
              _CapabilityChip(label: 'Reps', icon: Icons.tag),
              _CapabilityChip(label: 'Peso', icon: Icons.scale),
              _CapabilityChip(label: 'Notas', icon: Icons.note),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Detalles avanzados se ajustan después.',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: Colors.white38,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip pequeño para mostrar una capacidad
class _CapabilityChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _CapabilityChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white54),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

/// Punto pulsante para indicadores de estado
class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const _PulsingDot({
    required this.color,
    this.size = 12.0,
  });

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
