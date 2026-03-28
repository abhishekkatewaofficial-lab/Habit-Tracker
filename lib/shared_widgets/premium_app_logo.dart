import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Supported premium styles for the Habit Tracker logo.
enum AppLogoStyle {
  /// #A6C875 → #579A70
  premiumGreen,
  /// #157DEC → #082567
  deepBlue,
  /// White on dark, or primary on light
  monochrome,
}

/// A high-fidelity, resolution-independent vector logo for Habit Tracker.
/// Uses [CustomPainter] to render the "Growth Arc" and "Integrated Checkmark."
class PremiumAppLogo extends StatelessWidget {
  final double size;
  final AppLogoStyle style;
  final bool showBackground;

  const PremiumAppLogo({
    super.key,
    this.size = 120,
    this.style = AppLogoStyle.premiumGreen,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(
          style: style,
          isDark: isDark,
          showBackground: showBackground,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final AppLogoStyle style;
  final bool isDark;
  final bool showBackground;

  _LogoPainter({
    required this.style,
    required this.isDark,
    required this.showBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // ── 1. Background (iOS-style Rounded Canvas) ──────────────────────────
    if (showBackground) {
      final bgPaint = Paint();
      
      if (style == AppLogoStyle.monochrome) {
        bgPaint.color = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF8F8FC);
      } else {
        // Dark metallic gradient background for premium pop
        bgPaint.shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF2C2C2E) : const Color(0xFFFFFFFF),
            isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF1F1F8),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      }

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(size.width * 0.223), // Standard iOS corner radius ratio
      );
      canvas.drawRRect(rrect, bgPaint);
      
      // Subtle Border
      final borderPaint = Paint()
        ..color = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(rrect, borderPaint);
    }

    // ── 2. The "Habit Loop" (Faded Circle Trace) ───────────────────────────
    final loopPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06
      ..strokeCap = StrokeCap.round
      ..color = _getPrimaryColor().withValues(alpha: 0.12);

    final loopPath = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius * 0.6),
        math.pi * 0.7,
        math.pi * 1.5,
      );
    canvas.drawPath(loopPath, loopPaint);

    // ── 3. The "Growth Arc" & "Checkmark" (Main Icon) ──────────────────────
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Main Gradient
    mainPaint.shader = _getPrimaryGradient().createShader(
      Rect.fromCircle(center: center, radius: radius * 0.8),
    );

    // Add glowing shadow effect (Subtle Depth)
    mainPaint.maskFilter = const MaskFilter.blur(BlurStyle.solid, 0.5);

    // Define the path: A smooth parabolic arc leading into a checkmark
    final iconPath = Path();
    
    // Starting point (Bottom Left quadrant)
    iconPath.moveTo(size.width * 0.32, size.height * 0.68);
    
    // Smooth quadratic curve to the peak (representing Progress/Rise)
    iconPath.quadraticBezierTo(
      size.width * 0.45, size.height * 0.85, // control
      size.width * 0.72, size.height * 0.38, // end peak
    );
    
    // Integrated Checkmark stroke (The "Completion" return)
    iconPath.relativeLineTo(size.width * 0.08, size.height * 0.08);

    // Drop shadow for the main stroke only for premium punch
    canvas.drawShadow(iconPath, Colors.black.withValues(alpha: 0.15), 4, false);
    canvas.drawPath(iconPath, mainPaint);

    // ── 4. The "Spark" (Subtle Growth Element) ───────────────────────────
    final sparkPaint = Paint()
      ..color = _getPrimaryColor().withValues(alpha: 0.8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.38),
      size.width * 0.035,
      sparkPaint,
    );
  }

  Color _getPrimaryColor() {
    switch (style) {
      case AppLogoStyle.premiumGreen: return const Color(0xFF579A70);
      case AppLogoStyle.deepBlue: return const Color(0xFF157DEC);
      case AppLogoStyle.monochrome: return isDark ? Colors.white : const Color(0xFF1A1A2E);
    }
  }

  Gradient _getPrimaryGradient() {
    switch (style) {
      case AppLogoStyle.premiumGreen:
        return const LinearGradient(
          colors: [Color(0xFFA6C875), Color(0xFF579A70)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        );
      case AppLogoStyle.deepBlue:
        return const LinearGradient(
          colors: [Color(0xFF157DEC), Color(0xFF082567)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        );
      case AppLogoStyle.monochrome:
        final color = isDark ? Colors.white : const Color(0xFF1A1A2E);
        return LinearGradient(colors: [color, color]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
