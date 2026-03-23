import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker_ios/core/constants/app_colors.dart';
import '../controllers/pomodoro_controller.dart';
import 'pomodoro_fullscreen.dart';

class FocusTimerScreen extends ConsumerStatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  ConsumerState<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends ConsumerState<FocusTimerScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _currentDisplay = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final state = ref.read(pomodoroProvider);
      if (state.isRunning) {
        setState(() {
          _currentDisplay = state.currentRemaining;
        });
        ref.read(pomodoroProvider.notifier).checkTick();
      }
    });

    final initialState = ref.read(pomodoroProvider);
    _currentDisplay = initialState.currentRemaining;
    if (initialState.isRunning) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onProviderStateChange(PomodoroState prev, PomodoroState next) {
    if (next.isRunning) {
      if (!_ticker.isTicking && !_ticker.isActive) {
        _ticker.start();
      }
    } else {
      if (_ticker.isTicking || _ticker.isActive) {
        _ticker.stop();
      }
    }

    if (!next.isRunning) {
      setState(() {
        _currentDisplay = next.currentRemaining;
      });
    }
  }

  String _formatTime(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showSetupModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PomodoroSetupModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PomodoroState>(pomodoroProvider, (prev, next) {
      _onProviderStateChange(prev ?? const PomodoroState(), next);
    });
    final state = ref.watch(pomodoroProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isIdle = !state.isRunning &&
        state.currentSessionIndex == 0 &&
        !state.isBreak &&
        state.currentRemaining.inSeconds == (state.focusMinutes * 60);

    // Warm colors for Focus, Cool colors for Break
    final Color activeColor =
        state.isBreak ? const Color(0xFF26C6DA) : const Color(0xFFFF7043);

    final double totalS = state.isBreak
        ? state.breakMinutes * 60.0
        : state.focusMinutes * 60.0;
    final double elapsedS = totalS - _currentDisplay.inSeconds.toDouble();
    final double progress = totalS > 0 ? (elapsedS / totalS).clamp(0.0, 1.0) : 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final isCompact = h < 500; // landscape / small screen
        final clockSize = (h * 0.45).clamp(150.0, 260.0);
        final innerSize = clockSize - 20;
        final timeFontSize = isCompact ? 40.0 : 60.0;
        final topGap = isCompact ? 4.0 : h * 0.04;
        final midGap = isCompact ? 4.0 : h * 0.05;
        final bottomGap = isCompact ? 4.0 : h * 0.06;
        final bottomPad = isCompact ? 50.0 : 120.0;
        final headerFontSize = isCompact ? 26.0 : 40.0;

        return ClipRect(
          child: Container(
          color: Colors.transparent,
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.fromLTRB(20, topGap, 20, 4),
                  child: Center(
                    child: Text(
                      'Pomodoro',
                      style: GoogleFonts.greatVibes(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: topGap),

                // Circular Timer
                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PomodoroFullscreen(),
                        ),
                      );
                    },
                    child: SizedBox(
                      width: clockSize,
                      height: clockSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background Circle
                          Container(
                            width: innerSize,
                            height: innerSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.transparent : activeColor.withValues(alpha: 0.05),
                              boxShadow: isDark
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: activeColor.withValues(alpha: 0.1),
                                        blurRadius: 40,
                                        spreadRadius: 10,
                                      ),
                                    ],
                            ),
                          ),
                          // Progress Ring
                          SizedBox(
                            width: innerSize,
                            height: innerSize,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 10,
                              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.2) : Theme.of(context).colorScheme.outline,
                              valueColor: AlwaysStoppedAnimation<Color>(isDark ? Colors.white : activeColor),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          // Time Text
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isCompact && state.isBreak)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    "BREAK",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              Text(
                                _formatTime(_currentDisplay),
                                style: GoogleFonts.spaceMono(
                                  fontSize: timeFontSize,
                                  fontWeight: isDark ? FontWeight.bold : FontWeight.w400,
                                  color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                  letterSpacing: -1.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: midGap),

                // Session Indicator Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(state.totalSessions, (index) {
                    final isCompleted = index < state.currentSessionIndex;
                    final isCurrent = index == state.currentSessionIndex;
                    return TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 300),
                      tween: Tween(
                        begin: 0,
                        end: isCompleted || (isCurrent && !state.isBreak && state.isRunning) ? 1.0 : 0.0,
                      ),
                      builder: (context, val, child) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                                color: isCompleted
                                    ? (isDark ? Colors.white.withValues(alpha: 0.2) : Theme.of(context).colorScheme.onSurfaceVariant)
                                    : (isCurrent && !state.isBreak
                                        ? (isDark ? Colors.white.withValues(alpha: 0.2 + (0.8 * val)) : activeColor.withValues(alpha: 0.2 + (0.8 * val)))
                                        : (isDark ? Colors.transparent : Theme.of(context).colorScheme.outline)),
                              border: isCompleted || (isCurrent && !state.isBreak)
                                  ? null
                                  : Border.all(color: isDark ? Colors.white.withValues(alpha: 0.2) : Theme.of(context).colorScheme.outline, width: 2),
                          ),
                        );
                      },
                    );
                  }),
                ),
                if (!isCompact) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Session ${state.currentSessionIndex + 1} of ${state.totalSessions}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],

                SizedBox(height: bottomGap),

                // Controls
                if (isIdle)
                  _PremiumGradientButton(
                    label: 'New Pomodoro',
                    onTap: _showSetupModal,
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CircleControl(
                        icon: CupertinoIcons.refresh,
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surfaceContainerHighest,
                        iconColor: isDark ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                        onTap: () {
                          ref.read(pomodoroProvider.notifier).reset();
                        },
                      ),
                      const SizedBox(width: 24),
                      _CircleControl(
                        icon: state.isRunning
                            ? CupertinoIcons.pause_fill
                            : CupertinoIcons.play_fill,
                        color: isDark ? Colors.white.withValues(alpha: 0.2) : (state.isRunning ? activeColor : const Color(0xFF22C55E)),
                        iconColor: Colors.white,
                        isLarge: true,
                        onTap: () {
                          if (state.isRunning) {
                            ref.read(pomodoroProvider.notifier).pause();
                          } else {
                            ref.read(pomodoroProvider.notifier).start();
                          }
                        },
                      ),
                    ],
                  ),
                SizedBox(height: bottomPad),
              ],
            ),
          ),
         ),  // ClipRect
        );
      },
    );
  }
}

// ── Circle Controls ───────────────────────────────────────────────────────────

class _CircleControl extends StatefulWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final bool isLarge;
  final VoidCallback onTap;

  const _CircleControl({
    required this.icon,
    required this.color,
    required this.iconColor,
    this.isLarge = false,
    required this.onTap,
  });

  @override
  State<_CircleControl> createState() => _CircleControlState();
}

class _CircleControlState extends State<_CircleControl> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.isLarge ? 72.0 : 56.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.diagonal3Values(
          _pressed ? 0.94 : 1.0,
          _pressed ? 0.94 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            if (widget.isLarge && !_pressed)
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Icon(
          widget.icon,
          color: widget.iconColor,
          size: widget.isLarge ? 32 : 24,
        ),
      ),
    );
  }
}

// ── Premium Gradient Button ───────────────────────────────────────────────────
class _PremiumGradientButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _PremiumGradientButton({required this.label, required this.onTap});

  @override
  State<_PremiumGradientButton> createState() => _PremiumGradientButtonState();
}

class _PremiumGradientButtonState extends State<_PremiumGradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        transform: Matrix4.diagonal3Values(
          _pressed ? 0.96 : 1.0,
          _pressed ? 0.96 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        padding: isDark 
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: isDark 
            ? BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.accent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: _pressed ? 0.15 : 0.3),
                    blurRadius: _pressed ? 8 : 16,
                    offset: Offset(0, _pressed ? 4 : 8),
                  ),
                ],
              ),
        child: Text(
          widget.label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Setup Modal ───────────────────────────────────────────────────────────────
class _PomodoroSetupModal extends ConsumerStatefulWidget {
  const _PomodoroSetupModal();

  @override
  ConsumerState<_PomodoroSetupModal> createState() => _PomodoroSetupModalState();
}

class _PomodoroSetupModalState extends ConsumerState<_PomodoroSetupModal> {
  late int _focusM;
  late int _breakM;
  late int _sessions;

  @override
  void initState() {
    super.initState();
    final state = ref.read(pomodoroProvider);
    _focusM = state.focusMinutes;
    _breakM = state.breakMinutes;
    _sessions = state.totalSessions;
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Text(
                  'Configure Session',
                  style: GoogleFonts.greatVibes(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              _SetupRow(
                label: 'Focus Time',
                value: '$_focusM min',
                icon: CupertinoIcons.flame_fill,
                iconColor: const Color(0xFFFF7043),
                child: Slider(
                  value: _focusM.toDouble(),
                  min: 1,
                  max: 90,
                  activeColor: const Color(0xFFFF7043),
                  onChanged: (val) => setState(() => _focusM = val.toInt()),
                ),
              ),
              const SizedBox(height: 24),

              _SetupRow(
                label: 'Break Time',
                value: '$_breakM min',
                icon: CupertinoIcons.moon_stars_fill,
                iconColor: const Color(0xFF26C6DA),
                child: Slider(
                  value: _breakM.toDouble(),
                  min: 1,
                  max: 30,
                  activeColor: const Color(0xFF26C6DA),
                  onChanged: (val) => setState(() => _breakM = val.toInt()),
                ),
              ),
              const SizedBox(height: 24),

              _SetupRow(
                label: 'Total Sessions',
                value: '$_sessions',
                icon: CupertinoIcons.layers_alt_fill,
                iconColor: const Color(0xFF7E57C2),
                child: Slider(
                  value: _sessions.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: const Color(0xFF7E57C2),
                  onChanged: (val) => setState(() => _sessions = val.toInt()),
                ),
              ),
              const SizedBox(height: 48),

              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () {
                        final notif = ref.read(pomodoroProvider.notifier);
                        notif.configure(_focusM, _breakM, _sessions);
                        notif.start();
                        Navigator.pop(context);
                      },
                      child: Text(
                        'Start',
                        style: GoogleFonts.poppins(
                          color: Theme.of(context).colorScheme.surface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SetupRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: iconColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: child,
        ),
      ],
    );
  }
}
