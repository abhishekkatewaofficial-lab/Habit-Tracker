import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/core/services/sync_tracker_service.dart';

// Models
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/features/todo/data/models/todo_category.dart';
import 'package:habit_tracker_ios/features/eisenhower/data/models/eisenhower_task.dart';
import 'package:habit_tracker_ios/features/diary/data/models/diary_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CloudSyncService {
  CloudSyncService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Call this when the app goes into the background
  static Future<void> pushBatchSync() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final changes = await SyncTrackerService.getPendingChanges();
    
    bool needsHabits = changes['habits'] == true;
    bool needsDiary = changes['diary'] == true;
    bool needsTodos = changes['todos'] == true;
    bool needsEisenhower = changes['eisenhower'] == true;
    List<String> dailyLogsChanged = List<String>.from(changes['daily_logs'] ?? []);

    if (!needsHabits && !needsDiary && !needsTodos && !needsEisenhower && dailyLogsChanged.isEmpty) {
      return; // Nothing to sync
    }

    try {
      final batch = _db.batch();
      final uid = user.uid;

      // 1. Configs
      if (needsHabits) {
        final habits = HiveService.habitsBox.values
            .map((e) => (e is Map ? Habit.fromJson(e) : e as Habit).toJson())
            .toList();
        batch.set(
          _db.doc('users/$uid/config/habits'),
          {
            'updatedAt': FieldValue.serverTimestamp(),
            'habits': habits,
          },
          SetOptions(merge: true),
        );
      }

      if (needsTodos) {
        final todos = HiveService.todoBox.values
            .map((e) => (e is Map ? TodoCategory.fromJson(Map<String, dynamic>.from(e)) : e as TodoCategory).toJson())
            .toList();
        batch.set(
          _db.doc('users/$uid/config/todos'),
          {
            'updatedAt': FieldValue.serverTimestamp(),
            'todos': todos,
          },
          SetOptions(merge: true),
        );
      }

      if (needsEisenhower) {
        final tasks = HiveService.eisenhowerBox.values.cast<EisenhowerTask>().map((e) => e.toJson()).toList();
        batch.set(
          _db.doc('users/$uid/config/eisenhower'),
          {
            'updatedAt': FieldValue.serverTimestamp(),
            'tasks': tasks,
          },
          SetOptions(merge: true),
        );
      }

      // We will treat Diary differently. Since a user can have many diary entries over time, 
      // but they wanted full sync and limited document counts. We can store diary entries grouped by date in daily_logs.
      // Wait, let's sync all diary entries to a single document if the list is small, or into daily_logs.
      // "Target < 20 writes per day. ONE document per user per day: users/{uid}/daily_logs/{yyyy-mm-dd}"
      // So any change to a dairy entry should write to the corresponding date's daily_log it belongs to.
      
      // Let's gather all habit daily progresses for the changed dates
      Map<String, Map<String, int>> habitProgressByDate = {};
      for (var raw in HiveService.habitsBox.values) {
        final habit = raw is Map ? Habit.fromJson(raw) : raw as Habit;
        for (var dateStr in habit.dailyProgress.keys) {
          if (dailyLogsChanged.contains(dateStr)) {
            habitProgressByDate[dateStr] ??= {};
            habitProgressByDate[dateStr]![habit.id] = habit.dailyProgress[dateStr]!;
          }
        }
      }

      // Gather diary entries for the changed dates
      Map<String, List<Map<String, dynamic>>> diaryByDate = {};
      for (var raw in HiveService.diaryBox.values) {
        final entry = raw is Map ? DiaryEntry.fromJson(raw) : raw as DiaryEntry;
        if (dailyLogsChanged.contains(entry.date) || needsDiary) {
          // If a diary change happened, we should make sure its date is synced
          if (!dailyLogsChanged.contains(entry.date)) {
            dailyLogsChanged.add(entry.date);
          }
          diaryByDate[entry.date] ??= [];
          diaryByDate[entry.date]!.add(entry.toJson());
        }
      }

      // Gather moods for the changed dates
      Map<String, String> moodByDate = {};
      final dailyMoodsBox = HiveService.dailyMoodsBox;
      for (var key in dailyMoodsBox.keys) {
        final dateStr = key.toString();
        if (dailyLogsChanged.contains(dateStr)) {
          moodByDate[dateStr] = dailyMoodsBox.get(key)!;
        }
      }

      // Apply batch for daily_logs
      for (var dateStr in dailyLogsChanged) {
        batch.set(
          _db.doc('users/$uid/daily_logs/$dateStr'),
          {
            'updatedAt': FieldValue.serverTimestamp(),
            'habits': habitProgressByDate[dateStr] ?? {},
            'diary': diaryByDate[dateStr] ?? [],
            'mood': moodByDate[dateStr],
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      // Clear pending changes since we successfully sent to Firestore
      await SyncTrackerService.clearPendingChanges();
      
      // Update local timestamps to know when we last synced
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_sync_time', DateTime.now().millisecondsSinceEpoch);
      
      debugPrint("🔥 SYNC PUSH SUCCESSFUL");
    } catch (e, st) {
      debugPrint("🔥 SYNC PUSH ERROR: $e");
    }
  }

  /// To be called when the user successfully signs in or manually triggers a full refresh
  /// Pulls ALL cloud data and forcefully updates Hive (assuming Cloud has the full history)
  static Future<void> pullHydration() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final uid = user.uid;

      // 1. Fetch Configs
      final habitsDoc = await _db.doc('users/$uid/config/habits').get();
      if (habitsDoc.exists) {
        final data = habitsDoc.data()!;
        if (data['habits'] != null) {
          final List habitsRaw = data['habits'];
          await HiveService.habitsBox.clear();
          for (var item in habitsRaw) {
            final habit = Habit.fromJson(item as Map<dynamic, dynamic>);
            await HiveService.habitsBox.put(habit.id, habit.toJson());
          }
        }
      }

      final todosDoc = await _db.doc('users/$uid/config/todos').get();
      if (todosDoc.exists) {
        final data = todosDoc.data()!;
        if (data['todos'] != null) {
          final List todosRaw = data['todos'];
          await HiveService.todoBox.clear();
          for (var item in todosRaw) {
            final category = TodoCategory.fromJson(Map<String, dynamic>.from(item));
            await HiveService.todoBox.put(category.id, category.toJson());
          }
        }
      }

      final eisenhowerDoc = await _db.doc('users/$uid/config/eisenhower').get();
      if (eisenhowerDoc.exists) {
        final data = eisenhowerDoc.data()!;
        if (data['tasks'] != null) {
          final List tasksRaw = data['tasks'];
          await HiveService.eisenhowerBox.clear();
          for (var item in tasksRaw) {
            final task = EisenhowerTask.fromJson(Map<String, dynamic>.from(item));
            await HiveService.eisenhowerBox.put(task.id, task);
          }
        }
      }

      // 2. Fetch Full History Daily Logs
      // To minimize docs, maybe we just fetch everything in the daily_logs collection
      final logsQuery = await _db.collection('users/$uid/daily_logs').get();
      
      await HiveService.diaryBox.clear();
      await HiveService.dailyMoodsBox.clear();

      for (var doc in logsQuery.docs) {
        final dateStr = doc.id;
        final data = doc.data();

        // Hydrate Habits
        if (data['habits'] != null) {
          // data['habits'] format: {'habitId': 3}
          final Map<String, dynamic> habitProgress = data['habits'];
          habitProgress.forEach((habitId, progress) {
            final rawHabit = HiveService.habitsBox.get(habitId);
            if (rawHabit != null) {
              final habit = rawHabit is Map ? Habit.fromJson(rawHabit) : rawHabit as Habit;
              final newProgress = Map<String, int>.from(habit.dailyProgress);
              newProgress[dateStr] = (progress as num).toInt();
              final updatedHabit = habit.copyWith(dailyProgress: newProgress);
              HiveService.habitsBox.put(habit.id, updatedHabit.toJson());
            }
          });
        }

        // Hydrate Diary
        if (data['diary'] != null && data['diary'] is List) {
          for (var item in (data['diary'] as List)) {
            final entry = DiaryEntry.fromJson(item as Map<dynamic, dynamic>);
            HiveService.diaryBox.put(entry.id, entry.toJson());
          }
        }

        // Hydrate Mood
        if (data['mood'] != null) {
          HiveService.dailyMoodsBox.put(dateStr, data['mood'] as String);
        }
      }

      // Clear any pending sync tracker so we don't accidentally push old state back to cloud immediately
      await SyncTrackerService.clearPendingChanges();
      
      debugPrint("🔥 SYNC PULL (HYDRATION) SUCCESSFUL");
    } catch (e, st) {
      debugPrint("🔥 SYNC PULL ERROR: $e\n$st");
    }
  }
}
