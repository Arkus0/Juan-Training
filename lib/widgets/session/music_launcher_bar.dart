import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/media_control_service.dart';

/// Barra de control multimedia para sesiones de entrenamiento.
///
/// Muestra controles de reproducción cuando hay música activa.
/// Usa [MediaControlService] para comunicación con la plataforma.
class MusicLauncherBar extends StatefulWidget {
  const MusicLauncherBar({super.key});

  @override
  State<MusicLauncherBar> createState() => _MusicLauncherBarState();
}

class _MusicLauncherBarState extends State<MusicLauncherBar> {
  final _mediaService = MediaControlService.instance;

  bool _isVisible = false;
  bool _isPlaying = false;
  String? _currentTitle;
  String? _currentArtist;

  StreamSubscription<MediaSessionInfo>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _initializeMediaService();
  }

  Future<void> _initializeMediaService() async {
    await _mediaService.initialize();

    // Verificar estado inicial
    _updateFromSession(_mediaService.currentSession);

    // Escuchar cambios de sesión
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
      _currentArtist = session.artist;
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onPlayPause() async {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    final result = await _mediaService.playPause();

    if (!mounted) return;

    if (result.success) {
      // Actualizar estado localmente para feedback inmediato
      setState(() => _isPlaying = !_isPlaying);
    } else if (result.fallbackUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abriendo Spotify'),
          duration: Duration(milliseconds: 700),
        ),
      );
    }
  }

  Future<void> _onPrevious() async {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    final result = await _mediaService.previous();

    if (!mounted) return;

    if (!result.success && result.fallbackUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abriendo Spotify — canción anterior'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  Future<void> _onNext() async {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    final result = await _mediaService.next();

    if (!mounted) return;

    if (!result.success && result.fallbackUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abriendo Spotify — canción siguiente'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  Future<void> _openSpotify() async {
    await _mediaService.openSpotify();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[900]!.withOpacity(0.3), Colors.black],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openSpotify,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Icono de la App
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954), // Verde Spotify
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.black, size: 24),
                ),
                const SizedBox(width: 12),

                // Información de la canción
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentTitle ?? "Reproduciendo",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _currentArtist ?? "Toca para abrir Spotify",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Controles de reproducción
                _ControlIcon(
                  icon: Icons.skip_previous_rounded,
                  onTap: _onPrevious,
                ),
                _ControlIcon(
                  icon: _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  isPlay: true,
                  onTap: _onPlayPause,
                ),
                _ControlIcon(
                  icon: Icons.skip_next_rounded,
                  onTap: _onNext,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isPlay;

  const _ControlIcon({required this.icon, required this.onTap, this.isPlay = false});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: isPlay ? Colors.white : Colors.white.withOpacity(0.5),
      iconSize: isPlay ? 32 : 24,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
