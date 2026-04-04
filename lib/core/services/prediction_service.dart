import 'package:intl/intl.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';

class PredictionService {
  PredictionService._();

  static String? _lastCacheDate;
  static final Map<String, int?> _cachedPredictions = {};

  /// Computes a Predictive Success Score (10% - 95%) predicting the likelihood
  /// of completing the habit today. Follows a weighted formula over historical data.
  /// Returns null if there's insufficient data (<5 days).
  static int? getPredictionScore(Habit habit) {
    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // Invalidate cache if new day
    if (_lastCacheDate != todayKey) {
      _cachedPredictions.clear();
      _lastCacheDate = todayKey;
    }

    if (_cachedPredictions.containsKey(habit.id)) {
      return _cachedPredictions[habit.id];
    }

    final score = _computePrediction(habit);
    _cachedPredictions[habit.id] = score;
    return score;
  }

  static void invalidate() {
    _cachedPredictions.clear();
  }

  static int? _computePrediction(Habit habit) {
    final today = DateTime.now();
    final allKeys = habit.dailyProgress.keys.toList()..sort();
    
    // 1. Gather historical valid data (up to yesterday)
    // We only evaluate past dates, not today's currently active progress
    List<DateTime> pastDates = [];
    DateTime pointer = habit.startDate;
    final cutoff = DateTime(today.year, today.month, today.day);

    while (pointer.isBefore(cutoff)) {
      if (habit.isEveryDay || habit.selectedDays.contains(pointer.weekday % 7)) {
        pastDates.add(pointer);
      }
      pointer = pointer.add(const Duration(days: 1));
    }

    if (pastDates.length < 5) return null; // Rule 3: Do NOT show prediction if < 5 valid days

    int totalScheduled = 0;
    double totalCompleted = 0.0;
    
    int recent7Scheduled = 0;
    double recent7Completed = 0.0;
    
    int recent3Scheduled = 0;
    double recent3Completed = 0.0;

    int weekdayScheduled = 0;
    double weekdayCompleted = 0.0;

    int currentStreak = 0;

    // We iterate backwards to easily count recent 3, recent 7, and current streak
    for (int i = pastDates.length - 1; i >= 0; i--) {
      final d = pastDates[i];
      final key = DateFormat('yyyy-MM-dd').format(d);
      
      final goal = habit.goalFor(key);
      if (goal <= 0) continue;
      
      final rawProgress = (habit.dailyProgress[key] ?? 0).toDouble();
      final normalized = (rawProgress / goal).clamp(0.0, 1.0);

      totalScheduled++;
      totalCompleted += normalized;

      // Current Weekday stats
      if (d.weekday == today.weekday) {
        weekdayScheduled++;
        weekdayCompleted += normalized;
      }

      int daysFromCutoff = cutoff.difference(d).inDays;
      
      if (daysFromCutoff <= 7) {
        recent7Scheduled++;
        recent7Completed += normalized;
      }
      
      if (daysFromCutoff <= 3) {
        recent3Scheduled++;
        recent3Completed += normalized;
      }

      // Streak logic (trailing from yesterday backwards)
      if (totalScheduled == currentStreak + 1) { // If streak hasn't broken yet
        if (normalized >= 1.0) {
          currentStreak++;
        }
      }
    }

    if (totalScheduled < 5) return null; // Safe guard if goals were 0

    // Component Calculations
    double overallSuccessRate = totalCompleted / totalScheduled;
    double recentPerformance = recent7Scheduled > 0 ? (recent7Completed / recent7Scheduled) : overallSuccessRate;
    double weekdayPerformance = weekdayScheduled > 0 ? (weekdayCompleted / weekdayScheduled) : overallSuccessRate;
    double momentum = recent3Scheduled > 0 ? (recent3Completed / recent3Scheduled) : recentPerformance;
    
    // Normalize streak factor: cap at 14 days (14 days = 100% streak component)
    double streakFactor = (currentStreak / 14.0).clamp(0.0, 1.0);

    // Score = (0.30*recent) + (0.20*weekday) + (0.20*overall) + (0.15*streak) + (0.15*momentum)
    double rawScore = 
      (0.30 * recentPerformance) +
      (0.20 * weekdayPerformance) +
      (0.20 * overallSuccessRate) +
      (0.15 * streakFactor) +
      (0.15 * momentum);

    int finalPercentage = (rawScore * 100).round();
    return finalPercentage.clamp(10, 95); 
  }
}
