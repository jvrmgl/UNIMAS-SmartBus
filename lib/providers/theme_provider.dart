import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  static const String _boxName = 'settings';
  static const String _themeKey = 'themeMode';

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final box = await Hive.openBox(_boxName);
    final index = box.get(_themeKey, defaultValue: ThemeMode.light.index) as int;
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.index == index,
      orElse: () => ThemeMode.light,
    );
    notifyListeners();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final box = await Hive.openBox(_boxName);
    await box.put(_themeKey, mode.index);
  }
}
