import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_controller.dart';

enum HabitFilter {
  all,
  completed,
  pending,
}

final habitFilterProvider = StateProvider<HabitFilter>((ref) => HabitFilter.all);

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Returns true if the habit is scheduled on the given date.
/// isEveryDay = true  →  always scheduled.
/// isEveryDay = false →  scheduled only when the weekday (0=Sun…6=Sat) is in selectedDays.
bool isHabitScheduledOn(Habit habit, DateTime date) {
  final normalizedDate = DateTime(date.year, date.month, date.day);
  if (normalizedDate.isBefore(habit.startDate)) return false;

  if (habit.isEveryDay) return true;
  if (habit.selectedDays.isEmpty) return true; // fall-back: treat as everyday
  final weekday = date.weekday % 7; // Flutter: Mon=1..Sun=7  →  we map Sun→0, Mon→1..Sat→6
  return habit.selectedDays.contains(weekday);
}

/// Calculates the CURRENT (active) streak for a habit, respecting custom-frequency schedules.
///
/// Rules:
///   - Non-scheduled days are bridges — they neither break nor increment the streak.
///   - Only 100% completion (done >= goalValue) counts as a streak day.
///   - Today (if scheduled but not yet completed) does NOT break the streak.
int calculateHabitStreak(Habit habit) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  int streak = 0;
  DateTime checkDay = today;

  while (true) {
    if (checkDay.isBefore(habit.startDate)) break;

    final isScheduled = isHabitScheduledOn(habit, checkDay);

    if (!isScheduled) {
      // Bridge day — step back without breaking streak
      checkDay = checkDay.subtract(const Duration(days: 1));
      if (today.difference(checkDay).inDays > 730) break;
      continue;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(checkDay);
    final done = habit.dailyProgress[dateStr] ?? 0;
    final isMet = habit.goalValue > 0 && done >= habit.goalValue;

    if (isMet) {
      streak++;
      checkDay = checkDay.subtract(const Duration(days: 1));
    } else if (checkDay == today) {
      // Today is scheduled but not yet complete — don't break, just step back
      checkDay = checkDay.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }

  return streak;
}

/// Calculates the BEST (all-time longest) streak for a habit, respecting custom-frequency schedules.
int calculateHabitBestStreak(Habit habit) {
  if (habit.dailyProgress.isEmpty) return 0;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final startDay = habit.startDate;

  int best = 0;
  int current = 0;
  DateTime checkDay = startDay;

  while (!checkDay.isAfter(today)) {
    final isScheduled = isHabitScheduledOn(habit, checkDay);

    if (!isScheduled) {
      checkDay = checkDay.add(const Duration(days: 1));
      continue;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(checkDay);
    final done = habit.dailyProgress[dateStr] ?? 0;
    final isMet = habit.goalValue > 0 && done >= habit.goalValue;

    if (isMet) {
      current++;
      if (current > best) best = current;
    } else if (checkDay == today) {
      // Today not yet done — don't penalise best streak scan
    } else {
      current = 0;
    }

    checkDay = checkDay.add(const Duration(days: 1));
  }

  return best;
}

final filteredHabitsProvider = Provider((ref) {
  final habits = ref.watch(habitProvider);
  final filter = ref.watch(habitFilterProvider);
  final selectedDate = ref.watch(selectedDateProvider);

  final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

  // Step 1: Only show habits scheduled for the selected date
  final scheduled = habits.where((h) => isHabitScheduledOn(h, selectedDate)).toList();

  // Step 2: Apply completed / pending filter
  switch (filter) {
    case HabitFilter.all:
      return scheduled;
    case HabitFilter.completed:
      return scheduled.where((h) {
        final progress = h.dailyProgress[dateStr] ?? 0;
        return progress >= h.goalValue;
      }).toList();
    case HabitFilter.pending:
      return scheduled.where((h) {
        final progress = h.dailyProgress[dateStr] ?? 0;
        return progress < h.goalValue;
      }).toList();
  }
});
