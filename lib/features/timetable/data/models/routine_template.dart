import 'package:habit_tracker_ios/features/timetable/data/models/time_block.dart';

class RoutineTemplate {
  final String id;
  final String name;
  final String emoji;
  final String colorHex;
  final List<TimeBlock> blocks;

  RoutineTemplate({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorHex,
    required this.blocks,
  });

  factory RoutineTemplate.fromJson(Map<String, dynamic> json) {
    return RoutineTemplate(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Template',
      emoji: json['emoji']?.toString() ?? '✨',
      colorHex: json['colorHex']?.toString() ?? '#7C3AED',
      blocks: (json['blocks'] as List<dynamic>?)
              ?.map((item) {
                // Ensure recursive map casts exist for nested objects when read from hive/firestore
                if (item is Map) {
                  return TimeBlock.fromJson(Map<String, dynamic>.from(item));
                }
                return null;
              })
              .whereType<TimeBlock>()
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'colorHex': colorHex,
      'blocks': blocks.map((e) => e.toJson()).toList(),
    };
  }

  RoutineTemplate copyWith({
    String? id,
    String? name,
    String? emoji,
    String? colorHex,
    List<TimeBlock>? blocks,
  }) {
    return RoutineTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      colorHex: colorHex ?? this.colorHex,
      blocks: blocks ?? this.blocks,
    );
  }
}
