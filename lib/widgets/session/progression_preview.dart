import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/progression_engine_models.dart';

/// Widget que muestra la predicción de progresión de forma clara
/// 
/// Diseño:
/// - Muestra claramente qué se espera en esta sesión
/// - Indica qué pasará si el usuario tiene éxito
/// - Código de colores según confianza y acción
class ProgressionPreviewCard extends StatelessWidget {
  final ProgressionDecision decision;
  final VoidCallback? onTap;
  final bool compact;

  const ProgressionPreviewCard({
    super.key,
    required this.decision,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor, iconColor) = _getColors(decision);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(compact ? 8 : 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: compact ? _buildCompact(iconColor) : _buildFull(iconColor),
      ),
    );
  }

  Widget _buildCompact(Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_getIcon(decision.action), size: 16, color: iconColor),
        const SizedBox(width: 6),
        Text(
          '${_formatWeight(decision.suggestedWeight)}kg × ${decision.suggestedReps}',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (decision.isImprovement) ...[
          const SizedBox(width: 4),
          Icon(Icons.arrow_upward_rounded, size: 12, color: Colors.green[400]),
        ],
      ],
    );
  }

  Widget _buildFull(Color iconColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Row(
          children: [
            Icon(_getIcon(decision.action), size: 18, color: iconColor),
            const SizedBox(width: 8),
            Text(
              _getActionLabel(decision.action),
              style: GoogleFonts.montserrat(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: Colors.grey[400],
              ),
            ),
            if (decision.isImprovement) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[900]?.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '↑ MEJORA',
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.green[400],
                  ),
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Peso y reps grandes
        Text(
          '${_formatWeight(decision.suggestedWeight)}kg × ${decision.suggestedReps}',
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        
        const SizedBox(height: 6),
        
        // Mensaje para usuario
        Text(
          decision.userMessage,
          style: GoogleFonts.montserrat(
            fontSize: 11,
            color: Colors.grey[400],
          ),
        ),
        
        // Preview del siguiente paso
        if (decision.nextStepPreview != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.next_plan_outlined, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  decision.nextStepPreview!,
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  (Color, Color, Color) _getColors(ProgressionDecision decision) {
    switch (decision.action) {
      case ProgressionAction.increaseWeight:
        return (
          Colors.green[900]!.withValues(alpha: 0.2),
          Colors.green[700]!,
          Colors.green[400]!,
        );
      case ProgressionAction.increaseReps:
        return (
          Colors.blue[900]!.withValues(alpha: 0.2),
          Colors.blue[700]!,
          Colors.blue[400]!,
        );
      case ProgressionAction.maintain:
        return (
          Colors.grey[850]!,
          Colors.grey[700]!,
          Colors.amber[400]!,
        );
      case ProgressionAction.decreaseWeight:
      case ProgressionAction.decreaseReps:
        return (
          Colors.orange[900]!.withValues(alpha: 0.2),
          Colors.orange[700]!,
          Colors.orange[400]!,
        );
    }
  }

  IconData _getIcon(ProgressionAction action) {
    switch (action) {
      case ProgressionAction.increaseWeight:
        return Icons.fitness_center_rounded;
      case ProgressionAction.increaseReps:
        return Icons.add_circle_outline_rounded;
      case ProgressionAction.maintain:
        return Icons.repeat_rounded;
      case ProgressionAction.decreaseWeight:
      case ProgressionAction.decreaseReps:
        return Icons.trending_down_rounded;
    }
  }

  String _getActionLabel(ProgressionAction action) {
    switch (action) {
      case ProgressionAction.increaseWeight:
        return 'SUBIR PESO';
      case ProgressionAction.increaseReps:
        return 'SUBIR REPS';
      case ProgressionAction.maintain:
        return 'OBJETIVO HOY';
      case ProgressionAction.decreaseWeight:
        return 'CONSOLIDAR';
      case ProgressionAction.decreaseReps:
        return 'AJUSTAR';
    }
  }

  String _formatWeight(double weight) {
    if (weight == weight.roundToDouble()) {
      return weight.toInt().toString();
    }
    return weight.toStringAsFixed(1);
  }
}

/// Badge pequeño para mostrar junto al nombre del ejercicio
/// 
/// Muestra estado de confirmación cuando aplica (1/2, 2/2)
class ProgressionBadge extends StatelessWidget {
  final ProgressionDecision decision;
  final int? confirmationStep; // 1 = esperando confirmación, 2 = confirmado
  
  const ProgressionBadge({
    super.key,
    required this.decision,
    this.confirmationStep,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getColor(decision.action);
    final icon = _getIcon(decision.action);
    final isConfirming = decision.reason.contains('1/2') || 
                         decision.reason.contains('Confirmando');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            _getShortLabel(decision.action, isConfirming),
            style: GoogleFonts.montserrat(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(ProgressionAction action) {
    switch (action) {
      case ProgressionAction.increaseWeight:
        return Colors.green[400]!;
      case ProgressionAction.increaseReps:
        return Colors.blue[400]!;
      case ProgressionAction.maintain:
        return Colors.amber[400]!;
      case ProgressionAction.decreaseWeight:
      case ProgressionAction.decreaseReps:
        return Colors.orange[400]!;
    }
  }

  IconData _getIcon(ProgressionAction action) {
    switch (action) {
      case ProgressionAction.increaseWeight:
        return Icons.arrow_upward_rounded;
      case ProgressionAction.increaseReps:
        return Icons.add;
      case ProgressionAction.maintain:
        return Icons.sync_rounded; // Mejor icono para "repitiendo"
      case ProgressionAction.decreaseWeight:
      case ProgressionAction.decreaseReps:
        return Icons.arrow_downward_rounded;
    }
  }

  String _getShortLabel(ProgressionAction action, bool isConfirming) {
    switch (action) {
      case ProgressionAction.increaseWeight:
        return '+KG ✓';
      case ProgressionAction.increaseReps:
        return '+REP';
      case ProgressionAction.maintain:
        // Mostrar estado de confirmación si aplica
        return isConfirming ? '1/2' : 'REPITE';
      case ProgressionAction.decreaseWeight:
        return 'DELOAD';
      case ProgressionAction.decreaseReps:
        return '-REP';
    }
  }
}

/// Tooltip expandido con información completa de progresión
class ProgressionInfoTooltip extends StatelessWidget {
  final ProgressionDecision decision;
  final ExerciseProgressionContext? context;
  
  const ProgressionInfoTooltip({
    super.key,
    required this.decision,
    this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Text(
            '¿POR QUÉ ESTA SUGERENCIA?',
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: Colors.grey[500],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Razón técnica
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  decision.reason,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Confianza
          Row(
            children: [
              Icon(
                _getConfidenceIcon(decision.confidence),
                size: 16,
                color: _getConfidenceColor(decision.confidence),
              ),
              const SizedBox(width: 8),
              Text(
                'Confianza: ${_getConfidenceLabel(decision.confidence)}',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: _getConfidenceColor(decision.confidence),
                ),
              ),
            ],
          ),
          
          // Contexto adicional si existe
          if (this.context != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.grey),
            const SizedBox(height: 12),
            
            Text(
              'HISTORIAL',
              style: GoogleFonts.montserrat(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              '${this.context!.recentSessions.length} sesiones analizadas',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: Colors.grey[400],
              ),
            ),
            Text(
              '${this.context!.consecutiveSuccesses} éxitos consecutivos',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: this.context!.consecutiveSuccesses > 0 
                    ? Colors.green[400] 
                    : Colors.grey[400],
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getConfidenceIcon(ProgressionConfidence conf) {
    switch (conf) {
      case ProgressionConfidence.high:
        return Icons.verified_rounded;
      case ProgressionConfidence.medium:
        return Icons.check_circle_outline_rounded;
      case ProgressionConfidence.low:
        return Icons.help_outline_rounded;
    }
  }

  Color _getConfidenceColor(ProgressionConfidence conf) {
    switch (conf) {
      case ProgressionConfidence.high:
        return Colors.green[400]!;
      case ProgressionConfidence.medium:
        return Colors.amber[400]!;
      case ProgressionConfidence.low:
        return Colors.grey[400]!;
    }
  }

  String _getConfidenceLabel(ProgressionConfidence conf) {
    switch (conf) {
      case ProgressionConfidence.high:
        return 'Alta';
      case ProgressionConfidence.medium:
        return 'Media';
      case ProgressionConfidence.low:
        return 'Baja (pocos datos)';
    }
  }
}

/// Widget que muestra el progreso de la sesión actual en tiempo real
/// 
/// Muestra: ✅ ✅ ✅ ⬜ (75%) - Meta: 80%
/// El usuario sabe si va bien ANTES de terminar
class SessionProgressIndicator extends StatelessWidget {
  final List<bool> setsCompleted; // true = serie completada con éxito
  final int successThreshold; // % necesario para éxito (default 80)
  
  const SessionProgressIndicator({
    super.key,
    required this.setsCompleted,
    this.successThreshold = 80,
  });

  @override
  Widget build(BuildContext context) {
    if (setsCompleted.isEmpty) return const SizedBox.shrink();
    
    final completed = setsCompleted.where((s) => s).length;
    final total = setsCompleted.length;
    final percent = (completed / total * 100).round();
    final isSuccess = percent >= successThreshold;
    final setsNeeded = ((successThreshold / 100) * total).ceil() - completed;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuccess ? Colors.green[700]! : Colors.grey[700]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicadores de series
          ...setsCompleted.asMap().entries.map((entry) {
            final isDone = entry.value;
            return Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(
                isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 14,
                color: isDone ? Colors.green[400] : Colors.grey[600],
              ),
            );
          }),
          
          const SizedBox(width: 6),
          
          // Porcentaje
          Text(
            '$percent%',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSuccess ? Colors.green[400] : Colors.grey[400],
            ),
          ),
          
          // Mensaje de ayuda
          if (!isSuccess && setsNeeded > 0) ...[
            const SizedBox(width: 6),
            Text(
              '(faltan $setsNeeded)',
              style: GoogleFonts.montserrat(
                fontSize: 9,
                color: Colors.grey[500],
              ),
            ),
          ],
          
          if (isSuccess) ...[
            const SizedBox(width: 4),
            Icon(Icons.check, size: 12, color: Colors.green[400]),
          ],
        ],
      ),
    );
  }
}

/// Widget compacto que muestra "protección" cuando hay un día malo
class ProtectionBadge extends StatelessWidget {
  const ProtectionBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue[900]?.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue[700]!.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 10, color: Colors.blue[400]),
          const SizedBox(width: 3),
          Text(
            'PROTEGIDO',
            style: GoogleFonts.montserrat(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: Colors.blue[400],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget que muestra el incremento específico del ejercicio
class IncrementInfoBadge extends StatelessWidget {
  final double increment;
  final String categoryLabel;
  
  const IncrementInfoBadge({
    super.key,
    required this.increment,
    required this.categoryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_circle_outline, size: 10, color: Colors.grey[500]),
          const SizedBox(width: 3),
          Text(
            '+${_formatWeight(increment)}kg',
            style: GoogleFonts.montserrat(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatWeight(double weight) {
    if (weight == weight.roundToDouble()) {
      return weight.toInt().toString();
    }
    return weight.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }
}
