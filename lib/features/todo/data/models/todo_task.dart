import 'package:uuid/uuid.dart';

class TodoTask {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? reminderTime;
  final double? reminderLat;
  final double? reminderLng;
  final String? reminderLocationName;

  TodoTask({
    String? id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
    this.reminderTime,
    this.reminderLat,
    this.reminderLng,
    this.reminderLocationName,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  TodoTask copyWith({
    String? title,
    bool? isCompleted,
    DateTime? reminderTime,
    bool clearReminder = false,
    double? reminderLat,
    double? reminderLng,
    String? reminderLocationName,
    bool clearLocation = false,
  }) {
    return TodoTask(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      reminderTime: clearReminder ? null : (reminderTime ?? this.reminderTime),
      reminderLat: clearLocation ? null : (reminderLat ?? this.reminderLat),
      reminderLng: clearLocation ? null : (reminderLng ?? this.reminderLng),
      reminderLocationName: clearLocation ? null : (reminderLocationName ?? this.reminderLocationName),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
        if (reminderTime != null) 'reminderTime': reminderTime!.toIso8601String(),
        if (reminderLat != null) 'reminderLat': reminderLat,
        if (reminderLng != null) 'reminderLng': reminderLng,
        if (reminderLocationName != null) 'reminderLocationName': reminderLocationName,
      };

  factory TodoTask.fromJson(Map<String, dynamic> json) => TodoTask(
        id: json['id'] as String? ?? const Uuid().v4(),
        title: json['title'] as String? ?? '',
        isCompleted: json['isCompleted'] as bool? ?? false,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        reminderTime: json['reminderTime'] != null
            ? DateTime.tryParse(json['reminderTime'].toString())
            : null,
        reminderLat: json['reminderLat'] as double?,
        reminderLng: json['reminderLng'] as double?,
        reminderLocationName: json['reminderLocationName'] as String?,
      );
}
