import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/progression_engine_models.dart';
import '../../utils/design_system.dart';

// ════════════════════════════════════════════════════════════════════════════
// PROGRESSION UX WIDGETS
// ════════════════════════════════════════════════════════════════════════════
// 
// Widgets diseñados desde la experiencia del usuario:
// - Mínima información
// - Máxima claridad
// - Consecuencias visibles
// ════════════════════════════════════════════════════════════════════════════

/// Widget principal: Muestra el peso objetivo con consecuencia clara
class ExerciseTargetCard extends StatelessWidget {
  final double weight;
  final int reps;
  final int sets;
  final String? consequenceText;
  final VoidCallback? onStart;
  final VoidCallback? onAdjustWeight;
  
  const ExerciseTargetCard({
    super.key,
    required this.weight,
    required this.reps,
    this.sets = 3,
    this.consequenceText,
    this.onStart,
    this.onAdjustWeight,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Peso principal (grande y claro)
            GestureDetector(
              onTap: onAdjustWeight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatWeight(weight),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '× $reps reps',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                      ),
                    ),
                    if (sets > 1) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$sets series',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Consecuencia (si existe)
            if (consequenceText != null) ...[
              const SizedBox(height: 16),
              ConsequenceChip(text: consequenceText!),
            ],
            
            // Botón empezar
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('EMPEZAR'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(200, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatWeight(double w) {
    return w == w.roundToDouble() ? '${w.toInt()} kg' : '${w.toStringAsFixed(1)} kg';
  }
}

/// Chip de consecuencia: "Si lo logras: +2.5kg"
class ConsequenceChip extends StatelessWidget {
  final String text;
  final bool isPositive;
  
  const ConsequenceChip({
    super.key,
    required this.text,
    this.isPositive = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // 🎯 NEON IRON: Usar cyan para feedback positivo
        color: isPositive 
            ? AppColors.success.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPositive 
              ? AppColors.success.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPositive ? Icons.check_circle_outline : Icons.info_outline,
            size: 18,
            color: isPositive ? AppColors.success : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isPositive ? AppColors.neonCyanDark : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget de serie activa: Mínimo, solo lo necesario
class ActiveSetWidget extends StatelessWidget {
  final int currentSet;
  final int totalSets;
  final double weight;
  final int targetReps;
  final ValueChanged<int> onRepsCompleted;
  
  const ActiveSetWidget({
    super.key,
    required this.currentSet,
    required this.totalSets,
    required this.weight,
    required this.targetReps,
    required this.onRepsCompleted,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de serie
            Text(
              'SERIE $currentSet de $totalSets',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Peso y reps objetivo
            Text(
              _formatWeight(weight),
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '× $targetReps reps',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Selector de reps completadas
            _RepsSelector(
              targetReps: targetReps,
              onSelected: onRepsCompleted,
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatWeight(double w) {
    return w == w.roundToDouble() ? '${w.toInt()} kg' : '${w.toStringAsFixed(1)} kg';
  }
}

/// Selector de reps: Números táctiles grandes
class _RepsSelector extends StatefulWidget {
  final int targetReps;
  final ValueChanged<int> onSelected;
  
  const _RepsSelector({
    required this.targetReps,
    required this.onSelected,
  });
  
  @override
  State<_RepsSelector> createState() => _RepsSelectorState();
}

class _RepsSelectorState extends State<_RepsSelector> {
  int? _selectedReps;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Mostrar reps desde target-3 hasta target+2
    final minReps = (widget.targetReps - 3).clamp(0, widget.targetReps);
    final maxReps = widget.targetReps + 2;
    final repsOptions = List.generate(maxReps - minReps + 1, (i) => minReps + i);
    
    return Column(
      children: [
        Text(
          'REPS COMPLETADAS',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: repsOptions.map((reps) {
            final isTarget = reps == widget.targetReps;
            final isSelected = _selectedReps == reps;
            final isBelowTarget = reps < widget.targetReps;
            
            return _RepButton(
              reps: reps,
              isTarget: isTarget,
              isSelected: isSelected,
              isBelowTarget: isBelowTarget,
              onTap: () {
                setState(() => _selectedReps = reps);
                HapticFeedback.lightImpact();
              },
            );
          }).toList(),
        ),
        
        const SizedBox(height: 24),
        
        // Botón confirmar
        AnimatedOpacity(
          opacity: _selectedReps != null ? 1.0 : 0.3,
          duration: const Duration(milliseconds: 200),
          child: FilledButton.icon(
            onPressed: _selectedReps != null 
                ? () => widget.onSelected(_selectedReps!)
                : null,
            icon: const Icon(Icons.check),
            label: const Text('LISTO'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(160, 48),
            ),
          ),
        ),
      ],
    );
  }
}

class _RepButton extends StatelessWidget {
  final int reps;
  final bool isTarget;
  final bool isSelected;
  final bool isBelowTarget;
  final VoidCallback onTap;
  
  const _RepButton({
    required this.reps,
    required this.isTarget,
    required this.isSelected,
    required this.isBelowTarget,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Color backgroundColor;
    Color textColor;
    
    if (isSelected) {
      backgroundColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
    } else if (isTarget) {
      backgroundColor = theme.colorScheme.primaryContainer;
      textColor = theme.colorScheme.onPrimaryContainer;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      textColor = theme.colorScheme.onSurfaceVariant;
    }
    
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          child: Text(
            reps.toString(),
            style: theme.textTheme.titleLarge?.copyWith(
              color: textColor,
              fontWeight: isSelected || isTarget ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// Feedback después de una serie
class SetFeedbackWidget extends StatelessWidget {
  final int setNumber;
  final int repsCompleted;
  final int targetReps;
  final VoidCallback? onContinue;
  
  const SetFeedbackWidget({
    super.key,
    required this.setNumber,
    required this.repsCompleted,
    required this.targetReps,
    this.onContinue,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metTarget = repsCompleted >= targetReps;
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Resultado
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  metTarget ? Icons.check_circle : Icons.check_circle_outline,
                  // 🎯 NEON IRON: Cyan para éxito
                  color: metTarget ? AppColors.success : theme.colorScheme.onSurfaceVariant,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Serie $setNumber: $repsCompleted reps',
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            
            // Mensaje solo si no alcanzó objetivo
            if (!metTarget) ...[
              const SizedBox(height: 12),
              Text(
                'No pasa nada. Completa lo que puedas.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            TextButton(
              onPressed: onContinue,
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resumen al final del ejercicio
class ExerciseSummaryWidget extends StatelessWidget {
  final double weight;
  final List<int> repsPerSet;
  final ProgressionDecision decision;
  final VoidCallback? onNext;
  final VoidCallback? onRejectDeload;
  
  const ExerciseSummaryWidget({
    super.key,
    required this.weight,
    required this.repsPerSet,
    required this.decision,
    this.onNext,
    this.onRejectDeload,
  });
  
  @override
  Widget build(BuildContext context) {
    return _buildSummary(context, decision);
  }
  
  Widget _buildSummary(BuildContext context, ProgressionDecision decision) {
    final theme = Theme.of(context);
    
    // Determinar tipo de resumen
    final isSuccess = decision.isImprovement;
    final isDeload = decision.action == ProgressionAction.decreaseWeight;
    final isConfirmation = decision.reason.contains('Confirm');
    
    IconData icon;
    Color iconColor;
    String title;
    
    if (isSuccess && isConfirmation) {
      icon = Icons.celebration;
      // 🎯 NEON IRON: Oro Venice para celebraciones
      iconColor = AppColors.goldAccent;
      title = '¡NUEVO PESO DESBLOQUEADO!';
    } else if (isSuccess) {
      icon = Icons.check_circle;
      iconColor = AppColors.success;
      title = '¡Bien hecho!';
    } else if (isDeload) {
      icon = Icons.flash_on;
      iconColor = AppColors.warning;
      title = 'Hora de recuperar';
    } else {
      icon = Icons.check;
      iconColor = theme.colorScheme.primary;
      title = 'Completado';
    }
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono y título
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Series completadas
            Text(
              '${_formatWeight(weight)} × ${repsPerSet.join(', ')}',
              style: theme.textTheme.titleMedium,
            ),
            
            const SizedBox(height: 20),
            
            // Próximo paso
            _NextStepCard(decision: decision),
            
            // Mensaje deload si aplica
            if (isDeload) ...[
              const SizedBox(height: 12),
              Text(
                'Esto es parte del proceso.\nLos mejores atletas lo hacen.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Botones
            if (isDeload) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: onRejectDeload,
                    child: const Text('Mantener peso'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: onNext,
                    child: const Text('Aceptar'),
                  ),
                ],
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('SIGUIENTE'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  String _formatWeight(double w) {
    return w == w.roundToDouble() ? '${w.toInt()} kg' : '${w.toStringAsFixed(1)} kg';
  }
}

/// Card con el próximo paso
class _NextStepCard extends StatelessWidget {
  final ProgressionDecision decision;
  
  const _NextStepCard({required this.decision});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final isIncrease = decision.action == ProgressionAction.increaseWeight;
    final isDecrease = decision.action == ProgressionAction.decreaseWeight;
    
    IconData icon;
    Color bgColor;
    Color iconColor;
    
    if (isIncrease) {
      icon = Icons.trending_up;
      // 🎯 NEON IRON: Cyan para progreso
      bgColor = AppColors.success.withValues(alpha: 0.1);
      iconColor = AppColors.success;
    } else if (isDecrease) {
      icon = Icons.trending_down;
      bgColor = AppColors.warning.withValues(alpha: 0.1);
      iconColor = AppColors.warning;
    } else {
      icon = Icons.arrow_forward;
      bgColor = theme.colorScheme.surfaceContainerHighest;
      iconColor = theme.colorScheme.primary;
    }
    
    final weightStr = decision.suggestedWeight == decision.suggestedWeight.roundToDouble()
        ? '${decision.suggestedWeight.toInt()} kg'
        : '${decision.suggestedWeight.toStringAsFixed(1)} kg';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Próxima vez',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$weightStr × ${decision.suggestedReps} reps',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ajustador de peso (modal o inline)
class WeightAdjuster extends StatelessWidget {
  final double currentWeight;
  final double increment;
  final ValueChanged<double> onWeightChanged;
  final VoidCallback? onDismiss;
  
  const WeightAdjuster({
    super.key,
    required this.currentWeight,
    this.increment = 2.5,
    required this.onWeightChanged,
    this.onDismiss,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '⚖️ Ajustar peso',
                  style: theme.textTheme.titleMedium,
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: onDismiss,
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Sugerido: ${_formatWeight(currentWeight)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Botón menos
                FilledButton.tonal(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onWeightChanged(currentWeight - increment);
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  child: Text('-${increment.toStringAsFixed(1)}'),
                ),
                
                // Peso actual
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _formatWeight(currentWeight),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                // Botón más
                FilledButton.tonal(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onWeightChanged(currentWeight + increment);
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 48),
                  ),
                  child: Text('+${increment.toStringAsFixed(1)}'),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Text(
              'ℹ️ El sistema recordará tu ajuste',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatWeight(double w) {
    return w == w.roundToDouble() ? '${w.toInt()} kg' : '${w.toStringAsFixed(1)} kg';
  }
}

/// Indicador de progreso de serie sutil
class SeriesProgressIndicator extends StatelessWidget {
  final List<int?> completedReps; // null = no completada aún
  final int targetReps;
  
  const SeriesProgressIndicator({
    super.key,
    required this.completedReps,
    required this.targetReps,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: completedReps.asMap().entries.map((entry) {
        final _ = entry.key; // index not needed currently
        final reps = entry.value;
        final isCompleted = reps != null;
        final metTarget = reps != null && reps >= targetReps;
        
        Color color;
        IconData icon;
        
        if (!isCompleted) {
          color = theme.colorScheme.surfaceContainerHighest;
          icon = Icons.circle_outlined;
        } else if (metTarget) {
          // 🎯 NEON IRON: Cyan para éxito
          color = AppColors.success;
          icon = Icons.check_circle;
        } else {
          color = AppColors.warning;
          icon = Icons.check_circle;
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              if (isCompleted)
                Text(
                  '$reps',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
