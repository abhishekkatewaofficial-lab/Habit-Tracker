import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';

class StopwatchState {
  final bool isRunning;
  final DateTime? startTime;
  final Duration accumulatedTime;
  final List<Duration> laps;

  const StopwatchState({
    this.isRunning = false,
    this.startTime,
    this.accumulatedTime = Duration.zero,
    this.laps = const [],
  });

  Duration get currentElapsed {
    if (!isRunning || startTime == null) return accumulatedTime;
    return accumulatedTime + DateTime.now().difference(startTime!);
  }

  StopwatchState copyWith({
    bool? isRunning,
    DateTime? startTime,
    Duration? accumulatedTime,
    List<Duration>? laps,
  }) {
    return StopwatchState(
      isRunning: isRunning ?? this.isRunning,
      startTime: startTime ?? this.startTime,
      accumulatedTime: accumulatedTime ?? this.accumulatedTime,
      laps: laps ?? this.laps,
    );
  }
}

class StopwatchNotifier extends StateNotifier<StopwatchState> {
  StopwatchNotifier() : super(const StopwatchState()) {
    _loadState();
  }

  void _loadState() {
    final box = HiveService.stopwatchBox;
    final isRunning = box.get('isRunning', defaultValue: false) as bool;
    final startMs = box.get('startTimeMs') as int?;
    final accumulatedMs = box.get('accumulatedMs', defaultValue: 0) as int;
    final lapsMsList = box.get('laps', defaultValue: <int>[]) as List<dynamic>;

    final laps = lapsMsList.map((ms) => Duration(milliseconds: ms as int)).toList();
    DateTime? startTime = startMs != null ? DateTime.fromMillisecondsSinceEpoch(startMs) : null;

    state = StopwatchState(
      isRunning: isRunning,
      startTime: startTime,
      accumulatedTime: Duration(milliseconds: accumulatedMs),
      laps: laps,
    );
  }

  void _saveState(StopwatchState s) {
    final box = HiveService.stopwatchBox;
    box.put('isRunning', s.isRunning);
    if (s.startTime != null) {
      box.put('startTimeMs', s.startTime!.millisecondsSinceEpoch);
    } else {
      box.delete('startTimeMs');
    }
    box.put('accumulatedMs', s.accumulatedTime.inMilliseconds);
    box.put('laps', s.laps.map((d) => d.inMilliseconds).toList());
  }

  void start() {
    if (state.isRunning) return;
    final newState = state.copyWith(
      isRunning: true,
      startTime: DateTime.now(),
    );
    state = newState;
    _saveState(newState);
  }

  void stop() {
    if (!state.isRunning) return;
    final newState = state.copyWith(
      isRunning: false,
      accumulatedTime: state.currentElapsed,
      startTime: null,
    );
    state = newState;
    _saveState(newState);
  }

  void addLap() {
    final newState = state.copyWith(laps: [state.currentElapsed, ...state.laps]); // prepend so latest is first
    state = newState;
    _saveState(newState);
  }

  void reset() {
    const newState = StopwatchState();
    state = newState;
    _saveState(newState);
  }
}

final stopwatchProvider = StateNotifierProvider<StopwatchNotifier, StopwatchState>((ref) {
  return StopwatchNotifier();
});
