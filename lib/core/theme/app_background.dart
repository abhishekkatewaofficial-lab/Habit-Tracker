import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── 5 Preset Pastel Gradient Themes ─────────────────────────────────────────

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

// ── Global Background Theme Provider ─────────────────────────────────────────

/// Picked once at app launch and held for the entire session.
final globalBackgroundThemeProvider = Provider<AppGradientTheme>((ref) {
  final index = Random().nextInt(kGradientThemes.length);
  return kGradientThemes[index];
});

// ── Reusable Background Widget ────────────────────────────────────────────────

/// Wrap any Scaffold/page body with this to apply the app-wide gradient.
/// All inner Scaffolds should set `backgroundColor: Colors.transparent`.
class AppBackground extends ConsumerWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(globalBackgroundThemeProvider);
    return Container(
      decoration: BoxDecoration(
        gradient: theme.toGradient(),
      ),
      child: child,
    );
  }
}
