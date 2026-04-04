import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/core/services/firestore_sync_service.dart';
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
    habits.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return habits;
  }

  Future<void> saveHabit(Habit habit) async {
    await HiveService.habitsBox.put(habit.id, habit.toJson());
    // Write-through: async, does not block UI
    FirestoreSyncService.pushHabit(habit);
  }

  Future<void> deleteHabit(String id) async {
    await HiveService.habitsBox.delete(id);
    // This delete propagates to Device B via Firestore listener instantly
    FirestoreSyncService.deleteHabit(id);
  }
}

