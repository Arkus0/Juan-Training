import '../../utils/design_system.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RestTimerPanel extends StatefulWidget {
  final bool isRestActive;
  final int defaultRestSeconds;
  final VoidCallback onStartRest;
  final VoidCallback onStopRest;
  final ValueChanged<int> onDurationChange;
  final VoidCallback onTimerFinished;

  const RestTimerPanel({
    super.key,
    required this.isRestActive,
    required this.defaultRestSeconds,
    required this.onStartRest,
    required this.onStopRest,
    required this.onDurationChange,
    required this.onTimerFinished,
  });

  @override
  State<RestTimerPanel> createState() => _RestTimerPanelState();
}

class _RestTimerPanelState extends State<RestTimerPanel> with WidgetsBindingObserver {
  Timer? _timer;
  double _currentSeconds = 0;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.isRestActive) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(RestTimerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRestActive && !oldWidget.isRestActive) {
      _startTimer();
    } else if (!widget.isRestActive && oldWidget.isRestActive) {
      _stopTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isRestActive && _endTime != null) {
       _updateTime();
    }
  }

  void _startTimer() {
    final duration = Duration(seconds: widget.defaultRestSeconds);
    _endTime = DateTime.now().add(duration);
    _currentSeconds = widget.defaultRestSeconds.toDouble();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      _updateTime();
    });
  }

  void _updateTime() {
     if (_endTime == null) return;
     final now = DateTime.now();
     final remaining = _endTime!.difference(now).inMilliseconds / 1000.0;

     if (remaining <= 0) {
       _stopTimer();
       widget.onTimerFinished();
       widget.onStopRest();
     } else {
       setState(() {
         _currentSeconds = remaining;
       });
     }
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _endTime = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isRestActive) {
      return Container(
        color: Colors.black.withValues(alpha: 0.95),
        height: 250,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: _AggressiveTimerDisplay(seconds: _currentSeconds),
            ),
            ElevatedButton(
              onPressed: widget.onStopRest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.live,
                minimumSize: const Size(200, 50),
              ),
              child: const Text('¡A LA CARGA! (SALTAR)'),
            )
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: AppColors.neonPrimary!, width: 2)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('DESCANSO', style: Theme.of(context).textTheme.labelSmall),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.grey),
                      onPressed: () {
                        if (widget.defaultRestSeconds > 10) {
                          widget.onDurationChange(widget.defaultRestSeconds - 10);
                        }
                      },
                    ),
                    Text(
                      '${widget.defaultRestSeconds}s',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    IconButton(
                      icon: Icon(Icons.add_circle, color: AppColors.neonPrimary),
                      onPressed: () {
                        widget.onDurationChange(widget.defaultRestSeconds + 10);
                      },
                    ),
                  ],
                ),
              ],
            ),
            ElevatedButton(
              onPressed: widget.onStartRest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.neonPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('DESCANSAR'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AggressiveTimerDisplay extends StatefulWidget {
  final double seconds;

  const _AggressiveTimerDisplay({required this.seconds});

  @override
  State<_AggressiveTimerDisplay> createState() => _AggressiveTimerDisplayState();
}

class _AggressiveTimerDisplayState extends State<_AggressiveTimerDisplay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_AggressiveTimerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seconds <= 10 && widget.seconds > 0) {
      if (!_controller.isAnimating) {
        _controller.repeat(reverse: true);
      }
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int seconds = widget.seconds.ceil();
    final bool isCritical = seconds <= 10;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isCritical ? _scaleAnimation.value : 1.0,
          child: Text(
            '$seconds',
            style: GoogleFonts.montserrat(
              fontSize: 120,
              fontWeight: FontWeight.w900,
              color: isCritical ? AppColors.neonPrimary : Colors.white,
              shadows: [
                Shadow(
                  // 🎯 NEON IRON: Usar colores del sistema
                  color: (isCritical ? AppColors.neonPrimaryGlow : AppColors.liveGlow).withValues(alpha: 0.8),
                  blurRadius: isCritical ? 20 : 10,
                  offset: const Offset(0, 0),
                )
              ],
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
