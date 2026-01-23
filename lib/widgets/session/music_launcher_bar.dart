import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/media_control_service.dart';
import '../../utils/design_system.dart';

/// 🎯 NEON IRON: Control de música ultra-compacto para AppBar
///
/// Principios aplicados:
/// - Mínimo footprint: Solo un icono en AppBar
/// - Interacción bajo demanda: Popup con controles al tocar
/// - No compite: Desaparece cuando no hay música
class MusicLauncherBar extends StatefulWidget {
  const MusicLauncherBar({super.key});

  @override
  State<MusicLauncherBar> createState() => _MusicLauncherBarState();
}

class _MusicLauncherBarState extends State<MusicLauncherBar> {
  final _mediaService = MediaControlService.instance;

  bool _isVisible = false;
  bool _isPlaying = false;

  StreamSubscription<MediaSessionInfo>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeMediaService();
  }

  Future<void> _initializeMediaService() async {
    await _mediaService.initialize();
    _updateFromSession(_mediaService.currentSession);
    _sessionSubscription = _mediaService.sessionStream.listen(_updateFromSession);
  }

  void _updateFromSession(MediaSessionInfo session) {
    if (!mounted) return;
    setState(() {
      _isVisible = session.hasMedia ||
          session.playbackState == MediaPlaybackState.playing ||
          session.playbackState == MediaPlaybackState.paused;
      _isPlaying = session.playbackState == MediaPlaybackState.playing;
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onPlayPause() async {
    HapticFeedback.mediumImpact();
    final result = await _mediaService.playPause();
    if (!mounted) return;
    if (result.success) {
      setState(() => _isPlaying = !_isPlaying);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎯 NEON IRON: No mostrar nada si no hay música activa
    if (!_isVisible) return const SizedBox.shrink();

    return const SizedBox.shrink(); // Removido del body - ahora es AppBar action
  }
}

/// 🎯 NEON IRON: Botón de música compacto para AppBar
/// Uso: Añadir a actions[] del AppBar
class MusicAppBarAction extends StatefulWidget {
  const MusicAppBarAction({super.key});

  @override
  State<MusicAppBarAction> createState() => _MusicAppBarActionState();
}

class _MusicAppBarActionState extends State<MusicAppBarAction>
    with SingleTickerProviderStateMixin {
  final _mediaService = MediaControlService.instance;

  bool _isVisible = false;
  bool _isPlaying = false;
  String? _currentTitle;

  StreamSubscription<MediaSessionInfo>? _sessionSubscription;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _initializeMediaService();
  }

  Future<void> _initializeMediaService() async {
    await _mediaService.initialize();
    _updateFromSession(_mediaService.currentSession);
    _sessionSubscription = _mediaService.sessionStream.listen(_updateFromSession);
  }

  void _updateFromSession(MediaSessionInfo session) {
    if (!mounted) return;
    setState(() {
      _isVisible = session.hasMedia ||
          session.playbackState == MediaPlaybackState.playing ||
          session.playbackState == MediaPlaybackState.paused;
      _isPlaying = session.playbackState == MediaPlaybackState.playing;
      _currentTitle = session.title;
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _onPlayPause() async {
    HapticFeedback.mediumImpact();
    final result = await _mediaService.playPause();
    if (!mounted) return;
    if (result.success) {
      setState(() => _isPlaying = !_isPlaying);
    } else if (result.fallbackUsed) {
      // Abre Spotify como fallback
    }
  }

  Future<void> _openSpotify() async {
    HapticFeedback.selectionClick();
    await _mediaService.openSpotify();
  }

  void _showMusicPopup() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MusicControlSheet(
        isPlaying: _isPlaying,
        title: _currentTitle,
        onPlayPause: () async {
          await _onPlayPause();
          if (mounted) Navigator.pop(context);
        },
        onOpenSpotify: () async {
          await _openSpotify();
          if (mounted) Navigator.pop(context);
        },
        onPrevious: () async {
          HapticFeedback.selectionClick();
          await _mediaService.previous();
        },
        onNext: () async {
          HapticFeedback.selectionClick();
          await _mediaService.next();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = _isPlaying ? 0.3 + (_pulseController.value * 0.2) : 0.5;
        return IconButton(
          onPressed: _showMusicPopup,
          tooltip: 'Controles de música',
          icon: Stack(
            alignment: Alignment.center,
            children: [
              // Glow cuando reproduce
              if (_isPlaying)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.neonCyan.withValues(alpha: pulseValue),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              Icon(
                _isPlaying ? Icons.music_note : Icons.music_off,
                color: _isPlaying ? AppColors.neonCyan : AppColors.textTertiary,
                size: 22,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 🎯 NEON IRON: Sheet de controles de música (bajo demanda)
class _MusicControlSheet extends StatelessWidget {
  final bool isPlaying;
  final String? title;
  final VoidCallback onPlayPause;
  final VoidCallback onOpenSpotify;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MusicControlSheet({
    required this.isPlaying,
    required this.title,
    required this.onPlayPause,
    required this.onOpenSpotify,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonCyan.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Título
          Text(
            title ?? 'Reproduciendo',
            style: AppTypography.sectionTitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 24),

          // Controles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: Icons.skip_previous_rounded,
                onTap: onPrevious,
              ),
              const SizedBox(width: 16),
              _PlayPauseButton(
                isPlaying: isPlaying,
                onTap: onPlayPause,
              ),
              const SizedBox(width: 16),
              _ControlButton(
                icon: Icons.skip_next_rounded,
                onTap: onNext,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Abrir Spotify
          TextButton.icon(
            onPressed: onOpenSpotify,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Abrir Spotify'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgDeep,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.textSecondary, size: 28),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayPauseButton({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.neonCyan,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: AppColors.bgDeep,
            size: 36,
          ),
        ),
      ),
    );
  }
}
