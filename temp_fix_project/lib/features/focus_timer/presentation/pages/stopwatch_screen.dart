import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker_ios/core/constants/app_colors.dart';
import '../controllers/stopwatch_controller.dart';
import 'package:habit_tracker_ios/shared_widgets/adaptive_layout.dart';

class StopwatchScreen extends ConsumerStatefulWidget {
  const StopwatchScreen({super.key});

  @override
  ConsumerState<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends ConsumerState<StopwatchScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _currentDisplay = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final state = ref.read(stopwatchProvider);
      if (state.isRunning) {
        setState(() {
          _currentDisplay = state.currentElapsed;
        });
      }
    });
    // Start ticker only if existing state is running
    final initialState = ref.read(stopwatchProvider);
    _currentDisplay = initialState.currentElapsed;
    if (initialState.isRunning) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onProviderStateChange(StopwatchState prev, StopwatchState next) {
    if (next.isRunning && !_ticker.isTicking) {
      _ticker.start();
    } else if (!next.isRunning && _ticker.isTicking) {
      _ticker.stop();
    }
    // Update local display immediately if stopped or reset manually
    if (!next.isRunning) {
      setState(() {
        _currentDisplay = next.currentElapsed;
      });
    }
  }

  String _formatTime(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final centiseconds =
        (d.inMilliseconds.remainder(1000) / 10).floor().toString().padLeft(2, '0');

    if (hours > 0) {
      final h = hours.toString().padLeft(2, '0');
      return '$h:$minutes:$seconds:$centiseconds';
    }
    return '$minutes:$seconds:$centiseconds';
  }

  void _toggleStartStop(StopwatchState state) {
    if (state.isRunning) {
      ref.read(stopwatchProvider.notifier).stop();
    } else {
      ref.read(stopwatchProvider.notifier).start();
    }
  }

  void _onLeftBtn(StopwatchState state) {
    if (state.isRunning) {
      // Lap
      ref.read(stopwatchProvider.notifier).addLap();
    } else if (state.currentElapsed > Duration.zero) {
      // Reset
      ref.read(stopwatchProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes for ticking logistics without rebuilding everything unnecessarily.
    // Wait, ref.listen handles side effects, ref.watch handles data.
    ref.listen<StopwatchState>(stopwatchProvider, (prev, next) {
      _onProviderStateChange(prev ?? const StopwatchState(), next);
    });
    final state = ref.watch(stopwatchProvider);

    final isIdle = !state.isRunning && state.currentElapsed == Duration.zero;
    final isRunning = state.isRunning;

    // Determine left button state
    final String leftLabel = isRunning || isIdle ? 'Lap' : 'Reset';
    final bool leftEnabled = isRunning || (!isRunning && !isIdle);
    final Color leftColor = !leftEnabled
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final Color leftTextColor =
        !leftEnabled ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : Theme.of(context).colorScheme.onSurface;

    // Determine right button state
    final String rightLabel = isRunning ? 'Stop' : 'Start';
    final Color rightColor =
        isRunning ? const Color(0xFFEF4444) : const Color(0xFF22C55E);

    return AdaptiveBody(
      child: Container(
        color: Colors.transparent,
        child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
              child: Center(
                child: Text(
                  'Stopwatch',
                  style: GoogleFonts.greatVibes(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),

            // Time Display Display Group
            const Spacer(flex: 2),
            Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.spaceMono(
                  fontSize: _currentDisplay.inHours > 0 ? 52 : 64,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -1.5,
                ),
                child: Text(_formatTime(_currentDisplay)),
              ),
            ),
            const Spacer(flex: 2),

            // Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Btn
                  _CircleButton(
                    label: leftLabel,
                    color: leftColor,
                    textColor: leftTextColor,
                    enabled: leftEnabled,
                    onTap: () => _onLeftBtn(state),
                  ),
                  // Right Btn
                  _CircleButton(
                    label: rightLabel,
                    color: rightColor.withValues(alpha: 0.15),
                    textColor: rightColor,
                    enabled: true,
                    innerColor: rightColor,
                    onTap: () => _toggleStartStop(state),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
            Container(height: 1, color: Theme.of(context).colorScheme.outline),

            // Laps List
            Expanded(
              flex: 5,
              child: state.laps.isEmpty
                  ? Center(
                      child: Text(
                        'No laps yet',
                        style: GoogleFonts.poppins(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
                      itemCount: state.laps.length,
                      itemBuilder: (context, index) {
                        final isLatest = index == 0;
                        final lapIdx = state.laps.length - index;
                        final lap = state.laps[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lap $lapIdx',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: isLatest ? FontWeight.w600 : FontWeight.w400,
                                  color: isLatest
                                      ? AppColors.primary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                _formatTime(lap),
                                style: GoogleFonts.spaceMono(
                                  fontSize: 16,
                                  fontWeight: isLatest
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isLatest
                                      ? AppColors.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ── Circle Button Component ────────────────────────────────────────────────────
class _CircleButton extends StatefulWidget {
  final String label;
  final Color color;
  final Color textColor;
  final bool enabled;
  final VoidCallback onTap;
  final Color? innerColor;

  const _CircleButton({
    required this.label,
    required this.color,
    required this.textColor,
    required this.enabled,
    required this.onTap,
    this.innerColor,
  });

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool hasInner = widget.innerColor != null;

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel:
          widget.enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.diagonal3Values(
          _pressed ? 0.94 : 1.0,
          _pressed ? 0.94 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
        ),
        child: Center(
          child: hasInner
              ? Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.innerColor,
                  ),
                  child: Center(
                    child: Text(
                      widget.label,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: widget.textColor,
                  ),
                ),
        ),
      ),
    );
  }
}
