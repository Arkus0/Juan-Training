import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/performance_utils.dart';

/// Claves de SharedPreferences para settings
class SettingsKeys {
  static const String timerSoundEnabled = 'timer_sound_enabled';
  static const String timerVibrationEnabled = 'timer_vibration_enabled';
  static const String autoStartTimer = 'auto_start_timer';
  static const String defaultRestSeconds = 'default_rest_seconds';
  static const String showSupersetIndicator = 'show_superset_indicator';
  static const String performanceModeEnabled = 'performance_mode_enabled';
  static const String reduceAnimations = 'reduce_animations';
  static const String reduceVibrations = 'reduce_vibrations';
}

/// Estado inmutable de las preferencias del usuario
class UserSettings {
  final bool timerSoundEnabled;
  final bool timerVibrationEnabled;
  final bool autoStartTimer;
  final int defaultRestSeconds;
  final bool showSupersetIndicator;

  /// Modo performance: reduce animaciones y vibraciones para mejor rendimiento
  final bool performanceModeEnabled;

  /// Reducir animaciones (sombras, transiciones, etc.)
  final bool reduceAnimations;

  /// Reducir vibraciones
  final bool reduceVibrations;

  const UserSettings({
    this.timerSoundEnabled = false, // Desactivado por defecto (gym = sin sonido)
    this.timerVibrationEnabled = true,
    this.autoStartTimer = true,
    this.defaultRestSeconds = 90,
    this.showSupersetIndicator = true,
    this.performanceModeEnabled = false,
    this.reduceAnimations = false,
    this.reduceVibrations = false,
  });

  UserSettings copyWith({
    bool? timerSoundEnabled,
    bool? timerVibrationEnabled,
    bool? autoStartTimer,
    int? defaultRestSeconds,
    bool? showSupersetIndicator,
    bool? performanceModeEnabled,
    bool? reduceAnimations,
    bool? reduceVibrations,
  }) {
    return UserSettings(
      timerSoundEnabled: timerSoundEnabled ?? this.timerSoundEnabled,
      timerVibrationEnabled: timerVibrationEnabled ?? this.timerVibrationEnabled,
      autoStartTimer: autoStartTimer ?? this.autoStartTimer,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      showSupersetIndicator: showSupersetIndicator ?? this.showSupersetIndicator,
      performanceModeEnabled: performanceModeEnabled ?? this.performanceModeEnabled,
      reduceAnimations: reduceAnimations ?? this.reduceAnimations,
      reduceVibrations: reduceVibrations ?? this.reduceVibrations,
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

    final performanceMode = prefs.getBool(SettingsKeys.performanceModeEnabled) ?? false;
    final reduceAnims = prefs.getBool(SettingsKeys.reduceAnimations) ?? false;
    final reduceVibes = prefs.getBool(SettingsKeys.reduceVibrations) ?? false;

    // Sincronizar con PerformanceMode singleton
    PerformanceMode.instance.reduceAnimations = performanceMode || reduceAnims;
    PerformanceMode.instance.reduceVibrations = performanceMode || reduceVibes;
    PerformanceMode.instance.useLowPowerMode = performanceMode;

    state = UserSettings(
      timerSoundEnabled: prefs.getBool(SettingsKeys.timerSoundEnabled) ?? false,
      timerVibrationEnabled: prefs.getBool(SettingsKeys.timerVibrationEnabled) ?? true,
      autoStartTimer: prefs.getBool(SettingsKeys.autoStartTimer) ?? true,
      defaultRestSeconds: prefs.getInt(SettingsKeys.defaultRestSeconds) ?? 90,
      showSupersetIndicator: prefs.getBool(SettingsKeys.showSupersetIndicator) ?? true,
      performanceModeEnabled: performanceMode,
      reduceAnimations: reduceAnims,
      reduceVibrations: reduceVibes,
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

  /// Activar/desactivar el modo performance completo
  /// Esto activa todas las optimizaciones de rendimiento
  Future<void> setPerformanceModeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.performanceModeEnabled, value);

    // Sincronizar con PerformanceMode singleton
    PerformanceMode.instance.setPerformanceMode(value);

    state = state.copyWith(
      performanceModeEnabled: value,
      reduceAnimations: value,
      reduceVibrations: value,
    );

    // Persistir también los sub-settings
    if (value) {
      await prefs.setBool(SettingsKeys.reduceAnimations, true);
      await prefs.setBool(SettingsKeys.reduceVibrations, true);
    }
  }

  /// Reducir animaciones (independiente del modo performance)
  Future<void> setReduceAnimations(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.reduceAnimations, value);

    PerformanceMode.instance.reduceAnimations = value;

    state = state.copyWith(reduceAnimations: value);
  }

  /// Reducir vibraciones (independiente del modo performance)
  Future<void> setReduceVibrations(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.reduceVibrations, value);

    PerformanceMode.instance.reduceVibrations = value;

    state = state.copyWith(reduceVibrations: value);
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

/// Provider de conveniencia para modo performance
final performanceModeProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.performanceModeEnabled));
});

/// Provider de conveniencia para reducir animaciones
final reduceAnimationsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.reduceAnimations));
});

/// Provider de conveniencia para reducir vibraciones
final reduceVibrationsProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.reduceVibrations));
});
