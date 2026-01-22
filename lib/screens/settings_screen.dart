import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

          _SettingsTile(
            icon: Icons.play_circle_outline,
            title: 'Auto-iniciar timer',
            subtitle: 'Iniciar descanso al completar serie',
            trailing: Switch(
              value: settings.autoStartTimer,
              onChanged: notifier.setAutoStartTimer,
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
