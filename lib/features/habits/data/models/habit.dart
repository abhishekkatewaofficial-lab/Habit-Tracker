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
  final int createdAt;
  final int sortOrder;
  final Map<String, int> dailyProgress; // Format: {yyyy-mm-dd: current_progress}

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
    required this.createdAt,
    this.sortOrder = 0,
    this.dailyProgress = const {},
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
      createdAt: json['createdAt'] as int,
      sortOrder: json['sortOrder'] as int? ?? 0,
      dailyProgress: progress,
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
      'createdAt': createdAt,
      'sortOrder': sortOrder,
      'dailyProgress': dailyProgress,
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
    int? sortOrder,
    Map<String, int>? dailyProgress,
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
      createdAt: createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      dailyProgress: dailyProgress ?? this.dailyProgress,
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
        createdAt,
        sortOrder,
        dailyProgress,
      ];
}
