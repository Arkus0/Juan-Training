import '../../utils/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/progression_engine_models.dart';

// ════════════════════════════════════════════════════════════════════════════
// CONSECUENCIA MESSAGE - WIDGET PRINCIPAL DE UX
// ════════════════════════════════════════════════════════════════════════════
// 
// Filosofía UX (de PROGRESSION_USER_EXPERIENCE.md):
// - Mostrar CONSECUENCIAS, no métricas
// - "Si lo logras: +2.5kg" en vez de "Incremento: 2.5kg"
// - Verde sutil, nunca rojo (UX_UI_REDESIGN_GUIDE)
// ════════════════════════════════════════════════════════════════════════════

/// Widget de consecuencia clara: "Si lo logras: siguiente vez 82.5kg"
/// 
/// Estados según documento UX:
/// - Normal: "Si lo logras: +2.5kg"  
/// - Confirmando: "Repite para confirmar subida"
/// - Deload: "Peso reducido para recuperar"
/// - Día difícil: "No pasa nada. Completa lo que puedas."
class ConsequenceMessage extends StatelessWidget {
  final ProgressionDecision decision;
  final bool showIcon;
  
  const ConsequenceMessage({
    super.key,
    required this.decision,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final message = _buildMessage();
    final (bgColor, iconColor) = _getColors();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(_getIcon(), size: 14, color: iconColor),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              message,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _buildMessage() {
    final isConfirming = decision.reason.contains('1/2') || 
                         decision.reason.contains('Confirmando') ||
                         decision.reason.contains('confirmando');
    
    switch (decision.action) {
      case ProgressionAction.increaseWeight:
        final weight = _formatWeight(decision.suggestedWeight);
        return 'Si éxito: ${weight}kg';
      
      case ProgressionAction.increaseReps:
        return 'Siguiente: ${decision.suggestedReps} reps';
      
      case ProgressionAction.maintain:
        if (isConfirming) {
          return 'Repite para confirmar subida';
        }
        return 'Mismo objetivo hoy';
      
      case ProgressionAction.decreaseWeight:
        return 'Peso reducido para recuperar';
      
      case ProgressionAction.decreaseReps:
        return 'Consolidando base';
    }
  }
  
  (Color, Color) _getColors() {
    switch (decision.action) {
      case ProgressionAction.increaseWeight:
      case ProgressionAction.increaseReps:
        // Verde sutil (no rojo) - UX_UI guidelines
        return (
          Colors.green.withValues(alpha: 0.1),
          AppColors.neonCyan!,
        );
      case ProgressionAction.maintain:
        return (
          AppColors.bgElevated!.withValues(alpha: 0.5),
          AppColors.textSecondary!,
        );
      case ProgressionAction.decreaseWeight:
      case ProgressionAction.decreaseReps:
        // Naranja para deload (no rojo = no error)
        return (
          Colors.orange.withValues(alpha: 0.1),
          AppColors.warning!,
        );
    }
  }
  
  IconData _getIcon() {
    switch (decision.action) {
      case ProgressionAction.increaseWeight:
        return Icons.check_circle_outline;
      case ProgressionAction.increaseReps:
        return Icons.add_circle_outline;
      case ProgressionAction.maintain:
        return Icons.sync_rounded;
      case ProgressionAction.decreaseWeight:
      case ProgressionAction.decreaseReps:
        return Icons.flash_on_rounded;
    }
  }
  
  String _formatWeight(double weight) {
    if (weight == weight.roundToDouble()) {
      return weight.toInt().toString();
    }
    return weight.toStringAsFixed(1);
  }
}

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
    // En modo compacto, usar el nuevo ConsequenceMessage
    if (compact) {
      return GestureDetector(
        onTap: onTap,
        child: ConsequenceMessage(decision: decision),
      );
    }
    
    final (bgColor, borderColor, iconColor) = _getColors(decision);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: _buildFull(iconColor),
      ),
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
                color: AppColors.textSecondary,
              ),
            ),
            if (decision.isImprovement) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.neonCyanSubtle?.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '↑ MEJORA',
                  style: GoogleFonts.montserrat(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: AppColors.neonCyan,
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
            color: AppColors.textSecondary,
          ),
        ),
        
        // Preview del siguiente paso
        if (decision.nextStepPreview != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.next_plan_outlined, size: 12, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  decision.nextStepPreview!,
                  style: GoogleFonts.montserrat(
                    fontSize: 9,
                    color: AppColors.textTertiary,
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
          AppColors.neonCyanSubtle!.withValues(alpha: 0.2),
          AppColors.success!,
          AppColors.neonCyan!,
        );
      case ProgressionAction.increaseReps:
        return (
          AppColors.info!.withValues(alpha: 0.2),
          AppColors.info!,
          AppColors.info!,
        );
      case ProgressionAction.maintain:
        return (
          AppColors.bgElevated!,
          AppColors.border!,
          AppColors.warning!,
        );
      case ProgressionAction.decreaseWeight:
      case ProgressionAction.decreaseReps:
        return (
          AppColors.goldAccent!.withValues(alpha: 0.2),
          AppColors.goldAccent!,
          AppColors.warning!,
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
        return AppColors.neonCyan!;
      case ProgressionAction.increaseReps:
        return AppColors.info!;
      case ProgressionAction.maintain:
        return AppColors.warning!;
      case ProgressionAction.decreaseWeight:
      case ProgressionAction.decreaseReps:
        return AppColors.warning!;
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
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border!),
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
              color: AppColors.textTertiary,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Razón técnica
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 16, color: AppColors.textSecondary),
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
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              '${this.context!.recentSessions.length} sesiones analizadas',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${this.context!.consecutiveSuccesses} éxitos consecutivos',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: this.context!.consecutiveSuccesses > 0 
                    ? AppColors.neonCyan 
                    : AppColors.textSecondary,
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
        return AppColors.neonCyan!;
      case ProgressionConfidence.medium:
        return AppColors.warning!;
      case ProgressionConfidence.low:
        return AppColors.textSecondary!;
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
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSuccess ? AppColors.success! : AppColors.border!,
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
                color: isDone ? AppColors.neonCyan : AppColors.textTertiary,
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
              color: isSuccess ? AppColors.neonCyan : AppColors.textSecondary,
            ),
          ),
          
          // Mensaje de ayuda
          if (!isSuccess && setsNeeded > 0) ...[
            const SizedBox(width: 6),
            Text(
              '(faltan $setsNeeded)',
              style: GoogleFonts.montserrat(
                fontSize: 9,
                color: AppColors.textTertiary,
              ),
            ),
          ],
          
          if (isSuccess) ...[
            const SizedBox(width: 4),
            Icon(Icons.check, size: 12, color: AppColors.neonCyan),
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
        color: AppColors.info?.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.info!.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 10, color: AppColors.info),
          const SizedBox(width: 3),
          Text(
            'PROTEGIDO',
            style: GoogleFonts.montserrat(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: AppColors.info,
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
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_circle_outline, size: 10, color: AppColors.textTertiary),
          const SizedBox(width: 3),
          Text(
            '+${_formatWeight(increment)}kg',
            style: GoogleFonts.montserrat(
              fontSize: 8,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
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

// ════════════════════════════════════════════════════════════════════════════
// EMPATHETIC FEEDBACK - MENSAJES DE DÍAS DIFÍCILES
// ════════════════════════════════════════════════════════════════════════════
// 
// Filosofía UX (ERROR_TOLERANCE_DESIGN.md + PROGRESSION_USER_EXPERIENCE.md):
// - Nunca rojo para feedback negativo
// - Normalizar días difíciles
// - "No pasa nada" como filosofía base
// ════════════════════════════════════════════════════════════════════════════

/// Tipos de situación que requieren feedback empático
enum DifficultDayType {
  /// Las reps fueron menores al objetivo
  underperformed,
  /// El usuario falló la serie
  failedSet,
  /// El usuario saltó una sesión
  missedSession,
  /// El usuario lleva varias sesiones sin progreso
  plateau,
  /// El sistema sugiere un deload
  deloadRecommended,
}

/// Widget de feedback empático para días difíciles
/// 
/// NUNCA usa rojo - solo colores neutros
/// Mensajes de apoyo, no de juicio
class EmpatheticFeedback extends StatelessWidget {
  final DifficultDayType type;
  final String? customMessage;
  final VoidCallback? onDismiss;
  
  const EmpatheticFeedback({
    super.key,
    required this.type,
    this.customMessage,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final message = customMessage ?? _getDefaultMessage();
    final subtext = _getSubtext();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Gris cálido, nunca rojo
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Icono de apoyo, nunca de error
              Icon(
                _getIcon(),
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: Icon(Icons.close, size: 16, color: AppColors.textTertiary),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (subtext != null) ...[
            const SizedBox(height: 6),
            Text(
              subtext,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  String _getDefaultMessage() {
    switch (type) {
      case DifficultDayType.underperformed:
        return 'No pasa nada';
      case DifficultDayType.failedSet:
        return 'Ocurre, forma parte del proceso';
      case DifficultDayType.missedSession:
        return 'Retomamos donde lo dejaste';
      case DifficultDayType.plateau:
        return 'Estás consolidando';
      case DifficultDayType.deloadRecommended:
        return 'Tu cuerpo pide recuperarse';
    }
  }
  
  String? _getSubtext() {
    switch (type) {
      case DifficultDayType.underperformed:
        return 'Completa lo que puedas. La consistencia importa más.';
      case DifficultDayType.failedSet:
        return 'El próximo set puede ser diferente.';
      case DifficultDayType.missedSession:
        return 'El sistema recuerda tu progreso.';
      case DifficultDayType.plateau:
        return 'El cuerpo adapta antes de avanzar.';
      case DifficultDayType.deloadRecommended:
        return 'Descansar también es entrenar.';
    }
  }
  
  IconData _getIcon() {
    switch (type) {
      case DifficultDayType.underperformed:
        return Icons.sentiment_neutral_rounded;
      case DifficultDayType.failedSet:
        return Icons.refresh_rounded;
      case DifficultDayType.missedSession:
        return Icons.replay_rounded;
      case DifficultDayType.plateau:
        return Icons.trending_flat_rounded;
      case DifficultDayType.deloadRecommended:
        return Icons.battery_charging_full_rounded;
    }
  }
}

/// Banner compacto para mostrar arriba del ejercicio cuando hay feedback
class EmpatheticBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;
  
  const EmpatheticBanner({
    super.key,
    required this.message,
    this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgElevated!.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              message,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget para mostrar resumen post-ejercicio
/// 
/// Muestra de forma positiva lo logrado, incluso si no se alcanzó el objetivo
class ExerciseSummaryFeedback extends StatelessWidget {
  final int completedSets;
  final int targetSets;
  final int totalReps;
  final bool metTarget;
  final String? nextSessionHint;
  
  const ExerciseSummaryFeedback({
    super.key,
    required this.completedSets,
    required this.targetSets,
    required this.totalReps,
    required this.metTarget,
    this.nextSessionHint,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: metTarget 
            ? Colors.green.withValues(alpha: 0.1)
            : AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: metTarget
              ? Colors.green.withValues(alpha: 0.3)
              : AppColors.border!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icono y mensaje principal
          Row(
            children: [
              Icon(
                metTarget ? Icons.check_circle_rounded : Icons.sports_score_rounded,
                size: 20,
                color: metTarget ? AppColors.neonCyan : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                metTarget ? '¡Objetivo cumplido!' : 'Ejercicio completado',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Stats compactos
          Row(
            children: [
              _StatChip(
                label: 'Sets',
                value: '$completedSets/$targetSets',
                highlighted: completedSets >= targetSets,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Total reps',
                value: '$totalReps',
                highlighted: false,
              ),
            ],
          ),
          
          // Hint para próxima sesión
          if (nextSessionHint != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgDeep,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    nextSessionHint!,
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;
  
  const _StatChip({
    required this.label,
    required this.value,
    required this.highlighted,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted 
            ? Colors.green.withValues(alpha: 0.15)
            : AppColors.bgDeep,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 9,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: highlighted ? AppColors.neonCyan : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
