import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists light/dark choice and notifies listeners (e.g. [MaterialApp] rebuild).
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _key = 'colony_use_dark_theme';

  bool _useDark = false;
  bool get useDark => _useDark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _useDark = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> setUseDark(bool value) async {
    if (_useDark == value) return;
    _useDark = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    notifyListeners();
  }
}
