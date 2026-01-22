import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Claves de SharedPreferences para settings
class SettingsKeys {
  static const String timerSoundEnabled = 'timer_sound_enabled';
  static const String timerVibrationEnabled = 'timer_vibration_enabled';
  static const String autoStartTimer = 'auto_start_timer';
  static const String defaultRestSeconds = 'default_rest_seconds';
  static const String showSupersetIndicator = 'show_superset_indicator';
}

/// Estado inmutable de las preferencias del usuario
class UserSettings {
  final bool timerSoundEnabled;
  final bool timerVibrationEnabled;
  final bool autoStartTimer;
  final int defaultRestSeconds;
  final bool showSupersetIndicator;

  const UserSettings({
    this.timerSoundEnabled = false, // Desactivado por defecto (gym = sin sonido)
    this.timerVibrationEnabled = true,
    this.autoStartTimer = true,
    this.defaultRestSeconds = 90,
    this.showSupersetIndicator = true,
  });

  UserSettings copyWith({
    bool? timerSoundEnabled,
    bool? timerVibrationEnabled,
    bool? autoStartTimer,
    int? defaultRestSeconds,
    bool? showSupersetIndicator,
  }) {
    return UserSettings(
      timerSoundEnabled: timerSoundEnabled ?? this.timerSoundEnabled,
      timerVibrationEnabled: timerVibrationEnabled ?? this.timerVibrationEnabled,
      autoStartTimer: autoStartTimer ?? this.autoStartTimer,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      showSupersetIndicator: showSupersetIndicator ?? this.showSupersetIndicator,
    );
  }
}

/// Notifier para manejar settings con persistencia en SharedPreferences
class SettingsNotifier extends StateNotifier<UserSettings> {
  SettingsNotifier() : super(const UserSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    state = UserSettings(
      timerSoundEnabled: prefs.getBool(SettingsKeys.timerSoundEnabled) ?? false,
      timerVibrationEnabled: prefs.getBool(SettingsKeys.timerVibrationEnabled) ?? true,
      autoStartTimer: prefs.getBool(SettingsKeys.autoStartTimer) ?? true,
      defaultRestSeconds: prefs.getInt(SettingsKeys.defaultRestSeconds) ?? 90,
      showSupersetIndicator: prefs.getBool(SettingsKeys.showSupersetIndicator) ?? true,
    );
  }

  Future<void> setTimerSoundEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.timerSoundEnabled, value);
    state = state.copyWith(timerSoundEnabled: value);
  }

  Future<void> setTimerVibrationEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.timerVibrationEnabled, value);
    state = state.copyWith(timerVibrationEnabled: value);
  }

  Future<void> setAutoStartTimer(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.autoStartTimer, value);
    state = state.copyWith(autoStartTimer: value);
  }

  Future<void> setDefaultRestSeconds(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SettingsKeys.defaultRestSeconds, value);
    state = state.copyWith(defaultRestSeconds: value);
  }

  Future<void> setShowSupersetIndicator(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.showSupersetIndicator, value);
    state = state.copyWith(showSupersetIndicator: value);
  }
}

/// Provider global de settings
final settingsProvider = StateNotifierProvider<SettingsNotifier, UserSettings>((ref) {
  return SettingsNotifier();
});

/// Providers de conveniencia para seleccionar settings específicos
final timerSoundEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.timerSoundEnabled));
});

final timerVibrationEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.timerVibrationEnabled));
});

final autoStartTimerProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.autoStartTimer));
});
