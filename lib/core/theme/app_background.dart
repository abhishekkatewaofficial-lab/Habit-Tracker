import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/theme/theme_provider.dart';

// ── 5 Preset Light Pastel Gradient Themes ─────────────────────────────────────

class AppGradientTheme {
  final String name;
  final Color start;
  final Color end;

  const AppGradientTheme({
    required this.name,
    required this.start,
    required this.end,
  });

  LinearGradient toGradient() => LinearGradient(
        colors: [start, end],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

const List<AppGradientTheme> kGradientThemes = [
  // Theme 1: Soft Peach → Light Pink
  AppGradientTheme(
    name: 'Peach Bloom',
    start: Color(0xFFFFF0E8),
    end: Color(0xFFFDE4EE),
  ),
  // Theme 2: Baby Blue → Lavender
  AppGradientTheme(
    name: 'Sky Dream',
    start: Color(0xFFE8F4FD),
    end: Color(0xFFEDE8FD),
  ),
  // Theme 3: Mint Green → Soft Teal
  AppGradientTheme(
    name: 'Fresh Mint',
    start: Color(0xFFE8FAF3),
    end: Color(0xFFE4F5F2),
  ),
  // Theme 4: Light Yellow → Cream
  AppGradientTheme(
    name: 'Morning Sun',
    start: Color(0xFFFFFBE8),
    end: Color(0xFFFCF4E4),
  ),
  // Theme 5: Soft Purple → Light Blue
  AppGradientTheme(
    name: 'Dusk Haze',
    start: Color(0xFFF2E8FD),
    end: Color(0xFFE6EFFE),
  ),
];

// ── 5 Preset Dark Gradient Themes ────────────────────────────────────────────
// Deep, AMOLED-friendly near-black gradients — soft directional depth
const List<AppGradientTheme> kDarkGradientThemes = [
  AppGradientTheme(
    name: 'Midnight',
    start: Color(0xFF0D0D0F),
    end: Color(0xFF1A1A2E),
  ),
  AppGradientTheme(
    name: 'Deep Ocean',
    start: Color(0xFF0A0E1A),
    end: Color(0xFF141E30),
  ),
  AppGradientTheme(
    name: 'Obsidian',
    start: Color(0xFF0D0D0D),
    end: Color(0xFF1C1C1E),
  ),
  AppGradientTheme(
    name: 'Abyss',
    start: Color(0xFF0F0A1A),
    end: Color(0xFF1A1028),
  ),
  AppGradientTheme(
    name: 'Carbon',
    start: Color(0xFF0D100D),
    end: Color(0xFF141A14),
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

    // Light mode: pastel gradient
    final gradientTheme = kGradientThemes[themeIndex];
    return Container(
      decoration: BoxDecoration(
        gradient: gradientTheme.toGradient(),
      ),
      child: child,
    );
  }
}
