/// Performance Utilities for Juan Training App
///
/// Provides optimized widgets, extensions, and helpers to minimize
/// rebuilds, reduce jank, and improve overall app performance.
///
/// Author: Senior Flutter Architect
/// Date: 2026-01-22
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ============================================================================
// CONST WIDGET HELPERS
// ============================================================================

/// A const-friendly wrapper that isolates expensive children from parent rebuilds.
/// Use this around widgets that don't need to rebuild with their parent.
class IsolatedRebuild extends StatelessWidget {
  final Widget child;

  const IsolatedRebuild({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// RepaintBoundary wrapper with const constructor for performance isolation.
/// Use around animated or frequently updating content.
class PerformanceBoundary extends StatelessWidget {
  final Widget child;

  const PerformanceBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: child);
  }
}

/// A widget that only rebuilds its child on specific frame intervals.
/// Useful for reducing animation frame rates when 60fps isn't needed.
class ThrottledBuilder extends StatefulWidget {
  final Widget Function(BuildContext context) builder;
  final int
      frameInterval; // Rebuild every N frames (1 = 60fps, 2 = 30fps, 3 = 20fps)

  const ThrottledBuilder({
    super.key,
    required this.builder,
    this.frameInterval = 2, // Default: 30fps
  });

  @override
  State<ThrottledBuilder> createState() => _ThrottledBuilderState();
}

class _ThrottledBuilderState extends State<ThrottledBuilder>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  int _frameCount = 0;
  Widget? _cachedChild;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    _frameCount++;
    if (_frameCount >= widget.frameInterval) {
      _frameCount = 0;
      if (mounted) {
        setState(() {
          _cachedChild = null; // Force rebuild
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _cachedChild ??= widget.builder(context);
    return _cachedChild!;
  }
}

// ============================================================================
// DEBOUNCE & THROTTLE UTILITIES
// ============================================================================

/// Debouncer for reducing frequency of expensive operations.
/// Perfect for search inputs, save operations, etc.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 300)});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}

/// Throttler for limiting frequency of operations.
/// Unlike debounce, this executes immediately then waits.
class Throttler {
  final Duration interval;
  DateTime? _lastRun;
  Timer? _pendingTimer;
  VoidCallback? _pendingAction;

  Throttler({this.interval = const Duration(milliseconds: 100)});

  void run(VoidCallback action) {
    final now = DateTime.now();

    if (_lastRun == null || now.difference(_lastRun!) >= interval) {
      _lastRun = now;
      action();
    } else {
      // Schedule pending action for when throttle expires
      _pendingAction = action;
      _pendingTimer?.cancel();
      _pendingTimer = Timer(
        interval - now.difference(_lastRun!),
        () {
          _lastRun = DateTime.now();
          _pendingAction?.call();
          _pendingAction = null;
        },
      );
    }
  }

  void cancel() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _pendingAction = null;
  }

  void dispose() => cancel();
}

// ============================================================================
// MEMOIZATION HELPERS
// ============================================================================

/// Simple memoization cache with optional expiration.
class MemoCache<K, V> {
  final Map<K, _MemoEntry<V>> _cache = {};
  final Duration? expiration;

  MemoCache({this.expiration});

  V getOrCompute(K key, V Function() compute) {
    final existing = _cache[key];
    final now = DateTime.now();

    if (existing != null) {
      if (expiration == null ||
          now.difference(existing.timestamp) < expiration!) {
        return existing.value;
      }
    }

    final value = compute();
    _cache[key] = _MemoEntry(value, now);
    return value;
  }

  void invalidate(K key) => _cache.remove(key);

  void clear() => _cache.clear();
}

class _MemoEntry<V> {
  final V value;
  final DateTime timestamp;

  _MemoEntry(this.value, this.timestamp);
}

// ============================================================================
// LAZY BUILDER
// ============================================================================

/// Builds child lazily only when it becomes visible.
/// Reduces initial layout/paint cost for complex widgets.
class LazyBuilder extends StatefulWidget {
  final WidgetBuilder builder;
  final Widget placeholder;
  final Duration delay;

  const LazyBuilder({
    super.key,
    required this.builder,
    this.placeholder = const SizedBox.shrink(),
    this.delay = Duration.zero,
  });

  @override
  State<LazyBuilder> createState() => _LazyBuilderState();
}

class _LazyBuilderState extends State<LazyBuilder> {
  bool _isBuilt = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isBuilt = true);
      });
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) setState(() => _isBuilt = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isBuilt ? widget.builder(context) : widget.placeholder;
  }
}

// ============================================================================
// PERFORMANCE EXTENSIONS
// ============================================================================

extension PerformanceExtensions on Widget {
  /// Wraps widget in RepaintBoundary for paint isolation.
  Widget isolated() => RepaintBoundary(child: this);

  /// Wraps widget in KeyedSubtree for efficient list rebuilds.
  Widget keyed(Key key) => KeyedSubtree(key: key, child: this);
}

extension ListPerformanceExtensions<T> on List<T> {
  /// Creates a paginated view of the list.
  List<T> paginate(int page, int pageSize) {
    final start = page * pageSize;
    if (start >= length) return [];
    final end = (start + pageSize).clamp(0, length);
    return sublist(start, end);
  }
}

// ============================================================================
// PERFORMANCE MODE STATE
// ============================================================================

/// Global performance mode settings.
/// Access via PerformanceMode.instance
class PerformanceMode {
  static final PerformanceMode instance = PerformanceMode._();
  PerformanceMode._();

  /// When true, reduces animation complexity
  bool reduceAnimations = false;

  /// When true, disables non-essential vibrations
  bool reduceVibrations = false;

  /// When true, uses lower FPS for non-critical animations
  bool useLowPowerMode = false;

  /// Timer ticker interval (higher = less frequent updates)
  Duration get timerTickInterval => useLowPowerMode
      ? const Duration(milliseconds: 250)
      : const Duration(milliseconds: 100);

  /// Animation duration multiplier
  double get animationScale => reduceAnimations ? 0.5 : 1.0;

  /// Whether to show complex shadows
  bool get showShadows => !reduceAnimations;

  /// Notifier for performance mode changes
  final ValueNotifier<bool> modeNotifier = ValueNotifier(false);

  void setPerformanceMode({required bool enabled}) {
    reduceAnimations = enabled;
    reduceVibrations = enabled;
    useLowPowerMode = enabled;
    modeNotifier.value = enabled;
  }

  void toggle() => setPerformanceMode(enabled: !reduceAnimations);
}

// ============================================================================
// OPTIMIZED LIST HELPERS
// ============================================================================

/// Configuration for optimized list views.
class OptimizedListConfig {
  /// Use this for long lists (100+ items)
  static const ScrollPhysics smoothPhysics = BouncingScrollPhysics(
    decelerationRate: ScrollDecelerationRate.fast,
  );

  /// Default cache extent for ListView.builder
  static const double cacheExtent = 250.0;

  /// Semantic child count for accessibility
  static const bool addSemanticIndexes = true;
}

/// Creates a ScrollController optimized for performance.
ScrollController createOptimizedScrollController() {
  return ScrollController(
    debugLabel: 'OptimizedScrollController',
  );
}

// ============================================================================
// FRAME CALLBACK UTILITIES
// ============================================================================

/// Schedules a callback after the current frame completes.
/// Use instead of raw addPostFrameCallback for clarity.
void afterFrame(VoidCallback callback) {
  SchedulerBinding.instance.addPostFrameCallback((_) => callback());
}

/// Schedules a callback for the next idle period.
/// Use for non-urgent background tasks.
void whenIdle(VoidCallback callback) {
  SchedulerBinding.instance.scheduleTask(callback, Priority.idle);
}

/// Schedules a callback at animation priority.
void atAnimationPriority(VoidCallback callback) {
  SchedulerBinding.instance.scheduleTask(callback, Priority.animation);
}
