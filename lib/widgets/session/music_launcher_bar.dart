import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:url_launcher/url_launcher.dart';

const MethodChannel _mediaChannel = MethodChannel('juan_training/music_launcher');

class MusicLauncherBar extends StatelessWidget {
  const MusicLauncherBar({super.key});

  // Lógica para abrir Spotify
  Future<void> _launchSpotify(BuildContext context) async {
    // Intentamos abrir la app nativa (schema spotify://)
    final Uri spotifyAppUri = Uri.parse('spotify:');
    // Enlace a la tienda por si no la tienes (web fallback)
    final Uri spotifyWebUri = Uri.parse('https://open.spotify.com');

    try {
      if (await canLaunchUrl(spotifyAppUri)) {
        await launchUrl(spotifyAppUri, mode: LaunchMode.externalApplication);
      } else {
        // Si falla, abrimos la web
        await launchUrl(spotifyWebUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Spotify')),
      );
    }
  }

  // Intenta enviar comando multimedia vía canal de plataforma (Android).
  // Devuelve true si se envió, false si no está disponible o falló.
  Future<bool> _trySendMediaCommand(String method, BuildContext context) async {
    if (!Platform.isAndroid) return false;
    try {
      await _mediaChannel.invokeMethod(method);
      return true;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // Gradiente sutil estilo "Spotify"
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
          onTap: () => _launchSpotify(context), // <--- AL TOCAR EL RECUADRO
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // 1. Icono de la App (Visual)
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

                // 2. Texto "Tu Música"
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Abrir Spotify",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        "Toca para elegir canción",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Botones funcionales (abren Spotify y dan feedback)
                // Intentamos enviar comando multimedia en Android; si no, abrimos Spotify.
                _ControlIcon(
                  icon: Icons.skip_previous_rounded,
                  onTap: () async {
                    Vibrate.feedback(FeedbackType.selection);
                    final sent = await _trySendMediaCommand('mediaPrevious', context);
                    if (sent) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Comando anterior enviado'), duration: Duration(milliseconds: 700)),
                      );
                      return;
                    }
                    // fallback
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Abriendo Spotify — canción anterior'), duration: Duration(milliseconds: 800)),
                    );
                    _launchSpotify(context);
                  },
                ),
                _ControlIcon(
                  icon: Icons.play_arrow_rounded,
                  isPlay: true,
                  onTap: () async {
                    Vibrate.feedback(FeedbackType.heavy);
                    final sent = await _trySendMediaCommand('mediaPlayPause', context);
                    if (sent) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Comando play/pausa enviado'), duration: Duration(milliseconds: 700)),
                      );
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Abriendo Spotify'), duration: Duration(milliseconds: 700)),
                    );
                    _launchSpotify(context);
                  },
                ),
                _ControlIcon(
                  icon: Icons.skip_next_rounded,
                  onTap: () async {
                    Vibrate.feedback(FeedbackType.selection);
                    final sent = await _trySendMediaCommand('mediaNext', context);
                    if (sent) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Comando siguiente enviado'), duration: Duration(milliseconds: 700)),
                      );
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Abriendo Spotify — canción siguiente'), duration: Duration(milliseconds: 800)),
                    );
                    _launchSpotify(context);
                  },
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
