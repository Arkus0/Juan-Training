import '../utils/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/rutina.dart';
import '../services/routine_sharing_service.dart';

/// Dialog to preview an imported routine before adding it to the database.
class RoutineImportPreviewDialog extends StatefulWidget {
  final Rutina rutina;
  final VoidCallback onConfirm;

  const RoutineImportPreviewDialog({
    super.key,
    required this.rutina,
    required this.onConfirm,
  });

  @override
  State<RoutineImportPreviewDialog> createState() =>
      _RoutineImportPreviewDialogState();
}

class _RoutineImportPreviewDialogState
    extends State<RoutineImportPreviewDialog> {
  late TextEditingController _nameController;
  late Rutina _editedRutina;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rutina.nombre);
    _editedRutina = widget.rutina;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _updateName(String name) {
    setState(() {
      _editedRutina = _editedRutina.copyWith(nombre: name);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = RoutineSharingService.instance.getImportStats(_editedRutina);

    return Dialog(
      backgroundColor: AppColors.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.live,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.download, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'IMPORTAR RUTINA',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name Editor
                    Text(
                      'NOMBRE',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.bgElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.live),
                        ),
                        hintText: 'Nombre de la rutina',
                        hintStyle: const TextStyle(color: AppColors.textTertiary),
                      ),
                      onChanged: _updateName,
                    ),

                    const SizedBox(height: 20),

                    // Stats Section
                    _buildStatsSection(stats),

                    const SizedBox(height: 20),

                    // Days Preview
                    Text(
                      'DÍAS',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(
                      _editedRutina.dias.length,
                      (index) => _buildDayPreview(index),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
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
                      onPressed: _nameController.text.trim().isEmpty
                          ? null
                          : () {
                              try { HapticFeedback.vibrate(); } catch (_) {}
                              Navigator.of(context).pop(_editedRutina);
                              widget.onConfirm();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.live,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        disabledBackgroundColor: AppColors.border,
                      ),
                      child: Text(
                        'IMPORTAR',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(RoutineImportStats stats) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatItem(
                icon: Icons.calendar_view_week,
                value: '${stats.daysCount}',
                label: 'DÍAS',
              ),
              _buildStatItem(
                icon: Icons.fitness_center,
                value: '${stats.exercisesCount}',
                label: 'EJERCICIOS',
              ),
              _buildStatItem(
                icon: Icons.repeat,
                value: '${stats.totalSeries}',
                label: 'SERIES',
              ),
            ],
          ),
          if (stats.supersetsCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.link, size: 16, color: Colors.redAccent[100]),
                const SizedBox(width: 4),
                Text(
                  '${stats.supersetsCount} SUPERSETS',
                  style: TextStyle(
                    color: Colors.redAccent[100],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          if (stats.muscleGroups.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: stats.muscleGroups.take(5).map((muscle) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.live.withValues(alpha:0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    muscle,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.neonPrimary, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayPreview(int index) {
    final dia = _editedRutina.dias[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgElevated.withValues(alpha:0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDeep),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.live.withValues(alpha:0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'DÍA ${index + 1}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dia.nombre,
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${dia.ejercicios.length} ej.',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (dia.ejercicios.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Show first 3 exercises
            ...dia.ejercicios.take(3).map((ejercicio) {
              final hasSuperset = ejercicio.supersetId != null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    if (hasSuperset)
                      Container(
                        width: 3,
                        height: 16,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    const Icon(
                      Icons.fitness_center,
                      size: 12,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ejercicio.nombre,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${ejercicio.series}x${ejercicio.repsRange}',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (dia.ejercicios.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${dia.ejercicios.length - 3} más',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Dialog to paste/input JSON for import
class RoutineImportInputDialog extends StatefulWidget {
  const RoutineImportInputDialog({super.key});

  @override
  State<RoutineImportInputDialog> createState() =>
      _RoutineImportInputDialogState();
}

class _RoutineImportInputDialogState extends State<RoutineImportInputDialog> {
  final TextEditingController _jsonController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _jsonController.text = data!.text!;
        _errorMessage = null;
      });
      try { HapticFeedback.selectionClick(); } catch (_) {}
    }
  }

  void _parseAndContinue() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = RoutineSharingService.instance
        .parseRoutineJson(_jsonController.text);

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess) {
      try { HapticFeedback.vibrate(); } catch (_) {}

      Navigator.of(context).pop(result.rutina);
    } else {
      try { HapticFeedback.vibrate(); } catch (_) {}
      setState(() {
        _errorMessage = result.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.live,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.code, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'PEGAR JSON',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Pega el JSON de la rutina:',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _pasteFromClipboard,
                          icon: const Icon(Icons.content_paste, size: 18),
                          label: const Text('PEGAR'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        controller: _jsonController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: GoogleFonts.firaCode(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.bgElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.live),
                          ),
                          hintText: '{\n  "nombre": "...",\n  "dias": [...]\n}',
                          hintStyle: const TextStyle(color: AppColors.border),
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.live.withValues(alpha:0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
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
                      onPressed: _jsonController.text.trim().isEmpty || _isLoading
                          ? null
                          : _parseAndContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.live,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        disabledBackgroundColor: AppColors.border,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'CONTINUAR',
                              style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
