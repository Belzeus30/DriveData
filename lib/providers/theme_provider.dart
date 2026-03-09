import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeMode = 'theme_mode';
const _kSeedColor = 'seed_color';

/// Manages the app's visual theme: [ThemeMode] and seed colour.
///
/// Settings are persisted to [SharedPreferences] under the keys
/// `theme_mode` (int index of [ThemeMode]) and `seed_color` (ARGB int).
///
/// [availableColors] contains the 7 preset seed colours; their user-visible
/// labels are in [colorNames] (kept in matching order).
///
/// [buildTheme] constructs a Material 3 [ThemeData] from the active seed
/// colour and the supplied brightness, with app-specific overrides for
/// cards, app-bars, chips, inputs and buttons.
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Color _seedColor = const Color(0xFF1565C0);

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  static const List<Color> availableColors = [
    Color(0xFF1565C0), // Blue (default)
    Color(0xFF2E7D32), // Green
    Color(0xFFC62828), // Red
    Color(0xFF6A1B9A), // Purple
    Color(0xFFE65100), // Orange
    Color(0xFF00695C), // Teal
    Color(0xFF37474F), // Grey
  ];

  static const List<String> colorNames = [
    'Blue',
    'Green',
    'Red',
    'Purple',
    'Orange',
    'Teal',
    'Grey',
  ];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_kThemeMode) ?? 0;
    final colorValue =
        prefs.getInt(_kSeedColor) ?? const Color(0xFF1565C0).toARGB32();
    _themeMode = ThemeMode.values[modeIndex];
    _seedColor = Color(colorValue);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, mode.index);
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSeedColor, color.toARGB32());
  }

  ThemeData buildTheme(Brightness brightness) {
    final cs = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 2,
        shadowColor: cs.shadow.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
          letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 8,
        shadowColor: cs.shadow,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
    );
  }
}
