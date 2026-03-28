import 'package:intl/intl.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';

// ── Data Models ─────────────────────────────────────────────────────────────

enum DailyPlanTag {
  missedYesterday,
  atRisk,
  weakConsistency,
  doNow,
}

class DailyPlanHabit {
  final Habit habit;
  final DailyPlanTag tag;

  const DailyPlanHabit({required this.habit, required this.tag});

  String get tagLabel {
    switch (tag) {
      case DailyPlanTag.missedYesterday:
        return 'Missed yesterday';
      case DailyPlanTag.atRisk:
        return 'Streak at risk';
      case DailyPlanTag.weakConsistency:
        return 'Weak consistency';
      case DailyPlanTag.doNow:
        return 'Do now';
    }
  }
}

// ── Scoring Engine (V2) ──────────────────────────────────────────────────────

class DailyPlanService {
  static const int _maxPlanHabits = 3;
  static const int _minDataDaysForAdvanced = 3;

  /// Main entry: deterministic, normalized, time-aware.
  static List<DailyPlanHabit> computePlan(List<Habit> allHabits) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

    // STEP 1: only today's pending (not yet completed) habits
    final pendingHabits = allHabits
        .where((h) => _isScheduledOn(h, now) && !_isCompleted(h, todayStr))
        .toList();

    if (pendingHabits.isEmpty) return [];

    // STEP 2: score each habit
    final scored = <({DailyPlanHabit plan, double score, int? reminderMins})>[];

    for (final habit in pendingHabits) {
      final advanced = _hasSufficientData(habit, now);
      final missedYesterday = _isScheduledOn(habit, yesterday) &&
          !_isCompletedNorm(habit, yesterdayStr);

      double score = 0;
      DailyPlanTag tag = DailyPlanTag.doNow;

      if (!advanced) {
        // FALLBACK for new habits
        score = missedYesterday ? 30 : 10;
        tag = missedYesterday ? DailyPlanTag.missedYesterday : DailyPlanTag.doNow;
      } else {
        // ── Factor 1: Missed yesterday (weight 40) ──
        if (missedYesterday) {
          score += 40;
          tag = DailyPlanTag.missedYesterday;
        }

        // ── Factor 2: Streak risk (weight up to 40 for streak ≥ 5) ──
        final streak = _calculateStreak(habit, now);
        if (streak >= 2) {
          // At streak ≥ 5, treat as equal to missedYesterday (cap at 40)
          final streakBoost = streak >= 5
              ? 40.0
              : (streak * 5.0).clamp(0.0, 25.0);
          score += streakBoost;
          if (!missedYesterday) tag = DailyPlanTag.atRisk;
        }

        // ── Factor 3: Skip memory (consecutive scheduled skips) ──
        final recentSkips = _consecutiveSkips(habit, now);
        if (recentSkips >= 2) {
          // Intentional skip pattern → reduce urgency
          score -= (recentSkips * 3.0).clamp(0.0, 12.0);
        }

        // ── Factor 4: Consistency weakness using NORMALIZED completion ──
        // Uses percentage (0–1) regardless of habit type
        final rate = _normalizedCompletionRate(habit, now, days: 14);
        if (rate < 0.5) {
          score += (1.0 - rate) * 20;
          if (!missedYesterday && score < 30) tag = DailyPlanTag.weakConsistency;
        } else {
          score -= (rate - 0.5) * 6;
        }

        // ── Factor 5: Time relevance (±3h, gradient weight, max 10) ──
        int? reminderMins;
        if (habit.reminderEnabled &&
            habit.reminderHour != null &&
            habit.reminderMinute != null) {
          reminderMins = habit.reminderHour! * 60 + habit.reminderMinute!;
          final nowMins = now.hour * 60 + now.minute;
          final diff = (reminderMins - nowMins).abs();
          if (diff <= 180) {
            score += 10.0 * (1.0 - diff / 180.0);
            if (!missedYesterday && score < 15) tag = DailyPlanTag.doNow;
          }
        }

        // Tie-breaker metadata
        final tieReminder = reminderMins;

        scored.add((
          plan: DailyPlanHabit(habit: habit, tag: tag),
          score: score,
          reminderMins: tieReminder,
        ));
        continue;
      }

      // Fallback path (no advanced scoring)
      scored.add((
        plan: DailyPlanHabit(habit: habit, tag: tag),
        score: score,
        reminderMins: null,
      ));
    }

    // STEP 3: Sort — deterministic tie-breaker chain
    scored.sort((a, b) {
      final scoreCmp = b.score.compareTo(a.score);
      if (scoreCmp != 0) return scoreCmp;

      // Tie-breaker 1: earlier reminder time
      final aRem = a.reminderMins ?? 9999;
      final bRem = b.reminderMins ?? 9999;
      final remCmp = aRem.compareTo(bRem);
      if (remCmp != 0) return remCmp;

      // Tie-breaker 2: alphabetical
      return a.plan.habit.name.compareTo(b.plan.habit.name);
    });

    // STEP 4: Pick top N, then time-aware reorder within the final set
    final top = scored.take(_maxPlanHabits).toList();

    // Time-aware reorder of the final top list:
    // Sort by closest reminder to now first, with non-reminded habits last.
    final nowMins = now.hour * 60 + now.minute;
    top.sort((a, b) {
      final aRem = a.reminderMins;
      final bRem = b.reminderMins;

      if (aRem == null && bRem == null) {
        return b.score.compareTo(a.score);
      }
      if (aRem == null) return 1;
      if (bRem == null) return -1;

      final aDiff = (aRem - nowMins).abs();
      final bDiff = (bRem - nowMins).abs();
      // Closer to current time → show first
      return aDiff.compareTo(bDiff);
    });

    return top.map((e) => e.plan).toList();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static bool _hasSufficientData(Habit habit, DateTime now) {
    int days = 0;
    for (int i = 1; i <= _minDataDaysForAdvanced + 5; i++) {
      final d = now.subtract(Duration(days: i));
      if (d.isBefore(habit.startDate)) break;
      if (!_isScheduledOn(habit, d)) continue;
      final ds = DateFormat('yyyy-MM-dd').format(d);
      if ((habit.dailyProgress[ds] ?? 0) > 0) days++;
      if (days >= _minDataDaysForAdvanced) return true;
    }
    return days >= _minDataDaysForAdvanced;
  }

  static bool _isScheduledOn(Habit habit, DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    if (normalizedDate.isBefore(habit.startDate)) return false;

    if (habit.isEveryDay) return true;
    if (habit.selectedDays.isEmpty) return false;
    final appDay = date.weekday % 7; // Mon=1..6, Sun=0
    return habit.selectedDays.contains(appDay);
  }

  static bool _isCompleted(Habit habit, String dateStr) {
    final progress = habit.dailyProgress[dateStr] ?? 0;
    return progress >= habit.goalValue;
  }

  /// Normalized: binary → 0 or 1, measurable → progress/goal clamped 0–1.
  static bool _isCompletedNorm(Habit habit, String dateStr) =>
      _normalizedProgress(habit, dateStr) >= 1.0;

  static double _normalizedProgress(Habit habit, String dateStr) {
    final progress = habit.dailyProgress[dateStr] ?? 0;
    if (habit.goalValue <= 0) return progress > 0 ? 1.0 : 0.0;
    return (progress / habit.goalValue).clamp(0.0, 1.0);
  }

  /// Consecutive scheduled days recently skipped (not completed, not today).
  static int _consecutiveSkips(Habit habit, DateTime now) {
    int skips = 0;
    var day = now.subtract(const Duration(days: 1));
    for (int i = 0; i < 14; i++) {
      if (day.isBefore(habit.startDate)) break;
      if (!_isScheduledOn(habit, day)) {
        day = day.subtract(const Duration(days: 1));
        continue;
      }
      final ds = DateFormat('yyyy-MM-dd').format(day);
      if (!_isCompletedNorm(habit, ds)) {
        skips++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break; // consecutive chain broken
      }
    }
    return skips;
  }

  /// Streak = consecutive completed days before today. Capped at 90.
  static int _calculateStreak(Habit habit, DateTime now) {
    int streak = 0;
    var day = now.subtract(const Duration(days: 1));
    for (int i = 0; i < 90; i++) {
      if (day.isBefore(habit.startDate)) break;
      if (!_isScheduledOn(habit, day)) {
        day = day.subtract(const Duration(days: 1));
        continue;
      }
      final ds = DateFormat('yyyy-MM-dd').format(day);
      if (_isCompletedNorm(habit, ds)) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  /// Normalized completion rate (0–1). Uses % progress not raw count.
  static double _normalizedCompletionRate(Habit habit, DateTime now, {int days = 14}) {
    int scheduled = 0;
    double completedSum = 0;
    for (int i = 1; i <= days; i++) {
      final d = now.subtract(Duration(days: i));
      if (d.isBefore(habit.startDate)) break;
      if (!_isScheduledOn(habit, d)) continue;
      scheduled++;
      final ds = DateFormat('yyyy-MM-dd').format(d);
      completedSum += _normalizedProgress(habit, ds);
    }
    if (scheduled == 0) return 1.0;
    return completedSum / scheduled;
  }
}
