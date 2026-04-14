import 'package:flutter/material.dart';

/// A single time-block entry in the timetable.
class TimeBlock {
  final String id;
  final String title;
  final String emoji;
  final DateTime startTime;
  final DateTime endTime;
  final String colorHex; // e.g. '#7C3AED'
  final String date;     // 'yyyy-MM-dd' key for the day this belongs to
  final bool isCompleted;

  const TimeBlock({
    required this.id,
    required this.title,
    required this.emoji,
    required this.startTime,
    required this.endTime,
    required this.colorHex,
    required this.date,
    this.isCompleted = false,
  });

  Duration get duration => endTime.difference(startTime);

  TimeBlock copyWith({
    String? id,
    String? title,
    String? emoji,
    DateTime? startTime,
    DateTime? endTime,
    String? colorHex,
    String? date,
    bool? isCompleted,
  }) {
    return TimeBlock(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      colorHex: colorHex ?? this.colorHex,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'colorHex': colorHex,
        'date': date,
        'isCompleted': isCompleted,
      };

  factory TimeBlock.fromJson(Map<dynamic, dynamic> json) => TimeBlock(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        emoji: json['emoji']?.toString() ?? '📌',
        startTime: DateTime.parse(json['startTime'].toString()),
        endTime: DateTime.parse(json['endTime'].toString()),
        colorHex: json['colorHex']?.toString() ?? '#7C3AED',
        date: json['date']?.toString() ?? '',
        isCompleted: json['isCompleted'] == true,
      );

  /// Parse '#RRGGBB' into a Flutter Color.
  Color get color {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
