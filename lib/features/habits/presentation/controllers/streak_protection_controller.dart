import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';

class StreakProtectionNotifier extends Notifier<Set<String>> {
  static const String _storageKey = 'streakProtected';

  /// Cost in coins to restore a broken streak for one habit for one day.
  static const int protectionCost = 50;

  @override
  Set<String> build() {
    final List<dynamic>? raw =
        HiveService.settingsBox.get(_storageKey) as List<dynamic>?;
    return raw != null ? raw.map((e) => e.toString()).toSet() : {};
  }

  /// Returns true if this habit's streak was already protected for [dateStr].
  bool isProtected(String habitId, String dateStr) =>
      state.contains('${habitId}_$dateStr');

  /// Persists streak protection for [habitId] on [dateStr].
  /// Idempotent — safe to call multiple times.
  void protect(String habitId, String dateStr) {
    final key = '${habitId}_$dateStr';
    if (state.contains(key)) return;
    final updated = Set<String>.from(state)..add(key);
    state = updated;
    HiveService.settingsBox.put(_storageKey, updated.toList());
  }

  // Removed weekly limits to support unlimited protections (coin-based only)
}

final streakProtectionProvider =
    NotifierProvider<StreakProtectionNotifier, Set<String>>(() {
  return StreakProtectionNotifier();
});

/// Persistent storage — tracks reminder state for today.
/// Supports firing up to 3 times per day, spaced 4 hours apart.
class StreakReminderNotifier extends Notifier<Map<String, dynamic>> {
  static const String _storageKey = 'streakReminderStateV2';

  @override
  Map<String, dynamic> build() {
    final raw = HiveService.settingsBox.get(_storageKey);
    return raw != null
        ? Map<String, dynamic>.from(raw as Map)
        : {
            'date': '',
            'showCount': 0,
            'lastShownAt': 0,
            'permanentlyDismissed': false,
          };
  }

  bool shouldShowReminder() {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final stateDate = state['date'] as String? ?? '';
    final showCount = state['showCount'] as int? ?? 0;
    final lastShownAt = state['lastShownAt'] as int? ?? 0;
    final dismissed = state['permanentlyDismissed'] as bool? ?? false;

    // Reset state for a new day
    if (stateDate != todayStr) {
      return true;
    }

    if (dismissed) return false;
    if (showCount >= 3) return false;

    final lastShownTime = DateTime.fromMillisecondsSinceEpoch(lastShownAt);
    if (now.difference(lastShownTime).inHours < 4) {
      return false; // must wait 4 hours between reminders
    }

    return true;
  }

  void markShown() {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final stateDate = state['date'] as String? ?? '';
    int showCount = state['showCount'] as int? ?? 0;

    if (stateDate != todayStr) {
      showCount = 0;
    }

    final newState = {
      'date': todayStr,
      'showCount': showCount + 1,
      'lastShownAt': now.millisecondsSinceEpoch,
      'permanentlyDismissed': false,
    };
    state = newState;
    HiveService.settingsBox.put(_storageKey, newState);
  }

  void dismissPermanently() {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final newState = {
      'date': todayStr,
      'showCount': 3, // max out
      'lastShownAt': now.millisecondsSinceEpoch,
      'permanentlyDismissed': true,
    };
    state = newState;
    HiveService.settingsBox.put(_storageKey, newState);
  }
}

final streakReminderStateProvider =
    NotifierProvider<StreakReminderNotifier, Map<String, dynamic>>(() {
  return StreakReminderNotifier();
});

/// In-memory only — holds the habit that the user dismissed the protection
/// modal for ("Let it break"). Drives the soft reminder banner on home screen.
/// Clears when user taps the banner or when the app restarts.
final streakReminderProvider = StateProvider<Habit?>((_) => null);
