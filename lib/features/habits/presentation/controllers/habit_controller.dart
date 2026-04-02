import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/features/habits/data/repositories/habit_repository.dart';
import 'package:habit_tracker_ios/core/services/notification_service.dart';
import 'package:habit_tracker_ios/core/services/smart_nudge_service.dart';
import 'package:habit_tracker_ios/core/services/anti_cheat_service.dart';
import 'package:habit_tracker_ios/features/profile/presentation/controllers/coin_controller.dart';
import 'package:habit_tracker_ios/features/profile/presentation/controllers/global_reward_tracker.dart';

final habitRepositoryProvider = Provider((ref) => HabitRepository());

final habitProvider = StateNotifierProvider<HabitNotifier, List<Habit>>((ref) {
  final repository = ref.watch(habitRepositoryProvider);
  return HabitNotifier(repository, ref);
});

class HabitNotifier extends StateNotifier<List<Habit>> {
  final HabitRepository _repository;
  final Ref _ref;

  HabitNotifier(this._repository, this._ref) : super([]) {
    _loadHabits();
  }

  void _loadHabits() {
    state = _repository.getAllHabits();
  }

  Future<void> addHabit(Habit habit) async {
    // Habit creation is UNRESTRICTED — only rewards are capped, not creation.
    // Overwrite the start date string safely precisely at creation to lock the locale timezone day
    final now = DateTime.now();
    final tzSafeStartDate = DateFormat('yyyy-MM-dd').format(now);

    // Assign next sortOrder
    final nextOrder = state.isEmpty ? 0 : state.map((h) => h.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final habitWithOrder = habit.copyWith(sortOrder: nextOrder, startDateString: tzSafeStartDate);
    await _repository.saveHabit(habitWithOrder);
    state = [...state, habitWithOrder];

    // Schedule notifications if reminder is enabled and time is set
    if (habitWithOrder.reminderEnabled &&
        habitWithOrder.reminderHour != null &&
        habitWithOrder.reminderMinute != null) {
      await NotificationService.scheduleHabitReminders(
        habitId: habitWithOrder.id,
        habitName: habitWithOrder.name,
        hour: habitWithOrder.reminderHour!,
        minute: habitWithOrder.reminderMinute!,
        isEveryDay: habitWithOrder.isEveryDay,
        selectedDays: habitWithOrder.selectedDays,
      );
    }
    // Re-evaluate smart nudges
    SmartNudgeService.scheduleForToday(state);
  }

  /// DEBUG-ONLY: Saves a habit exactly as provided, preserving startDateString.
  /// Unlike [addHabit], this does NOT overwrite startDateString with today's date.
  /// Used by DebugTestDataService to create backdated habits for snapshot testing.
  Future<void> saveHabitDirectly(Habit habit) async {
    assert(() {
      // Enforce debug-only usage at runtime in debug mode
      return true;
    }());
    final nextOrder = state.isEmpty ? 0 : state.map((h) => h.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final habitWithOrder = habit.copyWith(sortOrder: nextOrder);
    await _repository.saveHabit(habitWithOrder);
    state = [...state, habitWithOrder];
  }

  Future<void> reorderHabits(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final habits = List<Habit>.from(state);
    final item = habits.removeAt(oldIndex);
    habits.insert(newIndex, item);

    // Update all sortOrders to reflect new list order
    final updatedHabits = <Habit>[];
    for (int i = 0; i < habits.length; i++) {
      final updated = habits[i].copyWith(sortOrder: i);
      updatedHabits.add(updated);
      await _repository.saveHabit(updated);
    }
    
    state = updatedHabits;
  }

  Future<void> updateHabit(Habit habit) async {
    await _repository.saveHabit(habit);
    state = [
      for (final h in state)
        if (h.id == habit.id) habit else h
    ];

    // Always cancel old notifications first, then reschedule if still enabled
    await NotificationService.cancelHabitReminders(habit.id);
    if (habit.reminderEnabled &&
        habit.reminderHour != null &&
        habit.reminderMinute != null) {
      await NotificationService.scheduleHabitReminders(
        habitId: habit.id,
        habitName: habit.name,
        hour: habit.reminderHour!,
        minute: habit.reminderMinute!,
        isEveryDay: habit.isEveryDay,
        selectedDays: habit.selectedDays,
      );
    }
    // Re-evaluate smart nudges
    SmartNudgeService.scheduleForToday(state);
  }

  Future<void> deleteHabit(String id) async {
    await _repository.deleteHabit(id);
    await NotificationService.cancelHabitReminders(id);
    state = state.where((h) => h.id != id).toList();
    // Re-evaluate smart nudges
    SmartNudgeService.scheduleForToday(state);
  }

  Future<void> incrementHabitProgress(String habitId, String date) async {
    // Look up the habit first so we can pass its startDate to the gate
    final habitIndex = state.indexWhere((h) => h.id == habitId);
    if (habitIndex == -1) return;
    final habit = state[habitIndex];

    // PRIORITY RULE 0: Pre-start check then anti-cheat
    final entryState = AntiCheatService.getEntryState(
      date,
      habitStartDate: habit.startDate,
    );
    if (entryState == HabitEntryState.preStart ||
        entryState == HabitEntryState.lockedFinal ||
        entryState == HabitEntryState.future) return;

    final dailyProgress = Map<String, int>.from(habit.dailyProgress);
    final currentProgress = dailyProgress[date] ?? 0;

    if (currentProgress < habit.goalValue) {
      dailyProgress[date] = currentProgress + 1;

      // ── Snapshot the active goal for this day ──────────────────────────────
      // Ensures that a future goal edit never retroactively changes whether
      // this day was "completed" in reports/streaks.
      final goalSnaps = Map<String, int>.from(habit.goalSnapshots);
      goalSnaps[date] = habit.goalValue;
      
      // ── Anti-Farming: Calendar-Day Maturity + Rewardable Cap ───────────────
      // Rule 1: No coins on creation day.
      // Rule 2: Only first 5 distinct habit completions per day earn coins.
      final habitStartDateStr = DateFormat('yyyy-MM-dd').format(habit.startDate);
      final isCreationDay = (habitStartDateStr == date);

      if (dailyProgress[date]! >= habit.goalValue &&
          entryState == HabitEntryState.editable &&
          !isCreationDay) {
        final globalRewardTracker = _ref.read(rewardTrackerProvider.notifier);
        final alreadyClaimed = globalRewardTracker.hasClaimed(habit.name, habit.startDate, date);
        final capAvailable = globalRewardTracker.canGrantRewardToday(date);

        if (!alreadyClaimed && capAvailable) {
          globalRewardTracker.registerClaim(habit.name, habit.startDate, date);
          _ref.read(coinProvider.notifier).addCoins(10);
          HapticFeedback.lightImpact(); // subtle, premium confirmation tap
          _ref.read(coinRewardedProvider.notifier).state = true;
        } else if (!alreadyClaimed && !capAvailable) {
          // Cap hit — fire once-per-day notification pulse
          if (globalRewardTracker.shouldNotifyCapToday(date)) {
            globalRewardTracker.markCapNotified(date);
            _ref.read(rewardCapNotifyProvider.notifier).state = true;
          }
        }
      }

      final updatedHabit = habit.copyWith(
        dailyProgress: dailyProgress,
        goalSnapshots: goalSnaps,
      );
      await updateHabit(updatedHabit);
    }
    
    // Reschedule nudges only when editing today's habits (editable state)
    if (entryState == HabitEntryState.editable) {
      SmartNudgeService.scheduleForToday(state);
    }
  }

  Future<void> setHabitProgress(String habitId, String date, int value) async {
    // Look up the habit first so we can pass its startDate to the gate
    final habitIndex = state.indexWhere((h) => h.id == habitId);
    if (habitIndex == -1) return;
    final habit = state[habitIndex];

    // PRIORITY RULE 0: Pre-start check then anti-cheat
    final entryState = AntiCheatService.getEntryState(
      date,
      habitStartDate: habit.startDate,
    );
    if (entryState == HabitEntryState.preStart ||
        entryState == HabitEntryState.lockedFinal ||
        entryState == HabitEntryState.future) return;

    final dailyProgress = Map<String, int>.from(habit.dailyProgress);
    
    // Clamp between 0 and goal
    final clampedValue = value.clamp(0, habit.goalValue);
    dailyProgress[date] = clampedValue;

    // ── Snapshot the active goal for this day ──────────────────────────────
    // Ensures that a future goal edit never retroactively changes whether
    // this day was "completed" in reports/streaks.
    final goalSnaps = Map<String, int>.from(habit.goalSnapshots);
    goalSnaps[date] = habit.goalValue;

    // ── Anti-Farming: Calendar-Day Maturity + Rewardable Cap ───────────────
    // Rule 1: No coins on creation day.
    // Rule 2: Only first 5 distinct habit completions per day earn coins.
    final habitStartDateStr = DateFormat('yyyy-MM-dd').format(habit.startDate);
    final isCreationDay = (habitStartDateStr == date);

    if (clampedValue >= habit.goalValue &&
        entryState == HabitEntryState.editable &&
        !isCreationDay) {
      final globalRewardTracker = _ref.read(rewardTrackerProvider.notifier);
      final alreadyClaimed = globalRewardTracker.hasClaimed(habit.name, habit.startDate, date);
      final capAvailable = globalRewardTracker.canGrantRewardToday(date);

      if (!alreadyClaimed && capAvailable) {
        globalRewardTracker.registerClaim(habit.name, habit.startDate, date);
        _ref.read(coinProvider.notifier).addCoins(10);
        HapticFeedback.lightImpact(); // subtle, premium confirmation tap
        _ref.read(coinRewardedProvider.notifier).state = true;
      } else if (!alreadyClaimed && !capAvailable) {
        // Cap hit — fire once-per-day notification pulse
        if (globalRewardTracker.shouldNotifyCapToday(date)) {
          globalRewardTracker.markCapNotified(date);
          _ref.read(rewardCapNotifyProvider.notifier).state = true;
        }
      }
    }

    final updatedHabit = habit.copyWith(
      dailyProgress: dailyProgress,
      goalSnapshots: goalSnaps,
    );
    await updateHabit(updatedHabit);
    
    // Reschedule nudges only when editing today's habits (editable state)
    if (entryState == HabitEntryState.editable) {
      SmartNudgeService.scheduleForToday(state);
    }
  }
}
