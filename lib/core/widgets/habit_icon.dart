import 'package:flutter/material.dart';

class HabitIcon extends StatelessWidget {
  final String iconStr;
  final Color? color;
  final double size;

  const HabitIcon({
    super.key,
    required this.iconStr,
    this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    // If it's a known asset path
    if (iconStr.contains('.png') || iconStr.contains('.svg') || iconStr.contains('assets/')) {
      return Image.asset(
        iconStr,
        width: size,
        height: size,
        fit: BoxFit.contain,
        color: color, 
        errorBuilder: (context, error, stackTrace) => Text(
          '🎯', // Default fallback for broken assets (like cached .DS_Store)
          style: TextStyle(fontSize: size),
        ),
      );
    }
    
    // Fallback to traditional emoji String rendering
    return Text(
      iconStr,
      style: TextStyle(
        fontSize: size,
        height: 1.0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
  }
}
