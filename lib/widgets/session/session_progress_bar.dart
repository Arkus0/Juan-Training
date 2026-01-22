import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/session_progress_provider.dart';

/// Barra de progreso de sesión no invasiva (estilo Hevy)
///
/// Características:
/// - Barra fina animada en la parte superior
/// - Texto con porcentaje completado (Montserrat)
/// - Indicadores de ejercicios pendientes
/// - Cambio de color gradual hacia 100%
/// - Animación smooth de fill
/// - Vibración en milestones (50%, 75%, 100%)
class SessionProgressBar extends ConsumerWidget {
  /// Altura de la barra (default: 32px, compacta)
  final double height;

  /// Si mostrar el detalle expandido con ejercicios
  final bool showDetails;

  const SessionProgressBar({
    super.key,
    this.height = 32,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(sessionProgressProvider);

    // No mostrar si no hay ejercicios
    if (progress.totalSets == 0) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          bottom: BorderSide(
            color: _getProgressColor(progress.percentage).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Stack(
        children: [
          // Barra de progreso animada
          _AnimatedProgressFill(
            percentage: progress.percentage,
            isComplete: progress.isComplete,
          ),

          // Contenido sobre la barra
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Porcentaje
                _PercentageText(
                  percentage: progress.percentage,
                  isComplete: progress.isComplete,
                ),

                const SizedBox(width: 8),

                // Separador
                Container(
                  width: 1,
                  height: 16,
                  color: Colors.grey[700],
                ),

                const SizedBox(width: 8),

                // Info de series
                _SetsInfo(
                  completed: progress.completedSets,
                  total: progress.totalSets,
                ),

                const Spacer(),

                // Indicadores de ejercicios pendientes
                if (!progress.isComplete)
                  _PendingExercisesIndicator(
                    total: progress.totalExercises,
                    completed: progress.completedExercises,
                  ),

                // Icono de completado
                if (progress.isComplete)
                  _CompleteIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 0.9) return Colors.green[400]!;
    if (percentage >= 0.75) return Colors.orange[400]!;
    return Colors.redAccent[700]!;
  }
}

/// Barra de fondo con gradiente animado
class _AnimatedProgressFill extends StatelessWidget {
  final double percentage;
  final bool isComplete;

  const _AnimatedProgressFill({
    required this.percentage,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Fondo de la barra
            Container(
              color: Colors.grey[900],
            ),

            // Fill animado
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: constraints.maxWidth * percentage.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.15),
                  ],
                ),
              ),
            ),

            // Línea de progreso fina en el borde superior
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                height: 3,
                width: double.infinity,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color,
                          color.withValues(alpha: 0.7),
                        ],
                      ),
                      boxShadow: isComplete
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getColor() {
    if (isComplete) return Colors.green[400]!;
    if (percentage >= 0.9) return Colors.green[400]!;
    if (percentage >= 0.75) return Colors.orange[400]!;
    return Colors.redAccent[700]!;
  }
}

/// Texto del porcentaje con animación
class _PercentageText extends StatelessWidget {
  final double percentage;
  final bool isComplete;

  const _PercentageText({
    required this.percentage,
    required this.isComplete,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percentage * 100),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Text(
          '${value.round()}%',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
            letterSpacing: 0.5,
          ),
        );
      },
    );
  }

  Color _getColor() {
    if (isComplete) return Colors.green[400]!;
    if (percentage >= 0.9) return Colors.green[400]!;
    if (percentage >= 0.75) return Colors.orange[400]!;
    return Colors.white;
  }
}

/// Info de series completadas
class _SetsInfo extends StatelessWidget {
  final int completed;
  final int total;

  const _SetsInfo({
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.fitness_center,
          size: 12,
          color: Colors.grey[500],
        ),
        const SizedBox(width: 4),
        Text(
          '$completed/$total',
          style: GoogleFonts.montserrat(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[400],
          ),
        ),
      ],
    );
  }
}

/// Indicador visual de ejercicios pendientes
class _PendingExercisesIndicator extends StatelessWidget {
  final int total;
  final int completed;

  const _PendingExercisesIndicator({
    required this.total,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final pending = total - completed;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Círculos pequeños para cada ejercicio
        ...List.generate(
          total.clamp(0, 6), // Máximo 6 círculos visibles
          (index) {
            final isCompleted = index < completed;
            return Padding(
              padding: const EdgeInsets.only(left: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? Colors.green[400]
                      : Colors.grey[700],
                  border: Border.all(
                    color: isCompleted
                        ? Colors.green[400]!
                        : Colors.grey[600]!,
                    width: 1,
                  ),
                ),
              ),
            );
          },
        ),

        // Indicador de más si hay más de 6
        if (total > 6) ...[
          const SizedBox(width: 4),
          Text(
            '+${total - 6}',
            style: GoogleFonts.montserrat(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: Colors.grey[500],
            ),
          ),
        ],

        const SizedBox(width: 8),

        // Texto de pendientes
        Text(
          pending == 1 ? '1 pendiente' : '$pending pendientes',
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

/// Indicador de sesión completada
class _CompleteIndicator extends StatefulWidget {
  @override
  State<_CompleteIndicator> createState() => _CompleteIndicatorState();
}

class _CompleteIndicatorState extends State<_CompleteIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[400]?.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green[400]!.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Colors.green[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'COMPLETADO',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.green[400],
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Versión expandida de la barra de progreso con detalles de superseries
class SessionProgressBarExpanded extends ConsumerWidget {
  const SessionProgressBarExpanded({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(sessionProgressProvider);

    if (progress.totalSets == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con porcentaje
          Row(
            children: [
              _PercentageText(
                percentage: progress.percentage,
                isComplete: progress.isComplete,
              ),
              const SizedBox(width: 8),
              Text(
                'completado',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
              const Spacer(),
              _SetsInfo(
                completed: progress.completedSets,
                total: progress.totalSets,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Barra de progreso horizontal
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: _AnimatedProgressFill(
                percentage: progress.percentage,
                isComplete: progress.isComplete,
              ),
            ),
          ),

          // Info de superseries si hay
          if (progress.supersets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'SUPERSERIES',
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.orange[400],
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            ...progress.supersets.map((ss) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        ss.isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 12,
                        color: ss.isComplete ? Colors.green[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ss.exerciseNames.join(' + '),
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[400],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${ss.completedRounds}/${ss.totalRounds}',
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ss.isComplete ? Colors.green[400] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
