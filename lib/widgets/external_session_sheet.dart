import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/external_session.dart';
import '../models/library_exercise.dart';
import '../providers/voice_input_provider.dart';
import '../services/exercise_matching_service.dart';
import '../services/voice_input_service.dart';
import '../utils/design_system.dart';
import 'voice/ptt_voice_button.dart';

/// Sheet para agregar sesiones externas al historial.
///
/// Flujo:
/// 1. Usuario selecciona fecha
/// 2. Elige método de entrada: Voz, OCR, Texto o Manual
/// 3. Captura ejercicios
/// 4. Preview editable con confirmación
/// 5. Opción de incluir en progresión
/// 6. Guardar
class ExternalSessionSheet extends ConsumerStatefulWidget {
  final Function(ExternalSession) onSave;
  final VoidCallback? onCancel;

  const ExternalSessionSheet({
    super.key,
    required this.onSave,
    this.onCancel,
  });

  @override
  ConsumerState<ExternalSessionSheet> createState() => _ExternalSessionSheetState();

  static Future<ExternalSession?> show(BuildContext context) async {
    return showModalBottomSheet<ExternalSession>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExternalSessionSheet(
        onSave: (session) => Navigator.of(ctx).pop(session),
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }
}

class _ExternalSessionSheetState extends ConsumerState<ExternalSessionSheet> {
  DateTime _sessionDate = DateTime.now();
  ExternalSessionSource? _selectedSource;
  final List<ExternalExercise> _exercises = [];
  bool _includeInProgression = false;

  // Notas opcionales de la sesión
  String? _sessionNotes;

  // Para entrada de texto
  final _textController = TextEditingController();

  // Undo stack
  final List<List<ExternalExercise>> _undoStack = [];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _saveToUndoStack() {
    _undoStack.add(List.from(_exercises));
    // Mantener solo los últimos 10 estados
    if (_undoStack.length > 10) {
      _undoStack.removeAt(0);
    }
  }

  void _undo() {
    if (_undoStack.isNotEmpty) {
      setState(() {
        _exercises.clear();
        _exercises.addAll(_undoStack.removeLast());
      });
      try { HapticFeedback.lightImpact(); } catch (_) {}
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.error,
              surface: AppColors.bgElevated,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _sessionDate = picked);
    }
  }

  void _onSourceSelected(ExternalSessionSource source) {
    setState(() => _selectedSource = source);
    try { HapticFeedback.selectionClick(); } catch (_) {}
  }

  void _addExercisesFromVoice(List<VoiceParsedExercise> parsed) {
    _saveToUndoStack();
    setState(() {
      for (final p in parsed) {
        _exercises.add(ExternalExercise(
          name: p.matchedName ?? p.rawText,
          libraryId: p.matchedId,
          series: p.series,
          repsRange: p.repsRange,
          weight: p.weight,
          notes: p.notes,
          confidence: p.confidence,
          rawInput: p.rawText,
        ),);
      }
    });
  }

  Future<void> _processTextInput() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _selectedSource = ExternalSessionSource.text);

    // Usar el servicio de matching para procesar el texto
    final service = VoiceInputService.instance;
    final parsed = await service.parseTranscript(text);

    if (parsed.isNotEmpty) {
      _addExercisesFromVoice(parsed);
      _textController.clear();
    }
  }

  Future<void> _startOcrFromCamera() async {
    // Implementación pendiente: usar image_picker + google_mlkit_text_recognition.
    // De momento mostramos un snackbar informativo y dejamos la función lista para extender.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OCR disponible pronto')),
    );
  }

  Future<void> _startOcrFromGallery() async {
    // Implementación pendiente: seleccionar imagen de galería y procesar OCR.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OCR disponible pronto')),
    );
  }

  void _removeExercise(int index) {
    _saveToUndoStack();
    setState(() => _exercises.removeAt(index));
    try { HapticFeedback.lightImpact(); } catch (_) {}
  }

  void _updateExercise(int index, ExternalExercise updated) {
    _saveToUndoStack();
    setState(() => _exercises[index] = updated);
  }

  Future<void> _changeExerciseMatch(int index) async {
    final current = _exercises[index];

    // Buscar alternativas
    final matchingService = ExerciseMatchingService.instance;
    final alternatives = await matchingService.matchMultiple(current.rawInput, limit: 10);
    final validAlternatives = alternatives
        .where((a) => a.exercise != null)
        .map((a) => a.exercise!)
        .toList();

    if (!mounted) return;

    final selected = await showModalBottomSheet<LibraryExercise>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ExerciseSearchSheet(
        query: current.rawInput,
        alternatives: validAlternatives,
      ),
    );

    if (selected != null) {
      _updateExercise(
        index,
        current.copyWith(
          name: selected.name,
          libraryId: selected.id,
          confidence: 1.0, // Manual = 100%
        ),
      );
    }
  }

  void _onSave() {
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Agrega al menos un ejercicio',
            style: GoogleFonts.montserrat(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try { HapticFeedback.heavyImpact(); } catch (_) {}

    final session = ExternalSession.create(
      sessionDate: _sessionDate,
      exercises: _exercises,
      notes: _sessionNotes,
      includeInProgression: _includeInProgression,
      source: _selectedSource ?? ExternalSessionSource.manual,
    );

    widget.onSave(session);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.upload_file, color: AppColors.neonCyan),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AGREGAR SESIÓN EXTERNA',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (_undoStack.isNotEmpty)
                  IconButton(
                    onPressed: _undo,
                    icon: const Icon(Icons.undo, color: AppColors.textSecondary),
                    tooltip: 'Deshacer',
                  ),
              ],
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selector de fecha
                  _buildDateSelector(),
                  const SizedBox(height: 24),

                  // Selector de método de entrada
                  if (_selectedSource == null) ...[
                    _buildSourceSelector(),
                  ] else ...[
                    // Método de entrada activo
                    _buildActiveInput(),
                    const SizedBox(height: 24),

                    // Lista de ejercicios
                    if (_exercises.isNotEmpty) ...[
                      _buildExercisesList(),
                      const SizedBox(height: 24),
                    ],

                    // Opciones adicionales
                    _buildOptions(),
                    const SizedBox(height: 24),

                    // Botones de acción
                    _buildActions(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(_sessionDate);
    final isToday = DateUtils.isSameDay(_sessionDate, DateTime.now());

    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: isToday ? AppColors.neonCyan : Colors.white70,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FECHA DE LA SESIÓN',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isToday ? 'Hoy - ${dateStr.split(',')[1].trim()}' : dateStr,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Cómo quieres agregar los ejercicios?',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SourceButton(
                icon: Icons.mic,
                label: 'VOZ',
                color: AppColors.error,
                onTap: () => _onSourceSelected(ExternalSessionSource.voice),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SourceButton(
                icon: Icons.photo_camera,
                label: 'OCR',
                color: Colors.blue,
                onTap: () => _onSourceSelected(ExternalSessionSource.ocr),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SourceButton(
                icon: Icons.keyboard,
                label: 'TEXTO',
                color: Colors.purple,
                onTap: () => _onSourceSelected(ExternalSessionSource.text),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SourceButton(
                icon: Icons.touch_app,
                label: 'MANUAL',
                color: Colors.green,
                onTap: () => _onSourceSelected(ExternalSessionSource.manual),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildLimitsInfo(),
      ],
    );
  }

  Widget _buildLimitsInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.neonCyan),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'La voz captura ejercicios básicos: nombre, series, reps y peso. Detalles avanzados se editan después.',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveInput() {
    switch (_selectedSource) {
      case ExternalSessionSource.voice:
        return _buildVoiceInput();
      case ExternalSessionSource.ocr:
        return _buildOcrInput();
      case ExternalSessionSource.text:
        return _buildTextInput();
      case ExternalSessionSource.manual:
        return _buildManualInput();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildVoiceInput() {
    return Column(
      children: [
        // Botón de cambiar método
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _selectedSource = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Cambiar método'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
            Row(
              children: [
                _MethodChip(
                  icon: Icons.photo_camera,
                  label: 'OCR',
                  onTap: () => _onSourceSelected(ExternalSessionSource.ocr),
                ),
                const SizedBox(width: 8),
                _MethodChip(
                  icon: Icons.keyboard,
                  label: 'Texto',
                  onTap: () => _onSourceSelected(ExternalSessionSource.text),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Botón PTT
        PttVoiceButton(
          size: 100,
          onListeningEnd: (_) {
            final state = ref.read(voiceInputProvider);
            if (state.parsedExercises.isNotEmpty) {
              _addExercisesFromVoice(state.parsedExercises);
              ref.read(voiceInputProvider.notifier).clearResults();
            }
          },
        ),

        const SizedBox(height: 16),

        // Ejemplos
        _buildVoiceExamples(),
      ],
    );
  }

  Widget _buildVoiceExamples() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ejemplos de lo que puedes decir:',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          _buildExampleChip('"Press banca 4 series de 8 con 80 kilos"'),
          _buildExampleChip('"Sentadillas 3 por 5, notas: felt strong"'),
          _buildExampleChip('"Luego curl bíceps 3x12 a 15 kg"'),
        ],
      ),
    );
  }

  Widget _buildExampleChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.format_quote, size: 14, color: AppColors.neonPrimary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOcrInput() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _selectedSource = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Cambiar método'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(Icons.photo_camera, size: 48, color: Colors.blue.withValues(alpha: 0.7)),
              const SizedBox(height: 16),
              Text(
                'Escanear log de entrenamiento',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Toma una foto de tu log escrito o impreso',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _startOcrFromCamera,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Cámara'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _startOcrFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galería'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.bgDeep,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'OCR funciona mejor con texto claro y legible. Usa voz o texto si falla.',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _selectedSource = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Cambiar método'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _textController,
          maxLines: 4,
          style: GoogleFonts.montserrat(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Escribe tu entrenamiento...\n\nEj: Press banca 4x8 80kg, Sentadilla 3x5 100kg',
            hintStyle: GoogleFonts.montserrat(color: Colors.white30),
            filled: true,
            fillColor: AppColors.bgElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.purple),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _processTextInput,
            icon: const Icon(Icons.add),
            label: const Text('PROCESAR TEXTO'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualInput() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _selectedSource = null),
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Cambiar método'),
              style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ManualExerciseForm(
          onAdd: (exercise) {
            _saveToUndoStack();
            setState(() => _exercises.add(exercise));
          },
        ),
      ],
    );
  }

  Widget _buildExercisesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EJERCICIOS (${_exercises.length})',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 1,
              ),
            ),
            if (_exercises.isNotEmpty)
              Text(
                '~${(_exercises.fold(0.0, (sum, e) => sum + (e.weight ?? 0) * _parseReps(e.repsRange) * e.series) / 1000).toStringAsFixed(1)}t volumen',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: AppColors.neonCyan,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(_exercises.length, (index) {
          final exercise = _exercises[index];
          return _ExerciseCard(
            exercise: exercise,
            onRemove: () => _removeExercise(index),
            onChangeMatch: () => _changeExerciseMatch(index),
            onEdit: (updated) => _updateExercise(index, updated),
          );
        }),
      ],
    );
  }

  int _parseReps(String repsRange) {
    if (repsRange.contains('-')) {
      final parts = repsRange.split('-');
      final min = int.tryParse(parts[0]) ?? 0;
      final max = int.tryParse(parts[1]) ?? 0;
      return ((min + max) / 2).round();
    }
    return int.tryParse(repsRange) ?? 10;
  }

  Widget _buildOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle de progresión
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _includeInProgression ? AppColors.neonCyan.withValues(alpha: 0.5) : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incluir en métricas de progresión',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Afecta sugerencias automáticas de peso',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _includeInProgression,
                onChanged: (v) => setState(() => _includeInProgression = v),
                activeThumbColor: AppColors.neonCyan,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Notas opcionales
        TextField(
          onChanged: (v) => _sessionNotes = v.isEmpty ? null : v,
          style: GoogleFonts.montserrat(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Notas de la sesión (opcional)',
            hintStyle: GoogleFonts.montserrat(color: Colors.white30, fontSize: 14),
            prefixIcon: const Icon(Icons.note, color: AppColors.textSecondary, size: 20),
            filled: true,
            fillColor: AppColors.bgElevated,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {
              widget.onCancel?.call();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white30),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'CANCELAR',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _exercises.isNotEmpty ? _onSave : null,
            icon: const Icon(Icons.save),
            label: Text(
              'GUARDAR SESIÓN',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonCyan,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AppColors.bgDeep,
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Componentes auxiliares ---

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MethodChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgDeep,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final ExternalExercise exercise;
  final VoidCallback onRemove;
  final VoidCallback onChangeMatch;
  final Function(ExternalExercise) onEdit;

  const _ExerciseCard({
    required this.exercise,
    required this.onRemove,
    required this.onChangeMatch,
    required this.onEdit,
  });

  Color _getConfidenceColor() {
    switch (exercise.confidenceLevel) {
      case ConfidenceLevel.high:
        return AppColors.neonCyan;
      case ConfidenceLevel.medium:
        return Colors.amber;
      case ConfidenceLevel.low:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (exercise.rawInput != exercise.name) ...[
                      const SizedBox(height: 2),
                      Text(
                        '"${exercise.rawInput}"',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getConfidenceColor().withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(exercise.confidence * 100).toInt()}%',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _getConfidenceColor(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onChangeMatch,
                icon: const Icon(Icons.swap_horiz, size: 18),
                color: AppColors.textSecondary,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: 'Cambiar ejercicio',
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
                color: AppColors.error,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                tooltip: 'Eliminar',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(
                label: 'Series',
                value: exercise.series.toString(),
                onEdit: (v) {
                  final series = int.tryParse(v);
                  if (series != null && series > 0) {
                    onEdit(exercise.copyWith(series: series));
                  }
                },
              ),
              const SizedBox(width: 8),
              _InfoChip(
                label: 'Reps',
                value: exercise.repsRange,
                onEdit: (v) {
                  if (v.isNotEmpty) {
                    onEdit(exercise.copyWith(repsRange: v));
                  }
                },
              ),
              if (exercise.weight != null) ...[
                const SizedBox(width: 8),
                _InfoChip(
                  label: 'Peso',
                  value: '${exercise.weight!.toStringAsFixed(1)} kg',
                  onEdit: (v) {
                    final weight = double.tryParse(v.replaceAll('kg', '').trim());
                    if (weight != null) {
                      onEdit(exercise.copyWith(weight: weight));
                    }
                  },
                ),
              ],
            ],
          ),
          if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Nota: ${exercise.notes}',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.white38,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Function(String) onEdit;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final controller = TextEditingController(text: value.replaceAll(' kg', ''));
        final result = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bgElevated,
            title: Text('Editar $label', style: const TextStyle(color: Colors.white)),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: label == 'Reps' ? TextInputType.text : TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: label,
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
        if (result != null && result.isNotEmpty) {
          onEdit(result);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgDeep,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                color: Colors.white54,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualExerciseForm extends StatefulWidget {
  final Function(ExternalExercise) onAdd;

  const _ManualExerciseForm({required this.onAdd});

  @override
  State<_ManualExerciseForm> createState() => _ManualExerciseFormState();
}

class _ManualExerciseFormState extends State<_ManualExerciseForm> {
  final _nameController = TextEditingController();
  final _seriesController = TextEditingController(text: '3');
  final _repsController = TextEditingController(text: '10');
  final _weightController = TextEditingController();

  LibraryExercise? _selectedExercise;

  @override
  void dispose() {
    _nameController.dispose();
    _seriesController.dispose();
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _searchExercise() async {
    final query = _nameController.text.trim();
    if (query.length < 2) return;

    final matchingService = ExerciseMatchingService.instance;
    final results = await matchingService.matchMultiple(query, limit: 10);
    final validResults = results
        .where((r) => r.exercise != null)
        .map((r) => r.exercise!)
        .toList();

    if (!mounted) return;

    final selected = await showModalBottomSheet<LibraryExercise>(
      context: context,
      backgroundColor: AppColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _ExerciseSearchSheet(
        query: query,
        alternatives: validResults,
      ),
    );

    if (selected != null) {
      setState(() {
        _selectedExercise = selected;
        _nameController.text = selected.name;
      });
    }
  }

  void _onAdd() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final series = int.tryParse(_seriesController.text) ?? 3;
    final reps = _repsController.text.isNotEmpty ? _repsController.text : '10';
    final weight = double.tryParse(_weightController.text);

    widget.onAdd(ExternalExercise(
      name: _selectedExercise?.name ?? name,
      libraryId: _selectedExercise?.id,
      series: series,
      repsRange: reps,
      weight: weight,
      confidence: _selectedExercise != null ? 1.0 : 0.5,
      rawInput: name,
    ),);

    // Limpiar formulario
    _nameController.clear();
    _seriesController.text = '3';
    _repsController.text = '10';
    _weightController.clear();
    setState(() => _selectedExercise = null);

    try { HapticFeedback.selectionClick(); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
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
            'Añadir ejercicio',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Nombre del ejercicio
          TextField(
            controller: _nameController,
            style: GoogleFonts.montserrat(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Nombre del ejercicio',
              labelStyle: GoogleFonts.montserrat(color: Colors.white54),
              suffixIcon: IconButton(
                onPressed: _searchExercise,
                icon: const Icon(Icons.search, color: AppColors.textSecondary),
              ),
              filled: true,
              fillColor: AppColors.bgDeep,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _searchExercise(),
          ),

          if (_selectedExercise != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.neonCyan.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, size: 14, color: AppColors.neonCyan),
                  const SizedBox(width: 6),
                  Text(
                    'Encontrado en biblioteca',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: AppColors.neonCyan,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Series, Reps, Peso
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _seriesController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Series',
                    labelStyle: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.bgDeep,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _repsController,
                  keyboardType: TextInputType.text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Reps',
                    labelStyle: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
                    hintText: '8-12',
                    hintStyle: GoogleFonts.montserrat(color: Colors.white24),
                    filled: true,
                    fillColor: AppColors.bgDeep,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Peso (kg)',
                    labelStyle: GoogleFonts.montserrat(color: Colors.white54, fontSize: 12),
                    filled: true,
                    fillColor: AppColors.bgDeep,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _nameController.text.isNotEmpty ? _onAdd : null,
              icon: const Icon(Icons.add),
              label: const Text('AÑADIR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.bgDeep,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseSearchSheet extends StatefulWidget {
  final String query;
  final List<LibraryExercise> alternatives;

  const _ExerciseSearchSheet({
    required this.query,
    required this.alternatives,
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

    final matchingService = ExerciseMatchingService.instance;
    final results = await matchingService.matchMultiple(query, limit: 10);

    setState(() {
      _results = results.where((r) => r.exercise != null).map((r) => r.exercise!).toList();
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
                      backgroundColor: AppColors.error.withValues(alpha: 0.3),
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
                      try { HapticFeedback.selectionClick(); } catch (_) {}
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
