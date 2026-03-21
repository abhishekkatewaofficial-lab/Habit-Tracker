import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker_ios/core/constants/app_colors.dart';

/// App-wide text styles built on Google Fonts Inter.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => GoogleFonts.inter(
        color: AppColors.textPrimary,
      ).copyWith(
        fontFamilyFallback: const ['.SF Pro Display', 'Helvetica Neue'],
      );

  static TextStyle get displayLarge =>
      _base.copyWith(fontSize: 34, fontWeight: FontWeight.w700, height: 1.2);
  static TextStyle get displayMedium =>
      _base.copyWith(fontSize: 28, fontWeight: FontWeight.w700, height: 1.25);
  static TextStyle get displaySmall =>
      _base.copyWith(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle get headlineLarge =>
      _base.copyWith(fontSize: 20, fontWeight: FontWeight.w600);
  static TextStyle get headlineMedium =>
      _base.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
  static TextStyle get headlineSmall =>
      _base.copyWith(fontSize: 16, fontWeight: FontWeight.w600);

  static TextStyle get bodyLarge =>
      _base.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle get bodyMedium =>
      _base.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5);
  static TextStyle get bodySmall =>
      _base.copyWith(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4);

  static TextStyle get labelLarge =>
      _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500);
  static TextStyle get labelMedium =>
      _base.copyWith(fontSize: 12, fontWeight: FontWeight.w500);
  static TextStyle get labelSmall =>
      _base.copyWith(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.5);

  static TextStyle get hint =>
      bodyMedium.copyWith(color: AppColors.textHint);
  static TextStyle get secondary =>
      bodyMedium.copyWith(color: AppColors.textSecondary);

  static TextStyle get diaryTitle => GoogleFonts.dancingScript(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );
}
