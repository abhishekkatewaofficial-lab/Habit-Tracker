import 'package:equatable/equatable.dart';

class DiaryEntry extends Equatable {
  final String id;
  final String date; // Format: yyyy-mm-dd
  final int timestamp;
  final String mood; // Emoji
  final String content;

  const DiaryEntry({
    required this.id,
    required this.date,
    required this.timestamp,
    required this.mood,
    required this.content,
  });

  factory DiaryEntry.fromJson(Map<dynamic, dynamic> json) {
    return DiaryEntry(
      id: json['id'] as String,
      date: json['date'] as String,
      timestamp: json['timestamp'] as int,
      mood: json['mood'] as String,
      content: json['content'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'timestamp': timestamp,
      'mood': mood,
      'content': content,
    };
  }

  @override
  List<Object?> get props => [id, date, timestamp, mood, content];
}
