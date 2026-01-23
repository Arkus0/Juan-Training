import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AJUSTES',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección Timer
          _SectionHeader(title: 'TIMER DE DESCANSO'),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.vibration,
            title: 'Vibración',
            subtitle: 'Vibrar en los últimos 10 segundos',
            trailing: Switch(
              value: settings.timerVibrationEnabled,
              onChanged: notifier.setTimerVibrationEnabled,
              activeColor: Colors.redAccent[700],
            ),
          ),

          _SettingsTile(
            icon: Icons.volume_up,
            title: 'Sonido',
            subtitle: 'Beep en los últimos 3 segundos',
            trailing: Switch(
              value: settings.timerSoundEnabled,
              onChanged: notifier.setTimerSoundEnabled,
              activeColor: Colors.redAccent[700],
            ),
          ),

          // 🎯 P1: Timer siempre auto-inicia - setting eliminado para reducir fricción

          _SettingsTile(
            icon: Icons.lock_clock,
            title: 'Mostrar en pantalla de bloqueo',
            subtitle: 'Ver y controlar el timer sin desbloquear',
            trailing: Switch(
              value: settings.lockScreenTimerEnabled,
              onChanged: notifier.setLockScreenTimerEnabled,
              activeColor: Colors.redAccent[700],
            ),
          ),

          _SettingsTile(
            icon: Icons.timer,
            title: 'Descanso por defecto',
            subtitle: '${settings.defaultRestSeconds} segundos',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: settings.defaultRestSeconds > 10
                      ? () => notifier.setDefaultRestSeconds(settings.defaultRestSeconds - 10)
                      : null,
                  color: Colors.grey,
                ),
                Text(
                  '${settings.defaultRestSeconds}s',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => notifier.setDefaultRestSeconds(settings.defaultRestSeconds + 10),
                  color: Colors.redAccent[700],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Sección Entrada de Datos
          _SectionHeader(title: 'ENTRADA DE DATOS'),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.touch_app,
            title: 'Modo entrada rápida',
            subtitle: 'Modal numpad grande al tocar KG/REPS',
            trailing: Switch(
              value: settings.useFocusedInputMode,
              onChanged: notifier.setUseFocusedInputMode,
              activeColor: Colors.green[600],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Optimizado para gimnasio: botones grandes, contexto visible, auto-completado.',
              style: GoogleFonts.montserrat(
                color: Colors.grey[600],
                fontSize: 11,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Sección Superseries
          _SectionHeader(title: 'SUPERSERIES'),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.link,
            title: 'Indicador de superset',
            subtitle: 'Mostrar badge cuando ejercicio está en superset',
            trailing: Switch(
              value: settings.showSupersetIndicator,
              onChanged: notifier.setShowSupersetIndicator,
              activeColor: Colors.redAccent[700],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'En superseries, el timer solo inicia después del último ejercicio del grupo.',
              style: GoogleFonts.montserrat(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Sección Rendimiento
          _SectionHeader(title: 'RENDIMIENTO'),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.speed,
            title: 'Modo máximo rendimiento',
            subtitle: 'Reduce animaciones y vibraciones',
            trailing: Switch(
              value: settings.performanceModeEnabled,
              onChanged: notifier.setPerformanceModeEnabled,
              activeColor: Colors.green[600],
            ),
          ),

          if (!settings.performanceModeEnabled) ...[
            _SettingsTile(
              icon: Icons.animation,
              title: 'Reducir animaciones',
              subtitle: 'Desactiva sombras y transiciones',
              trailing: Switch(
                value: settings.reduceAnimations,
                onChanged: notifier.setReduceAnimations,
                activeColor: Colors.redAccent[700],
              ),
            ),

            _SettingsTile(
              icon: Icons.vibration,
              title: 'Reducir vibraciones',
              subtitle: 'Solo vibraciones esenciales',
              trailing: Switch(
                value: settings.reduceVibrations,
                onChanged: notifier.setReduceVibrations,
                activeColor: Colors.redAccent[700],
              ),
            ),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'El modo debug de VS Code es ~10x más lento que release. '
              'Para probar rendimiento real: flutter run --release',
              style: GoogleFonts.montserrat(
                color: Colors.orange[400],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Sección Almacenamiento
          _SectionHeader(title: 'ALMACENAMIENTO'),
          const SizedBox(height: 8),

          _StorageTile(),

          const SizedBox(height: 24),

          // Info de la app
          _SectionHeader(title: 'INFORMACIÓN'),
          const SizedBox(height: 8),

          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Juan Training',
            subtitle: 'Versión 1.0.0',
            trailing: null,
          ),

          const SizedBox(height: 40),

          // Créditos
          Center(
            child: Text(
              '💪 Hecho para el gym',
              style: GoogleFonts.montserrat(
                color: Colors.grey[700],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Text(
        title,
        style: GoogleFonts.montserrat(
          color: Colors.redAccent[700],
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(
          title,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        trailing: trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

/// Widget para mostrar y gestionar almacenamiento
class _StorageTile extends StatefulWidget {
  @override
  State<_StorageTile> createState() => _StorageTileState();
}

class _StorageTileState extends State<_StorageTile> {
  String _storageInfo = 'Calculando...';
  bool _isClearing = false;
  int _imageCount = 0;
  int _totalSizeMB = 0;

  @override
  void initState() {
    super.initState();
    _calculateStorage();
  }

  Future<void> _calculateStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/ejercicios_images');

      int totalSize = 0;
      int imageCount = 0;

      // Contar imágenes
      if (await imagesDir.exists()) {
        final files = imagesDir.listSync();
        for (var entity in files) {
          if (entity is File) {
            totalSize += await entity.length();
            imageCount++;
          }
        }
      }

      // Contar JSON de ejercicios
      final jsonFile = File('${directory.path}/exercises.json');
      if (await jsonFile.exists()) {
        totalSize += await jsonFile.length();
      }

      final sizeMB = (totalSize / (1024 * 1024)).ceil();

      if (mounted) {
        setState(() {
          _imageCount = imageCount;
          _totalSizeMB = sizeMB;
          _storageInfo = '$imageCount imágenes · ${sizeMB}MB';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _storageInfo = 'Error al calcular';
        });
      }
    }
  }

  Future<void> _clearImageCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Limpiar caché',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        content: Text(
          '¿Eliminar $_imageCount imágenes descargadas (${_totalSizeMB}MB)?\n\n'
          'Se volverán a descargar cuando las necesites.',
          style: GoogleFonts.montserrat(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.montserrat(color: Colors.grey[500]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Eliminar',
              style: GoogleFonts.montserrat(
                color: Colors.red[400],
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isClearing = true);

    try {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/ejercicios_images');

      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
        await imagesDir.create(); // Recrear vacía
      }

      // Limpiar cache de Flutter
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Caché limpiado: ${_totalSizeMB}MB liberados',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: Colors.green[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClearing = false);
        _calculateStorage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          Icons.storage,
          color: _totalSizeMB > 100 ? Colors.orange[400] : Colors.white70,
        ),
        title: Text(
          'Caché de imágenes',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          _storageInfo,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: _totalSizeMB > 100 ? Colors.orange[400] : Colors.grey[500],
          ),
        ),
        trailing: _isClearing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: _imageCount > 0 ? _clearImageCache : null,
                child: Text(
                  'Limpiar',
                  style: GoogleFonts.montserrat(
                    color: _imageCount > 0 ? Colors.red[400] : Colors.grey[700],
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
