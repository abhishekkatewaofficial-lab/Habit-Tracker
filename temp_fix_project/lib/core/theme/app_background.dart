import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/theme/theme_provider.dart';

// ── 5 Preset Light Pastel Gradient Themes ─────────────────────────────────────

class AppGradientTheme {
  final String name;
  final List<Color> colors;

  const AppGradientTheme({
    required this.name,
    required this.colors,
  });

  LinearGradient toGradient() => LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

const List<AppGradientTheme> kGradientThemes = [
  AppGradientTheme(
    name: 'Set 1',
    colors: [Color(0xFFE6F3E8), Color(0xFFCFE2FA), Color(0xFFF8DEE6)],
  ),
  AppGradientTheme(
    name: 'Set 2',
    colors: [Color(0xFFFFE9CC), Color(0xFFCFEAFC), Color(0xFFEBD8F1)],
  ),
  AppGradientTheme(
    name: 'Set 3',
    colors: [Color(0xFFDDF0DF), Color(0xFFB9DAFA), Color(0xFFF7D0DC)],
  ),
  AppGradientTheme(
    name: 'Set 4',
    colors: [Color(0xFFE1F3EF), Color(0xFFC3CAE9), Color(0xFFFFE0D4)],
  ),
  AppGradientTheme(
    name: 'Set 5',
    colors: [Color(0xFFE6F4C9), Color(0xFFAEE2FB), Color(0xFFE5CFF0)],
  ),
];

// ── 5 Preset Dark Gradient Themes ────────────────────────────────────────────
// Deep, AMOLED-friendly near-black gradients — soft directional depth
const List<AppGradientTheme> kDarkGradientThemes = [
  AppGradientTheme(
    name: 'Midnight',
    colors: [Color(0xFF0D0D0F), Color(0xFF1A1A2E)],
  ),
  AppGradientTheme(
    name: 'Deep Ocean',
    colors: [Color(0xFF0A0E1A), Color(0xFF141E30)],
  ),
  AppGradientTheme(
    name: 'Obsidian',
    colors: [Color(0xFF0D0D0D), Color(0xFF1C1C1E)],
  ),
  AppGradientTheme(
    name: 'Abyss',
    colors: [Color(0xFF0F0A1A), Color(0xFF1A1028)],
  ),
  AppGradientTheme(
    name: 'Carbon',
    colors: [Color(0xFF0D100D), Color(0xFF141A14)],
  ),
];

// ── Global Background Theme Provider ─────────────────────────────────────────

/// Picks once at app launch – same index for both light and dark variants.
final globalBackgroundThemeProvider = Provider<int>((ref) {
  return Random().nextInt(kGradientThemes.length);
});

// ── Reusable Background Widget ────────────────────────────────────────────────

/// Wrap any Scaffold/page body with this to apply the theme-aware gradient.
/// All inner Scaffolds should set `backgroundColor: Colors.transparent`.
class AppBackground extends ConsumerWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeIndex = ref.watch(globalBackgroundThemeProvider);
    final themeMode = ref.watch(themeProvider);
    final platformBrightness = MediaQuery.of(context).platformBrightness;

    final isDark = themeMode == ThemeModeType.dark ||
        (themeMode == ThemeModeType.system &&
            platformBrightness == Brightness.dark);

    if (isDark) {
      // Dark mode: pure AMOLED black — no gradient
      return Container(
        color: const Color(0xFF000000),
        child: child,
      );
    }

    // Light mode: pastel gradient with soft 20% white overlay for readability
    final gradientTheme = kGradientThemes[themeIndex];
    return Container(
      decoration: BoxDecoration(
        gradient: gradientTheme.toGradient(),
      ),
      child: Container(
        color: Colors.white.withValues(alpha: 0.18),
        child: child,
      ),
    );
  }
}
