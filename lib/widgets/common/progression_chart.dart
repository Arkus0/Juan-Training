import '../../utils/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/serie_log.dart';

/// Widget que muestra un gráfico simple de progresión con los últimos logs.
/// Usa CustomPaint para dibujar líneas sin dependencias externas.
class ProgressionChart extends StatelessWidget {
  final String exerciseName;
  final List<SetHistoryData> history; // Ordenado de más antiguo a más reciente
  final int maxEntries;

  const ProgressionChart({
    super.key,
    required this.exerciseName,
    required this.history,
    this.maxEntries = 10,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return _buildEmptyState();
    }

    final displayHistory = history.length > maxEntries
        ? history.sublist(history.length - maxEntries)
        : history;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PROGRESIÓN',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.neonPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: CustomPaint(
            painter: _ChartPainter(displayHistory),
            child: Container(),
          ),
        ),
        const SizedBox(height: 4),
        // Leyenda
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(color: AppColors.neonPrimary!, label: 'Peso'),
            const SizedBox(width: 16),
            _LegendItem(color: AppColors.info!, label: 'Volumen'),
          ],
        ),
        const SizedBox(height: 8),
        // Lista compacta de sesiones
        ...displayHistory.reversed.take(5).map((entry) => _HistoryRow(entry: entry)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 40, color: AppColors.border),
          const SizedBox(height: 8),
          Text(
            'Sin datos de progresión',
            style: GoogleFonts.montserrat(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
        ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final SetHistoryData entry;

  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateStr = '${entry.date.day}/${entry.date.month}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            dateStr,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
          ),
          const SizedBox(width: 8),
          Text(
            '${entry.maxWeight}kg',
            style: TextStyle(
              color: AppColors.neonPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '×${entry.bestReps}',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 10),
          ),
          const Spacer(),
          Text(
            '${entry.volume.toStringAsFixed(0)}kg vol',
            style: TextStyle(color: AppColors.info, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// Painter para el gráfico de líneas.
class _ChartPainter extends CustomPainter {
  final List<SetHistoryData> data;

  _ChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final weightPaint = Paint()
      ..color = AppColors.neonPrimary!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final volumePaint = Paint()
      ..color = AppColors.info!
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = AppColors.neonPrimary!
      ..style = PaintingStyle.fill;

    // Encontrar min/max para normalizar
    double minWeight = double.infinity;
    double maxWeight = 0;
    double minVolume = double.infinity;
    double maxVolume = 0;

    for (final entry in data) {
      if (entry.maxWeight < minWeight) minWeight = entry.maxWeight;
      if (entry.maxWeight > maxWeight) maxWeight = entry.maxWeight;
      if (entry.volume < minVolume) minVolume = entry.volume;
      if (entry.volume > maxVolume) maxVolume = entry.volume;
    }

    // Evitar división por cero
    if (maxWeight == minWeight) maxWeight = minWeight + 1;
    if (maxVolume == minVolume) maxVolume = minVolume + 1;

    final weightPath = Path();
    final volumePath = Path();
    final padding = 10.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    for (int i = 0; i < data.length; i++) {
      final x = padding + (i / (data.length - 1).clamp(1, double.infinity)) * chartWidth;

      // Normalizar peso a [0, 1] -> [chartHeight, 0]
      final normalizedWeight = (data[i].maxWeight - minWeight) / (maxWeight - minWeight);
      final yWeight = padding + chartHeight * (1 - normalizedWeight);

      // Normalizar volumen
      final normalizedVolume = (data[i].volume - minVolume) / (maxVolume - minVolume);
      final yVolume = padding + chartHeight * (1 - normalizedVolume);

      if (i == 0) {
        weightPath.moveTo(x, yWeight);
        volumePath.moveTo(x, yVolume);
      } else {
        weightPath.lineTo(x, yWeight);
        volumePath.lineTo(x, yVolume);
      }

      // Dibujar punto en peso
      canvas.drawCircle(Offset(x, yWeight), 3, dotPaint);
    }

    canvas.drawPath(volumePath, volumePaint);
    canvas.drawPath(weightPath, weightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Datos de historial para un día/sesión.
class SetHistoryData {
  final DateTime date;
  final double maxWeight;
  final int bestReps;
  final double volume;

  const SetHistoryData({
    required this.date,
    required this.maxWeight,
    required this.bestReps,
    required this.volume,
  });

  /// Crea desde una lista de SerieLog.
  factory SetHistoryData.fromLogs(DateTime date, List<SerieLog> logs) {
    double maxWeight = 0;
    int bestReps = 0;
    double volume = 0;

    for (final log in logs) {
      if (log.completed) {
        if (log.peso > maxWeight) {
          maxWeight = log.peso;
          bestReps = log.reps;
        }
        volume += log.peso * log.reps;
      }
    }

    return SetHistoryData(
      date: date,
      maxWeight: maxWeight,
      bestReps: bestReps,
      volume: volume,
    );
  }
}
