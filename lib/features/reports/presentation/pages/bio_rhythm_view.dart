import 'dart:ui';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/features/habits/data/repositories/habit_repository.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_controller.dart';
import 'package:habit_tracker_ios/features/mood/presentation/controllers/mood_controller.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker_ios/core/services/personality_engine.dart';
// ─── Mood Sentiment Map (confirmed from diary_screen.dart palette) ────────────
const Map<String, String> _moodSentiment = {
  '😊': 'positive', '😄': 'positive', '😎': 'positive',
  '😇': 'positive', '🤩': 'positive',
  '😐': 'neutral',  '😴': 'neutral',
  '😔': 'negative', '😤': 'negative', '😡': 'negative',
};

// ─── Data Classes ─────────────────────────────────────────────────────────────
class _PeakHourResult {
  final Map<int, int> blockCounts; // 0-5 (4-hour blocks)
  final int peakBlock;
  final int totalCompletions;
  const _PeakHourResult({required this.blockCounts, required this.peakBlock, required this.totalCompletions});
}

class _MoodResult {
  final double positiveAvg, neutralAvg, negativeAvg;
  final int posDays, neuDays, negDays;
  const _MoodResult({
    required this.positiveAvg, required this.neutralAvg, required this.negativeAvg,
    required this.posDays, required this.neuDays, required this.negDays,
  });
}

class _DominoResult {
  final String habitName;
  final String? habitIcon;
  final int colorValue;
  final double upliftPercent;
  final int dayCount;
  const _DominoResult({required this.habitName, this.habitIcon, required this.colorValue, required this.upliftPercent, required this.dayCount});
}

class _BurnoutResult {
  final List<double> scores; // oldest → newest valid day scores
  final double trend;
  final String trendLabel;
  final Color trendColor;
  const _BurnoutResult({required this.scores, required this.trend, required this.trendLabel, required this.trendColor});
}

class _FocusMoodResult {
  final double posMinutes, neuMinutes, negMinutes;
  final String topMoodEmoji;
  const _FocusMoodResult({required this.posMinutes, required this.neuMinutes, required this.negMinutes, required this.topMoodEmoji});
}

class _DayOfWeekResult {
  final Map<int, double> dayRates; // 1 (Mon) - 7 (Sun)
  final int bestDay, worstDay;
  final double bestRate, worstRate;
  const _DayOfWeekResult({required this.dayRates, required this.bestDay, required this.worstDay, required this.bestRate, required this.worstRate});
}

class _ClinicalAssessment {
  final String label;
  final String diagnosis;
  final String prescription;
  final String volatilityLabel;
  final List<double> volatilityEkg; 
  const _ClinicalAssessment({required this.label, required this.diagnosis, required this.prescription, required this.volatilityLabel, required this.volatilityEkg});
}

class _BioResult {
  final _PeakHourResult? peak;
  final _MoodResult? mood;
  final _DominoResult? domino;
  final _BurnoutResult? burnout;
  final _FocusMoodResult? focus;
  final _DayOfWeekResult? dayOfWeek;
  final _ClinicalAssessment? clinical;
  const _BioResult({this.peak, this.mood, this.domino, this.burnout, this.focus, this.dayOfWeek, this.clinical});
}

// ─── Engine ───────────────────────────────────────────────────────────────────
class _BioEngine {
  _BioEngine._();

  static _BioResult analyse(List<Habit> habits, Map<String, String> moods) {
    final trackable = habits.where((h) => !h.isQuitHabit).toList();
    final base = _BioResult(
      peak: _peak(trackable),
      mood: _mood(trackable, moods),
      domino: _domino(trackable),
      burnout: _burnout(trackable),
      focus: _focus(moods),
      dayOfWeek: _bestDay(trackable),
    );
    
    return _BioResult(
      peak: base.peak, mood: base.mood, domino: base.domino, 
      burnout: base.burnout, focus: base.focus, dayOfWeek: base.dayOfWeek,
      clinical: _synthesizeAssessment(base),
    );
  }

  // Card 1 — Peak Hour (6 time blocks of 4 hours each)
  static _PeakHourResult? _peak(List<Habit> habits) {
    final Map<int, int> blocks = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    int total = 0;
    for (final h in habits) {
      for (final ts in h.completionTimestamps.values) {
        final block = (ts.hour ~/ 4).clamp(0, 5);
        blocks[block] = (blocks[block] ?? 0) + 1;
        total++;
      }
    }
    if (total < 10) return null;
    int peakBlock = 0;
    int peakCount = 0;
    blocks.forEach((b, c) { if (c > peakCount) { peakCount = c; peakBlock = b; } });
    return _PeakHourResult(blockCounts: blocks, peakBlock: peakBlock, totalCompletions: total);
  }

  // Card 2 — Mood × Habit Correlation
  static _MoodResult? _mood(List<Habit> habits, Map<String, String> moods) {
    if (moods.isEmpty || habits.isEmpty) return null;
    double posT = 0, neuT = 0, negT = 0;
    int posD = 0, neuD = 0, negD = 0;

    for (final entry in moods.entries) {
      final dateStr = entry.key;
      final sentiment = _moodSentiment[entry.value];
      if (sentiment == null) continue;
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      double possible = 0, actual = 0;
      for (final h in habits) {
        if (date.isBefore(h.startDate)) continue;
        if (!_scheduled(h, date)) continue;
        final goal = h.goalFor(dateStr);
        if (goal <= 0) continue;
        possible += 1.0;
        actual += ((h.dailyProgress[dateStr] ?? 0) / goal).clamp(0.0, 1.0);
      }
      if (possible == 0) continue;
      final rate = actual / possible;
      if (sentiment == 'positive') { posT += rate; posD++; }
      else if (sentiment == 'neutral') { neuT += rate; neuD++; }
      else { negT += rate; negD++; }
    }

    // Need at least 2 buckets with 3+ samples
    int valid = 0;
    if (posD >= 3) valid++;
    if (neuD >= 3) valid++;
    if (negD >= 3) valid++;
    if (valid < 2) return null;

    return _MoodResult(
      positiveAvg: posD > 0 ? posT / posD : -1,
      neutralAvg: neuD > 0 ? neuT / neuD : -1,
      negativeAvg: negD > 0 ? negT / negD : -1,
      posDays: posD, neuDays: neuD, negDays: negD,
    );
  }

  // Card 3 — Domino Habit
  static _DominoResult? _domino(List<Habit> habits) {
    if (habits.length < 2) return null;
    final withTs = habits.where((h) => h.completionTimestamps.isNotEmpty).toList();
    if (withTs.length < 2) return null;

    final today = DateTime.now();
    final Map<String, int> firstCount = {};
    final Map<String, double> firstOtherSum = {};
    double baselineSum = 0;
    int baselineDays = 0;

    for (int i = 1; i <= 60; i++) {
      final date = today.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final completed = <String, DateTime>{};
      for (final h in withTs) {
        if (date.isBefore(h.startDate)) continue;
        if (!_scheduled(h, date)) continue;
        final ts = h.completionTimestamps[dateStr];
        if (ts != null) completed[h.id] = ts;
      }
      if (completed.length < 2) continue;

      // Find first completed habit (sorted by timestamp, then by id as tiebreaker)
      final sorted = completed.entries.toList()
        ..sort((a, b) {
          final cmp = a.value.compareTo(b.value);
          return cmp != 0 ? cmp : a.key.compareTo(b.key);
        });
      final firstId = sorted.first.key;

      // Compute other-habits completion rate (excluding the first)
      double possible = 0, actual = 0;
      for (final h in habits) {
        if (h.id == firstId) continue;
        if (date.isBefore(h.startDate)) continue;
        if (!_scheduled(h, date)) continue;
        final goal = h.goalFor(dateStr);
        if (goal <= 0) continue;
        possible += 1.0;
        actual += ((h.dailyProgress[dateStr] ?? 0) / goal).clamp(0.0, 1.0);
      }
      final otherRate = possible > 0 ? actual / possible : 0.0;

      baselineSum += otherRate;
      baselineDays++;
      firstCount[firstId] = (firstCount[firstId] ?? 0) + 1;
      firstOtherSum[firstId] = (firstOtherSum[firstId] ?? 0.0) + otherRate;
    }

    if (baselineDays < 7) return null;
    final baseline = baselineSum / baselineDays;

    Habit? best;
    double bestUplift = 0;
    int bestCount = 0;

    for (final entry in firstCount.entries) {
      if (entry.value < 5) continue;
      final avgOther = firstOtherSum[entry.key]! / entry.value;
      final uplift = (avgOther - baseline) * 100;
      if (uplift >= 15.0 && uplift > bestUplift) {
        try {
          best = withTs.firstWhere((h) => h.id == entry.key);
          bestUplift = uplift;
          bestCount = entry.value;
        } catch (_) {}
      }
    }
    if (best == null) return null;
    return _DominoResult(
      habitName: best.name, habitIcon: best.icon,
      colorValue: best.colorValue,
      upliftPercent: (bestUplift * 10).round() / 10,
      dayCount: bestCount,
    );
  }

  // Card 4 — Burnout Trend (14 days)
  static _BurnoutResult? _burnout(List<Habit> habits) {
    if (habits.isEmpty) return null;
    final today = DateTime.now();
    final scores = <double>[];

    for (int i = 13; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      double possible = 0, actual = 0;
      for (final h in habits) {
        if (date.isBefore(h.startDate)) continue;
        if (!_scheduled(h, date)) continue;
        final goal = h.goalFor(dateStr);
        if (goal <= 0) continue;
        possible += 1.0;
        actual += ((h.dailyProgress[dateStr] ?? 0) / goal).clamp(0.0, 1.0);
      }
      if (possible > 0) scores.add(actual / possible);
    }

    if (scores.length < 7) return null;

    // Trend: recent 3 avg vs older avg
    final recent = scores.sublist(math.max(0, scores.length - 3)).reduce((a, b) => a + b) /
        math.min(3, scores.length);
    final olderList = scores.sublist(0, math.max(0, scores.length - 3));
    final older = olderList.isEmpty ? recent : olderList.reduce((a, b) => a + b) / olderList.length;
    final trend = (recent - older) * 100;

    String label;
    Color color;
    if (trend >= 5) { label = 'Recovering ↑'; color = const Color(0xFF10B981); }
    else if (trend >= -5) { label = 'Stable →'; color = const Color(0xFF6366F1); }
    else if (trend >= -15) { label = 'Declining ↓'; color = const Color(0xFFF59E0B); }
    else { label = 'Critical 🔴'; color = const Color(0xFFEF4444); }

    return _BurnoutResult(scores: scores, trend: trend, trendLabel: label, trendColor: color);
  }

  // Card 5 — Focus x Mood (Deep Work Predictor)
  static _FocusMoodResult? _focus(Map<String, String> moods) {
    final box = HiveService.focusDailySummaryBox;
    if (box.isEmpty || moods.isEmpty) return null;

    double posMin = 0, neuMin = 0, negMin = 0;
    int posD = 0, neuD = 0, negD = 0;

    for (var key in box.keys) {
      if (key is! String) continue;
      final mood = moods[key];
      if (mood == null) continue;
      final sentiment = _moodSentiment[mood];
      if (sentiment == null) continue;

      final data = box.get(key);
      if (data != null && data is Map) {
         final totalSecs = data['totalSeconds'] as int? ?? 0;
         if (totalSecs == 0) continue;
         
         final mins = totalSecs / 60.0;
         if (sentiment == 'positive') { posMin += mins; posD++; }
         else if (sentiment == 'neutral') { neuMin += mins; neuD++; }
         else { negMin += mins; negD++; }
      }
    }

    int valid = 0;
    if (posD >= 2) valid++;
    if (neuD >= 2) valid++;
    if (negD >= 2) valid++;
    if (valid < 2) return null;

    final posAvg = posD > 0 ? posMin / posD : 0.0;
    final neuAvg = neuD > 0 ? neuMin / neuD : 0.0;
    final negAvg = negD > 0 ? negMin / negD : 0.0;

    String topEmoji = '😊';
    double topMin = posAvg;
    if (neuAvg > topMin) { topMin = neuAvg; topEmoji = '😐'; }
    if (negAvg > topMin) { topMin = negAvg; topEmoji = '😔'; }

    // Ensure we have an actual standout (if everything is 0, return null)
    if (topMin == 0) return null;

    return _FocusMoodResult(posMinutes: posAvg, neuMinutes: neuAvg, negMinutes: negAvg, topMoodEmoji: topEmoji);
  }

  // Card 6 — Weekday Powerhouse
  static _DayOfWeekResult? _bestDay(List<Habit> habits) {
    if (habits.isEmpty) return null;
    final Map<int, double> sumRates = {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0};
    final Map<int, int> counts =     {1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0};
    final today = DateTime.now();

    for (int i = 0; i < 30; i++) {
      final date = today.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final wd = date.weekday;

      double possible = 0, actual = 0;
      for (final h in habits) {
        if (date.isBefore(h.startDate)) continue;
        if (!_scheduled(h, date)) continue;
        final goal = h.goalFor(dateStr);
        if (goal <= 0) continue;
        possible += 1.0;
        actual += ((h.dailyProgress[dateStr] ?? 0) / goal).clamp(0.0, 1.0);
      }
      if (possible > 0) {
        sumRates[wd] = sumRates[wd]! + (actual / possible);
        counts[wd] = counts[wd]! + 1;
      }
    }

    if (counts.values.every((c) => c < 3)) return null;

    final rates = <int, double>{};
    for (int i = 1; i <= 7; i++) {
       rates[i] = counts[i]! > 0 ? sumRates[i]! / counts[i]! : 0.0;
    }

    int best = 1, worst = 1;
    for (int i = 2; i <= 7; i++) {
       if (rates[i]! > rates[best]!) best = i;
       if (rates[i]! < rates[worst]!) worst = i;
    }

    if (rates[best]! == rates[worst]!) return null;

    return _DayOfWeekResult(dayRates: rates, bestDay: best, worstDay: worst, bestRate: rates[best]!, worstRate: rates[worst]!);
  }

  // Card 7 — Clinical Synthesizer (The Engine)
  static _ClinicalAssessment? _synthesizeAssessment(_BioResult base) {
    if (base.burnout == null || base.burnout!.scores.length < 3) return null; // Guardian Layer

    final scores = base.burnout!.scores;
    List<double> ekg = [];
    double totalVariance = 0;
    
    // EKG Variance math
    for (int i = 1; i < scores.length; i++) {
       final diff = (scores[i] - scores[i-1]).abs() * 100;
       ekg.add(diff);
       totalVariance += diff;
    }
    
    final avgVariance = ekg.isEmpty ? 0.0 : totalVariance / ekg.length;
    String vLabel = 'Anchored';
    if (avgVariance > 30) vLabel = 'Spike & Crash';
    else if (avgVariance > 15) vLabel = 'Variable';
    else if (avgVariance == 0) vLabel = 'Flawless';
    
    String label, diagnosis, rx;
    
    if (base.burnout!.trend < -15) {
       label = 'Running on Empty 🔴';
       diagnosis = 'You have been pushing yourself too hard lately, and your energy is catching up with you. Your 14-day streak is taking a clear dip.';
       rx = 'Try This: Cut your daily habit goals in half for 3 days. Rest is not failure — it is part of the system.';
    } else if (vLabel == 'Spike & Crash') {
       label = 'Roller Coaster Pattern ⚠️';
       diagnosis = 'Your days alternate between crushing it and barely showing up. That is a classic Spike & Crash pattern over the past two weeks.';
       rx = 'Try This: Aim for boring consistency over big effort. A 70% day every day beats a 100% day followed by a 30% day.';
    } else if (base.focus != null && base.focus!.topMoodEmoji == '😔') {
       label = 'Running on Willpower 🔋';
       diagnosis = 'You are forcing deep focus on the days you feel worst. That takes serious grit, but it is not sustainable long-term.';
       rx = 'Try This: On low-mood days, start with your easiest, most enjoyable habit first to give yourself a quick win before diving into hard work.';
    } else if (vLabel == 'Flawless' && base.burnout!.scores.last >= 0.99) {
       label = 'On Fire 🌟';
       diagnosis = 'You are absolutely nailing it. Your habits are consistent, your energy is stable, and your streaks are holding strong.';
       rx = 'Try This: You have mastered your current setup. Time to level up — add one new challenge habit to your routine.';
    } else {
       label = 'Steady & Solid 🟢';
       diagnosis = 'You are in a good rhythm right now. Your mood and habit completion are working together in a sustainable way.';
       rx = 'Try This: Keep your current pace. Avoid the temptation to add too much at once — boring consistency is winning right now.';
    }
    
    return _ClinicalAssessment(
       label: label, diagnosis: diagnosis, prescription: rx, volatilityLabel: vLabel, volatilityEkg: ekg
    );
  }

  static bool _scheduled(Habit h, DateTime date) {
    if (h.isEveryDay) return true;
    return h.selectedDays.contains(date.weekday % 7);
  }
}

// ─── Main View ────────────────────────────────────────────────────────────────
class BioRhythmView extends ConsumerWidget {
  const BioRhythmView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitProvider);
    final moods = ref.watch(dailyMoodsProvider);
    final result = _BioEngine.analyse(habits, moods);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BioHeader(),
          const SizedBox(height: 16),
          
          // 1. The Big Picture
          _ExecutiveDiagnosis(data: result.clinical),
          const SizedBox(height: 16),
          
          // 2. Momentum & Energy
          const _WillpowerForecastCard(),
          const SizedBox(height: 12),
          _BurnoutCard(data: result.burnout),
          const SizedBox(height: 12),
          
          // 3. Behavioral Psychology
          _VolatilityEkgCard(data: result.clinical),
          const SizedBox(height: 12),
          _MoodCorrelationCard(data: result.mood),
          const SizedBox(height: 12),
          
          // 4. Tactical Optimizers
          _PeakHourCard(data: result.peak),
          const SizedBox(height: 12),
          _WeekdayPowerhouseCard(data: result.dayOfWeek),
          const SizedBox(height: 12),
          _DeepWorkCard(data: result.focus),
          const SizedBox(height: 12),
          _DominoHabitCard(data: result.domino),
          
          const SizedBox(height: 120),
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _BioHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
              ).createShader(bounds),
              child: Text(
                'Bio-Rhythm',
                style: GoogleFonts.poppins(
                  fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFEC4899)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('DEEP', style: GoogleFonts.poppins(
                fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.2,
              )),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Insights computed from your real habit data',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}

// ─── Card Wrapper ─────────────────────────────────────────────────────────────
class _CardWrapper extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  const _CardWrapper({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : accentColor.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: isDark ? 0.08 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 17, color: accentColor),
                  ),
                  const SizedBox(width: 10),
                  Text(title, style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _NotEnoughData extends StatelessWidget {
  final String message;
  const _NotEnoughData({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(CupertinoIcons.lock_fill,
              size: 28, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card 1: Peak Hour ────────────────────────────────────────────────────────
class _PeakHourCard extends StatelessWidget {
  final _PeakHourResult? data;
  static const _blockLabels = ['12–4AM', '4–8AM', '8AM–12', '12–4PM', '4–8PM', '8PM–12'];
  static const _blockIcons  = ['🌙',     '🌅',    '☀️',      '🌤️',     '🌆',    '🌃'];

  const _PeakHourCard({required this.data});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6366F1);
    return _CardWrapper(
      title: 'Peak Performance Window',
      icon: CupertinoIcons.clock_fill,
      accentColor: accent,
      child: data == null
          ? const _NotEnoughData(message: 'Complete 10+ habits to unlock\nyour peak performance window')
          : _buildChart(context),
    );
  }

  Widget _buildChart(BuildContext context) {
    final d = data!;
    final maxCount = d.blockCounts.values.fold(0, (a, b) => a > b ? a : b);
    const accent = Color(0xFF6366F1);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(6, (i) {
            final count = d.blockCounts[i] ?? 0;
            final ratio = maxCount > 0 ? count / maxCount : 0.0;
            final isPeak = i == d.peakBlock;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    if (isPeak)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: accent, borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('PEAK', style: GoogleFonts.poppins(
                          fontSize: 7, fontWeight: FontWeight.w800, color: Colors.white,
                        )),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: 60 * ratio.clamp(0.05, 1.0),
                      decoration: BoxDecoration(
                        gradient: isPeak
                            ? const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                                begin: Alignment.bottomCenter, end: Alignment.topCenter)
                            : LinearGradient(
                                colors: [accent.withValues(alpha: 0.25), accent.withValues(alpha: 0.15)],
                                begin: Alignment.bottomCenter, end: Alignment.topCenter),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_blockIcons[i], style: const TextStyle(fontSize: 12)),
                    Text(_blockLabels[i], style: GoogleFonts.poppins(
                      fontSize: 7, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.sparkles, size: 16, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your habits peak in the ${_blockLabels[data!.peakBlock]} window. Schedule your hardest habits here.',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF6366F1), height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Card 2: Mood Correlation ─────────────────────────────────────────────────
class _MoodCorrelationCard extends StatelessWidget {
  final _MoodResult? data;
  const _MoodCorrelationCard({required this.data});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF10B981);
    return _CardWrapper(
      title: 'Mood × Habit Correlation',
      icon: CupertinoIcons.heart_fill,
      accentColor: accent,
      child: data == null
          ? const _NotEnoughData(message: 'Select your mood on the Home screen\nfor 7+ days to unlock this insight')
          : _buildChart(context),
    );
  }

  Widget _buildChart(BuildContext context) {
    final d = data!;
    final buckets = <_MoodBucket>[];
    if (d.posDays >= 3) buckets.add(_MoodBucket('Positive 😊', d.positiveAvg, const Color(0xFF10B981), d.posDays));
    if (d.neuDays >= 3) buckets.add(_MoodBucket('Neutral 😐', d.neutralAvg, const Color(0xFF6366F1), d.neuDays));
    if (d.negDays >= 3) buckets.add(_MoodBucket('Stressed 😔', d.negativeAvg, const Color(0xFFEF4444), d.negDays));

    // Sort descending
    buckets.sort((a, b) => b.avg.compareTo(a.avg));

    return Column(
      children: [
        Row(
          children: buckets.map((b) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _MoodBox(bucket: b),
            ),
          )).toList(),
        ),
        const SizedBox(height: 12),
        if (buckets.length >= 2) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.info_circle_fill, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'On ${buckets.first.label.split(' ').first.toLowerCase()} days, your habit completion is ${(buckets.first.avg * 100).toStringAsFixed(0)}%.',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF10B981), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('🧠', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hypothesis: Negative emotion often triggers Decision Fatigue, causing completion rates to plummet.',
                    style: GoogleFonts.poppins(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ]
      ],
    );
  }
}

class _MoodBucket {
  final String label;
  final double avg;
  final Color color;
  final int days;
  const _MoodBucket(this.label, this.avg, this.color, this.days);
}

class _MoodBox extends StatelessWidget {
  final _MoodBucket bucket;
  const _MoodBox({required this.bucket});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: bucket.color.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: bucket.color.withValues(alpha: 0.25), width: 1),
      ),
      child: Column(
        children: [
          Text('${(bucket.avg * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.poppins(
                fontSize: 22, fontWeight: FontWeight.w800, color: bucket.color,
              )),
          const SizedBox(height: 2),
          Text(bucket.label, style: GoogleFonts.poppins(
            fontSize: 9, fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ), textAlign: TextAlign.center),
          Text('${bucket.days} days', style: GoogleFonts.poppins(
            fontSize: 8, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          )),
        ],
      ),
    );
  }
}

// ─── Card 3: Domino Habit ─────────────────────────────────────────────────────
class _DominoHabitCard extends StatelessWidget {
  final _DominoResult? data;
  const _DominoHabitCard({required this.data});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFF59E0B);
    return _CardWrapper(
      title: 'Domino Habit',
      icon: CupertinoIcons.flame_fill,
      accentColor: accent,
      child: data == null
          ? const _NotEnoughData(message: 'Track 2+ habits for 30+ days\nto discover your Domino Habit')
          : _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final d = data!;
    final habitColor = Color(d.colorValue);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [habitColor.withValues(alpha: 0.15), habitColor.withValues(alpha: 0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: habitColor.withValues(alpha: 0.3), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: habitColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: habitColor.withValues(alpha: 0.4), width: 2),
            ),
            child: Center(
              child: Text(d.habitIcon ?? '🎯', style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.habitName, style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                )),
                const SizedBox(height: 2),
                Text(
                  'When done first, ${d.upliftPercent.toStringAsFixed(0)}% more habits completed',
                  style: GoogleFonts.poppins(
                    fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('🧠', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Hypothesis: This acts as an anchor, triggering sequential momentum.',
                          style: GoogleFonts.poppins(fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text('+${d.upliftPercent.toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w900, color: habitColor,
                  )),
              Text('uplift', style: GoogleFonts.poppins(
                fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              )),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Card 4: Burnout Trend ────────────────────────────────────────────────────
class _BurnoutCard extends StatelessWidget {
  final _BurnoutResult? data;
  const _BurnoutCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final accentColor = data?.trendColor ?? const Color(0xFF6366F1);
    return _CardWrapper(
      title: 'Burnout Trend (14 Days)',
      icon: CupertinoIcons.chart_bar_fill,
      accentColor: accentColor,
      child: data == null
          ? const _NotEnoughData(message: 'Track habits for 7+ days\nto see your burnout trend')
          : _buildChart(context),
    );
  }

  Widget _buildChart(BuildContext context) {
    final d = data!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spots = d.scores.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), (e.value * 100).clamp(0.0, 100.0)))
        .toList();

    return Column(
      children: [
        // Trend Badge
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: d.trendColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: d.trendColor.withValues(alpha: 0.3), width: 1),
              ),
              child: Text(d.trendLabel, style: GoogleFonts.poppins(
                fontSize: 12, fontWeight: FontWeight.w700, color: d.trendColor,
              )),
            ),
            const Spacer(),
            Text(
              '${d.trend >= 0 ? '+' : ''}${d.trend.toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w800, color: d.trendColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Sparkline
        SizedBox(
          height: 80,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (d.scores.length - 1).toDouble(),
              minY: 0,
              maxY: 100,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: d.trendColor,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        d.trendColor.withValues(alpha: isDark ? 0.3 : 0.2),
                        d.trendColor.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('14 days ago', style: GoogleFonts.poppins(
              fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            )),
            Text('Today', style: GoogleFonts.poppins(
              fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            )),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: d.trendColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.sparkles, size: 16, color: d.trendColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getInsightText(d.trend),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: d.trendColor,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getInsightText(double trend) {
    if (trend <= -15) {
      return "Your habit momentum has sharply dropped. Take it easy and prioritize your core routines to recover.";
    } else if (trend < 0) {
      return "You're seeing a slight dip in completion rates. Small, consistent efforts will help stabilize your rhythm.";
    } else if (trend > 15) {
      return "Great recovery! Your completion rates are bouncing back strongly. Keep fueling this positive momentum.";
    } else if (trend > 0) {
      return "Your momentum is steadily building. The current routine seems to be working well for you.";
    } else {
      return "Your behavioral momentum is highly stable. You have found a sustainable output pace.";
    }
  }
}


// ─── Card 5: Deep Work Predictor ──────────────────────────────────────────────
class _DeepWorkCard extends StatelessWidget {
  final _FocusMoodResult? data;
  const _DeepWorkCard({required this.data});

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF8B5CF6);
    return _CardWrapper(
      title: 'Deep Work Predictor',
      icon: CupertinoIcons.timer_fill,
      accentColor: accentColor,
      child: data == null
          ? const _NotEnoughData(message: 'Use the Focus Timer + Mood Tracker\nfor 7+ days to unlock this insight')
          : _buildChart(context),
    );
  }

  Widget _buildChart(BuildContext context) {
    final d = data!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    String description;
    if (d.topMoodEmoji == '😊') description = 'You focus longest on Positive days.';
    else if (d.topMoodEmoji == '😐') description = 'You focus longest on Neutral days.';
    else description = 'You use focus to push through Stressed days.';

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _FocusMoodBar(emoji: '😊', label: 'Positive', mins: d.posMinutes, isTop: d.topMoodEmoji == '😊')),
            const SizedBox(width: 8),
            Expanded(child: _FocusMoodBar(emoji: '😐', label: 'Neutral', mins: d.neuMinutes, isTop: d.topMoodEmoji == '😐')),
            const SizedBox(width: 8),
            Expanded(child: _FocusMoodBar(emoji: '😔', label: 'Stressed', mins: d.negMinutes, isTop: d.topMoodEmoji == '😔')),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.sparkles, size: 16, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  description,
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF8B5CF6), height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FocusMoodBar extends StatelessWidget {
  final String emoji;
  final String label;
  final double mins;
  final bool isTop;

  const _FocusMoodBar({required this.emoji, required this.label, required this.mins, required this.isTop});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isTop ? const Color(0xFF8B5CF6) : (isDark ? Colors.white30 : Colors.black26);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isTop ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isTop ? color.withValues(alpha: 0.3) : Colors.transparent),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            mins > 0 ? '${mins.round()}m' : '--',
            style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w800, color: color,
            ),
          ),
          Text(label, style: GoogleFonts.poppins(
            fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          )),
        ],
      ),
    );
  }
}

// ─── Card 7: Clinical Assessment ──────────────────────────────────────────────
class _ExecutiveDiagnosis extends StatelessWidget {
  final _ClinicalAssessment? data;
  const _ExecutiveDiagnosis({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            const Icon(CupertinoIcons.waveform, color: Colors.grey, size: 28),
            const SizedBox(height: 8),
            Text('Generating Baseline', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Focus on tracking basic completion for 7 days to establish your psychological profile.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final d = data!;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05))),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.doc_text_fill, size: 18),
                const SizedBox(width: 8),
                Text('YOUR HABIT SNAPSHOT', style: GoogleFonts.outfit(
                  fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                )),
              ],
            ),
          ),
          
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.label, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(d.diagnosis, style: GoogleFonts.poppins(fontSize: 13, height: 1.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
                const SizedBox(height: 16),
                
                // Prescription Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          d.prescription,
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card 8: Volatility EKG ───────────────────────────────────────────────────
class _VolatilityEkgCard extends StatelessWidget {
  final _ClinicalAssessment? data;
  const _VolatilityEkgCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _CardWrapper(
      title: 'Behavioral Volatility (EKG)',
      icon: CupertinoIcons.waveform_path_ecg,
      accentColor: const Color(0xFF14B8A6), // Teal medical color
      child: data == null || data!.volatilityEkg.isEmpty
          ? const _NotEnoughData(message: 'Gathering baseline for volatility analysis.')
          : _buildChart(context),
    );
  }

  Widget _buildChart(BuildContext context) {
    final d = data!;
    final spots = d.volatilityEkg.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.clamp(0.0, 100.0))).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(d.volatilityLabel.toUpperCase(), style: GoogleFonts.outfit(
                fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF14B8A6), letterSpacing: 1.0,
              )),
            ),
            const Spacer(),
            Text('Day-to-day variance', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              minX: 0,
              maxX: (spots.length - 1).toDouble() > 0 ? (spots.length - 1).toDouble() : 1.0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: false, // EKG lines are sharp, not curved
                  color: const Color(0xFF14B8A6),
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF14B8A6).withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF14B8A6).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(CupertinoIcons.sparkles, size: 16, color: Color(0xFF14B8A6)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getInsightText(d.volatilityLabel),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF14B8A6),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _getInsightText(String label) {
    switch (label) {
      case 'Spike & Crash':
        return "High variance. You alternate between highly productive days and total burnout. Try aiming for 70% effort every day rather than 100% occasionally.";
      case 'Variable':
        return "Moderate variance. Some days are much easier than others. Look for hidden triggers that might be draining your energy.";
      case 'Flawless':
        return "Zero variance detected. Your execution is machine-like. This is the optimal state for building compounding habits.";
      case 'Anchored':
      default:
        return "Stable variance. Your daily execution is highly predictable, which means your system and energy reserves are well balanced.";
    }
  }
}

// ─── Card 6: Weekday Powerhouse ───────────────────────────────────────────────
class _WeekdayPowerhouseCard extends StatelessWidget {
  final _DayOfWeekResult? data;
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  const _WeekdayPowerhouseCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _CardWrapper(
      title: 'Best & Worst Days',
      icon: CupertinoIcons.calendar_today,
      accentColor: const Color(0xFF3B82F6),
      child: data == null
          ? const _NotEnoughData(message: 'Build habits for 2+ weeks\nto see your weekly powerhouse days')
          : _buildChart(context),
    );
  }

  Widget _buildChart(BuildContext context) {
    final d = data!;
    return Column(
      children: [
        _buildDayRow(context, 'Powerhouse 🔥', d.bestDay, d.bestRate, const Color(0xFF10B981)),
        const SizedBox(height: 12),
        _buildDayRow(context, 'Kryptonite 📉', d.worstDay, d.worstRate, const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _buildDayRow(BuildContext context, String title, int dayIndex, double rate, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(title, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_days[dayIndex - 1], style: GoogleFonts.poppins(
                  fontSize: 14, 
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                )),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${(rate * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Willpower Forecast Card ──────────────────────────────────────────────────
class _WillpowerForecastCard extends ConsumerWidget {
  const _WillpowerForecastCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitProvider);
    const accent = Color(0xFF9D4EDD);

    if (habits.isEmpty) {
      return _CardWrapper(
        title: 'Willpower Forecast',
        icon: CupertinoIcons.waveform_path_ecg,
        accentColor: accent,
        child: const _NotEnoughData(message: 'Start tracking habits to unlock\nyour 7-day willpower forecast'),
      );
    }

    final forecast = PersonalityEngine.getWillpowerForecast(habits);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280);
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Theme.of(context).colorScheme.surface;

    double minY = forecast.next7Days.reduce((a, b) => a < b ? a : b);
    double maxY = forecast.next7Days.reduce((a, b) => a > b ? a : b);
    if ((maxY - minY) < 0.05) {
      minY = (minY - 0.2).clamp(0.0, 1.0);
      maxY = (maxY + 0.2).clamp(0.0, 1.0);
    } else {
      minY = (minY - 0.1).clamp(0.0, 1.0);
      maxY = (maxY + 0.1).clamp(0.0, 1.0);
    }
    final spots = List.generate(
      forecast.next7Days.length,
      (i) => FlSpot(i.toDouble(), forecast.next7Days[i]),
    );

    return _CardWrapper(
      title: 'Willpower Forecast',
      icon: CupertinoIcons.waveform_path_ecg,
      accentColor: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '7-day biorhythm prediction based on your history',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: labelColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 130,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                minX: 0,
                maxX: 6,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 3,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: labelColor.withValues(alpha: 0.12),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 26,
                      getTitlesWidget: (value, meta) {
                        final int idx = value.toInt();
                        if (idx < 0 || idx > 6) return const SizedBox.shrink();
                        final String label = idx == 0
                            ? 'Today'
                            : DateFormat('E')
                                .format(DateTime.now().add(Duration(days: idx)))
                                .substring(0, 1);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: idx == 0 ? FontWeight.w700 : FontWeight.w500,
                              color: idx == 0 ? accent : labelColor.withValues(alpha: 0.55),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: accent,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        if (index == 0) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: bgColor,
                            strokeWidth: 3,
                            strokeColor: accent,
                          );
                        }
                        return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.2),
                          accent.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(CupertinoIcons.sparkles, size: 16, color: Color(0xFF9D4EDD)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    forecast.insightMessage,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: accent,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
