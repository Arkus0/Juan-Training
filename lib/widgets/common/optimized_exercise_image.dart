import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/library_exercise.dart';
import '../../utils/design_system.dart';
import '../../utils/performance_utils.dart';

/// Widget optimizado para mostrar imágenes de ejercicios
///
/// Características:
/// - Lazy loading con placeholder
/// - Fade-in animado (configurable)
/// - Cache de imágenes en memoria (opcional)
/// - Soporte para assets locales y archivos descargados
/// - RepaintBoundary para aislar repaints
/// - Placeholder const para rendimiento
class OptimizedExerciseImage extends StatefulWidget {
  /// Ejercicio del cual mostrar la imagen
  final LibraryExercise exercise;

  /// Tamaño de la imagen
  final double size;

  /// Border radius
  final BorderRadius? borderRadius;

  /// Fit de la imagen
  final BoxFit fit;

  /// Si se debe mostrar el fade-in (false en modo performance)
  final bool enableFadeIn;

  /// Color de fondo del placeholder
  final Color? placeholderColor;

  const OptimizedExerciseImage({
    super.key,
    required this.exercise,
    this.size = 60,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.enableFadeIn = true,
    this.placeholderColor,
  });

  @override
  State<OptimizedExerciseImage> createState() => _OptimizedExerciseImageState();
}

class _OptimizedExerciseImageState extends State<OptimizedExerciseImage>
    with SingleTickerProviderStateMixin {
  late AnimationController? _fadeController;
  late Animation<double>? _fadeAnimation;
  bool _imageLoaded = false;
  ImageProvider? _imageProvider;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    // Solo crear animación si no está en modo performance
    final shouldAnimate =
        widget.enableFadeIn && !PerformanceMode.instance.reduceAnimations;

    if (shouldAnimate) {
      _fadeController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      );
      _fadeAnimation = CurvedAnimation(
        parent: _fadeController!,
        curve: Curves.easeIn,
      );
    } else {
      _fadeController = null;
      _fadeAnimation = null;
    }

    _loadImage();
  }

  @override
  void didUpdateWidget(OptimizedExerciseImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recargar si el ejercicio cambió
    if (oldWidget.exercise.id != widget.exercise.id) {
      _hasError = false;
      _imageLoaded = false;
      _loadImage();
    }
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    super.dispose();
  }

  void _loadImage() {
    _imageProvider = _getImageProvider();

    if (_imageProvider != null) {
      // Pre-cache la imagen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _imageProvider != null) {
          precacheImage(_imageProvider!, context).then((_) {
            if (mounted) {
              setState(() {
                _imageLoaded = true;
              });
              _fadeController?.forward();
            }
          }).catchError((_) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _imageLoaded = true;
              });
            }
          });
        }
      });
    }
  }

  ImageProvider? _getImageProvider() {
    // Primero intentar con la imagen local descargada
    if (widget.exercise.localImagePath != null &&
        widget.exercise.localImagePath!.isNotEmpty) {
      final file = File(widget.exercise.localImagePath!);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    // Luego intentar con la imagen del asset
    final assetPath = 'assets/img/ejercicios/${widget.exercise.id}.png';
    return AssetImage(assetPath);
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(8);
    final placeholderColor = widget.placeholderColor ?? AppColors.bgElevated;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: _buildContent(placeholderColor),
        ),
      ),
    );
  }

  Widget _buildContent(Color? placeholderColor) {
    // Si hay error, mostrar placeholder con icono
    if (_hasError) {
      return _ExercisePlaceholder(
        size: widget.size,
        color: placeholderColor,
        showIcon: true,
      );
    }

    // Si no se ha cargado, mostrar placeholder
    if (!_imageLoaded || _imageProvider == null) {
      return _ExercisePlaceholder(
        size: widget.size,
        color: placeholderColor,
      );
    }

    // Imagen cargada
    final imageWidget = Image(
      image: _imageProvider!,
      fit: widget.fit,
      width: widget.size,
      height: widget.size,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        return child;
      },
      errorBuilder: (context, error, stackTrace) {
        return _ExercisePlaceholder(
          size: widget.size,
          color: placeholderColor,
          showIcon: true,
        );
      },
    );

    // Si hay animación, usar fade
    if (_fadeAnimation != null) {
      return FadeTransition(
        opacity: _fadeAnimation!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Placeholder optimizado para ejercicios (const friendly)
class _ExercisePlaceholder extends StatelessWidget {
  final double size;
  final Color? color;
  final bool showIcon;

  const _ExercisePlaceholder({
    required this.size,
    this.color,
    this.showIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: color ?? AppColors.bgElevated,
      child: showIcon
          ? Icon(
              Icons.fitness_center,
              color: AppColors.border,
              size: size * 0.4,
            )
          : null,
    );
  }
}

/// Widget de imagen de ejercicio para listas (versión simplificada)
/// Útil para la biblioteca de ejercicios con 700+ items
class ExerciseListImage extends StatelessWidget {
  final int exerciseId;
  final double size;
  final BorderRadius? borderRadius;

  const ExerciseListImage({
    super.key,
    required this.exerciseId,
    this.size = 48,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = this.borderRadius ?? BorderRadius.circular(6);

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            'assets/img/ejercicios/$exerciseId.png',
            fit: BoxFit.cover,
            width: size,
            height: size,
            cacheWidth: (size * 2).round(), // Cache a 2x para retina
            cacheHeight: (size * 2).round(),
            errorBuilder: (context, error, stackTrace) {
              // Fallback al placeholder genérico
              return Container(
                width: size,
                height: size,
                color: AppColors.bgElevated,
                child: Icon(
                  Icons.fitness_center,
                  color: AppColors.border,
                  size: size * 0.4,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Cache global de imágenes de ejercicios (singleton)
/// Para mantener en memoria las imágenes más usadas
class ExerciseImageCache {
  static final ExerciseImageCache instance = ExerciseImageCache._();
  ExerciseImageCache._();

  final Map<int, ImageProvider> _cache = {};
  static const int _maxCacheSize = 50; // Máximo 50 imágenes en cache

  ImageProvider? get(int exerciseId) => _cache[exerciseId];

  void put(int exerciseId, ImageProvider provider) {
    // LRU simple: si llegamos al límite, limpiamos el más antiguo
    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[exerciseId] = provider;
  }

  void clear() => _cache.clear();

  int get size => _cache.length;
}
