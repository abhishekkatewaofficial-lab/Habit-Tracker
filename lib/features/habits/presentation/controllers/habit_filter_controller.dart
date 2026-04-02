import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_controller.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/streak_protection_controller.dart';

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
    final snappedGoal = habit.goalFor(dateStr);
    final isMet = snappedGoal > 0 && done >= snappedGoal;

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
    final snappedGoal = habit.goalFor(dateStr);
    final isMet = snappedGoal > 0 && done >= snappedGoal;

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

/// Identical to [calculateHabitStreak] but treats protected days as completed
/// for streak calculation ONLY. Actual completion data is never modified.
/// Used in the UI — reports always use the original [calculateHabitStreak].
int calculateHabitStreakWithProtection(Habit habit, Set<String> protectedDays) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  int streak = 0;
  DateTime checkDay = today;

  while (true) {
    if (checkDay.isBefore(habit.startDate)) break;

    final isScheduled = isHabitScheduledOn(habit, checkDay);

    if (!isScheduled) {
      checkDay = checkDay.subtract(const Duration(days: 1));
      if (today.difference(checkDay).inDays > 730) break;
      continue;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(checkDay);
    final done = habit.dailyProgress[dateStr] ?? 0;
    // A day counts if actually completed OR streak-protected
    final isProtected = protectedDays.contains('${habit.id}_$dateStr');
    final snappedGoal = habit.goalFor(dateStr);
    final isMet = (snappedGoal > 0 && done >= snappedGoal) || isProtected;

    if (isMet) {
      streak++;
      checkDay = checkDay.subtract(const Duration(days: 1));
    } else if (checkDay == today) {
      // Today not yet done — don't break streak
      checkDay = checkDay.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }

  return streak;
}

/// Computes all habits that are eligible for streak protection right now.
/// A habit is eligible when:
///   1. It was scheduled yesterday
///   2. Yesterday was NOT completed
///   3. It has NOT already been protected for yesterday
///   4. It has at least 1 previously completed day (so there's a real streak at risk)
final streakBreakCandidatesProvider = Provider<List<Habit>>((ref) {
  final habits = ref.watch(habitProvider);
  final protected = ref.watch(streakProtectionProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

  return habits.where((habit) {
    // Habit must have started before yesterday
    if (!habit.startDate.isBefore(today)) return false;
    // Must be scheduled yesterday
    if (!isHabitScheduledOn(habit, yesterday)) return false;
    // Must NOT have been completed yesterday
    final done = habit.dailyProgress[yesterdayStr] ?? 0;
    if (done >= habit.goalFor(yesterdayStr)) return false;
    // Must NOT already be protected for yesterday
    if (protected.contains('${habit.id}_$yesterdayStr')) return false;
    // Must have at least 1 prior completion day (real streak to protect)
    final hasHistory = habit.dailyProgress.entries.any((e) {
      final d = DateTime.tryParse(e.key);
      if (d == null || !d.isBefore(yesterday)) return false;
      return e.value >= habit.goalFor(e.key);
    });
    return hasHistory;
  // Sort by highest streak descending — highest-value streak shown first
  }).toList()
    ..sort((a, b) => calculateHabitStreak(b).compareTo(calculateHabitStreak(a)));
});

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
        return progress >= h.goalFor(dateStr);
      }).toList();
    case HabitFilter.pending:
      return scheduled.where((h) {
        final progress = h.dailyProgress[dateStr] ?? 0;
        return progress < h.goalFor(dateStr);
      }).toList();
  }
});
