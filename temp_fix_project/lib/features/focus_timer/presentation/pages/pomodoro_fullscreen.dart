import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/pomodoro_controller.dart';

class PomodoroFullscreen extends ConsumerStatefulWidget {
  const PomodoroFullscreen({super.key});

  @override
  ConsumerState<PomodoroFullscreen> createState() => _PomodoroFullscreenState();
}

class _PomodoroFullscreenState extends ConsumerState<PomodoroFullscreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _currentDisplay = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Defer orientation change to avoid race with main.dart's portraitUp lock
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    });

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
    // Restore portrait orientation via microtask to avoid engine-level race
    Future.microtask(() {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    });
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

  @override
  Widget build(BuildContext context) {
    ref.listen<PomodoroState>(pomodoroProvider, (prev, next) {
      _onProviderStateChange(prev ?? const PomodoroState(), next);
    });
    final state = ref.watch(pomodoroProvider);

    final minutes = _currentDisplay.inMinutes.toString().padLeft(2, '0');
    final seconds = _currentDisplay.inSeconds.remainder(60).toString().padLeft(2, '0');



    const Color tintColor = Colors.white;

    return Scaffold(
      backgroundColor: Colors.black, // Pure AMOLED black
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            Navigator.pop(context);
          }
        },
        child: Stack(
          children: [
            // Center Flip Clock
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.isBreak)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _FlipDigit(
                        value: int.parse(minutes[0]),
                        color: tintColor,
                      ),
                      const SizedBox(width: 8),
                      _FlipDigit(
                        value: int.parse(minutes[1]),
                        color: tintColor,
                      ),
                      const SizedBox(width: 24),
                      _buildColon(),
                      const SizedBox(width: 24),
                      _FlipDigit(
                        value: int.parse(seconds[0]),
                        color: tintColor,
                      ),
                      const SizedBox(width: 8),
                      _FlipDigit(
                        value: int.parse(seconds[1]),
                        color: tintColor,
                      ),
                    ],
                  ),
                ],
              ),
                ),
              ),
            ),

            // Controls & Session Dots (Bottom Center)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Playback Controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (state.isRunning) {
                              ref.read(pomodoroProvider.notifier).pause();
                            } else {
                              ref.read(pomodoroProvider.notifier).start();
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.transparent,
                            child: Icon(
                              state.isRunning ? CupertinoIcons.pause_circle : CupertinoIcons.play_circle,
                              color: Colors.white,
                              size: 56,
                            ),
                          ),
                        ),
                        if (state.isBreak) ...[
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: () => ref.read(pomodoroProvider.notifier).skipBreak(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                color: Colors.transparent,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Skip Break',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.skip_next_rounded, size: 20, color: Colors.white),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Session Dots
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(state.totalSessions, (index) {
                        final isCompleted = index < state.currentSessionIndex;
                        final isCurrent = index == state.currentSessionIndex;

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? Colors.grey.shade600
                                : (isCurrent && !state.isBreak
                                    ? Colors.white
                                    : Colors.grey.shade800),
                            border: isCompleted || (isCurrent && !state.isBreak)
                                ? null
                                : Border.all(color: Colors.grey.shade800, width: 2),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),

            // Exit Button (Top Right)
            Positioned(
              top: 24,
              right: 32,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColon() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

// ── Flip Digit Implementation ──────────────────────────────────────────────────

class _FlipDigit extends StatefulWidget {
  final int value;
  final Color color;

  const _FlipDigit({required this.value, required this.color});

  @override
  State<_FlipDigit> createState() => _FlipDigitState();
}

class _FlipDigitState extends State<_FlipDigit>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  int _currentValue = 0;
  int _nextValue = 0;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _nextValue = widget.value;
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void didUpdateWidget(_FlipDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _nextValue) {
      _currentValue = _nextValue;
      _nextValue = widget.value;
      _anim.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onAnimCompleted() {
    if (_anim.isCompleted) {
      setState(() {
        _currentValue = _nextValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _anim.addListener(_onAnimCompleted);
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final val = _anim.value;

        // Front card halves (top is next, bottom is current)
        final topCardNext = _buildCardHalf(true, _nextValue);
        final bottomCardCurrent = _buildCardHalf(false, _currentValue);

        // Flipping halves
        // Top half flips down (from 0 to pi/2, shows current value)
        // Bottom half flips down (from -pi/2 to 0, shows next value)
        
        Widget topFlip;
        Widget bottomFlip;

        if (val <= 0.5) {
          final angle = val * pi; // 0 to pi/2
          topFlip = Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.003)
              ..rotateX(angle),
            alignment: Alignment.bottomCenter,
            child: _buildCardHalf(true, _currentValue),
          );
          bottomFlip = const SizedBox.shrink(); // hidden
        } else {
          final angle = (val - 1.0) * pi; // -pi/2 to 0
          topFlip = const SizedBox.shrink(); // hidden
          bottomFlip = Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.003)
              ..rotateX(angle),
            alignment: Alignment.topCenter,
            child: _buildCardHalf(false, _nextValue),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF151515), // distinct card color against bg
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Base background cards
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  topCardNext,
                  Container(height: 2, width: 140, color: widget.color.withValues(alpha: 0.8)), // the split line
                  bottomCardCurrent,
                ],
              ),
              // Flipping mechanics
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: topFlip,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: bottomFlip,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardHalf(bool isTop, int displayValue) {
    return ClipRect(
      child: Align(
        alignment: isTop ? Alignment.topCenter : Alignment.bottomCenter,
        heightFactor: 0.5,
        child: Container(
          width: 140,
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            displayValue.toString(),
            style: GoogleFonts.spaceMono(
              fontSize: 140,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
