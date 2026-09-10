import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small typed wrapper over [SharedPreferences] for the handful of things the
/// app remembers between launches. Load once in main() so reads are synchronous
/// from then on.
class Prefs {
  static late SharedPreferences _p;

  static const _kVehicleId = 'confirmed_vehicle_id';
  static const _kThemeMode = 'theme_mode';

  static Future<void> load() async {
    _p = await SharedPreferences.getInstance();
  }

  /// The vehicle the driver last confirmed by typing its number.
  ///
  /// Kept so the vehicle step is asked once rather than every launch: it is
  /// compared against `profiles.vehicle_id`, so if a dispatcher reassigns the
  /// driver to another vehicle the two stop matching and the app asks again.
  static String? get confirmedVehicleId => _p.getString(_kVehicleId);

  static Future<void> setConfirmedVehicleId(String? id) async {
    if (id == null) {
      await _p.remove(_kVehicleId);
    } else {
      await _p.setString(_kVehicleId, id);
    }
  }

  /// The driver's light/dark choice; defaults to following the OS.
  static ThemeMode get themeMode => switch (_p.getString(_kThemeMode)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static Future<void> setThemeMode(ThemeMode mode) =>
      _p.setString(_kThemeMode, switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });
}

/// The app's current theme mode. [MaterialApp] listens to this, so setting it
/// repaints the whole app; the choice is written back to [Prefs].
class ThemeController {
  static final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.system);

  static void init() => mode.value = Prefs.themeMode;

  static Future<void> set(ThemeMode value) async {
    mode.value = value;
    await Prefs.setThemeMode(value);
  }
}
