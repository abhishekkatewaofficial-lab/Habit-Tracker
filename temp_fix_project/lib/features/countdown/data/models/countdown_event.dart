import 'package:uuid/uuid.dart';

/// Represents a single countdown event.
class CountdownEvent {
  final String id;
  final String name;
  final DateTime targetDate;
  final String iconCode; // codePoint of CupertinoIconData as string
  final int createdAt; // milliseconds since epoch
  final int? reminderHour;   // null = no reminder
  final int? reminderMinute; // null = no reminder

  CountdownEvent({
    String? id,
    required this.name,
    required this.targetDate,
    required this.iconCode,
    int? createdAt,
    this.reminderHour,
    this.reminderMinute,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  /// Number of days remaining (positive = future, negative = past, 0 = today).
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.difference(today).inDays;
  }

  CountdownEvent copyWith({
    String? name,
    DateTime? targetDate,
    String? iconCode,
    int? reminderHour,
    int? reminderMinute,
    bool clearReminder = false,
  }) {
    return CountdownEvent(
      id: id,
      name: name ?? this.name,
      targetDate: targetDate ?? this.targetDate,
      iconCode: iconCode ?? this.iconCode,
      createdAt: createdAt,
      reminderHour: clearReminder ? null : (reminderHour ?? this.reminderHour),
      reminderMinute: clearReminder ? null : (reminderMinute ?? this.reminderMinute),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetDate': targetDate.millisecondsSinceEpoch,
        'iconCode': iconCode,
        'createdAt': createdAt,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
      };

  factory CountdownEvent.fromJson(Map<dynamic, dynamic> json) {
    return CountdownEvent(
      id: json['id'] as String,
      name: json['name'] as String,
      targetDate: DateTime.fromMillisecondsSinceEpoch(json['targetDate'] as int),
      iconCode: json['iconCode'] as String,
      createdAt: json['createdAt'] as int,
      reminderHour: json['reminderHour'] as int?,
      reminderMinute: json['reminderMinute'] as int?,
    );
  }
}
