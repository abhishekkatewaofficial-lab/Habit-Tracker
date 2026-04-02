import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_controller.dart';
import 'package:habit_tracker_ios/features/profile/presentation/controllers/coin_controller.dart';

/// ────────────────────────────────────────────────────────────────────────────
/// DEBUG-ONLY: Test data generator for verifying the goalSnapshot system.
///
/// Key design:
/// • Uses [HabitNotifier.saveHabitDirectly] to preserve the backdated
///   startDateString — bypassing the addHabit() lock that always stamps today.
/// • All habits are tagged "[TEST]" and can be bulk-deleted.
/// • Hard-gated by [kDebugMode] — zero impact on release.
/// ────────────────────────────────────────────────────────────────────────────
class DebugTestDataService {
  DebugTestDataService._();

  static final _rng = Random(42); // deterministic seed for reproducibility

  static const _testHabits = [
    ('🏃', 'Running',       'km',    2),
    ('💧', 'Hydration',     'cups',  8),
    ('📚', 'Reading',       'pages', 20),
    ('🧘', 'Meditation',    'mins',  15),
    ('💪', 'Push-ups',      'reps',  30),
    ('🚶', 'Walking',       'steps', 5000),
    ('🛌', 'Sleep',         'hours', 8),
    ('🥗', 'Healthy meals', 'meals', 3),
    ('✍️', 'Journaling',   'pages', 1),
    ('🎸', 'Guitar',        'mins',  20),
  ];

  static final _colors = [
    0xFF4F46E5, 0xFF0EA5E9, 0xFF10B981, 0xFFF59E0B,
    0xFFEF4444, 0xFF8B5CF6, 0xFFF43F5E, 0xFF14B8A6,
    0xFF6366F1, 0xFF84CC16,
  ];

  /// Creates 10 test habits with 30 days of mixed progress + goalSnapshot data.
  ///
  /// Uses [saveHabitDirectly] so the backdated [startDateString] is NOT
  /// overwritten by the normal [addHabit] lock-to-today guard.
  static Future<void> generateAllTestData(WidgetRef ref) async {
    assert(kDebugMode, 'generateAllTestData must only run in debug mode');

    final today = DateTime.now();
    final notifier = ref.read(habitProvider.notifier);

    debugPrint('🧪 [DebugTest] Generating ${_testHabits.length} habits with 30d data…');

    for (int hi = 0; hi < _testHabits.length; hi++) {
      final (icon, name, unit, goalValue) = _testHabits[hi];
      final id = const Uuid().v4();

      // ── Start date = 31 days ago so every of the last 30 days qualifies ──
      final startDate = today.subtract(const Duration(days: 31));
      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);

      // ── Build progress + snapshot maps for the last 30 days ──
      final Map<String, int> dailyProgress = {};
      final Map<String, int> goalSnapshots = {};

      for (int day = 30; day >= 0; day--) {
        final date = today.subtract(Duration(days: day));
        final dateStr = DateFormat('yyyy-MM-dd').format(date);

        // Mixed pattern: ~55% fully done, ~25% partial, ~20% missed
        final roll = _rng.nextDouble();
        int progress;
        if (goalValue <= 1) {
          // Binary habit (e.g. goalValue=1): no room for partial — just done or missed
          progress = roll < 0.60 ? goalValue : 0;
        } else if (roll < 0.55) {
          progress = goalValue;            // ✅ fully completed
        } else if (roll < 0.80) {
          // 30%–90% of goal, never exactly the goal
          final partial = (_rng.nextDouble() * 0.60 * goalValue + 0.30 * goalValue).round();
          progress = partial.clamp(1, goalValue - 1); // safe: goalValue >= 2 here
        } else {
          progress = 0;                    // ❌ missed
        }

        if (progress > 0) {
          dailyProgress[dateStr] = progress;
          // ✅ Critical: snapshot records the ACTIVE goal at each day
          goalSnapshots[dateStr] = goalValue;
        }
      }

      final habit = Habit(
        id: id,
        name: '[TEST] $name',
        icon: icon,
        colorValue: _colors[hi % _colors.length],
        isQuitHabit: false,
        goalValue: goalValue,
        goalUnit: unit,
        isEveryDay: true,
        selectedDays: const [],
        reminderEnabled: false,
        // ── createdAt also backdated so any createdAt-based guard passes ──
        createdAt: startDate.millisecondsSinceEpoch,
        // ── startDateString is the key — saveHabitDirectly preserves this ──
        startDateString: startDateStr,
        dailyProgress: dailyProgress,
        goalSnapshots: goalSnapshots,
      );

      // ✅ saveHabitDirectly preserves startDateString (addHabit would clobber it)
      await notifier.saveHabitDirectly(habit);

      debugPrint(
        '🧪 [DebugTest] ✓ [TEST] $name | goal=$goalValue $unit | '
        'startDate=$startDateStr | '
        '${dailyProgress.length} progress days | '
        '${goalSnapshots.length} snapshots',
      );
    }

    debugPrint('🧪 [DebugTest] ✅ Done — all test habits have backdated start dates');
  }

  /// Adds [amount] coins instantly for testing streak protection.
  static void addCoins(WidgetRef ref, int amount) {
    assert(kDebugMode);
    ref.read(coinProvider.notifier).addCoins(amount);
    debugPrint('🧪 [DebugTest] 💰 Added $amount coins');
  }

  /// Prints a per-habit snapshot integrity report to the debug console.
  static void verifySnapshots(WidgetRef ref) {
    assert(kDebugMode);
    final habits = ref.read(habitProvider);

    debugPrint('🧪 [DebugTest] ──── Snapshot Verification Report ────');
    for (final h in habits) {
      final snapshotDays = h.goalSnapshots.length;
      final progressDays = h.dailyProgress.length;
      int missingSnapshots = 0;

      for (final entry in h.dailyProgress.entries) {
        if (!h.goalSnapshots.containsKey(entry.key)) {
          missingSnapshots++;
        }
      }

      final status = missingSnapshots == 0 ? '✅' : '⚠️ ';
      debugPrint(
        '  $status [${h.name}] '
        'currentGoal=${h.goalValue} | '
        'startDate=${h.startDateString ?? 'null'} | '
        'progressDays=$progressDays | '
        'snapshotDays=$snapshotDays | '
        'missingSnapshots=$missingSnapshots',
      );

      if (missingSnapshots > 0) {
        debugPrint(
          '     ↳ ${missingSnapshots} days fall back to currentGoal=${h.goalValue}'
          ' — snapshots NOT protecting those days',
        );
      }
    }
    debugPrint('🧪 [DebugTest] ──── End Snapshot Report ────');
  }

  /// Deletes all habits whose name starts with '[TEST]'.
  static Future<void> clearTestData(WidgetRef ref) async {
    assert(kDebugMode);
    final habits = ref.read(habitProvider);
    final notifier = ref.read(habitProvider.notifier);
    final testHabits = habits.where((h) => h.name.startsWith('[TEST]')).toList();
    for (final h in testHabits) {
      notifier.deleteHabit(h.id);
    }
    debugPrint('🧪 [DebugTest] 🗑 Deleted ${testHabits.length} test habits');
  }
}
