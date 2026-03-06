import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  static final ThemeController instance = ThemeController._internal();

  factory ThemeController() {
    return instance;
  }

  ThemeController._internal() : super(ThemeMode.light) {
    _loadTheme();
  }

  static const String _key = 'admin_dark_mode';

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_key) ?? false;
    value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    final isDark = value == ThemeMode.dark;
    value = isDark ? ThemeMode.light : ThemeMode.dark;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, !isDark);
  }
}
