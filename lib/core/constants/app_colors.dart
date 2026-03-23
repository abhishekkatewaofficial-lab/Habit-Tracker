import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/theme/theme_provider.dart';

/// Centralised colour palette – pastel / iOS-inspired, static constants.
class AppColors {
  AppColors._();

  // ── Brand / Accent ────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF7B8FF7);       // soft indigo
  static const Color primaryLight = Color(0xFFB5BEFF);  // lavender tint
  static const Color primaryDark = Color(0xFF5A6DD8);   // deeper indigo
  static const Color accent = Color(0xFFFF8FAB);        // pastel rose

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF6DCEA8);   // mint green
  static const Color warning = Color(0xFFFFD166);   // soft amber
  static const Color error = Color(0xFFFF6B6B);     // coral red
  static const Color info = Color(0xFF74C0FC);      // sky blue

  // ── Neutrals ──────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF8F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F1F8);
  static const Color outline = Color(0xFFE2E2EC);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7080);
  static const Color textHint = Color(0xFFA8AABB);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Category pastels (for habit cards) ───────────────────────────────────
  static const Color pastelBlue = Color(0xFFBDD7FF);
  static const Color pastelPurple = Color(0xFFD5C5F7);
  static const Color pastelPink = Color(0xFFFFCCDB);
  static const Color pastelGreen = Color(0xFFC4EDDA);
  static const Color pastelOrange = Color(0xFFFFDFB5);
  static const Color pastelYellow = Color(0xFFFFF3B0);
  static const Color pastelTeal = Color(0xFFB5EAE4);
  static const Color pastelRed = Color(0xFFFFCDD2);

  static const List<Color> pastelPalette = [
    pastelBlue,
    pastelPurple,
    pastelPink,
    pastelGreen,
    pastelOrange,
    pastelYellow,
    pastelTeal,
    pastelRed,
  ];
}

// ── Dynamic ThemeColors — resolves to light or dark ──────────────────────────

class ThemeColors {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color primary;
  final Color accent;
  final Color success;
  final Color warning;
  final Color error;
  final bool isDark;

  const ThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.primary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.isDark,
  });

  /// Reads the current theme mode from Riverpod + MediaQuery to resolve the
  /// correct colour set. Call inside a ConsumerWidget or Consumer.
  static ThemeColors of(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    final platformBrightness = MediaQuery.of(context).platformBrightness;

    final dark = mode == ThemeModeType.dark ||
        (mode == ThemeModeType.system && platformBrightness == Brightness.dark);

    return dark ? _dark : _light;
  }

  static const ThemeColors _light = ThemeColors(
    background: Color(0xFFF8F8FC),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF1F1F8),
    outline: Color(0xFFE2E2EC),
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF6B7080),
    textHint: Color(0xFFA8AABB),
    primary: Color(0xFF7B8FF7),
    accent: Color(0xFFFF8FAB),
    success: Color(0xFF6DCEA8),
    warning: Color(0xFFFFD166),
    error: Color(0xFFFF6B6B),
    isDark: false,
  );

  static const ThemeColors _dark = ThemeColors(
    background: Color(0xFF0D0D0F),
    surface: Color(0xFF1C1C1E),
    surfaceVariant: Color(0xFF2C2C2E),
    outline: Color(0xFF38383A),
    textPrimary: Color(0xFFECECEF),
    textSecondary: Color(0xFFB0B0B5),
    textHint: Color(0xFF636366),
    primary: Color(0xFF8A7BFF),
    accent: Color(0xFFFF8FAB),
    success: Color(0xFF30D158),
    warning: Color(0xFFFF9F0A),
    error: Color(0xFFFF453A),
    isDark: true,
  );
}
