import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';

class HabitRepository {
  List<Habit> getAllHabits() {
    final box = HiveService.habitsBox;
    final List<Habit> habits = [];

    for (var key in box.keys) {
      final value = box.get(key);
      if (value != null && value is Map) {
        habits.add(Habit.fromJson(value));
      }
    }

    // Sort by persistable sortOrder
    habits.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return habits;
  }

  Future<void> saveHabit(Habit habit) async {
    final box = HiveService.habitsBox;
    await box.put(habit.id, habit.toJson());
  }

  Future<void> deleteHabit(String id) async {
    final box = HiveService.habitsBox;
    await box.delete(id);
  }
}
