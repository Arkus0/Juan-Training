/// Performance Profiler for Juan Training App
///
/// Utilities for measuring and debugging performance issues.
/// Use these tools with Flutter DevTools for comprehensive analysis.
///
/// Author: Senior Flutter Architect
/// Date: 2026-01-22
library;

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

// ============================================================================
// FRAME TIMING
// ============================================================================

/// Measures frame rendering time and logs jank.
/// Enable in debug mode to identify slow frames.
class FrameTimeProfiler {
  static FrameTimeProfiler? _instance;
  static FrameTimeProfiler get instance => _instance ??= FrameTimeProfiler._();

  FrameTimeProfiler._();

  bool _isEnabled = false;
  int _jankyFrameCount = 0;
  int _totalFrameCount = 0;
  final List<double> _frameTimes = [];

  /// Threshold in milliseconds for a "janky" frame (>16.67ms = <60fps)
  static const double _jankThreshold = 16.67;

  /// Start profiling frames
  void start() {
    if (_isEnabled) return;
    _isEnabled = true;

    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
    debugPrint('🔍 FrameTimeProfiler: Started');
  }

  /// Stop profiling frames
  void stop() {
    if (!_isEnabled) return;
    _isEnabled = false;

    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _printSummary();
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _totalFrameCount++;

      final buildDuration = timing.buildDuration.inMicroseconds / 1000.0;
      final rasterDuration = timing.rasterDuration.inMicroseconds / 1000.0;
      final totalDuration = timing.totalSpan.inMicroseconds / 1000.0;

      _frameTimes.add(totalDuration);

      if (totalDuration > _jankThreshold) {
        _jankyFrameCount++;
        if (kDebugMode) {
          debugPrint(
            '⚠️ Janky frame #$_totalFrameCount: '
            'build=${buildDuration.toStringAsFixed(2)}ms, '
            'raster=${rasterDuration.toStringAsFixed(2)}ms, '
            'total=${totalDuration.toStringAsFixed(2)}ms',
          );
        }
      }
    }
  }

  void _printSummary() {
    if (_frameTimes.isEmpty) {
      debugPrint('🔍 FrameTimeProfiler: No frames recorded');
      return;
    }

    final avgTime = _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
    final maxTime = _frameTimes.reduce((a, b) => a > b ? a : b);
    final jankPercent = (_jankyFrameCount / _totalFrameCount * 100);

    debugPrint('''
📊 FrameTimeProfiler Summary:
   Total frames: $_totalFrameCount
   Janky frames: $_jankyFrameCount (${jankPercent.toStringAsFixed(1)}%)
   Avg frame time: ${avgTime.toStringAsFixed(2)}ms
   Max frame time: ${maxTime.toStringAsFixed(2)}ms
   Target: <16.67ms (60fps)
''');
  }

  /// Reset statistics
  void reset() {
    _jankyFrameCount = 0;
    _totalFrameCount = 0;
    _frameTimes.clear();
  }

  /// Get current statistics
  Map<String, dynamic> get stats => {
        'totalFrames': _totalFrameCount,
        'jankyFrames': _jankyFrameCount,
        'jankPercent': _totalFrameCount > 0
            ? (_jankyFrameCount / _totalFrameCount * 100)
            : 0,
        'avgFrameTime': _frameTimes.isNotEmpty
            ? _frameTimes.reduce((a, b) => a + b) / _frameTimes.length
            : 0,
      };
}

// ============================================================================
// METHOD TIMING
// ============================================================================

/// Measures execution time of code blocks.
class MethodProfiler {
  static final Map<String, _MethodStats> _stats = {};

  /// Time a synchronous operation
  static T sync<T>(String name, T Function() operation) {
    final stopwatch = Stopwatch()..start();
    try {
      return operation();
    } finally {
      stopwatch.stop();
      _recordTime(name, stopwatch.elapsedMicroseconds / 1000.0);
    }
  }

  /// Time an asynchronous operation
  static Future<T> async<T>(String name, Future<T> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await operation();
    } finally {
      stopwatch.stop();
      _recordTime(name, stopwatch.elapsedMicroseconds / 1000.0);
    }
  }

  static void _recordTime(String name, double ms) {
    _stats.putIfAbsent(name, () => _MethodStats());
    _stats[name]!.record(ms);

    if (kDebugMode && ms > 16.67) {
      debugPrint('⏱️ $name: ${ms.toStringAsFixed(2)}ms (slow!)');
    }
  }

  /// Print summary of all recorded methods
  static void printSummary() {
    debugPrint('\n📊 MethodProfiler Summary:');
    debugPrint(
        '${'Name'.padRight(30)} ${'Count'.padLeft(8)} ${'Avg(ms)'.padLeft(10)} ${'Max(ms)'.padLeft(10)}',);
    debugPrint('-' * 60);

    final entries = _stats.entries.toList()
      ..sort((a, b) => b.value.avgTime.compareTo(a.value.avgTime));

    for (final entry in entries) {
      debugPrint(
        '${entry.key.padRight(30)} '
        '${entry.value.count.toString().padLeft(8)} '
        '${entry.value.avgTime.toStringAsFixed(2).padLeft(10)} '
        '${entry.value.maxTime.toStringAsFixed(2).padLeft(10)}',
      );
    }
  }

  /// Clear all recorded statistics
  static void clear() => _stats.clear();
}

class _MethodStats {
  int count = 0;
  double totalTime = 0;
  double maxTime = 0;

  void record(double ms) {
    count++;
    totalTime += ms;
    if (ms > maxTime) maxTime = ms;
  }

  double get avgTime => count > 0 ? totalTime / count : 0;
}

// ============================================================================
// REBUILD COUNTER
// ============================================================================

/// Counts widget rebuilds for debugging excessive rebuilds.
class RebuildCounter {
  static final Map<String, int> _counts = {};

  /// Call this in a widget's build method to count rebuilds
  static void count(String widgetName) {
    _counts.update(widgetName, (v) => v + 1, ifAbsent: () => 1);
  }

  /// Print rebuild counts
  static void printCounts() {
    debugPrint('\n📊 Widget Rebuild Counts:');
    final entries = _counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in entries) {
      final emoji = entry.value > 10 ? '⚠️' : '✅';
      debugPrint('$emoji ${entry.key}: ${entry.value} rebuilds');
    }
  }

  /// Reset counts
  static void reset() => _counts.clear();

  /// Get count for specific widget
  static int getCount(String widgetName) => _counts[widgetName] ?? 0;
}

// ============================================================================
// TIMELINE EVENTS
// ============================================================================

/// Wrapper for Timeline events (visible in DevTools Performance tab)
class TimelineProfiler {
  /// Start a timeline event (call finish() when done)
  static void start(String name) {
    developer.Timeline.startSync(name);
  }

  /// Finish a timeline event
  static void finish() {
    developer.Timeline.finishSync();
  }

  /// Run an operation with timeline tracking
  static T track<T>(String name, T Function() operation) {
    developer.Timeline.startSync(name);
    try {
      return operation();
    } finally {
      developer.Timeline.finishSync();
    }
  }

  /// Run an async operation with timeline tracking
  static Future<T> trackAsync<T>(
    String name,
    Future<T> Function() operation,
  ) async {
    developer.Timeline.startSync(name);
    try {
      return await operation();
    } finally {
      developer.Timeline.finishSync();
    }
  }
}

// ============================================================================
// MEMORY PROFILER
// ============================================================================

/// Simple memory usage tracker
class MemoryProfiler {
  static final List<_MemorySnapshot> _snapshots = [];

  /// Take a memory snapshot
  static void snapshot(String label) {
    // Note: Actual memory values require platform-specific implementation
    // This is a placeholder for structure
    _snapshots.add(
      _MemorySnapshot(
        label: label,
        timestamp: DateTime.now(),
        // In real implementation, get memory from platform channels
        usedHeapSize: 0,
      ),
    );

    if (kDebugMode) {
      debugPrint('📸 Memory snapshot: $label');
    }
  }

  /// Print all snapshots
  static void printSnapshots() {
    debugPrint('\n📊 Memory Snapshots:');
    for (final snap in _snapshots) {
      debugPrint('${snap.timestamp}: ${snap.label} - ${snap.usedHeapSize}MB');
    }
  }

  /// Clear snapshots
  static void clear() => _snapshots.clear();
}

class _MemorySnapshot {
  final String label;
  final DateTime timestamp;
  final int usedHeapSize;

  _MemorySnapshot({
    required this.label,
    required this.timestamp,
    required this.usedHeapSize,
  });
}

// ============================================================================
// PERFORMANCE OVERLAY HELPER
// ============================================================================

/// Helper to enable/disable performance overlay programmatically
class PerformanceOverlayHelper {
  static bool _showOverlay = false;

  static bool get isEnabled => _showOverlay;

  static void toggle() {
    _showOverlay = !_showOverlay;
    debugPrint(
      '${_showOverlay ? '✅' : '❌'} Performance Overlay: $_showOverlay',
    );
  }

  static void enable() => _showOverlay = true;
  static void disable() => _showOverlay = false;
}

// ============================================================================
// CONVENIENCE FUNCTIONS
// ============================================================================

/// Quick profile a code block
T profile<T>(String name, T Function() block) {
  return MethodProfiler.sync(name, block);
}

/// Quick profile an async code block
Future<T> profileAsync<T>(String name, Future<T> Function() block) {
  return MethodProfiler.async(name, block);
}

/// Print all profiling summaries
void printAllProfilerSummaries() {
  FrameTimeProfiler.instance.stop();
  MethodProfiler.printSummary();
  RebuildCounter.printCounts();
  MemoryProfiler.printSnapshots();
}

// ============================================================================
// PERFORMANCE TEST HELPERS
// ============================================================================

/// Run a performance test with multiple iterations
Future<PerformanceTestResult> runPerformanceTest({
  required String name,
  required Future<void> Function() test,
  int iterations = 10,
  int warmupIterations = 2,
}) async {
  // Warmup
  for (var i = 0; i < warmupIterations; i++) {
    await test();
  }

  // Test iterations
  final times = <double>[];
  for (var i = 0; i < iterations; i++) {
    final stopwatch = Stopwatch()..start();
    await test();
    stopwatch.stop();
    times.add(stopwatch.elapsedMicroseconds / 1000.0);
  }

  final result = PerformanceTestResult(
    name: name,
    iterations: iterations,
    times: times,
  );

  if (kDebugMode) {
    debugPrint(result.toString());
  }

  return result;
}

class PerformanceTestResult {
  final String name;
  final int iterations;
  final List<double> times;

  PerformanceTestResult({
    required this.name,
    required this.iterations,
    required this.times,
  });

  double get avgTime => times.reduce((a, b) => a + b) / times.length;
  double get minTime => times.reduce((a, b) => a < b ? a : b);
  double get maxTime => times.reduce((a, b) => a > b ? a : b);

  @override
  String toString() => '''
📊 Performance Test: $name
   Iterations: $iterations
   Avg: ${avgTime.toStringAsFixed(2)}ms
   Min: ${minTime.toStringAsFixed(2)}ms
   Max: ${maxTime.toStringAsFixed(2)}ms
''';
}
