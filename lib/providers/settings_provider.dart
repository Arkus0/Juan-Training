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
  static const String barWeightKg = 'bar_weight_kg';
  static const String lockScreenTimerEnabled = 'lock_screen_timer_enabled';
  static const String useFocusedInputMode = 'use_focused_input_mode';
  static const String mediaControlsEnabled = 'media_controls_enabled';
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
  final double barWeight; // Default bar weight in kg

  /// Mostrar timer de descanso en pantalla de bloqueo
  final bool lockScreenTimerEnabled;

  /// Modo de entrada focalizada: modal numpad en lugar de inputs inline
  final bool useFocusedInputMode;

  /// Mostrar controles de media cuando hay música reproduciéndose
  /// Solo aparece si hay música activa (Spotify, etc), no con beeps del timer
  final bool mediaControlsEnabled;

  const UserSettings({
    this.timerSoundEnabled =
        false, // Desactivado por defecto (gym = sin sonido)
    this.timerVibrationEnabled = true,
    this.autoStartTimer = true,
    this.defaultRestSeconds = 90,
    this.showSupersetIndicator = true,
    this.performanceModeEnabled = false,
    this.reduceAnimations = false,
    this.reduceVibrations = false,
    this.barWeight = 20.0,
    this.lockScreenTimerEnabled = true, // Activado por defecto
    this.useFocusedInputMode = true, // Activado por defecto - UX optimizada
    this.mediaControlsEnabled = true, // Activado por defecto
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
    double? barWeight,
    bool? lockScreenTimerEnabled,
    bool? useFocusedInputMode,
    bool? mediaControlsEnabled,
  }) {
    return UserSettings(
      timerSoundEnabled: timerSoundEnabled ?? this.timerSoundEnabled,
      timerVibrationEnabled:
          timerVibrationEnabled ?? this.timerVibrationEnabled,
      autoStartTimer: autoStartTimer ?? this.autoStartTimer,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
      showSupersetIndicator:
          showSupersetIndicator ?? this.showSupersetIndicator,
      performanceModeEnabled:
          performanceModeEnabled ?? this.performanceModeEnabled,
      reduceAnimations: reduceAnimations ?? this.reduceAnimations,
      reduceVibrations: reduceVibrations ?? this.reduceVibrations,
      barWeight: barWeight ?? this.barWeight,
      lockScreenTimerEnabled:
          lockScreenTimerEnabled ?? this.lockScreenTimerEnabled,
      useFocusedInputMode: useFocusedInputMode ?? this.useFocusedInputMode,
      mediaControlsEnabled: mediaControlsEnabled ?? this.mediaControlsEnabled,
    );
  }
}

/// Notifier para manejar settings con persistencia en SharedPreferences
class SettingsNotifier extends Notifier<UserSettings> {
  @override
  UserSettings build() {
    _loadSettings();
    return const UserSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final performanceMode =
        prefs.getBool(SettingsKeys.performanceModeEnabled) ?? false;
    final reduceAnims = prefs.getBool(SettingsKeys.reduceAnimations) ?? false;
    final reduceVibes = prefs.getBool(SettingsKeys.reduceVibrations) ?? false;

    // Sincronizar con PerformanceMode singleton
    PerformanceMode.instance.reduceAnimations = performanceMode || reduceAnims;
    PerformanceMode.instance.reduceVibrations = performanceMode || reduceVibes;
    PerformanceMode.instance.useLowPowerMode = performanceMode;

    state = UserSettings(
      timerSoundEnabled: prefs.getBool(SettingsKeys.timerSoundEnabled) ?? false,
      timerVibrationEnabled:
          prefs.getBool(SettingsKeys.timerVibrationEnabled) ?? true,
      autoStartTimer: prefs.getBool(SettingsKeys.autoStartTimer) ?? true,
      defaultRestSeconds: prefs.getInt(SettingsKeys.defaultRestSeconds) ?? 90,
      showSupersetIndicator:
          prefs.getBool(SettingsKeys.showSupersetIndicator) ?? true,
      performanceModeEnabled: performanceMode,
      reduceAnimations: reduceAnims,
      reduceVibrations: reduceVibes,
      barWeight: prefs.getDouble(SettingsKeys.barWeightKg) ?? 20.0,
      lockScreenTimerEnabled:
          prefs.getBool(SettingsKeys.lockScreenTimerEnabled) ?? true,
      useFocusedInputMode:
          prefs.getBool(SettingsKeys.useFocusedInputMode) ?? true,
      mediaControlsEnabled:
          prefs.getBool(SettingsKeys.mediaControlsEnabled) ?? true,
    );
  }

  Future<void> setTimerSoundEnabled({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.timerSoundEnabled, value);
    state = state.copyWith(timerSoundEnabled: value);
  }

  Future<void> setTimerVibrationEnabled({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.timerVibrationEnabled, value);
    state = state.copyWith(timerVibrationEnabled: value);
  }

  Future<void> setAutoStartTimer({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.autoStartTimer, value);
    state = state.copyWith(autoStartTimer: value);
  }

  Future<void> setDefaultRestSeconds(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(SettingsKeys.defaultRestSeconds, value);
    state = state.copyWith(defaultRestSeconds: value);
  }

  Future<void> setShowSupersetIndicator({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.showSupersetIndicator, value);
    state = state.copyWith(showSupersetIndicator: value);
  }

  /// Activar/desactivar el modo performance completo
  /// Esto activa todas las optimizaciones de rendimiento
  Future<void> setPerformanceModeEnabled({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.performanceModeEnabled, value);

    // Sincronizar con PerformanceMode singleton
    PerformanceMode.instance.setPerformanceMode(enabled: value);

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
  Future<void> setReduceAnimations({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.reduceAnimations, value);

    PerformanceMode.instance.reduceAnimations = value;

    state = state.copyWith(reduceAnimations: value);
  }

  /// Reducir vibraciones (independiente del modo performance)
  Future<void> setReduceVibrations({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.reduceVibrations, value);

    PerformanceMode.instance.reduceVibrations = value;

    state = state.copyWith(reduceVibrations: value);
  }

  /// Persistir preferencia de peso de la barra
  Future<void> setBarWeight(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(SettingsKeys.barWeightKg, value);
    state = state.copyWith(barWeight: value);
  }

  /// Activar/desactivar el timer en pantalla de bloqueo
  Future<void> setLockScreenTimerEnabled({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.lockScreenTimerEnabled, value);
    state = state.copyWith(lockScreenTimerEnabled: value);
  }

  /// Activar/desactivar el modo de entrada focalizada (modal numpad)
  Future<void> setUseFocusedInputMode({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.useFocusedInputMode, value);
    state = state.copyWith(useFocusedInputMode: value);
  }

  /// Activar/desactivar controles de media (solo cuando hay música)
  Future<void> setMediaControlsEnabled({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.mediaControlsEnabled, value);
    state = state.copyWith(mediaControlsEnabled: value);
  }
}

/// Provider global de settings
final settingsProvider = NotifierProvider<SettingsNotifier, UserSettings>(
  SettingsNotifier.new,
);

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

/// Provider de conveniencia para timer en pantalla de bloqueo
final lockScreenTimerEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider.select((s) => s.lockScreenTimerEnabled));
});
