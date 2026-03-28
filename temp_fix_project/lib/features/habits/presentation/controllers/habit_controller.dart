import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/features/habits/data/repositories/habit_repository.dart';
import 'package:habit_tracker_ios/core/services/notification_service.dart';
import 'package:habit_tracker_ios/core/services/smart_nudge_service.dart';

final habitRepositoryProvider = Provider((ref) => HabitRepository());

final habitProvider = StateNotifierProvider<HabitNotifier, List<Habit>>((ref) {
  final repository = ref.watch(habitRepositoryProvider);
  return HabitNotifier(repository);
});

class HabitNotifier extends StateNotifier<List<Habit>> {
  final HabitRepository _repository;

  HabitNotifier(this._repository) : super([]) {
    _loadHabits();
  }

  void _loadHabits() {
    state = _repository.getAllHabits();
  }

  Future<void> addHabit(Habit habit) async {
    // Assign next sortOrder
    final nextOrder = state.isEmpty ? 0 : state.map((h) => h.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
    final habitWithOrder = habit.copyWith(sortOrder: nextOrder);
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
    // Prevent interaction for future dates
    final selectedDate = DateFormat('yyyy-MM-dd').parse(date);
    final today = DateTime.now();
    // Normalize both to midnight for accurate comparison
    final selectedMidnight = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final todayMidnight = DateTime(today.year, today.month, today.day);
    
    if (selectedMidnight.isAfter(todayMidnight)) return;

    final habitIndex = state.indexWhere((h) => h.id == habitId);
    if (habitIndex == -1) return;

    final habit = state[habitIndex];
    final dailyProgress = Map<String, int>.from(habit.dailyProgress);
    final currentProgress = dailyProgress[date] ?? 0;

    if (currentProgress < habit.goalValue) {
      dailyProgress[date] = currentProgress + 1;
      final updatedHabit = habit.copyWith(dailyProgress: dailyProgress);
      await updateHabit(updatedHabit);
    }
    
    // Reschedule smart nudges on any progress update today so mid-day
    // behavior shifts are instantly accounted for.
    if (selectedMidnight == todayMidnight) {
      SmartNudgeService.scheduleForToday(state);
    }
  }

  Future<void> setHabitProgress(String habitId, String date, int value) async {
    // Prevent interaction for future dates
    final selectedDate = DateFormat('yyyy-MM-dd').parse(date);
    final today = DateTime.now();
    // Normalize both to midnight for accurate comparison
    final selectedMidnight = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final todayMidnight = DateTime(today.year, today.month, today.day);
    
    if (selectedMidnight.isAfter(todayMidnight)) return;

    final habitIndex = state.indexWhere((h) => h.id == habitId);
    if (habitIndex == -1) return;

    final habit = state[habitIndex];
    final dailyProgress = Map<String, int>.from(habit.dailyProgress);
    
    // Clamp between 0 and goal
    final clampedValue = value.clamp(0, habit.goalValue);
    dailyProgress[date] = clampedValue;

    final updatedHabit = habit.copyWith(dailyProgress: dailyProgress);
    await updateHabit(updatedHabit);
    
    // Reschedule smart nudges on any progress update today so mid-day
    // behavior shifts are instantly accounted for.
    if (selectedMidnight == todayMidnight) {
      SmartNudgeService.scheduleForToday(state);
    }
  }
}
