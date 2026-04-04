import 'package:equatable/equatable.dart';

class Habit extends Equatable {
  final String id;
  final String name;
  final String? icon;
  final int colorValue;
  final bool isQuitHabit;
  final int goalValue;
  final String goalUnit;
  final bool isEveryDay;
  final List<int> selectedDays; // 0-6 (Sun-Sat)
  final bool reminderEnabled;
  final int? reminderHour;   // null = no time selected
  final int? reminderMinute;
  final int createdAt;
  final String? startDateString;
  final int sortOrder;
  final Map<String, int> dailyProgress; // Format: {yyyy-mm-dd: current_progress}
  
  /// Stores the exact time when the goal was reached for a specific date.
  /// Format: {yyyy-mm-dd: DateTime}
  final Map<String, DateTime> completionTimestamps;

  /// Stores the goal value that was active on each day progress was recorded.
  /// This makes every day self-contained so a future goal edit never corrupts
  /// historical completion, streaks, or report percentages.
  /// Format: {yyyy-mm-dd: goalValue_at_that_time}
  final Map<String, int> goalSnapshots;

  @Deprecated('Anti-farming rules strictly use GlobalRewardTracker natively now. Maintained for reverse-JSON compatibility only.')
  final Map<String, bool> rewardsClaimed; // Format: {yyyy-mm-dd: reward_given}

  /// Returns the goal value that was active on [dateStr].
  /// Falls back to the current [goalValue] for older entries that predate
  /// the snapshot system (backward compatible — no crashes, no retroactive changes).
  int goalFor(String dateStr) => goalSnapshots[dateStr] ?? goalValue;

  /// Extremely safe fallback resolver mapping `startDateString` (or `createdAt`) 
  /// precisely to `00:00:00` for perfectly accurate date difference comparisons.
  DateTime get startDate {
    if (startDateString != null) {
      final parts = startDateString!.split('-');
      if (parts.length == 3) {
        return DateTime(int.tryParse(parts[0]) ?? 2000, int.tryParse(parts[1]) ?? 1, int.tryParse(parts[2]) ?? 1);
      }
    }
    final d = DateTime.fromMillisecondsSinceEpoch(createdAt);
    return DateTime(d.year, d.month, d.day);
  }

  const Habit({
    required this.id,
    required this.name,
    this.icon,
    required this.colorValue,
    required this.isQuitHabit,
    required this.goalValue,
    required this.goalUnit,
    required this.isEveryDay,
    this.selectedDays = const [],
    required this.reminderEnabled,
    this.reminderHour,
    this.reminderMinute,
    required this.createdAt,
    this.startDateString,
    this.sortOrder = 0,
    this.dailyProgress = const {},
    this.completionTimestamps = const {},
    this.goalSnapshots = const {},
    this.rewardsClaimed = const {},
  });

  factory Habit.fromJson(Map<dynamic, dynamic> json) {
    // Migration logic: if old completedDates exists, convert to dailyProgress with full goalValue
    Map<String, int> progress = {};
    if (json['dailyProgress'] != null) {
      progress = Map<String, int>.from(json['dailyProgress'] as Map);
    } else if (json['completedDates'] != null) {
      final oldDates = List<String>.from(json['completedDates'] as List);
      final goalValue = json['goalValue'] as int;
      for (var date in oldDates) {
        progress[date] = goalValue;
      }
    }

    String? parsedStartDateString = json['startDateString'] as String?;
    if (parsedStartDateString == null) {
      final startMs = (json['startDate'] as int?) ?? (json['createdAt'] as int?);
      if (startMs != null) {
        final d = DateTime.fromMillisecondsSinceEpoch(startMs);
        parsedStartDateString = "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      }
    }

    Map<String, bool> rewards = {};
    if (json['rewardsClaimed'] != null) {
      rewards = Map<String, bool>.from(json['rewardsClaimed'] as Map);
    }

    // Backward compatible: default to empty map for entries that predate snapshots
    Map<String, int> snapshots = {};
    if (json['goalSnapshots'] != null) {
      snapshots = Map<String, int>.from(json['goalSnapshots'] as Map);
    }
    
    Map<String, DateTime> timestamps = {};
    if (json['completionTimestamps'] != null) {
      final map = Map<String, String>.from(json['completionTimestamps'] as Map);
      map.forEach((k, v) {
        final dt = DateTime.tryParse(v);
        if (dt != null) timestamps[k] = dt;
      });
    }

    return Habit(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      colorValue: json['colorValue'] as int,
      isQuitHabit: json['isQuitHabit'] as bool,
      goalValue: json['goalValue'] as int,
      goalUnit: json['goalUnit'] as String,
      isEveryDay: json['isEveryDay'] as bool,
      selectedDays: (json['selectedDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      reminderEnabled: json['reminderEnabled'] as bool,
      reminderHour: json['reminderHour'] as int?,
      reminderMinute: json['reminderMinute'] as int?,
      createdAt: json['createdAt'] as int,
      startDateString: parsedStartDateString,
      sortOrder: json['sortOrder'] as int? ?? 0,
      dailyProgress: progress,
      completionTimestamps: timestamps,
      goalSnapshots: snapshots,
      rewardsClaimed: rewards,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'colorValue': colorValue,
      'isQuitHabit': isQuitHabit,
      'goalValue': goalValue,
      'goalUnit': goalUnit,
      'isEveryDay': isEveryDay,
      'selectedDays': selectedDays,
      'reminderEnabled': reminderEnabled,
      'reminderHour': reminderHour,
      'reminderMinute': reminderMinute,
      'createdAt': createdAt,
      'startDateString': startDateString,
      'sortOrder': sortOrder,
      'dailyProgress': dailyProgress,
      'completionTimestamps': completionTimestamps.map((k, v) => MapEntry(k, v.toIso8601String())),
      'goalSnapshots': goalSnapshots,
      'rewardsClaimed': rewardsClaimed,
    };
  }

  Habit copyWith({
    String? name,
    String? icon,
    int? colorValue,
    bool? isQuitHabit,
    int? goalValue,
    String? goalUnit,
    bool? isEveryDay,
    List<int>? selectedDays,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    String? startDateString,
    int? sortOrder,
    Map<String, int>? dailyProgress,
    Map<String, DateTime>? completionTimestamps,
    Map<String, int>? goalSnapshots,
    Map<String, bool>? rewardsClaimed,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      colorValue: colorValue ?? this.colorValue,
      isQuitHabit: isQuitHabit ?? this.isQuitHabit,
      goalValue: goalValue ?? this.goalValue,
      goalUnit: goalUnit ?? this.goalUnit,
      isEveryDay: isEveryDay ?? this.isEveryDay,
      selectedDays: selectedDays ?? this.selectedDays,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      createdAt: createdAt,
      startDateString: startDateString ?? this.startDateString,
      sortOrder: sortOrder ?? this.sortOrder,
      dailyProgress: dailyProgress ?? this.dailyProgress,
      completionTimestamps: completionTimestamps ?? this.completionTimestamps,
      goalSnapshots: goalSnapshots ?? this.goalSnapshots,
      rewardsClaimed: rewardsClaimed ?? this.rewardsClaimed,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        icon,
        colorValue,
        isQuitHabit,
        goalValue,
        goalUnit,
        isEveryDay,
        selectedDays,
        reminderEnabled,
        reminderHour,
        reminderMinute,
        createdAt,
        startDateString,
        sortOrder,
        dailyProgress,
        completionTimestamps,
        goalSnapshots,
        rewardsClaimed,
      ];
}
