import 'package:equatable/equatable.dart';

class FocusSession extends Equatable {
  final String id;
  final String date; // yyyy-mm-dd
  final int timestamp;
  final int durationSeconds;
  final String? habitId; // Optional: link to a specific habit

  const FocusSession({
    required this.id,
    required this.date,
    required this.timestamp,
    required this.durationSeconds,
    this.habitId,
  });

  factory FocusSession.fromJson(Map<dynamic, dynamic> json) {
    return FocusSession(
      id: json['id'] as String,
      date: json['date'] as String,
      timestamp: json['timestamp'] as int,
      durationSeconds: json['durationSeconds'] as int,
      habitId: json['habitId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'timestamp': timestamp,
      'durationSeconds': durationSeconds,
      'habitId': habitId,
    };
  }

  @override
  List<Object?> get props => [id, date, timestamp, durationSeconds, habitId];
}
