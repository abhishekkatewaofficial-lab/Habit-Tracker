import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker_ios/core/services/step_tracking_service.dart';

/// Full-screen permission rationale shown before calling the OS prompt.
/// Pushes itself onto the navigator and pops with `true` (granted) or `false` (manual).
class StepPermissionScreen extends ConsumerWidget {
  const StepPermissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF101010) : const Color(0xFFF5F7FA);
    final surface = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final onSurface = isDark ? Colors.white : const Color(0xFF1F2937);
    const accent = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // ── Icon ──
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('👟', style: TextStyle(fontSize: 48)),
                ),
              ),
              const SizedBox(height: 36),

              // ── Title ──
              Text(
                'Track your steps\nautomatically',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),

              // ── Body ──
              Text(
                'We use your phone\'s built-in motion sensor — no internet or Health account needed.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: onSurface.withValues(alpha: 0.6),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),

              // ── Feature pills ──
              _FeaturePill(
                icon: CupertinoIcons.bolt_horizontal_fill,
                label: 'Auto-fills your step habit progress',
                surface: surface,
                onSurface: onSurface,
              ),
              const SizedBox(height: 12),
              _FeaturePill(
                icon: CupertinoIcons.lock_shield_fill,
                label: 'Works entirely on-device — private',
                surface: surface,
                onSurface: onSurface,
              ),
              const SizedBox(height: 12),
              _FeaturePill(
                icon: CupertinoIcons.battery_100,
                label: 'Low battery impact — reads once per session',
                surface: surface,
                onSurface: onSurface,
              ),

              const Spacer(flex: 3),

              // ── Primary CTA ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    // Mark granted optimistically — the OS dialog follows.
                    // If sensor fails later, the service marks denied automatically.
                    ref.read(stepPermissionProvider.notifier).markGranted();
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: accent.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    'Allow Step Tracking',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Secondary: skip to manual ──
              TextButton(
                onPressed: () {
                  ref.read(stepPermissionProvider.notifier).markDenied();
                  Navigator.of(context).pop(false);
                },
                child: Text(
                  'Enter steps manually instead',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color surface;
  final Color onSurface;

  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.surface,
    required this.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
