import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/core/services/ai_coach_service.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_controller.dart';
import 'package:habit_tracker_ios/features/profile/presentation/controllers/coin_controller.dart';
import 'package:habit_tracker_ios/features/profile/presentation/controllers/profile_controller.dart';
import 'package:habit_tracker_ios/features/mood/presentation/controllers/mood_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Message Model
// ─────────────────────────────────────────────────────────────────────────────

class CoachMessage {
  final String text;
  final bool isUser;
  final bool isStreaming;

  const CoachMessage({
    required this.text,
    required this.isUser,
    this.isStreaming = false,
  });

  CoachMessage copyWith({String? text, bool? isUser, bool? isStreaming}) {
    return CoachMessage(
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class AiCoachState {
  final List<CoachMessage> messages;
  final String? morningBriefing;
  final bool isBriefingLoading;
  final bool isReplying;
  final int messagesUsedToday;
  final String? errorMessage;

  const AiCoachState({
    this.messages = const [],
    this.morningBriefing,
    this.isBriefingLoading = false,
    this.isReplying = false,
    this.messagesUsedToday = 0,
    this.errorMessage,
  });

  int get messagesRemaining => (kDailyMessageLimit - messagesUsedToday).clamp(0, kDailyMessageLimit);
  bool get isLimitReached => messagesUsedToday >= kDailyMessageLimit;

  AiCoachState copyWith({
    List<CoachMessage>? messages,
    String? morningBriefing,
    bool? isBriefingLoading,
    bool? isReplying,
    int? messagesUsedToday,
    String? errorMessage,
    bool clearBriefing = false,
    bool clearError = false,
  }) {
    return AiCoachState(
      messages: messages ?? this.messages,
      morningBriefing: clearBriefing ? null : (morningBriefing ?? this.morningBriefing),
      isBriefingLoading: isBriefingLoading ?? this.isBriefingLoading,
      isReplying: isReplying ?? this.isReplying,
      messagesUsedToday: messagesUsedToday ?? this.messagesUsedToday,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────

class AiCoachController extends StateNotifier<AiCoachState> {
  final Ref _ref;
  late final AiCoachService _service;
  StreamSubscription<String>? _activeStream; // Issue #7

  AiCoachController(this._ref) : super(const AiCoachState()) {
    _initService();
  }

  void _initService() {
    // Issue #3: use ref.watch-equivalent read — controller is alive as long as
    // aiCoachControllerProvider is watched in the screen.
    final habits = _ref.read(habitProvider);
    final coins = _ref.read(coinProvider);
    final moods = _ref.read(dailyMoodsProvider);
    // profileProvider is AutoDispose — read via ref.read here inside init,
    // which is safe (we just need current name snapshot; not live updates).
    final profile = _ref.read(profileProvider);
    final userName = profile.name.isNotEmpty ? profile.name : 'Friend';

    _service = AiCoachService(
      habits: habits,
      coins: coins,
      userName: userName,
      moods: moods,
    );

    // Load rate limit count from Hive
    state = state.copyWith(
      messagesUsedToday: _service.getTodayMessageCount(),
    );

    // Trigger morning briefing (Issue #2 — NOT in build())
    _loadMorningBriefing();
  }

  // ── Morning Briefing ───────────────────────────────────────────────────────

  Future<void> _loadMorningBriefing() async {
    state = state.copyWith(isBriefingLoading: true);

    try {
      // Issue #10 — no habits case handled gracefully
      final habits = _ref.read(habitProvider);
      if (habits.isEmpty) {
        state = state.copyWith(isBriefingLoading: false, clearBriefing: true);
        return;
      }

      // Check cache first (Issue #11 safe read inside service)
      final cached = _service.getCachedBriefingIfToday();
      if (cached != null) {
        state = state.copyWith(morningBriefing: cached, isBriefingLoading: false);
        return;
      }

      // Generate fresh briefing
      final text = await _service.generateMorningBriefing();
      _service.saveBriefingCache(text);
      state = state.copyWith(morningBriefing: text, isBriefingLoading: false);
    } catch (_) {
      state = state.copyWith(isBriefingLoading: false, clearBriefing: true);
    }
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (state.isLimitReached) return;

    // Add user message
    final userMsg = CoachMessage(text: trimmed, isUser: true);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isReplying: true,
      messagesUsedToday: state.messagesUsedToday + 1,
      clearError: true,
    );

    // Increment in Hive (Issue #13)
    _service.incrementMessageCount();

    // Add empty streaming placeholder
    final placeholder = const CoachMessage(text: '', isUser: false, isStreaming: true);
    state = state.copyWith(messages: [...state.messages, placeholder]);

    // Cancel any existing stream (Issue #7)
    await _cancelStream();

    String accumulated = '';

    _activeStream = _service.sendMessage(trimmed).listen(
      (chunk) {
        accumulated += chunk;
        final updated = List<CoachMessage>.from(state.messages);
        if (updated.isNotEmpty) {
          updated[updated.length - 1] = placeholder.copyWith(
            text: accumulated,
            isStreaming: true,
          );
        }
        state = state.copyWith(messages: updated);
      },
      onDone: () {
        final updated = List<CoachMessage>.from(state.messages);
        if (updated.isNotEmpty) {
          updated[updated.length - 1] = CoachMessage(
            text: accumulated.isEmpty ? '...' : accumulated,
            isUser: false,
            isStreaming: false,
          );
        }
        state = state.copyWith(messages: updated, isReplying: false);
        _activeStream = null;
      },
      onError: (_) {
        final updated = List<CoachMessage>.from(state.messages);
        if (updated.isNotEmpty) {
          updated[updated.length - 1] = const CoachMessage(
            text: 'Sorry, I couldn\'t connect. Please check your internet and try again. 🌐',
            isUser: false,
          );
        }
        state = state.copyWith(messages: updated, isReplying: false);
        _activeStream = null;
      },
    );
  }

  // ── Quit Predictor ─────────────────────────────────────────────────────────

  /// Get habits predicted to be at risk of being quit.
  List<Habit> getAtRiskHabits() => _service.getAtRiskHabits();

  // ── Weekly Digest ──────────────────────────────────────────────────────────

  Future<String> generateWeeklyDigest() => _service.generateWeeklyDigest();

  // ── Cleanup (Issue #7) ─────────────────────────────────────────────────────

  Future<void> _cancelStream() async {
    await _activeStream?.cancel();
    _activeStream = null;
  }

  @override
  void dispose() {
    _cancelStream(); // Issue #7 — cancel stream on navigation away
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// AutoDispose so it rebuilds fresh context each time the coach is opened.
final aiCoachControllerProvider =
    StateNotifierProvider.autoDispose<AiCoachController, AiCoachState>((ref) {
  return AiCoachController(ref);
});
