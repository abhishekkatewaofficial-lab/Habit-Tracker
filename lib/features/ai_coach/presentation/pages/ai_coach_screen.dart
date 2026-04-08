import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/features/ai_coach/presentation/controllers/ai_coach_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AiCoachScreen — Apple Intelligence–style full-screen chat
// ─────────────────────────────────────────────────────────────────────────────

class AiCoachScreen extends ConsumerStatefulWidget {
  const AiCoachScreen({super.key});

  @override
  ConsumerState<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends ConsumerState<AiCoachScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _orbController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _orbController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    ref.read(aiCoachControllerProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiCoachControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Auto-scroll on new messages
    if (state.messages.isNotEmpty) _scrollToBottom();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D14) : const Color(0xFFF6F6FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark, state),
            Expanded(
              child: state.messages.isEmpty && !state.isBriefingLoading
                  ? _buildWelcomeState(context, isDark, state)
                  : _buildChatList(context, isDark, state),
            ),
            _buildInputBar(context, isDark, state),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark, AiCoachState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                CupertinoIcons.chevron_left,
                size: 18,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Animated orb
          AnimatedBuilder(
            animation: _orbController,
            builder: (_, __) {
              return Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    startAngle: 0,
                    endAngle: math.pi * 2,
                    transform: GradientRotation(_orbController.value * math.pi * 2),
                    colors: const [
                      Color(0xFF7B8FF7),
                      Color(0xFFB57BFF),
                      Color(0xFFFF8FAB),
                      Color(0xFF7B8FF7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7B8FF7).withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.sparkles,
                  size: 20,
                  color: Colors.white,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Habitus Coach',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    letterSpacing: -0.3,
                  ),
                ),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.isReplying
                              ? Color.lerp(
                                  const Color(0xFF30D158),
                                  const Color(0xFF7B8FF7),
                                  _pulseController.value,
                                )
                              : const Color(0xFF30D158),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        state.isReplying ? 'Thinking…' : 'AI Coach • Online',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7080),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Messages remaining badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7B8FF7), Color(0xFFB57BFF)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${state.messagesRemaining}/10',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Welcome / Empty State ──────────────────────────────────────────────────

  Widget _buildWelcomeState(BuildContext context, bool isDark, AiCoachState state) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 12),
        if (state.morningBriefing != null)
          _MorningBriefingCard(text: state.morningBriefing!, isDark: isDark),
        if (state.isBriefingLoading)
          _BriefingLoadingCard(isDark: isDark),
        const SizedBox(height: 24),
        _buildSuggestedQuestions(context, isDark, state),
      ],
    );
  }

  Widget _buildSuggestedQuestions(BuildContext context, bool isDark, AiCoachState state) {
    if (state.isLimitReached) {
      return _buildLimitReachedCard(isDark);
    }

    final questions = [
      'How are my habits doing this week?',
      'Which habits am I at risk of quitting?',
      'Give me a motivational pep talk 🔥',
      'What should I focus on today?',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ask me anything…',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7080),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        ...questions.map((q) => _SuggestedQuestion(
          text: q,
          isDark: isDark,
          onTap: () {
            ref.read(aiCoachControllerProvider.notifier).sendMessage(q);
            _scrollToBottom();
          },
        )),
      ],
    );
  }

  Widget _buildLimitReachedCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7B8FF7).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          const Icon(CupertinoIcons.moon_stars_fill, size: 40,
              color: Color(0xFF7B8FF7)),
          const SizedBox(height: 12),
          const Text("You've used all 10 messages for today!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text("Your coach will be fully recharged tomorrow. "
              "Check your morning briefing above for today's insights! 💙",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7080))),
        ],
      ),
    );
  }

  // ── Chat List ──────────────────────────────────────────────────────────────

  Widget _buildChatList(BuildContext context, bool isDark, AiCoachState state) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (state.morningBriefing != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _MorningBriefingCard(text: state.morningBriefing!, isDark: isDark),
          ),
        if (state.isBriefingLoading)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _BriefingLoadingCard(isDark: isDark),
          ),
        ...state.messages.map((msg) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: msg.isUser
              ? _UserMessageBubble(message: msg)
              : _CoachMessageBubble(message: msg, isDark: isDark,
                  pulseController: _pulseController),
        )),
        if (state.isLimitReached)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildLimitReachedCard(isDark),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Input Bar ──────────────────────────────────────────────────────────────

  Widget _buildInputBar(BuildContext context, bool isDark, AiCoachState state) {
    final canSend = !state.isReplying && !state.isLimitReached;

    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D14) : const Color(0xFFF6F6FF),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1C1C2E) : const Color(0xFFE2E2EC),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!state.isLimitReached)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${state.messagesRemaining} message${state.messagesRemaining == 1 ? "" : "s"} remaining today',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7080),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _textController,
                    enabled: canSend,
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: canSend ? (_) => _sendMessage() : null,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    decoration: InputDecoration(
                      hintText: state.isLimitReached
                          ? 'Come back tomorrow!'
                          : 'Ask your coach…',
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF8E8E93) : const Color(0xFFA8AABB),
                        fontSize: 15,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: canSend ? _sendMessage : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: canSend
                        ? const LinearGradient(
                            colors: [Color(0xFF7B8FF7), Color(0xFFB57BFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: canSend ? null : (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE2E2EC)),
                  ),
                  child: Icon(
                    state.isReplying
                        ? CupertinoIcons.stop_circle
                        : CupertinoIcons.arrow_up,
                    color: canSend ? Colors.white : (isDark ? const Color(0xFF8E8E93) : const Color(0xFFA8AABB)),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Morning Briefing Card
// ─────────────────────────────────────────────────────────────────────────────

class _MorningBriefingCard extends StatelessWidget {
  final String text;
  final bool isDark;

  const _MorningBriefingCard({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B3A), const Color(0xFF2A1B3D)]
              : [const Color(0xFFF0EEFF), const Color(0xFFFBEFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7B8FF7).withOpacity(0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7B8FF7).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B8FF7), Color(0xFFB57BFF)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(CupertinoIcons.sun_haze_fill, size: 13, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'Morning Briefing',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: isDark ? const Color(0xFFECECEF) : const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}

class _BriefingLoadingCard extends StatefulWidget {
  final bool isDark;
  const _BriefingLoadingCard({required this.isDark});

  @override
  State<_BriefingLoadingCard> createState() => _BriefingLoadingCardState();
}

class _BriefingLoadingCardState extends State<_BriefingLoadingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.isDark
                ? [const Color(0xFF1E1B3A), const Color(0xFF2A1B3D)]
                : [const Color(0xFFF0EEFF), const Color(0xFFFBEFFF)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF7B8FF7).withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerLine(width: 120, height: 20),
            const SizedBox(height: 12),
            _shimmerLine(width: double.infinity, height: 14),
            const SizedBox(height: 6),
            _shimmerLine(width: double.infinity, height: 14),
            const SizedBox(height: 6),
            _shimmerLine(width: 200, height: 14),
          ],
        ),
      ),
    );
  }

  Widget _shimmerLine({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7B8FF7).withOpacity(0.2),
            const Color(0xFFB57BFF).withOpacity(0.35),
            const Color(0xFF7B8FF7).withOpacity(0.2),
          ],
          stops: [
            (_shimmer.value - 0.3).clamp(0.0, 1.0),
            _shimmer.value.clamp(0.0, 1.0),
            (_shimmer.value + 0.3).clamp(0.0, 1.0),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message Bubbles
// ─────────────────────────────────────────────────────────────────────────────

class _CoachMessageBubble extends StatelessWidget {
  final CoachMessage message;
  final bool isDark;
  final AnimationController pulseController;

  const _CoachMessageBubble({
    required this.message,
    required this.isDark,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFF7B8FF7), Color(0xFFB57BFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(CupertinoIcons.sparkles, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: message.text.isEmpty && message.isStreaming
                ? _TypingDots(isDark: isDark)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          message.text,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: isDark ? const Color(0xFFECECEF) : const Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      if (message.isStreaming) ...[
                        const SizedBox(width: 3),
                        _BlinkingCursor(pulseController: pulseController),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _UserMessageBubble extends StatelessWidget {
  final CoachMessage message;
  const _UserMessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7B8FF7), Color(0xFFB57BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Micro-Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  final bool isDark;
  const _TypingDots({required this.isDark});

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final offset = ((_controller.value * 3) - i).clamp(0.0, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(
                widget.isDark ? const Color(0xFF8E8E93) : const Color(0xFFA8AABB),
                const Color(0xFF7B8FF7),
                math.sin(offset * math.pi),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _BlinkingCursor extends StatelessWidget {
  final AnimationController pulseController;
  const _BlinkingCursor({required this.pulseController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (_, __) => Opacity(
        opacity: pulseController.value,
        child: Container(
          width: 2,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF7B8FF7),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}

class _SuggestedQuestion extends StatelessWidget {
  final String text;
  final bool isDark;
  final VoidCallback onTap;

  const _SuggestedQuestion({
    required this.text,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF7B8FF7).withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFFECECEF) : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.arrow_right,
                size: 14,
                color: isDark ? const Color(0xFF8E8E93) : const Color(0xFFA8AABB),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quit Predictor Banner (used on HomeScreen)
// ─────────────────────────────────────────────────────────────────────────────

class QuitPredictorBanner extends StatelessWidget {
  final String habitName;
  final int predictionScore;
  final VoidCallback onDismiss;
  final VoidCallback onOpenCoach;

  const QuitPredictorBanner({
    super.key,
    required this.habitName,
    required this.predictionScore,
    required this.onDismiss,
    required this.onOpenCoach,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: Key('quit_predictor_$habitName'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) => onDismiss(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF2A1B1B), const Color(0xFF1E2040)]
                : [const Color(0xFFFFF0F0), const Color(0xFFF0EEFF)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF8FAB).withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$habitName is at risk',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFECECEF) : const Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    'Success chance: $predictionScore% — your coach can help!',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7080),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onOpenCoach,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
              ),
              child: const Text(
                'Coach me',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7B8FF7),
                ),
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                CupertinoIcons.xmark,
                size: 14,
                color: isDark ? const Color(0xFF8E8E93) : const Color(0xFFA8AABB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
