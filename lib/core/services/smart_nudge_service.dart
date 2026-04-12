import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/core/services/notification_service.dart';
import 'package:habit_tracker_ios/core/services/personality_engine.dart';

/// ════════════════════════════════════════════════════════════════
///  SmartNudgeService — Final Production Version
/// ════════════════════════════════════════════════════════════════
///
/// Architecture: Pre-Schedule + Single Nudge Policy
///
/// - On EVERY call to [scheduleForToday]:
///   1. Performs a new-day reset if the calendar date changed.
///   2. Cancels ALL previously scheduled smart nudge slots.
///   3. Validates all gate conditions (permissions, caps, etc.).
///   4. Evaluates habits in priority order.
///   5. Picks the SINGLE highest-priority matching habit/slot.
///   6. Schedules it via zonedSchedule → fires even when app is closed.
///
/// This self-correcting pattern means stale nudges are never shown:
/// even if a notification fires after a habit is completed, the next
/// app-open will have already cancelled & rescoded everything fresh.
///
/// Anti-spam:
/// - Max 2 nudges per calendar day.
/// - Min 2-hour gap between any two nudges.
/// - Per-habit dedup: each habit triggers at most 1 nudge per day.
///
/// Call [scheduleForToday] from:
/// - App open / resume (main.dart WidgetsBindingObserver)
/// - After any habit add / edit / delete
/// - After any habit progress update (today only)
class SmartNudgeService {
  SmartNudgeService._();

  // ── SharedPreferences keys ──────────────────────────────────────
  static const _kNotifsEnabled = 'notifications_enabled';
  static const _kNudgesEnabled = 'smart_nudges_enabled';
  static const _kLastKnownDate = 'sn_last_known_date'; // tracks date for new-day reset
  static const _kDailyCount = 'sn_daily_count_'; // + dateKey
  static const _kLastNudgeTs = 'sn_last_nudge_ts';
  static const _kNudgedHabits = 'sn_nudged_habits_'; // + dateKey → "id1,id2"

  // ── Notification IDs — stable 0x20000 range ─────────────────────
  // Only ONE slot is ever scheduled at a time; we use a fixed set of IDs.
  static const _kSlotId = 0x20010; // single active nudge slot

  // ── Scheduling Metadata Keys ───────────────────────────────────
  static const _kLastScheduledTime = 'sn_last_sched_time';
  static const _kLastScheduledType = 'sn_last_sched_type';
  static const _kLastScheduledHabit = 'sn_last_sched_habit';

  // ── Tuning ─────────────────────────────────────────────────────
  static const _maxPerDay = 2;
  static const _minGapMin = 120; // 2 hours
  static const _streakMin = 3;
  static const _nearMinTotal = 3; // require ≥ 3 total today
  static const _streakAfterHour = 18; // 6 PM

  // ── Message pools (deterministic selection via habit.id hash) ───
  static const _streakMsgs = [
    ('🔥 Streak at risk!', "Don't break your {n}-day streak on {name}."),
    ('🔥 Keep it going!', '{name} — {n} days strong. Don\'t stop now!'),
    ('🔥 Protect your streak!', 'Your {n}-day {name} streak is on the line.'),
  ];
  static const _nearMsgs = [
    ('🎯 Almost there!', 'Just {n} habit{s} left for a perfect day.'),
    ('✅ Finish strong!', 'Only {n} more habit{s} — you\'re almost done.'),
    ('🏁 So close!', 'Complete {n} habit{s} and own today fully.'),
  ];
  static const _timeMsgs = [
    ('⏰ Time for {name}', 'Your usual {name} time — don\'t skip it!'),
    ('⏰ {name} is calling', 'You usually do {name} around now. Let\'s go!'),
    ('⏰ Quick reminder', 'It\'s {name} time — stay consistent!'),
  ];
  static const _eodMsgs = [
    ('🌙 Wrap up your day', "You're close — {name} is still waiting."),
    ('🌙 Last chance today', "Finish {name} before the day ends."),
    ('🌙 Almost done!', "Just {name} left. End the day on a high note."),
  ];

  // ════════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ════════════════════════════════════════════════════════════════

  /// Primary entry point. Call on every app open, resume, and habit change.
  static Future<void> scheduleForToday(List<Habit> habits) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final today = _dateKey(now);

      // ── Step 1: New-day reset ────────────────────────────────────
      await _handleNewDay(prefs, today);

      // ── Step 2: Cancel ALL stale smart nudge slots ───────────────
      await _cancelAll();

      // ── Step 3: Gate checks ──────────────────────────────────────
      if (!(prefs.getBool(_kNotifsEnabled) ?? false)) return;
      if (!(prefs.getBool(_kNudgesEnabled) ?? true)) return;

      final sentToday = prefs.getInt('$_kDailyCount$today') ?? 0;
      if (sentToday >= _maxPerDay) return;

      final lastTs = prefs.getInt(_kLastNudgeTs) ?? 0;
      final lastDt = DateTime.fromMillisecondsSinceEpoch(lastTs);
      // If last nudge was within 2 hours, skip scheduling (budget would be
      // absorbed too quickly). Allow if lastTs=0 (never fired).
      if (lastTs != 0 && now.difference(lastDt).inMinutes < _minGapMin) return;

      // ── Step 4: Filter habits → scheduled today, not yet completed ─
      final nudgedIds = _nudgedSet(prefs, today);
      final todayAll = _scheduledToday(habits, now);
      if (todayAll.isEmpty) return;

      final incomplete = todayAll
          .where((h) => !_isCompleted(h, now) && !nudgedIds.contains(h.id))
          .toList();
      if (incomplete.isEmpty) return;

      // ── Step 5: Pick the SINGLE best nudge slot ─────────────────
      final chronotype = PersonalityEngine.getChronotype(habits);
      final slot = _pickBestSlot(incomplete, todayAll, now, prefs, today, chronotype);
      if (slot == null) return;

      // Skip if fire time already 5+ min in the past
      if (slot.fireAt.isBefore(now.subtract(const Duration(minutes: 5)))) {
        return;
      }

      // If fire time is within the next 90 seconds, fire immediately
      if (slot.fireAt.isBefore(now.add(const Duration(seconds: 90)))) {
        await NotificationService.showImmediate(
            id: slot.id, title: slot.title, body: slot.body);
        await _record(prefs, today, slot.habitId);
        debugPrint('🧠 [SmartNudge] Fired immediately: "${slot.title}"');
        return;
      }

      // Schedule via zonedSchedule (works when app is closed)
      final fireAtTz = tz.TZDateTime(
        tz.local,
        slot.fireAt.year,
        slot.fireAt.month,
        slot.fireAt.day,
        slot.fireAt.hour,
        slot.fireAt.minute,
      );
      await NotificationService.scheduleSmartNudge(
        id: slot.id,
        title: slot.title,
        body: slot.body,
        scheduledTime: fireAtTz,
        prefs: prefs,
      );

      // Save metadata for debugging and tracking
      await prefs.setInt(_kLastScheduledTime, slot.fireAt.millisecondsSinceEpoch);
      await prefs.setString(_kLastScheduledType, slot.type);
      await prefs.setString(_kLastScheduledHabit, slot.habitId);

      // Record intent (not the actual send — that happens at fire time)
      // We do NOT increment _kDailyCount here; we record it when the user
      // opens the app next time and the slot has fired.
      debugPrint(
          '🧠 [SmartNudge] Scheduled [${slot.type}] "${slot.title}" at ${slot.fireAt}');
    } catch (e, st) {
      debugPrint('🧠 [SmartNudge] Error: $e\n$st');
    }
  }

  /// Call when a nudge notification is tapped or when a notification fires.
  /// Records the send in the daily count so spam caps are respected.
  static Future<void> recordFired(String habitId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    await _record(prefs, today, habitId);
  }

  // ════════════════════════════════════════════════════════════════
  //  SLOT SELECTION — picks highest-priority single slot
  // ════════════════════════════════════════════════════════════════

  static _NudgeSlot? _pickBestSlot(
    List<Habit> incomplete,
    List<Habit> todayAll,
    DateTime now,
    SharedPreferences prefs,
    String today,
    Chronotype chronotype,
  ) {
    // ── Dynamic Chronotype Hour Configuration ──
    int streakHour = _streakAfterHour; // Default 18
    int nearHour = 17;                 // Default 17
    int eodHour = 21;                  // Default 21

    if (chronotype == Chronotype.lion) {
      nearHour = 14; // 2 PM
      eodHour = 18;  // 6 PM
    } else if (chronotype == Chronotype.wolf) {
      streakHour = 21; // 9 PM
      nearHour = 20;   // 8 PM
      eodHour = 23;    // 11 PM
    }

    // ── Priority 1: Streak Risk — schedule for [streakHour] or as soon as possible
    final streakHabit = _bestByStreak(incomplete);
    if (streakHabit != null) {
      final fireAt = now.hour >= streakHour
          ? now.add(const Duration(minutes: 3)) // past threshold → fire soon
          : _todayAt(now, streakHour, 0); // future → schedule for threshold
      final n = _streakLen(streakHabit);
      final m = _msg(_streakMsgs, streakHabit.id);
      return _NudgeSlot(
        id: _kSlotId,
        type: 'streak_risk',
        habitId: streakHabit.id,
        fireAt: fireAt,
        title: m.title,
        body: m.body
            .replaceAll('{name}', streakHabit.name)
            .replaceAll('{n}', '$n'),
      );
    }

    // ── Priority 2: Near Completion — only when total ≥ 3
    if (todayAll.length >= _nearMinTotal && incomplete.length <= 2) {
      final n = incomplete.length;
      final m = _msg(_nearMsgs, incomplete.first.id);
      final fireAt = _todayAt(now, nearHour, 0); 
      if (fireAt.isAfter(now)) {
        return _NudgeSlot(
          id: _kSlotId,
          type: 'near_completion',
          habitId: incomplete.first.id,
          fireAt: fireAt,
          title: m.title,
          body: m.body
              .replaceAll('{n}', '$n')
              .replaceAll('{s}', n == 1 ? '' : 's'),
        );
      }
    }

    // ── Priority 3: Time-Based — explicit times NEVER shift
    for (final h in incomplete) {
      if (h.reminderHour == null) continue;
      final reminderAt =
          _todayAt(now, h.reminderHour!, h.reminderMinute ?? 0);
      final nudgeAt = reminderAt.add(const Duration(minutes: 10));
      if (nudgeAt.isAfter(now)) {
        final m = _msg(_timeMsgs, h.id);
        return _NudgeSlot(
          id: _kSlotId,
          type: 'time_based',
          habitId: h.id,
          fireAt: nudgeAt,
          title: m.title.replaceAll('{name}', h.name),
          body: m.body.replaceAll('{name}', h.name),
        );
      }
    }

    // ── Priority 4: End-of-Day — dynamic [eodHour], at most once per day
    final eodKey = 'sn_eod_$today';
    final eodFired = prefs.getBool(eodKey) ?? false;
    if (!eodFired) {
      final fireAt = _todayAt(now, eodHour, 0);
      if (fireAt.isAfter(now)) {
        final h = incomplete.first;
        final m = _msg(_eodMsgs, h.id);
        return _NudgeSlot(
          id: _kSlotId,
          type: 'end_of_day',
          habitId: h.id,
          fireAt: fireAt,
          title: m.title,
          body: m.body.replaceAll('{name}', h.name),
        );
      }
    }

    return null;
  }

  // ════════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════════

  /// Resets daily nudge state when calendar date rolls over.
  static Future<void> _handleNewDay(
      SharedPreferences prefs, String today) async {
    final lastKnown = prefs.getString(_kLastKnownDate) ?? '';
    if (lastKnown != today) {
      // New day — wipe yesterday's per-habit records (old keys are auto-ignored)
      await prefs.setString(_kLastKnownDate, today);
      // Reset count and last-nudge for the new day
      await prefs.setInt('$_kDailyCount$today', 0);
      await prefs.remove(_kLastNudgeTs);
      debugPrint('🧠 [SmartNudge] New day — state reset.');
    }
  }

  static Future<void> _cancelAll() async {
    await NotificationService.cancel(_kSlotId);
  }

  static List<Habit> _scheduledToday(List<Habit> habits, DateTime now) {
    final nowNormalized = DateTime(now.year, now.month, now.day);
    final appDay = now.weekday % 7; // Sunday=0, Saturday=6
    return habits.where((h) {
      if (nowNormalized.isBefore(h.startDate)) return false;
      return h.isEveryDay || h.selectedDays.contains(appDay);
    }).toList();
  }

  /// Completion uses normalised progress (supports measurable habits).
  static bool _isCompleted(Habit h, DateTime now) {
    final progress = h.dailyProgress[_dateKey(now)] ?? 0;
    if (h.isQuitHabit) return progress == 0;
    return progress >= h.goalValue;
  }

  static Set<String> _nudgedSet(SharedPreferences prefs, String today) {
    final raw = prefs.getString('$_kNudgedHabits$today') ?? '';
    return raw.isEmpty ? {} : raw.split(',').toSet();
  }

  /// Picks the incomplete habit with the highest streak (≥ threshold).
  /// Tiebreak: earliest reminder time (deterministic).
  static Habit? _bestByStreak(List<Habit> incomplete) {
    Habit? best;
    int bestLen = 0;
    for (final h in incomplete) {
      final len = _streakLen(h);
      if (len < _streakMin) continue;
      if (best == null ||
          len > bestLen ||
          (len == bestLen && _rMin(h) < _rMin(best!))) {
        best = h;
        bestLen = len;
      }
    }
    return best;
  }

  /// Counts consecutive completed days ending yesterday.
  static int _streakLen(Habit h) {
    final today = DateTime.now();
    int streak = 0;
    for (int i = 1; i <= 90; i++) {
      final day = today.subtract(Duration(days: i));
      if (day.isBefore(h.startDate)) break;
      
      final appDay = day.weekday % 7;
      if (!h.isEveryDay && !h.selectedDays.contains(appDay)) continue;
      final key = _dateKey(day);
      final progress = h.dailyProgress[key] ?? 0;
      final done = h.isQuitHabit ? progress == 0 : progress >= h.goalValue;
      if (done) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Reminder time in minutes since midnight (9999 if none set).
  static int _rMin(Habit h) =>
      h.reminderHour == null ? 9999 : h.reminderHour! * 60 + (h.reminderMinute ?? 0);

  static DateTime _todayAt(DateTime now, int h, int m) =>
      DateTime(now.year, now.month, now.day, h, m);

  static String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Deterministically pick a message variant using the habit ID's hash.
  static ({String title, String body}) _msg(
      List<(String, String)> pool, String seed) {
    final idx = seed.hashCode.abs() % pool.length;
    final (t, b) = pool[idx];
    return (title: t, body: b);
  }

  static Future<void> _record(
      SharedPreferences prefs, String today, String habitId) async {
    final count = (prefs.getInt('$_kDailyCount$today') ?? 0) + 1;
    await prefs.setInt('$_kDailyCount$today', count);
    await prefs.setInt(_kLastNudgeTs, DateTime.now().millisecondsSinceEpoch);
    if (habitId.isNotEmpty) {
      final raw = prefs.getString('$_kNudgedHabits$today') ?? '';
      final updated = raw.isEmpty ? habitId : '$raw,$habitId';
      await prefs.setString('$_kNudgedHabits$today', updated);
    }
  }
}

class _NudgeSlot {
  final int id;
  final String type;
  final String habitId;
  final DateTime fireAt;
  final String title;
  final String body;
  const _NudgeSlot({
    required this.id,
    required this.type,
    required this.habitId,
    required this.fireAt,
    required this.title,
    required this.body,
  });
}
