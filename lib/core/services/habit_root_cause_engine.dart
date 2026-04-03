import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Types
// ─────────────────────────────────────────────────────────────────────────────

enum InsightCategory {
  streakPattern,
  weekdayPattern,
  habitDifficulty,
  dropPattern,
  timePattern,
  improvement,
  risk,
}

class RootCauseInsight {
  final String headline;
  final String detail;
  final String suggestion;
  final IconData icon;
  final Color accentColor;
  final double confidence;  // 0.0 – 1.0
  final int priority;       // higher = shown first
  final InsightCategory category;

  const RootCauseInsight({
    required this.headline,
    required this.detail,
    required this.suggestion,
    required this.icon,
    required this.accentColor,
    required this.confidence,
    required this.priority,
    required this.category,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Engine
// ─────────────────────────────────────────────────────────────────────────────

class HabitRootCauseEngine {
  HabitRootCauseEngine._();

  // Simple day-level cache so we don't recompute on every rebuild.
  static String? _lastCacheDate;
  static List<RootCauseInsight>? _cached;

  /// Returns up to [maxInsights] high-confidence root-cause insights.
  /// Results are cached for the current calendar day.
  static List<RootCauseInsight> analyse(
    List<Habit> habits, {
    int windowDays = 60,
    int maxInsights = 5,
    double minConfidence = 0.60,
    int minValidDays = 7,
  }) {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_lastCacheDate == todayKey && _cached != null) return _cached!;

    final insights = _run(habits,
        windowDays: windowDays,
        minConfidence: minConfidence,
        minValidDays: minValidDays);

    insights.sort((a, b) {
      final pCmp = b.priority.compareTo(a.priority);
      if (pCmp != 0) return pCmp;
      return b.confidence.compareTo(a.confidence);
    });

    _cached = insights.take(maxInsights).toList();
    _lastCacheDate = todayKey;
    return _cached!;
  }

  /// Invalidate cache (call when habits change).
  static void invalidate() {
    _lastCacheDate = null;
    _cached = null;
  }

  // ─── Main computation ────────────────────────────────────────────────────

  static List<RootCauseInsight> _run(
    List<Habit> habits, {
    required int windowDays,
    required double minConfidence,
    required int minValidDays,
  }) {
    final results = <RootCauseInsight>[];
    final today = DateTime.now();
    final window = List.generate(
        windowDays, (i) => today.subtract(Duration(days: windowDays - 1 - i)));

    // ── Pre-compute: day-level scores & per-habit data ───────────────────
    final List<double?> dayScores = [];
    final Map<int, List<double>> weekdayScores = {
      for (int i = 1; i <= 7; i++) i: []
    };
    final Map<String, List<bool>> habitSuccessLog = {}; 
    final Map<String, String> habitNames = {};
    final Map<String, Map<int, List<bool>>> habitWeekdayLog = {};

    int totalScheduledDays = 0;

    for (final date in window) {
      final key = _dateKey(date);
      double possible = 0;
      double actual = 0;

      for (final h in habits) {
        if (h.isQuitHabit) continue;
        if (date.isBefore(h.startDate)) continue;
        if (!_isScheduledOn(h, date)) continue;

        final snapGoal = h.goalFor(key);
        if (snapGoal <= 0) continue;

        final progress = (h.dailyProgress[key] ?? 0).toDouble();
        final normalized = (progress / snapGoal).clamp(0.0, 1.0);

        possible += 1.0;
        actual += normalized;
        final completed = normalized >= 1.0;

        habitSuccessLog.putIfAbsent(h.id, () => []);
        habitSuccessLog[h.id]!.add(completed);
        habitNames[h.id] = h.name;

        habitWeekdayLog.putIfAbsent(h.id, () => {});
        habitWeekdayLog[h.id]!.putIfAbsent(date.weekday, () => []);
        habitWeekdayLog[h.id]![date.weekday]!.add(completed);
      }

      if (possible > 0) {
        final score = actual / possible;
        dayScores.add(score);
        weekdayScores[date.weekday]!.add(score);
        totalScheduledDays++;
      } else {
        dayScores.add(null);
      }
    }

    // Insufficient data guard
    if (totalScheduledDays < minValidDays) {
      return [
        RootCauseInsight(
          headline: 'Keep building your routine!',
          detail: 'Track at least $minValidDays days to unlock behavior insights.',
          suggestion: 'Complete your scheduled habits today to gather more data',
          icon: CupertinoIcons.lock_fill,
          accentColor: const Color(0xFF9CA3AF),
          confidence: 1.0,
          priority: 0,
          category: InsightCategory.streakPattern,
        ),
      ];
    }

    // ── A: Streak Break Pattern ──────────────────────────────────────────
    final streakResult = _analyseStreakBreakPattern(dayScores, minValidDays);
    if (streakResult != null && streakResult.confidence >= minConfidence) {
      results.add(streakResult);
    }

    // ── B: Weekday Performance ───────────────────────────────────────────
    final weekdayResults = _analyseWeekdayPerformance(weekdayScores, minConfidence);
    results.addAll(weekdayResults);

    // ── C: Habit Difficulty ──────────────────────────────────────────────
    final difficultyResults = _analyseHabitDifficulty(
        habitSuccessLog, habitNames, minConfidence, minValidDays);
    results.addAll(difficultyResults);

    // ── D: Post-Weekend Drop ─────────────────────────────────────────────
    final dropResult = _analysePostWeekendDrop(weekdayScores, minConfidence);
    if (dropResult != null) results.add(dropResult);

    // ── E: Per-Habit Weekday Weakness ────────────────────────────────────
    final perHabitResult = _analysePerHabitWeakestDay(
        habitWeekdayLog, habitNames, minConfidence);
    if (perHabitResult != null) results.add(perHabitResult);

    // ── F: Streak-at-risk today ──────────────────────────────────────────
    final riskResult = _analyseStreakRisk(dayScores, today);
    if (riskResult != null) results.add(riskResult);

    return results;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Detector A — Streak break pattern
  // ─────────────────────────────────────────────────────────────────────────
  static RootCauseInsight? _analyseStreakBreakPattern(
      List<double?> dayScores, int minValidDays) {
    final List<int> completedStreaks = [];
    int current = 0;

    for (final score in dayScores) {
      if (score == null) continue;
      if (score >= 0.8) {
        current++;
      } else {
        if (current >= 2) completedStreaks.add(current);
        current = 0;
      }
    }
    if (current >= 2) completedStreaks.add(current); 

    if (completedStreaks.length < 3) return null;

    final Map<int, int> freq = {};
    for (final s in completedStreaks) {
      freq[s] = (freq[s] ?? 0) + 1;
    }
    final sortedByFreq = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final modal = sortedByFreq.first;
    final confidence = modal.value / completedStreaks.length;

    if (confidence < 0.4) return null; 

    final n = modal.key;
    String text;
    String detail;
    if (n <= 2) {
      text = 'Your streaks tend to break early';
      detail = 'You often lose momentum after just $n day${n == 1 ? '' : 's'}. Focus on making day ${n + 1} automatic.';
    } else {
      text = 'You usually break around day $n';
      detail = 'Your streaks most often end after $n days. Day ${n + 1} is your critical turning point — plan for it.';
    }

    String suggestion;
    if (confidence >= 0.8) {
      suggestion = 'Reduce your goal slightly around day ${n + 1} to avoid burnout';
    } else if (confidence >= 0.7) {
      suggestion = 'Plan a lighter day around day ${n + 1}';
    } else {
      suggestion = 'Try staying consistent past day $n';
    }

    return RootCauseInsight(
      headline: text,
      detail: detail,
      suggestion: suggestion,
      icon: CupertinoIcons.shield_lefthalf_fill,
      accentColor: const Color(0xFF3B82F6),
      confidence: confidence,
      priority: 80,
      category: InsightCategory.streakPattern,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Detector B — Weekday performance
  // ─────────────────────────────────────────────────────────────────────────
  static List<RootCauseInsight> _analyseWeekdayPerformance(
      Map<int, List<double>> weekdayScores, double minConfidence) {
    final results = <RootCauseInsight>[];
    final names = {
      1: 'Mondays', 2: 'Tuesdays', 3: 'Wednesdays',
      4: 'Thursdays', 5: 'Fridays', 6: 'Saturdays', 7: 'Sundays',
    };

    final Map<int, double> avgByDay = {};
    for (final entry in weekdayScores.entries) {
      if (entry.value.length >= 3) {
        avgByDay[entry.key] =
            entry.value.reduce((a, b) => a + b) / entry.value.length;
      }
    }
    if (avgByDay.length < 3) return results;

    final sorted = avgByDay.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = sorted.first;
    final worst = sorted.last;

    final gap = best.value - worst.value;

    if (best.value >= 0.75 && gap >= 0.25) {
      final conf = (best.value - 0.5).clamp(0.0, 0.5) / 0.5;
      
      String suggestion;
      if (conf >= 0.8) {
        suggestion = 'Capitalize on ${names[best.key]} by tackling your hardest goals';
      } else if (conf >= 0.7) {
        suggestion = 'Use your momentum on ${names[best.key]} for extra progress';
      } else {
        suggestion = 'Keep up the great work on ${names[best.key]}';
      }

      results.add(RootCauseInsight(
        headline: '${names[best.key]} are your strongest days',
        detail: 'You consistently complete more habits on ${names[best.key]} than any other day of the week.',
        suggestion: suggestion,
        icon: CupertinoIcons.star_fill,
        accentColor: const Color(0xFF10B981),
        confidence: conf,
        priority: 60,
        category: InsightCategory.weekdayPattern,
      ));
    }

    if (worst.value <= 0.55 && gap >= 0.25) {
      final conf = ((1 - worst.value) - 0.45).clamp(0.0, 0.55) / 0.55;
      
      String suggestion;
      if (conf >= 0.8) {
        suggestion = 'Consider reducing effort or treating ${names[worst.key]} as a recovery day';
      } else if (conf >= 0.7) {
        suggestion = 'Keep ${names[worst.key]} lighter';
      } else {
        suggestion = 'Be mindful on ${names[worst.key]}';
      }

      results.add(RootCauseInsight(
        headline: 'You slip most on ${names[worst.key]}',
        detail: 'Your habit completion drops noticeably on ${names[worst.key]}. Try setting an easy "anchor" habit for that day.',
        suggestion: suggestion,
        icon: CupertinoIcons.calendar_badge_minus,
        accentColor: const Color(0xFFF59E0B),
        confidence: conf,
        priority: 65,
        category: InsightCategory.weekdayPattern,
      ));
    }

    return results;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Detector C — Per-habit difficulty
  // ─────────────────────────────────────────────────────────────────────────
  static List<RootCauseInsight> _analyseHabitDifficulty(
    Map<String, List<bool>> logs,
    Map<String, String> names,
    double minConfidence,
    int minValidDays,
  ) {
    final results = <RootCauseInsight>[];
    if (logs.length < 2) return results;

    String? hardestId, easiestId;
    double minRate = 2.0, maxRate = -1.0;

    for (final entry in logs.entries) {
      final days = entry.value;
      if (days.length < minValidDays) continue;
      final rate = days.where((b) => b).length / days.length;
      if (rate < minRate) { minRate = rate; hardestId = entry.key; }
      if (rate > maxRate) { maxRate = rate; easiestId = entry.key; }
    }

    if (hardestId != null && minRate <= 0.5) {
      final conf = ((0.5 - minRate) / 0.5).clamp(0.0, 1.0);
      if (conf >= minConfidence) {
        String suggestion;
        if (conf >= 0.8) {
          suggestion = 'Reduce goal or divide into multiple sessions';
        } else if (conf >= 0.7) {
          suggestion = 'Try splitting this into smaller parts';
        } else {
          suggestion = 'This habit may need more consistency';
        }

        results.add(RootCauseInsight(
          headline: '"${names[hardestId]}" is your toughest habit',
          detail: 'You complete this habit less than half the time it\'s scheduled. Consider reducing its goal or pairing it with an easier habit.',
          suggestion: suggestion,
          icon: CupertinoIcons.flame_fill,
          accentColor: const Color(0xFFEF4444),
          confidence: conf,
          priority: 75,
          category: InsightCategory.habitDifficulty,
        ));
      }
    }

    if (easiestId != null && hardestId != easiestId && maxRate >= 0.85 && (maxRate - minRate) >= 0.35) {
      final conf = ((maxRate - 0.85) / 0.15).clamp(0.0, 1.0);
      if (conf >= minConfidence) {
        String suggestion;
        if (conf >= 0.8) {
          suggestion = 'Pair this with a new habit to build momentum';
        } else if (conf >= 0.7) {
          suggestion = 'Use this habit as an anchor for harder ones';
        } else {
          suggestion = 'Keep up the strong consistency';
        }

        results.add(RootCauseInsight(
          headline: '"${names[easiestId]}" is your strongest habit',
          detail: 'You almost never miss this one. Use it as an anchor to chain harder habits.',
          suggestion: suggestion,
          icon: CupertinoIcons.checkmark_seal_fill,
          accentColor: const Color(0xFF10B981),
          confidence: conf,
          priority: 40,
          category: InsightCategory.habitDifficulty,
        ));
      }
    }

    return results;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Detector D — Post-weekend drop
  // ─────────────────────────────────────────────────────────────────────────
  static RootCauseInsight? _analysePostWeekendDrop(
      Map<int, List<double>> weekdayScores, double minConfidence) {
    final monScores = weekdayScores[1] ?? [];
    final sunScores = weekdayScores[7] ?? [];
    if (monScores.length < 3 && sunScores.length < 3) return null;

    final weekdayAvgs = <double>[];
    for (int d = 2; d <= 6; d++) {
      final s = weekdayScores[d] ?? [];
      if (s.isNotEmpty) weekdayAvgs.add(s.reduce((a, b) => a + b) / s.length);
    }
    if (weekdayAvgs.isEmpty) return null;

    final weekAvg = weekdayAvgs.reduce((a, b) => a + b) / weekdayAvgs.length;

    double weakCount = 0;
    double totalWeekend = 0;

    if (sunScores.isNotEmpty) {
      final sunAvg = sunScores.reduce((a, b) => a + b) / sunScores.length;
      if (sunAvg < weekAvg - 0.20) weakCount++;
      totalWeekend++;
    }
    if (monScores.isNotEmpty) {
      final monAvg = monScores.reduce((a, b) => a + b) / monScores.length;
      if (monAvg < weekAvg - 0.20) weakCount++;
      totalWeekend++;
    }

    if (totalWeekend == 0) return null;
    final confidence = weakCount / totalWeekend;
    if (confidence < minConfidence) return null;

    String suggestion;
    if (confidence >= 0.8) {
      suggestion = 'Use Monday as a recovery day with lower intensity';
    } else if (confidence >= 0.7) {
      suggestion = 'Start Monday lighter to ease back into routines';
    } else {
      suggestion = 'Stay consistent after weekends';
    }

    return RootCauseInsight(
      headline: 'Your consistency drops over weekends',
      detail: 'Your habit scores noticeably dip on Sundays and Mondays. Weekend routines and a light Monday plan can help maintain momentum.',
      suggestion: suggestion,
      icon: CupertinoIcons.arrow_down_circle_fill,
      accentColor: const Color(0xFFF97316),
      confidence: confidence,
      priority: 70,
      category: InsightCategory.dropPattern,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Detector E — Per-habit worst weekday
  // ─────────────────────────────────────────────────────────────────────────
  static RootCauseInsight? _analysePerHabitWeakestDay(
    Map<String, Map<int, List<bool>>> habitWeekdayLog,
    Map<String, String> names,
    double minConfidence,
  ) {
    final dayNames = {
      1: 'Mondays', 2: 'Tuesdays', 3: 'Wednesdays',
      4: 'Thursdays', 5: 'Fridays', 6: 'Saturdays', 7: 'Sundays',
    };

    RootCauseInsight? best;
    double bestConf = 0;

    for (final hEntry in habitWeekdayLog.entries) {
      final String habitId = hEntry.key;
      final Map<int, List<bool>> wdLog = hEntry.value;

      final allDays = wdLog.values.expand((l) => l).toList();
      if (allDays.length < 7) continue;
      final overallRate = allDays.where((b) => b).length / allDays.length;

      int? worstDay;
      double worstRate = 2.0;
      for (final wd in wdLog.entries) {
        if (wd.value.length < 2) continue;
        final rate = wd.value.where((b) => b).length / wd.value.length;
        if (rate < worstRate) { worstRate = rate; worstDay = wd.key; }
      }

      if (worstDay == null) continue;
      final drop = overallRate - worstRate;
      if (drop < 0.30) continue; 

      final wdList = wdLog[worstDay]!;
      final conf = wdList.where((b) => !b).length / wdList.length;
      if (conf < minConfidence) continue;
      if (conf <= bestConf) continue;

      bestConf = conf;

      String suggestion;
      if (conf >= 0.8) {
        suggestion = 'Move this habit to a different day if possible';
      } else if (conf >= 0.7) {
        suggestion = 'Lower the goal for this habit on ${dayNames[worstDay]}';
      } else {
        suggestion = 'Try setting a reminder specifically for this day';
      }

      best = RootCauseInsight(
        headline: 'You often skip "${names[habitId]}" on ${dayNames[worstDay]}',
        detail: 'This specific habit has a much lower completion rate on ${dayNames[worstDay]} compared to the rest of the week. Try scheduling it differently on that day.',
        suggestion: suggestion,
        icon: CupertinoIcons.exclamationmark_circle_fill,
        accentColor: const Color(0xFFEC4899),
        confidence: conf,
        priority: 72,
        category: InsightCategory.dropPattern,
      );
    }

    return best;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Detector F — Streak at risk today
  // ─────────────────────────────────────────────────────────────────────────
  static RootCauseInsight? _analyseStreakRisk(
      List<double?> dayScores, DateTime today) {
    if (today.hour < 18) return null; 

    int streak = 0;
    for (int i = dayScores.length - 2; i >= 0; i--) {
      final s = dayScores[i];
      if (s == null) continue;
      if (s >= 0.8) {
        streak++;
      } else {
        break;
      }
    }
    if (streak < 2) return null;

    final todayScore = dayScores.isNotEmpty ? dayScores.last : null;
    if (todayScore == null || todayScore >= 0.8) return null;

    String suggestion;
    if (streak >= 7) {
      suggestion = 'Don\'t let a long streak slip—do a bare minimum rep right now';
    } else if (streak >= 3) {
      suggestion = 'You\'ve built momentum, take 2 minutes to keep it alive';
    } else {
      suggestion = 'Small efforts count, do just one rep to save the streak';
    }

    return RootCauseInsight(
      headline: 'Your $streak-day streak is at risk tonight',
      detail: 'You haven\'t reached your usual completion score today. Even finishing one more habit will help protect your streak.',
      suggestion: suggestion,
      icon: CupertinoIcons.exclamationmark_triangle_fill,
      accentColor: const Color(0xFFEF4444),
      confidence: 0.95,
      priority: 100,
      category: InsightCategory.risk,
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool _isScheduledOn(Habit habit, DateTime date) {
    if (habit.isEveryDay) return true;
    final appDay = date.weekday % 7; 
    return habit.selectedDays.contains(appDay);
  }
}
