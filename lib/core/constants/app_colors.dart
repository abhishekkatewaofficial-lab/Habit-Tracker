import 'package:flutter/material.dart';

/// Centralised colour palette – pastel / iOS-inspired.
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
