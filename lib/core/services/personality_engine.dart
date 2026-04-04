import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';

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
}
