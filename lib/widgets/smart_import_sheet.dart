import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/routine_ocr_service.dart';
import '../services/voice_input_service.dart';
import '../providers/voice_input_provider.dart';
import 'voice/voice_mic_button.dart';

/// Tipo de import seleccionado
enum SmartImportMode {
  selection, // Pantalla de selección inicial
  voice,     // Dictado por voz
  camera,    // OCR desde cámara
  gallery,   // OCR desde galería
}

/// Modelo unificado para ejercicios importados (de voz u OCR)
class SmartImportedExercise {
  final String rawText;
  final String? matchedName;
  final int? matchedId;
  final int series;
  final String repsRange;
  final double? weight;
  final double confidence;
  final SmartImportSource source;

  const SmartImportedExercise({
    required this.rawText,
    this.matchedName,
    this.matchedId,
    this.series = 3,
    this.repsRange = '10',
    this.weight,
    this.confidence = 0.0,
    required this.source,
  });

  bool get isValid => matchedName != null && matchedId != null;

  /// Convierte desde VoiceParsedExercise
  factory SmartImportedExercise.fromVoice(VoiceParsedExercise voice) {
    return SmartImportedExercise(
      rawText: voice.rawText,
      matchedName: voice.matchedName,
      matchedId: voice.matchedId,
      series: voice.series,
      repsRange: voice.repsRange,
      weight: voice.weight,
      confidence: voice.confidence,
      source: SmartImportSource.voice,
    );
  }

  /// Convierte desde ParsedExerciseCandidate (OCR)
  factory SmartImportedExercise.fromOcr(ParsedExerciseCandidate ocr) {
    return SmartImportedExercise(
      rawText: ocr.rawText,
      matchedName: ocr.matchedExerciseName,
      matchedId: ocr.matchedExerciseId,
      series: ocr.series,
      repsRange: ocr.reps.toString(),
      weight: ocr.weight,
      confidence: ocr.confidence,
      source: SmartImportSource.ocr,
    );
  }

  SmartImportedExercise copyWith({
    String? rawText,
    String? matchedName,
    int? matchedId,
    int? series,
    String? repsRange,
    double? weight,
    double? confidence,
    SmartImportSource? source,
  }) {
    return SmartImportedExercise(
      rawText: rawText ?? this.rawText,
      matchedName: matchedName ?? this.matchedName,
      matchedId: matchedId ?? this.matchedId,
      series: series ?? this.series,
      repsRange: repsRange ?? this.repsRange,
      weight: weight ?? this.weight,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
    );
  }
}

enum SmartImportSource { voice, ocr }

/// Sheet unificado para importación inteligente (Voz + OCR)
/// 
/// Flujo:
/// 1. Usuario elige método: Voz, Cámara, o Galería
/// 2. Se captura el input según el método
/// 3. Preview unificado de ejercicios detectados
/// 4. Confirmar para añadir a rutina
class SmartImportSheet extends ConsumerStatefulWidget {
  final Function(List<SmartImportedExercise>) onConfirm;
  final VoidCallback? onCancel;

  const SmartImportSheet({
    super.key,
    required this.onConfirm,
    this.onCancel,
  });

  @override
  ConsumerState<SmartImportSheet> createState() => _SmartImportSheetState();

  /// Muestra el sheet modal de import inteligente
  static Future<void> show(
    BuildContext context, {
    required Function(List<SmartImportedExercise>) onConfirm,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => SmartImportSheet(
        onConfirm: onConfirm,
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

class _SmartImportSheetState extends ConsumerState<SmartImportSheet> {
  SmartImportMode _mode = SmartImportMode.selection;
  List<SmartImportedExercise> _importedExercises = [];
  bool _isProcessing = false;
  String? _errorMessage;

  // Controllers para edición
  final Map<int, TextEditingController> _seriesControllers = {};
  final Map<int, TextEditingController> _repsControllers = {};

  final _ocrService = RoutineOcrService.instance;

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

  Future<void> _startVoiceImport() async {
    setState(() {
      _mode = SmartImportMode.voice;
    });
  }

  Future<void> _startOcrImport(ImageSource source) async {
    setState(() {
      _mode = source == ImageSource.camera 
          ? SmartImportMode.camera 
          : SmartImportMode.gallery;
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final lines = await _ocrService.scanImage(source);

      if (lines.isEmpty) {
        setState(() {
          _isProcessing = false;
          _mode = SmartImportMode.selection;
        });
        return;
      }

      final candidates = await _ocrService.parseLines(lines);

      setState(() {
        _importedExercises = candidates
            .map((c) => SmartImportedExercise.fromOcr(c))
            .toList();
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error procesando imagen: ${e.toString()}';
        _isProcessing = false;
        _mode = SmartImportMode.selection;
      });
    }
  }

  void _onVoiceComplete(List<VoiceParsedExercise> exercises) {
    setState(() {
      _importedExercises.addAll(
        exercises.map((e) => SmartImportedExercise.fromVoice(e)),
      );
    });
  }

  void _onConfirm() {
    final validExercises = _importedExercises.where((e) => e.isValid).toList();

    if (validExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No hay ejercicios válidos para añadir',
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: Colors.red[700],
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

  void _removeExercise(int index) {
    setState(() {
      _importedExercises.removeAt(index);
    });
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  void _updateExerciseSeries(int index, String value) {
    final series = int.tryParse(value);
    if (series == null || series <= 0) return;

    setState(() {
      _importedExercises[index] = _importedExercises[index].copyWith(series: series);
    });
  }

  void _updateExerciseReps(int index, String value) {
    if (value.isEmpty) return;

    setState(() {
      _importedExercises[index] = _importedExercises[index].copyWith(repsRange: value);
    });
  }

  void _backToSelection() {
    setState(() {
      _mode = SmartImportMode.selection;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Título con botón atrás si no está en selección
            Row(
              children: [
                if (_mode != SmartImportMode.selection) ...[
                  IconButton(
                    onPressed: _backToSelection,
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    _getTitle(),
                    style: GoogleFonts.montserrat(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    textAlign: _mode == SmartImportMode.selection 
                        ? TextAlign.center 
                        : TextAlign.left,
                  ),
                ),
                if (_mode != SmartImportMode.selection)
                  const SizedBox(width: 48), // Balance visual
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _getSubtitle(),
              style: GoogleFonts.montserrat(
                fontSize: 14,
                color: Colors.white54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Contenido según modo
            Flexible(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  String _getTitle() {
    switch (_mode) {
      case SmartImportMode.selection:
        return 'IMPORT SMART';
      case SmartImportMode.voice:
        return 'DICTADO POR VOZ';
      case SmartImportMode.camera:
      case SmartImportMode.gallery:
        return 'ESCANEO OCR';
    }
  }

  String _getSubtitle() {
    switch (_mode) {
      case SmartImportMode.selection:
        return 'Elige cómo añadir ejercicios';
      case SmartImportMode.voice:
        return 'Di los ejercicios en voz alta';
      case SmartImportMode.camera:
      case SmartImportMode.gallery:
        return 'Procesando imagen...';
    }
  }

  Widget _buildContent() {
    switch (_mode) {
      case SmartImportMode.selection:
        return _buildSelectionView();
      case SmartImportMode.voice:
        return _buildVoiceView();
      case SmartImportMode.camera:
      case SmartImportMode.gallery:
        if (_isProcessing) {
          return _buildProcessingView();
        }
        return _buildResultsView();
    }
  }

  /// Vista de selección inicial con 3 opciones
  Widget _buildSelectionView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icono central
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red[900]?.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.auto_awesome,
            size: 48,
            color: Colors.red[400],
          ),
        ),
        const SizedBox(height: 32),

        // Opciones
        _ImportOptionCard(
          icon: Icons.mic,
          title: 'Dictar por Voz',
          subtitle: 'Di los ejercicios: "Sentadilla 5x5, luego press banca 4x10"',
          color: Colors.blue,
          onTap: _startVoiceImport,
        ),
        const SizedBox(height: 12),
        _ImportOptionCard(
          icon: Icons.camera_alt,
          title: 'Escanear con Cámara',
          subtitle: 'Toma foto de una rutina escrita o impresa',
          color: Colors.green,
          onTap: () => _startOcrImport(ImageSource.camera),
        ),
        const SizedBox(height: 12),
        _ImportOptionCard(
          icon: Icons.photo_library,
          title: 'Importar de Galería',
          subtitle: 'Selecciona una imagen con ejercicios',
          color: Colors.orange,
          onTap: () => _startOcrImport(ImageSource.gallery),
        ),

        // Error message si existe
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[900]?.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[700]!),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[400], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.montserrat(
                      color: Colors.red[400],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Vista de dictado por voz (integra VoiceInputSheet)
  Widget _buildVoiceView() {
    final voiceState = ref.watch(voiceInputProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón de micrófono
        VoiceMicButton(
          onTap: () async {
            final notifier = ref.read(voiceInputProvider.notifier);
            if (voiceState.isListening) {
              final exercises = await notifier.stopListening();
              _onVoiceComplete(exercises);
            } else {
              await notifier.startListening(continuous: voiceState.isContinuousMode);
            }
          },
          size: 80,
        ),
        const SizedBox(height: 16),

        // Transcripción
        const VoiceTranscriptPreview(fontSize: 16),
        const SizedBox(height: 16),

        // Lista de ejercicios acumulados
        if (_importedExercises.isNotEmpty) ...[
          Flexible(
            child: _buildExercisesList(),
          ),
          const SizedBox(height: 16),
          _buildActionButtons(),
        ],

        // Sugerencias si no hay ejercicios
        if (_importedExercises.isEmpty && !voiceState.isListening) ...[
          const SizedBox(height: 16),
          _buildVoiceSuggestions(),
        ],
      ],
    );
  }

  Widget _buildProcessingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 40),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
        ),
        const SizedBox(height: 24),
        Text(
          'Analizando imagen...',
          style: GoogleFonts.montserrat(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Detectando ejercicios con OCR',
          style: GoogleFonts.montserrat(
            color: Colors.white38,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildResultsView() {
    if (_importedExercises.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),
          Icon(Icons.search_off, size: 48, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No se detectaron ejercicios',
            style: GoogleFonts.montserrat(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta con otra imagen o usa dictado por voz',
            style: GoogleFonts.montserrat(
              color: Colors.white38,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _backToSelection,
            icon: const Icon(Icons.arrow_back),
            label: const Text('VOLVER'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white30),
            ),
          ),
          const SizedBox(height: 40),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Resumen
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.green[900]?.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green[400], size: 20),
              const SizedBox(width: 8),
              Text(
                '${_importedExercises.where((e) => e.isValid).length} ejercicios detectados',
                style: GoogleFonts.montserrat(
                  color: Colors.green[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Lista
        Flexible(
          child: _buildExercisesList(),
        ),
        const SizedBox(height: 16),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildExercisesList() {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _importedExercises.length,
      itemBuilder: (ctx, index) {
        final exercise = _importedExercises[index];
        return _SmartExerciseCard(
          exercise: exercise,
          index: index,
          seriesController: _getSeriesController(index, exercise.series),
          repsController: _getRepsController(index, exercise.repsRange),
          onSeriesChanged: (v) => _updateExerciseSeries(index, v),
          onRepsChanged: (v) => _updateExerciseReps(index, v),
          onRemove: () => _removeExercise(index),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    final validCount = _importedExercises.where((e) => e.isValid).length;

    return Row(
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
            onPressed: validCount > 0 ? _onConfirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[800],
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'AÑADIR $validCount EJERCICIO${validCount == 1 ? '' : 'S'}',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceSuggestions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 18, color: Colors.amber[400]),
              const SizedBox(width: 8),
              Text(
                'Ejemplos de comandos:',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSuggestionChip('Banco plano 4x10'),
          _buildSuggestionChip('Dominadas 3 series al fallo'),
          _buildSuggestionChip('Curl bíceps 3x12 a 20 kilos'),
          _buildSuggestionChip('No, quise decir press inclinado'),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(Icons.format_quote, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '"$text"',
              style: GoogleFonts.montserrat(
                color: Colors.white54,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card de opción de import
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: color.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card para ejercicio importado
class _SmartExerciseCard extends StatelessWidget {
  final SmartImportedExercise exercise;
  final int index;
  final TextEditingController seriesController;
  final TextEditingController repsController;
  final Function(String) onSeriesChanged;
  final Function(String) onRepsChanged;
  final VoidCallback onRemove;

  const _SmartExerciseCard({
    required this.exercise,
    required this.index,
    required this.seriesController,
    required this.repsController,
    required this.onSeriesChanged,
    required this.onRepsChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isValid = exercise.isValid;
    final sourceIcon = exercise.source == SmartImportSource.voice 
        ? Icons.mic 
        : Icons.document_scanner;
    final sourceColor = exercise.source == SmartImportSource.voice 
        ? Colors.blue 
        : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid ? Colors.grey[850] : Colors.red[900]?.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isValid ? Colors.grey[700]! : Colors.red[700]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Source indicator
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: sourceColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(sourceIcon, size: 14, color: sourceColor),
              ),
              const SizedBox(width: 8),
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
                          fontSize: 14,
                        ),
                      )
                    else
                      Text(
                        'No encontrado',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          color: Colors.red[400],
                          fontSize: 14,
                        ),
                      ),
                    Text(
                      '"${exercise.rawText}"',
                      style: GoogleFonts.montserrat(
                        color: Colors.white38,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Confidence
              if (isValid)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(exercise.confidence).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${(exercise.confidence * 100).toInt()}%',
                    style: GoogleFonts.montserrat(
                      color: _getConfidenceColor(exercise.confidence),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close, color: Colors.red[400], size: 18),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _CompactField(
                  label: 'Series',
                  controller: seriesController,
                  onChanged: onSeriesChanged,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompactField(
                  label: 'Reps',
                  controller: repsController,
                  onChanged: onRepsChanged,
                  keyboardType: TextInputType.text,
                ),
              ),
              if (exercise.weight != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${exercise.weight!.toStringAsFixed(1)} kg',
                    style: GoogleFonts.montserrat(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.yellow;
    if (confidence >= 0.4) return Colors.orange;
    return Colors.red;
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
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 13,
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
