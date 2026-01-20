import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PlateCalculatorDialog extends StatefulWidget {
  final double currentWeight;
  final Function(double) onWeightSelected;

  const PlateCalculatorDialog({
    super.key,
    required this.currentWeight,
    required this.onWeightSelected,
  });

  @override
  State<PlateCalculatorDialog> createState() => _PlateCalculatorDialogState();
}

class _PlateCalculatorDialogState extends State<PlateCalculatorDialog> {
  late TextEditingController _weightController;
  double _barWeight = 20.0;
  final List<double> _availablePlates = [25, 20, 15, 10, 5, 2.5, 1.25];
  List<double> _calculatedPlates = [];

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.currentWeight.toString());
    _calculatePlates(widget.currentWeight);
  }

  void _calculatePlates(double targetWeight) {
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
    final weight = double.tryParse(value);
    if (weight != null) {
      _calculatePlates(weight);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.red[900]!, width: 2),
      ),
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
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Center(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Bar
                    Container(
                      height: 12,
                      width: double.infinity,
                      color: Colors.grey[400],
                    ),
                    // Plates
                    if (_calculatedPlates.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                             const SizedBox(width: 40), // Space for collar/handle
                            ..._calculatedPlates.map((plate) => _buildPlateWidget(plate)),
                          ],
                        ),
                      )
                    else
                      Center(child: Text('BARRA VACÍA', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold))),
                  ],
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
                Switch(
                  value: _barWeight == 20.0,
                  activeThumbColor: Colors.redAccent[700],
                  onChanged: (val) {
                    setState(() {
                      _barWeight = val ? 20.0 : 10.0; // Toggle 20kg / 10kg bar
                      _updateWeight(_weightController.text);
                    });
                  },
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
    );
  }

  Widget _buildPlateWidget(double weight) {
    double height = 40;
    Color color = Colors.grey;

    // Standard Plate Colors & Sizes
    if (weight >= 25) { height = 90; color = Colors.red; }
    else if (weight >= 20) { height = 90; color = Colors.blue; }
    else if (weight >= 15) { height = 80; color = Colors.yellow; }
    else if (weight >= 10) { height = 70; color = Colors.green; }
    else if (weight >= 5) { height = 55; color = Colors.white; }
    else { height = 40; color = Colors.grey; }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 12,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black, width: 1),
      ),
    );
  }
}
