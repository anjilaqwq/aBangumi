import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists and exposes the app-wide [ThemeMode].
class ThemeStore extends ChangeNotifier {
  ThemeStore._();

  static final ThemeStore instance = ThemeStore._();
  static const String _themeModeKey = 'appearance.theme_mode';

  ThemeMode _themeMode = ThemeMode.light;
  SharedPreferences? _preferences;

  ThemeMode get themeMode => _themeMode;

  Future<void> init() async {
    final preferences = await SharedPreferences.getInstance();
    _preferences = preferences;
    _themeMode = _fromName(preferences.getString(_themeModeKey));
  }

  Future<void> cycleThemeMode() async {
    final next = switch (_themeMode) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    await setThemeMode(next);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    if (_themeMode == value) return;

    _themeMode = value;
    notifyListeners();

    final preferences = _preferences ??= await SharedPreferences.getInstance();
    await preferences.setString(_themeModeKey, value.name);
  }

  ThemeMode _fromName(String? name) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == name,
      orElse: () => ThemeMode.light,
    );
  }
}
