import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';

enum Chronotype { lion, bear, wolf, dolphin, none }

class WillpowerForecast {
  final List<double> next7Days; // Index 0 = Today, Index 1 = Tomorrow, etc.
  final String insightMessage;
  final bool hasEnoughData;

  const WillpowerForecast({
    required this.next7Days,
    required this.insightMessage,
    required this.hasEnoughData,
  });
}

class HabitPersonality {
  final String title;
  final String icon;
  final String description;
  final double confidence; // Internal only (0.0 to 1.0)
  final Color color;

  const HabitPersonality({
    required this.title,
    required this.icon,
    required this.description,
    required this.confidence,
    required this.color,
  });
}

class PersonalityEngine {
  PersonalityEngine._();

  static String? _cacheDate;
  static List<HabitPersonality>? _cachedPersonalities;
  static Chronotype? _cachedChronotype;

  /// Gets the user's dominant Chronotype using advanced Active-Hours calculation
  /// with Time-Decay weighting to adapt quickly to shift changes.
  static Chronotype getChronotype(List<Habit> habits) {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_cacheDate == todayKey && _cachedChronotype != null) {
      return _cachedChronotype!;
    }

    final today = DateTime.now();
    final windowDays = 30;
    final window = List.generate(
        windowDays, (i) => today.subtract(Duration(days: windowDays - i - 1)));

    double lionWeight = 0;
    double bearWeight = 0;
    double wolfWeight = 0;
    int activeDaysCount = 0;

    for (final date in window) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      Set<int> activeHoursToday = {};

      for (final h in habits) {
        if (h.completionTimestamps.containsKey(key)) {
          try {
            final time = h.completionTimestamps[key];
            if (time != null) {
              // Extract the physical local hour
              activeHoursToday.add(time.hour);
            }
          } catch (_) {
            // Silently swallow malformed legacy dates
          }
        }
      }

      if (activeHoursToday.isNotEmpty) {
        activeDaysCount++;
        final daysAgo = today.difference(date).inDays.abs().clamp(0, 30);
        // Time decay: 1.0 weight today, decays to 0.2 weight at 30 days old
        final weight = 1.0 - (daysAgo * (0.8 / 30));

        for (final hour in activeHoursToday) {
          if (hour >= 5 && hour < 12) {
            lionWeight += weight; // 5 AM to 11:59 AM
          } else if (hour >= 12 && hour < 17) {
            bearWeight += weight; // 12 PM to 4:59 PM
          } else {
            wolfWeight += weight; // 5 PM to 4:59 AM
          }
        }
      }
    }

    Chronotype result;
    if (activeDaysCount < 7) {
      result = Chronotype.none; // Cold start safeguard
    } else {
      final totalWeight = lionWeight + bearWeight + wolfWeight;
      if (totalWeight <= 0) {
        result = Chronotype.none;
      } else {
        final lionRatio = lionWeight / totalWeight;
        final bearRatio = bearWeight / totalWeight;
        final wolfRatio = wolfWeight / totalWeight;

        if (lionRatio >= 0.50) {
          result = Chronotype.lion;
        } else if (wolfRatio >= 0.50) {
          result = Chronotype.wolf;
        } else if (bearRatio >= 0.50) {
          result = Chronotype.bear;
        } else {
          result = Chronotype.dolphin; // Erratic spread, no dominant majority
        }
      }
    }

    _cachedChronotype = result;
    return result;
  }

  /// Returns up to 2 top personalities based on the user's last 30 days of data.
  /// Minimum requirement: 10 valid days.
  /// Only traits with >= 60% confidence are returned.
  static List<HabitPersonality> analyze(List<Habit> habits) {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_cacheDate == todayKey && _cachedPersonalities != null) {
      return _cachedPersonalities!;
    }

    final results = _computeTraits(habits);
    
    // Sort descending by confidence
    results.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Filter to >= 60% confidence and take max 2
    final finalTraits = results.where((t) => t.confidence >= 0.60).take(2).toList();
    
    _cachedPersonalities = finalTraits;
    _cacheDate = todayKey;
    return finalTraits;
  }

  static void invalidate() {
    _cachedPersonalities = null;
    _cacheDate = null;
  }

  static List<HabitPersonality> _computeTraits(List<Habit> habits) {
    if (habits.isEmpty) return [];

    final today = DateTime.now();
    final windowDays = 30;
    final window = List.generate(windowDays, (i) => today.subtract(Duration(days: windowDays - 1 - i)));

    // Data structures for cross-habit daily completion
    final Map<String, double> dayScores = {}; // DateStr -> user's overall success rate that day
    
    int totalScheduledDays = 0; // Total active days across all window

    // Helper to evaluate each day
    for (final date in window) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      double possible = 0;
      double actual = 0;

      for (final h in habits) {
        if (h.isQuitHabit) continue;
        if (date.isBefore(h.startDate)) continue;
        
        bool isScheduled = h.isEveryDay || h.selectedDays.contains(date.weekday % 7);
        if (!isScheduled) continue;

        final goal = h.goalFor(key);
        if (goal <= 0) continue;

        final raw = (h.dailyProgress[key] ?? 0).toDouble();
        final normalized = (raw / goal).clamp(0.0, 1.0);

        possible += 1.0;
        actual += normalized;
      }

      if (possible > 0) {
        dayScores[key] = actual / possible;
        totalScheduledDays++;
      }
    }

    // Condition 3: Do NOT show anything if < 10 valid days of data
    if (totalScheduledDays < 10) return [];

    final traits = <HabitPersonality>[];
    
    // Convert dayScores to an ordered list for sequence analysis
    final sortedDates = dayScores.keys.toList()..sort();
    final orderedScores = sortedDates.map((k) => dayScores[k]!).toList();
    
    // Analyze Weekend vs Weekday Slacker (Weekend Slacker 📉)
    double weekendSum = 0, weekdaySum = 0;
    int weekendCount = 0, weekdayCount = 0;

    for (final date in window) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      if (!dayScores.containsKey(key)) continue;
      
      final score = dayScores[key]!;
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
        weekendSum += score;
        weekendCount++;
      } else {
        weekdaySum += score;
        weekdayCount++;
      }
    }

    if (weekendCount > 0 && weekdayCount > 0) {
      double weekdayAvg = weekdaySum / weekdayCount;
      double weekendAvg = weekendSum / weekendCount;
      
      // if weekend success << weekday success by >= 25% margin
      if (weekdayAvg - weekendAvg >= 0.25) {
        // Map 25% gap to 60% confidence, 50% gap to 100% confidence
        final conf = ((weekdayAvg - weekendAvg) - 0.25) / 0.25 * 0.40 + 0.60;
        traits.add(HabitPersonality(
          title: "Weekend Slacker",
          icon: "📉",
          description: "Your consistency drops on weekends",
          confidence: conf.clamp(0.0, 1.0),
          color: const Color(0xFFF59E0B),
        ));
      }
    }

    // Analyze Comeback Fighter (🔁)
    // habit missed AND next day completed frequently >= 60%
    int missCount = 0;
    int comebackCount = 0;
    
    for (int i = 0; i < orderedScores.length - 1; i++) {
      if (orderedScores[i] < 0.5) { // Threshold for "missed" day
        missCount++;
        if (orderedScores[i+1] >= 0.8) { // Next day bounced back
          comebackCount++;
        }
      }
    }
    
    if (missCount >= 2) {
      double comebackRate = comebackCount / missCount;
      if (comebackRate >= 0.60) {
        traits.add(HabitPersonality(
          title: "Comeback Fighter",
          icon: "🔁",
          description: "You bounce back quickly after missing a day",
          confidence: comebackRate,
          color: const Color(0xFFEC4899),
        ));
      }
    }

    // Analyze Consistency Driven (📈)
    double overallScore = orderedScores.reduce((a,b)=>a+b) / orderedScores.length;
    int streakBreaks = missCount; 
    
    // High success rate && low breaks
    if (overallScore >= 0.80 && streakBreaks <= 3) {
      // Scale confidence up towards 1.0 based on >0.80 overall score
      final conf = (overallScore - 0.80) / 0.20 * 0.40 + 0.60;
      traits.add(HabitPersonality(
        title: "Consistency Driven",
        icon: "📈",
        description: "You stay consistent across most days",
        confidence: conf.clamp(0.0, 1.0),
        color: const Color(0xFF10B981),
      ));
    }

    // Analyze Burst Performer (⚡)
    // Short streaks (1-3 days) but high intensity (score >= 0.9) surrounded by zero/low days
    int shortStreaks = 0;
    int currentStreak = 0;
    for (final score in orderedScores) {
      if (score >= 0.8) {
        currentStreak++;
      } else {
        if (currentStreak >= 1 && currentStreak <= 3) {
          shortStreaks++;
        }
        currentStreak = 0;
      }
    }
    if (currentStreak >= 1 && currentStreak <= 3) shortStreaks++;
    
    // If the majority of their successful days happened in short bursts
    int totalSuccessDays = orderedScores.where((s) => s >= 0.8).length;
    if (totalSuccessDays > 0 && shortStreaks >= 3) {
      // Calculate ratio of burst days vs total days
      double burstRatio = (shortStreaks * 2) / totalSuccessDays; // roughly assuming avg short streak = 2
      if (burstRatio >= 0.6) {
        traits.add(HabitPersonality(
          title: "Burst Performer",
          icon: "⚡",
          description: "You work in short but intense streaks",
          confidence: burstRatio.clamp(0.0, 1.0),
          color: const Color(0xFF8B5CF6),
        ));
      }
    }

    // Analyze Morning vs Evening vs Night Performer
    int totalTimedCompletions = 0;
    int morningCount = 0;
    int eveningCount = 0;
    int nightCount = 0;

    for (final date in window) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      for (final h in habits) {
        if (h.completionTimestamps.containsKey(key)) {
          final time = h.completionTimestamps[key]!;
          totalTimedCompletions++;
          if (time.hour < 12) {
            morningCount++;
          } else if (time.hour >= 12 && time.hour < 18) {
            eveningCount++;
          } else {
            nightCount++;
          }
        }
      }
    }

    if (totalTimedCompletions >= 10) {
      double morningRatio = morningCount / totalTimedCompletions;
      double eveningRatio = eveningCount / totalTimedCompletions;
      double nightRatio = nightCount / totalTimedCompletions;

      if (morningRatio >= 0.65) {
        traits.add(HabitPersonality(
          title: "Morning Performer",
          icon: "🌅",
          description: "You usually complete habits in the morning",
          confidence: morningRatio,
          color: const Color(0xFFF59E0B),
        ));
      } else if (eveningRatio >= 0.65) {
        traits.add(HabitPersonality(
          title: "Evening Performer",
          icon: "🌆",
          description: "You tend to complete habits in the afternoon/evening",
          confidence: eveningRatio,
          color: const Color(0xFFF43F5E),
        ));
      } else if (nightRatio >= 0.65) {
        traits.add(HabitPersonality(
          title: "Night Performer",
          icon: "🌙",
          description: "You usually complete habits late in the day",
          confidence: nightRatio,
          color: const Color(0xFF6366F1),
        ));
      }
    }

    return traits;
  }

  static WillpowerForecast getWillpowerForecast(List<Habit> habits) {
    final today = DateTime.now();
    final windowDays = 60; // 60 days of history for robust baseline
    final window = List.generate(
        windowDays, (i) => today.subtract(Duration(days: windowDays - i - 1)));

    // Group success ratios by weekday (1=Monday, 7=Sunday)
    final Map<int, List<double>> weekdayScores = {
      1: [], 2: [], 3: [], 4: [], 5: [], 6: [], 7: []
    };

    int activeScheduledDays = 0;

    for (final date in window) {
      final key = DateFormat('yyyy-MM-dd').format(date);
      double possible = 0;
      double actual = 0;

      for (final h in habits) {
        if (h.isQuitHabit) continue; // Exclude quit habits
        if (date.isBefore(h.startDate)) continue;

        bool isScheduled =
            h.isEveryDay || h.selectedDays.contains(date.weekday % 7);
        if (!isScheduled) continue;

        final goal = h.goalFor(key);
        if (goal <= 0) continue;

        final raw = (h.dailyProgress[key] ?? 0).toDouble();
        final normalized = (raw / goal).clamp(0.0, 1.0);

        possible += 1.0;
        actual += normalized;
      }

      if (possible > 0) {
        activeScheduledDays++;
        weekdayScores[date.weekday]!.add(actual / possible);
      }
    }

    // Cold-start safeguard
    if (activeScheduledDays < 14) {
      return WillpowerForecast(
        next7Days: List.filled(7, 0.85),
        insightMessage: "Gathering biological data... Keep tracking for a few more days to unlock your Willpower Forecast.",
        hasEnoughData: false,
      );
    }

    // Calculate historical average per weekday
    final Map<int, double> baseline = {};
    for (int i = 1; i <= 7; i++) {
      final scores = weekdayScores[i]!;
      if (scores.isEmpty) {
        baseline[i] = 0.85; // Fallback neutral average
      } else {
        baseline[i] = scores.reduce((a, b) => a + b) / scores.length;
      }
    }

    // Build the 7-day raw forecast array starting TODAY
    final List<double> rawForecast = [];
    for (int i = 0; i < 7; i++) {
      final targetDate = today.add(Duration(days: i));
      rawForecast.add(baseline[targetDate.weekday]!);
    }

    // Apply Simple Moving Average (SMA) smoothing
    final List<double> smoothedForecast = [];
    for (int i = 0; i < 7; i++) {
      if (i == 0) {
        smoothedForecast.add((rawForecast[0] + rawForecast[1]) / 2);
      } else if (i == 6) {
        smoothedForecast.add((rawForecast[5] + rawForecast[6]) / 2);
      } else {
        smoothedForecast.add(
            (rawForecast[i - 1] + rawForecast[i] + rawForecast[i + 1]) / 3);
      }
    }

    // Generate Generative Insight
    String insightMsg = "";
    double minVal = smoothedForecast[0];
    double maxVal = smoothedForecast[0];
    int minIndex = 0;
    int maxIndex = 0;

    for (int i = 1; i < 7; i++) {
      if (smoothedForecast[i] < minVal) {
        minVal = smoothedForecast[i];
        minIndex = i;
      }
      if (smoothedForecast[i] > maxVal) {
        maxVal = smoothedForecast[i];
        maxIndex = i;
      }
    }

    // Mathematical Variance
    final variance = maxVal - minVal;

    if (variance < 0.10) {
      insightMsg = "Your willpower reserve is exceptionally stable. You are highly consistent this week.";
    } else if (variance > 0.25 && minVal < 0.50 && minIndex > 0) {
      final dropDayStr = DateFormat('EEEE').format(today.add(Duration(days: minIndex)));
      insightMsg = "Watch out! Your biorhythm trend shows your willpower usually crashes on ${dropDayStr}s. Take it easy.";
    } else if (variance > 0.20 && maxIndex > 0) {
      final peakDayStr = DateFormat('EEEE').format(today.add(Duration(days: maxIndex)));
      insightMsg = "Your willpower historically peaks on ${peakDayStr}s. Use that energy to tackle your hardest habits!";
    } else if (smoothedForecast[1] > smoothedForecast[0]) {
      insightMsg = "Your willpower battery is recharging. Tomorrow looks like a highly productive day!";
    } else {
      insightMsg = "Your biological momentum is holding steady. Keep pushing forward.";
    }

    return WillpowerForecast(
      next7Days: smoothedForecast,
      insightMessage: insightMsg,
      hasEnoughData: true,
    );
  }
}
