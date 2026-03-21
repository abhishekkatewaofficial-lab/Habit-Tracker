import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'eisenhower_task.g.dart';

@HiveType(typeId: 8)
enum QuadrantType {
  @HiveField(0)
  doNow,
  @HiveField(1)
  schedule,
  @HiveField(2)
  delegate,
  @HiveField(3)
  eliminate,
}

@HiveType(typeId: 9)
class EisenhowerTask extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String title;
  
  @HiveField(2)
  final QuadrantType quadrant;
  
  @HiveField(3)
  final DateTime createdAt;
  
  @HiveField(4)
  final DateTime? dueDate;
  
  @HiveField(5)
  final int priority; // 1-3, where 1 is highest

  @HiveField(6, defaultValue: false)
  final bool isCompleted;

  EisenhowerTask({
    String? id,
    required this.title,
    required this.quadrant,
    DateTime? createdAt,
    this.dueDate,
    this.priority = 2,
    this.isCompleted = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  EisenhowerTask copyWith({
    String? title,
    QuadrantType? quadrant,
    DateTime? dueDate,
    int? priority,
    bool? isCompleted,
  }) {
    return EisenhowerTask(
      id: id,
      title: title ?? this.title,
      quadrant: quadrant ?? this.quadrant,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
