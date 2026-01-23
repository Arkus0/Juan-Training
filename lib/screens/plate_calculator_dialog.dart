import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';

class PlateCalculatorDialog extends ConsumerStatefulWidget {
  final double currentWeight;
  final Function(double) onWeightSelected;

  const PlateCalculatorDialog({
    super.key,
    required this.currentWeight,
    required this.onWeightSelected,
  });

  @override
  ConsumerState<PlateCalculatorDialog> createState() => _PlateCalculatorDialogState();
}

class _PlateCalculatorDialogState extends ConsumerState<PlateCalculatorDialog> {
  late TextEditingController _weightController;
  double _barWeight = 20.0;
  // Use common commercial plate denominations (as requested)
  final List<double> _availablePlates = [20, 15, 10, 5, 2, 1, 0.5, 0.25];
  List<double> _calculatedPlates = [];

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.currentWeight.toString());

    // Read persisted bar weight from settings after first frame and recalculate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final defaultBar = ref.read(settingsProvider).barWeight;
      setState(() {
        _barWeight = defaultBar;
      });
      _calculatePlates(double.tryParse(_weightController.text) ?? widget.currentWeight);
    });

    // Initial calculation based on passed weight
    _calculatePlates(widget.currentWeight);
  }

  void _calculatePlates(double targetWeight) {
    // Protección: si el campo está vacío, limpiamos resultado y salimos
    if (_weightController.text.isEmpty) {
      setState(() {
        _calculatedPlates = [];
      });
      return;
    }

    double remaining = (targetWeight - _barWeight) / 2;
    List<double> plates = [];

    if (remaining < 0) {
      setState(() => _calculatedPlates = []);
      return;
    }

    for (var plate in _availablePlates) {
      while (remaining >= plate) {
        plates.add(plate);
        remaining -= plate;
      }
    }

    setState(() {
      _calculatedPlates = plates;
    });
  }

  void _updateWeight(String value) {
    if (value.isEmpty) {
      setState(() {
        _calculatedPlates = [];
      });
      return;
    }

    final weight = double.tryParse(value);
    if (weight != null) {
      _calculatePlates(weight);
    }
  }

  String _getAccessibilityLabel() {
    if (_calculatedPlates.isEmpty) return 'Barra vacía';
    final platesString = _calculatedPlates.map((p) => '${p}kg').join(', ');
    return 'Placas por lado: $platesString';
  }

  @override
  Widget build(BuildContext context) {
    // Listen for runtime changes in the settings so the dialog updates live
    ref.listen<UserSettings>(settingsProvider, (previous, next) {
      if (previous?.barWeight != next.barWeight) {
        setState(() {
          _barWeight = next.barWeight;
          _updateWeight(_weightController.text);
        });
      }
    });

    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red[900]!, width: 2),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Text(
              'CALCULADORA DE PLACAS',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 20),
            // Bar Representation
            Tooltip(
              message: _getAccessibilityLabel(),
              child: Semantics(
                label: _getAccessibilityLabel(),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Center(
                    child: _calculatedPlates.isNotEmpty
                        ? SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(width: 16),
                                // Left side plates (mirror)
                                ..._calculatedPlates.reversed.map((plate) => _buildPlateWidget(plate)),
                                const SizedBox(width: 8),
                                // Bar center (flexible)
                                Container(
                                  height: 12,
                                  width: 220,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 8),
                                // Right side plates
                                ..._calculatedPlates.map((plate) => _buildPlateWidget(plate)),
                                const SizedBox(width: 16),
                              ],
                            ),
                          )
                        : Center(child: Text('BARRA VACÍA', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'PESO TOTAL (KG)',
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent[700]!)),
                    ),
                    onChanged: _updateWeight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Barra: ${_barWeight}kg', style: const TextStyle(color: Colors.white70)),
                Semantics(
                  label: 'Peso de la barra',
                  value: '${_barWeight}kg',
                  hint: 'Toca para cambiar entre 10kg y 20kg',
                  child: Switch(
                    value: _barWeight == 20.0,
                    activeThumbColor: Colors.redAccent[700],
                    onChanged: (val) {
                      setState(() {
                        _barWeight = val ? 20.0 : 10.0; // Toggle 20kg / 10kg bar
                        _updateWeight(_weightController.text);
                      });
                      // Persist the selection in settings
                      ref.read(settingsProvider.notifier).setBarWeight(_barWeight);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCELAR', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final w = double.tryParse(_weightController.text);
                    if (w != null) widget.onWeightSelected(w);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[900],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('APLICAR'),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildPlateWidget(double weight) {
    double height = 40;
    Color color = Colors.grey;

    // Plate colors/sizes (approx)
    if (weight >= 20) { height = 90; color = Colors.red; }
    else if (weight >= 15) { height = 80; color = Colors.blue; }
    else if (weight >= 10) { height = 70; color = Colors.yellow; }
    else if (weight >= 5) { height = 55; color = Colors.green; }
    else if (weight >= 2) { height = 45; color = Colors.white; }
    else { height = 36; color = Colors.grey; }

    String label;
    if ((weight % 1) == 0) {
      label = '${weight.toInt()}kg';
    } else {
      label = '${weight}kg';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 18,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black, width: 1),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white)),
      ],
    );
  }
}
