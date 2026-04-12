import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'todo_task.dart';

class TodoCategory {
  final String id;
  final String name;
  final Color color;
  final String emoji;
  final List<TodoTask> tasks;

  TodoCategory({
    String? id,
    required this.name,
    required this.color,
    this.emoji = '📝',
    this.tasks = const [],
  }) : id = id ?? const Uuid().v4();

  int get completedCount => tasks.where((t) => t.isCompleted).length;
  double get progress => tasks.isEmpty ? 0 : completedCount / tasks.length;

  TodoCategory copyWith({
    String? name,
    Color? color,
    String? emoji,
    List<TodoTask>? tasks,
  }) {
    return TodoCategory(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      emoji: emoji ?? this.emoji,
      tasks: tasks ?? this.tasks,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.value,
        'emoji': emoji,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

  factory TodoCategory.fromJson(Map<String, dynamic> json) {
    return TodoCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      color: Color(json['color'] as int? ?? 0),
      emoji: json['emoji'] as String? ?? '📝',
      tasks: (json['tasks'] as List? ?? [])
          .map((t) => TodoTask.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList(),
    );
  }
}
