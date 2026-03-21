import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';

class PomodoroState {
  // Configuration
  final int focusMinutes;
  final int breakMinutes;
  final int totalSessions;

  // Active Session State
  final bool isRunning;
  final bool isBreak;
  final int currentSessionIndex; // 0 to totalSessions - 1

  // Time Engine
  final DateTime? targetEndTime;
  final Duration remainingBeforePause; 

  const PomodoroState({
    this.focusMinutes = 25,
    this.breakMinutes = 5,
    this.totalSessions = 4,
    this.isRunning = false,
    this.isBreak = false,
    this.currentSessionIndex = 0,
    this.targetEndTime,
    this.remainingBeforePause = const Duration(minutes: 25),
  });

  Duration get currentRemaining {
    if (!isRunning || targetEndTime == null) return remainingBeforePause;
    final remaining = targetEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  PomodoroState copyWith({
    int? focusMinutes,
    int? breakMinutes,
    int? totalSessions,
    bool? isRunning,
    bool? isBreak,
    int? currentSessionIndex,
    DateTime? targetEndTime,
    Duration? remainingBeforePause,
  }) {
    return PomodoroState(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      totalSessions: totalSessions ?? this.totalSessions,
      isRunning: isRunning ?? this.isRunning,
      isBreak: isBreak ?? this.isBreak,
      currentSessionIndex: currentSessionIndex ?? this.currentSessionIndex,
      targetEndTime: targetEndTime ?? this.targetEndTime,
      remainingBeforePause: remainingBeforePause ?? this.remainingBeforePause,
    );
  }
}

class PomodoroNotifier extends StateNotifier<PomodoroState> {
  PomodoroNotifier() : super(const PomodoroState()) {
    _loadState();
  }

  void _loadState() {
    final box = HiveService.pomodoroBox;
    final focusM = box.get('focusMinutes', defaultValue: 25) as int;
    final breakM = box.get('breakMinutes', defaultValue: 5) as int;
    final totalS = box.get('totalSessions', defaultValue: 4) as int;
    
    final isRunning = box.get('isRunning', defaultValue: false) as bool;
    final isBreak = box.get('isBreak', defaultValue: false) as bool;
    final currentS = box.get('currentSessionIndex', defaultValue: 0) as int;

    final targetMs = box.get('targetEndTimeMs') as int?;
    final remainingMs = box.get('remainingBeforePauseMs', defaultValue: focusM * 60 * 1000) as int;

    DateTime? targetTime = targetMs != null ? DateTime.fromMillisecondsSinceEpoch(targetMs) : null;

    var loadedState = PomodoroState(
      focusMinutes: focusM,
      breakMinutes: breakM,
      totalSessions: totalS,
      isRunning: isRunning,
      isBreak: isBreak,
      currentSessionIndex: currentS,
      targetEndTime: targetTime,
      remainingBeforePause: Duration(milliseconds: remainingMs),
    );

    // If it was running, we need to check if it automatically advanced in the background
    state = loadedState;
    if (isRunning) {
      _processBackgroundAdvancement();
    }
  }

  void _saveState(PomodoroState s) {
    final box = HiveService.pomodoroBox;
    box.put('focusMinutes', s.focusMinutes);
    box.put('breakMinutes', s.breakMinutes);
    box.put('totalSessions', s.totalSessions);
    box.put('isRunning', s.isRunning);
    box.put('isBreak', s.isBreak);
    box.put('currentSessionIndex', s.currentSessionIndex);
    
    if (s.targetEndTime != null) {
      box.put('targetEndTimeMs', s.targetEndTime!.millisecondsSinceEpoch);
    } else {
      box.delete('targetEndTimeMs');
    }
    box.put('remainingBeforePauseMs', s.remainingBeforePause.inMilliseconds);
  }

  /// Called by the UI Ticker periodically to ensure state advances at 00:00
  void checkTick() {
    if (!state.isRunning) return;
    if (state.currentRemaining <= Duration.zero) {
      _advanceSession();
    }
  }

  /// Processes if the user was gone for a very long time and multiple sessions passed.
  void _processBackgroundAdvancement() {
    while (state.isRunning && state.currentRemaining <= Duration.zero) {
      _advanceSession();
    }
  }

  void _advanceSession() {
    if (!state.isRunning) return;

    if (!state.isBreak) {
      // Finished a Focus block. Move to Break
      final nextRemaining = Duration(minutes: state.breakMinutes);
      final newState = state.copyWith(
        isBreak: true,
        remainingBeforePause: nextRemaining,
        targetEndTime: DateTime.now().add(nextRemaining),
      );
      state = newState;
      _saveState(newState);
    } else {
      // Finished a Break block. Move to next Focus, OR finish.
      if (state.currentSessionIndex + 1 >= state.totalSessions) {
        // All done!
        reset();
      } else {
        // Next Focus block
        final nextRemaining = Duration(minutes: state.focusMinutes);
        final newState = state.copyWith(
          isBreak: false,
          currentSessionIndex: state.currentSessionIndex + 1,
          remainingBeforePause: nextRemaining,
          targetEndTime: DateTime.now().add(nextRemaining),
        );
        state = newState;
        _saveState(newState);
      }
    }
  }

  void start() {
    if (state.isRunning) return;
    final newState = state.copyWith(
      isRunning: true,
      targetEndTime: DateTime.now().add(state.remainingBeforePause),
    );
    state = newState;
    _saveState(newState);
    checkTick(); // immediately check in case remaining was 0
  }

  void pause() {
    if (!state.isRunning) return;
    final remaining = state.currentRemaining;
    final newState = state.copyWith(
      isRunning: false,
      remainingBeforePause: remaining,
      targetEndTime: null,
    );
    state = newState;
    _saveState(newState);
  }

  void reset() {
    final newState = PomodoroState(
      focusMinutes: state.focusMinutes,
      breakMinutes: state.breakMinutes,
      totalSessions: state.totalSessions,
      isRunning: false,
      isBreak: false,
      currentSessionIndex: 0,
      targetEndTime: null,
      remainingBeforePause: Duration(minutes: state.focusMinutes),
    );
    state = newState;
    _saveState(newState);
  }

  void configure(int focusM, int breakM, int totalS) {
    // Only configure if paused or resetting
    final newState = PomodoroState(
      focusMinutes: focusM,
      breakMinutes: breakM,
      totalSessions: totalS,
      isRunning: false,
      isBreak: false,
      currentSessionIndex: 0,
      targetEndTime: null,
      remainingBeforePause: Duration(minutes: focusM),
    );
    state = newState;
    _saveState(newState);
  }
}

final pomodoroProvider = StateNotifierProvider<PomodoroNotifier, PomodoroState>((ref) {
  return PomodoroNotifier();
});
