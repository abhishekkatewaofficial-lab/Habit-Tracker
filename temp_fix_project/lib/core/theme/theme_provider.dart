import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Theme Mode Enum ───────────────────────────────────────────────────────────
enum ThemeModeType { light, dark, system }

// ── Persistence Key ───────────────────────────────────────────────────────────
const _kThemeModeKey = 'app_theme_mode';

// ── Notifier ──────────────────────────────────────────────────────────────────
class ThemeModeNotifier extends Notifier<ThemeModeType> {
  @override
  ThemeModeType build() {
    // Load persisted value asynchronously; defaults to system
    _loadFromPrefs();
    return ThemeModeType.system;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeModeKey);
    if (stored != null) {
      state = ThemeModeType.values.firstWhere(
        (e) => e.name == stored,
        orElse: () => ThemeModeType.system,
      );
    }
  }

  Future<void> setMode(ThemeModeType mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, mode.name);
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────
final themeProvider = NotifierProvider<ThemeModeNotifier, ThemeModeType>(
  ThemeModeNotifier.new,
);
