import '../../utils/design_system.dart';
import 'package:flutter/material.dart';
import '../../utils/performance_utils.dart';

/// Skeleton loaders optimizados para Juan Training
///
/// Características:
/// - Animación shimmer eficiente (un solo AnimationController)
/// - Respeta PerformanceMode (sin animación si reduceAnimations)
/// - Widgets const donde posible
/// - Colores del tema oscuro gym

// ============================================================================
// SHIMMER ANIMATION PROVIDER
// ============================================================================

/// Provider global de animación shimmer para evitar múltiples controllers
class ShimmerController extends StatefulWidget {
  final Widget child;

  const ShimmerController({super.key, required this.child});

  static ShimmerControllerState? of(BuildContext context) {
    return context.findAncestorStateOfType<ShimmerControllerState>();
  }

  @override
  State<ShimmerController> createState() => ShimmerControllerState();
}

class ShimmerControllerState extends State<ShimmerController>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  Animation<double> get animation => _animation;

  @override
  void initState() {
    super.initState();

    // No animar si está en modo performance
    final shouldAnimate = !PerformanceMode.instance.reduceAnimations;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (shouldAnimate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ============================================================================
// BASE SKELETON WIDGET
// ============================================================================

/// Base skeleton widget con shimmer effect
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final shimmer = ShimmerController.of(context);
    final base = baseColor ?? AppColors.bgElevated!;
    final highlight = highlightColor ?? AppColors.bgDeep!;

    // Sin animación en modo performance
    if (PerformanceMode.instance.reduceAnimations || shimmer == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: shimmer.animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: [
                _clamp(shimmer.animation.value - 0.3),
                _clamp(shimmer.animation.value),
                _clamp(shimmer.animation.value + 0.3),
              ],
            ),
          ),
        );
      },
    );
  }

  double _clamp(double value) => value.clamp(0.0, 1.0);
}

/// Skeleton circular (para avatares/imágenes)
class SkeletonCircle extends StatelessWidget {
  final double size;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonCircle({
    super.key,
    required this.size,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final shimmer = ShimmerController.of(context);
    final base = baseColor ?? AppColors.bgElevated!;
    final highlight = highlightColor ?? AppColors.bgDeep!;

    // Sin animación en modo performance
    if (PerformanceMode.instance.reduceAnimations || shimmer == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: base,
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedBuilder(
      animation: shimmer.animation,
      builder: (context, child) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: [
                _clamp(shimmer.animation.value - 0.3),
                _clamp(shimmer.animation.value),
                _clamp(shimmer.animation.value + 0.3),
              ],
            ),
          ),
        );
      },
    );
  }

  double _clamp(double value) => value.clamp(0.0, 1.0);
}

// ============================================================================
// EXERCISE SKELETONS
// ============================================================================

/// Skeleton para un item de ejercicio en lista
class ExerciseListItemSkeleton extends StatelessWidget {
  final double height;

  const ExerciseListItemSkeleton({
    super.key,
    this.height = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.bgElevated!),
        ),
      ),
      child: Row(
        children: [
          // Imagen skeleton
          SkeletonBox(
            width: height - 16,
            height: height - 16,
            borderRadius: 8,
          ),
          const SizedBox(width: 12),
          // Texto skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonBox(
                  width: 150,
                  height: 14,
                  borderRadius: 4,
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    SkeletonBox(width: 60, height: 18, borderRadius: 4),
                    SizedBox(width: 6),
                    SkeletonBox(width: 50, height: 18, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
          // Icono skeleton
          const SkeletonCircle(size: 24),
        ],
      ),
    );
  }
}

/// Lista skeleton para biblioteca de ejercicios
class ExerciseListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ExerciseListSkeleton({
    super.key,
    this.itemCount = 8,
    this.itemHeight = 72,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerController(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) => ExerciseListItemSkeleton(
          height: itemHeight,
        ),
      ),
    );
  }
}

// ============================================================================
// SESSION SKELETONS
// ============================================================================

/// Skeleton para una card de ejercicio en sesión
class ExerciseCardSkeleton extends StatelessWidget {
  const ExerciseCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDeep!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const SkeletonCircle(size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 120, height: 16, borderRadius: 4),
                    SizedBox(height: 4),
                    SkeletonBox(width: 80, height: 12, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Sets skeleton
          ...List.generate(
            3,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: const [
                  SkeletonCircle(size: 28),
                  SizedBox(width: 8),
                  SkeletonBox(width: 52, height: 40, borderRadius: 6),
                  SizedBox(width: 8),
                  Expanded(child: SkeletonBox(width: 70, height: 44, borderRadius: 8)),
                  SizedBox(width: 8),
                  Expanded(child: SkeletonBox(width: 70, height: 44, borderRadius: 8)),
                  SizedBox(width: 8),
                  SkeletonBox(width: 40, height: 40, borderRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton para la pantalla de entrenamiento completa
class TrainingSessionSkeleton extends StatelessWidget {
  const TrainingSessionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerController(
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          // Progress bar skeleton
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SkeletonBox(width: double.infinity, height: 24, borderRadius: 12),
          ),
          // Exercise cards
          ExerciseCardSkeleton(),
          ExerciseCardSkeleton(),
          ExerciseCardSkeleton(),
        ],
      ),
    );
  }
}

// ============================================================================
// RUTINA SKELETONS
// ============================================================================

/// Skeleton para una card de rutina
class RutinaCardSkeleton extends StatelessWidget {
  const RutinaCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgElevated!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: SkeletonBox(width: 150, height: 20, borderRadius: 4),
              ),
              const SizedBox(width: 16),
              const SkeletonBox(width: 60, height: 24, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              SkeletonBox(width: 80, height: 28, borderRadius: 14),
              SkeletonBox(width: 100, height: 28, borderRadius: 14),
              SkeletonBox(width: 70, height: 28, borderRadius: 14),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lista skeleton para rutinas
class RutinasListSkeleton extends StatelessWidget {
  final int itemCount;

  const RutinasListSkeleton({
    super.key,
    this.itemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerController(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8),
        itemCount: itemCount,
        itemBuilder: (context, index) => const RutinaCardSkeleton(),
      ),
    );
  }
}

// ============================================================================
// HISTORY SKELETONS
// ============================================================================

/// Skeleton para un item de historial
class HistoryItemSkeleton extends StatelessWidget {
  const HistoryItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Fecha
          Column(
            children: const [
              SkeletonBox(width: 40, height: 32, borderRadius: 4),
              SizedBox(height: 4),
              SkeletonBox(width: 30, height: 14, borderRadius: 4),
            ],
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 120, height: 16, borderRadius: 4),
                SizedBox(height: 8),
                SkeletonBox(width: 200, height: 12, borderRadius: 4),
              ],
            ),
          ),
          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              SkeletonBox(width: 50, height: 16, borderRadius: 4),
              SizedBox(height: 4),
              SkeletonBox(width: 40, height: 12, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lista skeleton para historial
class HistoryListSkeleton extends StatelessWidget {
  final int itemCount;

  const HistoryListSkeleton({
    super.key,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerController(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8),
        itemCount: itemCount,
        itemBuilder: (context, index) => const HistoryItemSkeleton(),
      ),
    );
  }
}

// ============================================================================
// UTILITY
// ============================================================================

/// Wrapper para fácil uso de shimmer en cualquier widget
class Shimmer extends StatelessWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ShimmerController(child: child);
  }
}
