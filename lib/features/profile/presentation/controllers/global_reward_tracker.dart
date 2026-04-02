import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:intl/intl.dart';

/// Simple pulse provider — fires `true` once when the daily reward cap (5/day)
/// is hit for the first time. Home screen listens and shows a single SnackBar,
/// then resets this back to `false` to avoid repeated popups.
final rewardCapNotifyProvider = StateProvider<bool>((ref) => false);

class RewardTrackerState {
  final Set<String> claimedRewards;
  /// Tracks how many DISTINCT habits have been rewarded per day.
  /// Format: {yyyy-MM-dd: count}
  final Map<String, int> dailyRewardGrants;
  /// Tracks the date on which the reward cap SnackBar was last shown,
  /// preventing duplicate notifications within the same day.
  final String? lastCapNotifiedDate;

  RewardTrackerState({
    required this.claimedRewards,
    required this.dailyRewardGrants,
    this.lastCapNotifiedDate,
  });

  RewardTrackerState copyWith({
    Set<String>? claimedRewards,
    Map<String, int>? dailyRewardGrants,
    String? lastCapNotifiedDate,
  }) {
    return RewardTrackerState(
      claimedRewards: claimedRewards ?? this.claimedRewards,
      dailyRewardGrants: dailyRewardGrants ?? this.dailyRewardGrants,
      lastCapNotifiedDate: lastCapNotifiedDate ?? this.lastCapNotifiedDate,
    );
  }
}

class GlobalRewardTrackerNotifier extends Notifier<RewardTrackerState> {
  static const String _claimedKey = 'globalClaimedRewards';
  static const String _grantsKey = 'dailyRewardGrants';
  static const String _capNotifKey = 'rewardCapNotifiedDate';

  /// Only the first 5 distinct habit completions per day generate coins.
  /// Habit creation is NEVER blocked — only rewards are capped.
  static const int maxRewardableHabitsPerDay = 5;

  @override
  RewardTrackerState build() {
    final box = HiveService.settingsBox;

    // ── Multi-Device Safe Merge (Local → Union Ready) ─────────────────────────
    // All local claims are loaded as a Set.
    // When a cloud backend is connected, call mergeRemoteClaims(remoteList)
    // immediately after loading to union both sets before any reward check.
    // Pattern: claimedRewards = localSet.union(remoteSet)  — NEVER overwrite.
    final List<dynamic>? rawList = box.get(_claimedKey) as List<dynamic>?;
    final Set<String> localRewards = rawList != null
        ? rawList.map((e) => e.toString()).toSet()
        : {};

    // ── Daily Reward Grants ───────────────────────────────────────────────────
    final Map<dynamic, dynamic>? rawGrants =
        box.get(_grantsKey) as Map<dynamic, dynamic>?;
    final Map<String, int> loadedGrants = rawGrants != null
        ? rawGrants.map((key, value) => MapEntry(key.toString(), value as int))
        : {};

    // ── Cap Notification Tracking ─────────────────────────────────────────────
    final String? lastCapDate = box.get(_capNotifKey) as String?;

    return RewardTrackerState(
      claimedRewards: localRewards,
      dailyRewardGrants: loadedGrants,
      lastCapNotifiedDate: lastCapDate,
    );
  }

  // ── Multi-device sync hook ────────────────────────────────────────────────
  /// Call this when remote reward data arrives (e.g. from Firestore).
  /// Merges via union — never overwrites local claims.
  void mergeRemoteClaims(List<String> remoteIds) {
    final merged = Set<String>.from(state.claimedRewards)..addAll(remoteIds);
    if (merged.length == state.claimedRewards.length) return; // nothing new
    state = state.copyWith(claimedRewards: merged);
    HiveService.settingsBox.put(_claimedKey, merged.toList());
  }

  // ── Stable Habit Identity ─────────────────────────────────────────────────
  //
  // Strong normalization: lowercase + strip ALL non-alphanumeric characters
  // (spaces, emojis, punctuation, symbols).
  //
  //  "Morning Run"  → "morningrun"
  //  "morning run!" → "morningrun"
  //  "🏃 Morning Run" → "morningrun"
  //  "Morning-Run " → "morningrun"
  //
  // This means name-variation tricks ("Morning Run" → "Morning-Run!") produce
  // identical keys and thus identical rewardIds — exploit is structurally closed.
  static String _normalizeName(String name) {
    return name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]'), ''); // strip EVERYTHING non-alphanumeric
  }

  static String stableHabitKey(String habitName, DateTime startDate) {
    final normalizedName = _normalizeName(habitName);
    final dateStr = DateFormat('yyyy-MM-dd').format(startDate);
    return 'sk_${normalizedName}_$dateStr';
  }

  // ── Reward Claim API ──────────────────────────────────────────────────────

  /// Returns true if this habit has already claimed its reward for [dateStr].
  /// Uses stable identity — survives deletion, recreation, and name variations.
  bool hasClaimed(String habitName, DateTime habitStartDate, String dateStr) {
    final stableKey = stableHabitKey(habitName, habitStartDate);
    final rewardId = '${stableKey}_$dateStr';
    return state.claimedRewards.contains(rewardId);
  }

  /// Locks in the reward permanently for this habit+date combination.
  /// Also increments today's per-day grant counter and persists both to Hive.
  void registerClaim(String habitName, DateTime habitStartDate, String dateStr) {
    final stableKey = stableHabitKey(habitName, habitStartDate);
    final rewardId = '${stableKey}_$dateStr';

    final updatedSet = Set<String>.from(state.claimedRewards)..add(rewardId);
    final updatedGrants = Map<String, int>.from(state.dailyRewardGrants);
    updatedGrants[dateStr] = (updatedGrants[dateStr] ?? 0) + 1;

    state = state.copyWith(
      claimedRewards: updatedSet,
      dailyRewardGrants: updatedGrants,
    );

    HiveService.settingsBox.put(_claimedKey, updatedSet.toList());
    HiveService.settingsBox.put(_grantsKey, updatedGrants);
  }

  /// Returns true if fewer than [maxRewardableHabitsPerDay] distinct habits
  /// have already been rewarded on [dateStr].
  bool canGrantRewardToday(String dateStr) {
    final count = state.dailyRewardGrants[dateStr] ?? 0;
    return count < maxRewardableHabitsPerDay;
  }

  /// Marks that the reward-cap SnackBar was shown for [dateStr],
  /// preventing duplicate notifications within the same calendar day.
  void markCapNotified(String dateStr) {
    state = state.copyWith(lastCapNotifiedDate: dateStr);
    HiveService.settingsBox.put(_capNotifKey, dateStr);
  }

  /// Returns true if the cap notification has NOT yet been shown today.
  bool shouldNotifyCapToday(String dateStr) {
    return state.lastCapNotifiedDate != dateStr;
  }
}

final rewardTrackerProvider =
    NotifierProvider<GlobalRewardTrackerNotifier, RewardTrackerState>(() {
  return GlobalRewardTrackerNotifier();
});
