import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hive_service.dart';
import '../../../features/habits/data/models/habit.dart';
import '../../../features/todo/data/models/todo_category.dart';
import '../../../features/diary/data/models/diary_entry.dart';
import '../../../features/eisenhower/data/models/eisenhower_task.dart';
import '../../../features/countdown/data/models/countdown_event.dart';
import '../../../features/focus_timer/data/models/focus_item.dart';
import '../../../features/focus_timer/data/models/focus_session.dart';
import '../../../features/focus_timer/data/models/focus_daily_summary.dart';
import 'notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sync Refresh Notifier — bump counter pattern
// ─────────────────────────────────────────────────────────────────────────────
class SyncRefreshNotifier extends StateNotifier<int> {
  SyncRefreshNotifier() : super(0);
  void bump() => state = state + 1;
}

final syncRefreshProvider =
    StateNotifierProvider<SyncRefreshNotifier, int>((ref) {
  return SyncRefreshNotifier();
});

// ─────────────────────────────────────────────────────────────────────────────
// Firestore Sync Service — Pattern 1: Individual docs + Real-Time Listeners
//
// HOW IT WORKS:
//   • Every create/update/delete writes to BOTH Hive (instant) and Firestore
//   • Firestore listeners receive changes on OTHER devices in real-time
//   • Listener applies changes to Hive → bumps syncRefreshProvider → UI rebuilds
//   • Deletion: firestore.delete() propagates via listener → device B deletes too
//   • NO manual sync button needed. NO tombstones. NO merge blobs.
// ─────────────────────────────────────────────────────────────────────────────
class FirestoreSyncService {
  FirestoreSyncService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final Map<String, StreamSubscription<QuerySnapshot>> _subs = {};
  static SyncRefreshNotifier? _refreshNotifier;

  // Ignore re-entrant updates from our own writes
  static bool _selfWriting = false;

  // ── Start all real-time listeners ─────────────────────────────────────────
  static void startListeners(String uid, SyncRefreshNotifier refreshNotifier) {
    _refreshNotifier = refreshNotifier;

    // Cancel any existing before re-subscribing
    stopListeners();

    debugPrint('🔄 REALTIME SYNC — starting listeners for uid=$uid');

    _subs['habits'] = _db
        .collection('users/$uid/habits')
        .snapshots()
        .listen((snap) => _onHabitsChange(snap));

    _subs['todos'] = _db
        .collection('users/$uid/todos')
        .snapshots()
        .listen((snap) => _onTodosChange(snap));

    _subs['diary'] = _db
        .collection('users/$uid/diary')
        .snapshots()
        .listen((snap) => _onDiaryChange(snap));

    _subs['eisenhower'] = _db
        .collection('users/$uid/eisenhower')
        .snapshots()
        .listen((snap) => _onEisenhowerChange(snap));

    _subs['countdowns'] = _db
        .collection('users/$uid/countdowns')
        .snapshots()
        .listen((snap) => _onCountdownsChange(snap));

    _subs['focus_items'] = _db
        .collection('users/$uid/focus_items')
        .snapshots()
        .listen((snap) => _onFocusItemsChange(snap));

    _subs['focus_sessions'] = _db
        .collection('users/$uid/focus_sessions')
        .snapshots()
        .listen((snap) => _onFocusSessionsChange(snap));

    _subs['focus_summary'] = _db
        .collection('users/$uid/focus_summary')
        .snapshots()
        .listen((snap) => _onFocusSummaryChange(snap));

    _subs['moods'] = _db
        .collection('users/$uid/moods')
        .snapshots()
        .listen((snap) => _onMoodsChange(snap));

    _subs['profile'] = _db
        .collection('users/$uid/profile')
        .snapshots()
        .listen((snap) => _onProfileChange(snap));
  }

  static void stopListeners() {
    for (final sub in _subs.values) {
      sub.cancel();
    }
    _subs.clear();
    _refreshNotifier = null;
    debugPrint('🔄 REALTIME SYNC — all listeners stopped');
  }

  // ── Listener Handlers ─────────────────────────────────────────────────────

  static Future<void> _onHabitsChange(QuerySnapshot snap) async {
    // Skip snapshots caused by our own writes (fromCache=true + hasPendingWrites)
    if (snap.metadata.hasPendingWrites) return;

    bool changed = false;
    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.removed) {
        await HiveService.habitsBox.delete(change.doc.id);
        await NotificationService.cancelHabitReminders(change.doc.id);
        debugPrint('🔄 habits: DELETED ${change.doc.id}');
        changed = true;
      } else {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final habit = Habit.fromJson(data);
        await HiveService.habitsBox.put(habit.id, habit.toJson());
        
        if (habit.reminderEnabled && habit.reminderHour != null && habit.reminderMinute != null) {
          await NotificationService.scheduleHabitReminders(
            habitId: habit.id,
            habitName: habit.name,
            hour: habit.reminderHour!,
            minute: habit.reminderMinute!,
            isEveryDay: habit.isEveryDay,
            selectedDays: habit.selectedDays,
          );
        } else {
          await NotificationService.cancelHabitReminders(habit.id);
        }
        
        debugPrint('🔄 habits: UPSERTED "${habit.name}"');
        changed = true;
      }
    }
    if (changed) _refreshNotifier?.bump();
  }

  static Future<void> _onTodosChange(QuerySnapshot snap) async {
    if (snap.metadata.hasPendingWrites) return;

    bool changed = false;
    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.removed) {
        final oldCatJson = HiveService.todoBox.get(change.doc.id);
        if (oldCatJson != null) {
          final oldCat = TodoCategory.fromJson(Map<String, dynamic>.from(oldCatJson as Map));
          for (final t in oldCat.tasks) {
            await NotificationService.cancelTodoReminder(t.id);
          }
        }
        await HiveService.todoBox.delete(change.doc.id);
        debugPrint('🔄 todos: DELETED ${change.doc.id}');
        changed = true;
      } else {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final cat = TodoCategory.fromJson(data);
        
        final oldCatJson = HiveService.todoBox.get(cat.id);
        if (oldCatJson != null) {
          final oldCat = TodoCategory.fromJson(Map<String, dynamic>.from(oldCatJson as Map));
          final newTasks = cat.tasks.map((e) => e.id).toSet();
          for (final oldT in oldCat.tasks) {
            if (!newTasks.contains(oldT.id)) {
              await NotificationService.cancelTodoReminder(oldT.id);
            }
          }
        }
        
        await HiveService.todoBox.put(cat.id, cat.toJson());
        
        for (final t in cat.tasks) {
          if (!t.isCompleted && t.reminderTime != null) {
            await NotificationService.scheduleTodoReminder(
              taskId: t.id,
              taskTitle: t.title,
              targetDate: t.reminderTime!,
            );
          } else {
            await NotificationService.cancelTodoReminder(t.id);
          }
        }
        
        debugPrint('🔄 todos: UPSERTED "${cat.name}"');
        changed = true;
      }
    }
    if (changed) _refreshNotifier?.bump();
  }

  static Future<void> _onDiaryChange(QuerySnapshot snap) async {
    if (snap.metadata.hasPendingWrites) return;

    bool changed = false;
    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.removed) {
        await HiveService.diaryBox.delete(change.doc.id);
        debugPrint('🔄 diary: DELETED ${change.doc.id}');
        changed = true;
      } else {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final entry = DiaryEntry.fromJson(data);
        await HiveService.diaryBox.put(entry.id, entry.toJson());
        debugPrint('🔄 diary: UPSERTED entry on ${entry.date}');
        changed = true;
      }
    }
    if (changed) _refreshNotifier?.bump();
  }

  static Future<void> _onEisenhowerChange(QuerySnapshot snap) async {
    if (snap.metadata.hasPendingWrites) return;

    bool changed = false;
    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.removed) {
        await HiveService.eisenhowerBox.delete(change.doc.id);
        debugPrint('🔄 eisenhower: DELETED ${change.doc.id}');
        changed = true;
      } else {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final task = EisenhowerTask.fromJson(data);
        await HiveService.eisenhowerBox.put(task.id, task);
        debugPrint('🔄 eisenhower: UPSERTED "${task.title}"');
        changed = true;
      }
    }
    if (changed) _refreshNotifier?.bump();
  }

  static Future<void> _onCountdownsChange(QuerySnapshot snap) async {
    if (snap.metadata.hasPendingWrites) return;

    bool changed = false;
    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.removed) {
        await HiveService.countdownBox.delete(change.doc.id);
        await NotificationService.cancelCountdownReminder(change.doc.id);
        debugPrint('🔄 countdowns: DELETED ${change.doc.id}');
        changed = true;
      } else {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final event = CountdownEvent.fromJson(data);
        await HiveService.countdownBox.put(event.id, event.toJson());
        
        if (event.reminderHour != null && event.reminderMinute != null) {
          await NotificationService.scheduleCountdownReminder(
            countdownId: event.id,
            countdownName: event.name,
            targetDate: event.targetDate,
            hour: event.reminderHour!,
            minute: event.reminderMinute!,
          );
        } else {
          await NotificationService.cancelCountdownReminder(event.id);
        }
        
        debugPrint('🔄 countdowns: UPSERTED "${event.name}"');
        changed = true;
      }
    }
    if (changed) _refreshNotifier?.bump();
  }

  static Future<void> _onFocusItemsChange(QuerySnapshot snap) async {
    if (snap.metadata.hasPendingWrites) return;

    bool changed = false;
    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.removed) {
        await HiveService.focusItemsBox.delete(change.doc.id);
        changed = true;
      } else {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final item = FocusItem.fromJson(data);
        await HiveService.focusItemsBox.put(item.id, item.toJson());
        changed = true;
      }
    }
    if (changed) _refreshNotifier?.bump();
  }

  static Future<void> _onFocusSessionsChange(QuerySnapshot snap) async {
    if (snap.metadata.hasPendingWrites) return;

    bool changed = false;
    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.removed) {
        await HiveService.focusSessionsBox.delete(change.doc.id);
        changed = true;
      } else {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final session = FocusSession.fromJson(data);
        await HiveService.focusSessionsBox.put(session.id, session.toJson());
        changed = true;
      }
    }
    if (changed) _refreshNotifier?.bump();
  }

  static Future<void> _onFocusSummaryChange(QuerySnapshot snap) async {
    if (snap.metadata.hasPendingWrites) return;

    bool changed = false;
    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.removed) {
        await HiveService.focusDailySummaryBox.delete(change.doc.id);
        changed = true;
      } else {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        // The timestamp could be lost, but fromJson handles parsing
        final summary = FocusDailySummary.fromJson(data);
        await HiveService.focusDailySummaryBox.put(change.doc.id, summary.toJson());
        changed = true;
      }
    }
    if (changed) _refreshNotifier?.bump();
  }

  static Future<void> _onMoodsChange(QuerySnapshot snap) async {
    if (snap.metadata.hasPendingWrites) return;

    bool changed = false;
    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.removed) {
        await HiveService.dailyMoodsBox.delete(change.doc.id);
        debugPrint('🔄 moods: DELETED mood on ${change.doc.id}');
        changed = true;
      } else {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final emoji = data['emoji'] as String?;
        if (emoji != null) {
          await HiveService.dailyMoodsBox.put(change.doc.id, emoji);
          debugPrint('🔄 moods: UPSERTED mood on ${change.doc.id}');
          changed = true;
        }
      }
    }
    if (changed) _refreshNotifier?.bump();
  }

  static Future<void> _onProfileChange(QuerySnapshot snap) async {
    if (snap.metadata.hasPendingWrites) return;

    for (final change in snap.docChanges) {
      if (change.type == DocumentChangeType.removed) continue;
      final data = change.doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      if (data['name'] != null) {
        HiveService.settingsBox.put('userName', data['name'] as String);
      }
      if (data['imagePath'] != null) {
        HiveService.settingsBox.put('profileImagePath', data['imagePath'] as String);
      }
      if (data['coins'] != null) {
        HiveService.settingsBox.put('userCoins', (data['coins'] as num).toInt());
      }
    }
    _refreshNotifier?.bump();
  }

  // ── Push Helpers ────────────────────────────────────────────────────────
  static Future<void> _safeSet(String path, Map<String, dynamic> json, Future<void> Function() onReject) async {
    try {
      final payload = Map<String, dynamic>.from(json);
      payload['updatedAt'] = FieldValue.serverTimestamp();
      await _db.doc(path).set(payload, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        debugPrint('⚠️ SYNC REJECTED (permission-denied) - Reverting $path');
        await onReject();
      } else {
        debugPrint('⚠️ FIREBASE EXCEPTION on $path: ${e.code} - ${e.message}');
      }
    } catch (e) {
      debugPrint('⚠️ UNKNOWN SYNC ERROR $path: $e');
    }
  }

  static Future<void> _safeDelete(String path) async {
    try {
      await _db.doc(path).delete();
    } on FirebaseException catch (e) {
      debugPrint('⚠️ FIREBASE DELETE REJECTED on $path: ${e.code}');
    } catch (e) {
      debugPrint('⚠️ SYNC DELETE ERROR $path: $e');
    }
  }

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ── Push Methods (called from repositories on every write) ────────────────

  static Future<void> pushHabit(Habit habit) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeSet('users/$uid/habits/${habit.id}', habit.toJson(), () async {
      await HiveService.habitsBox.delete(habit.id);
      _refreshNotifier?.bump();
    });
  }

  static Future<void> deleteHabit(String habitId) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeDelete('users/$uid/habits/$habitId');
  }

  static Future<void> pushTodo(TodoCategory category) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeSet('users/$uid/todos/${category.id}', category.toJson(), () async {
      await HiveService.todoBox.delete(category.id);
      _refreshNotifier?.bump();
    });
  }

  static Future<void> deleteTodo(String categoryId) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeDelete('users/$uid/todos/$categoryId');
  }

  static Future<void> pushDiaryEntry(DiaryEntry entry) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeSet('users/$uid/diary/${entry.id}', entry.toJson(), () async {
      await HiveService.diaryBox.delete(entry.id);
      _refreshNotifier?.bump();
    });
  }

  static Future<void> deleteDiaryEntry(String entryId) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeDelete('users/$uid/diary/$entryId');
  }

  static Future<void> pushEisenhowerTask(EisenhowerTask task) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeSet('users/$uid/eisenhower/${task.id}', task.toJson(), () async {
      await HiveService.eisenhowerBox.delete(task.id);
      _refreshNotifier?.bump();
    });
  }

  static Future<void> deleteEisenhowerTask(String taskId) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeDelete('users/$uid/eisenhower/$taskId');
  }

  static Future<void> pushCountdownEvent(CountdownEvent event) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeSet('users/$uid/countdowns/${event.id}', event.toJson(), () async {
      await HiveService.countdownBox.delete(event.id);
      _refreshNotifier?.bump();
    });
  }

  static Future<void> deleteCountdownEvent(String eventId) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeDelete('users/$uid/countdowns/$eventId');
  }

  static Future<void> pushMood(String dateStr, String emoji) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeSet('users/$uid/moods/$dateStr', {'emoji': emoji}, () async {
      await HiveService.dailyMoodsBox.delete(dateStr);
      _refreshNotifier?.bump();
    });
  }

  static Future<void> deleteMood(String dateStr) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeDelete('users/$uid/moods/$dateStr');
  }

  static Future<void> pushProfile(String? name, String? imagePath, {int? coins}) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.doc('users/$uid/profile/info').set({
        if (name != null) 'name': name,
        if (imagePath != null) 'imagePath': imagePath,
        if (coins != null) 'coins': coins,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ pushProfile error: $e');
    }
  }

  static Future<void> pushFocusItem(FocusItem item) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeSet('users/$uid/focus_items/${item.id}', item.toJson(), () async {
      await HiveService.focusItemsBox.delete(item.id);
      _refreshNotifier?.bump();
    });
  }

  static Future<void> deleteFocusItem(String itemId) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeDelete('users/$uid/focus_items/$itemId');
  }

  static Future<void> pushFocusSession(FocusSession session) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeSet('users/$uid/focus_sessions/${session.id}', session.toJson(), () async {
      await HiveService.focusSessionsBox.delete(session.id);
      _refreshNotifier?.bump();
    });
  }

  static Future<void> deleteFocusSession(String sessionId) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeDelete('users/$uid/focus_sessions/$sessionId');
  }

  static Future<void> pushFocusDailySummary(FocusDailySummary summary) async {
    final uid = _uid;
    if (uid == null) return;
    await _safeSet('users/$uid/focus_summary/${summary.date}', summary.toJson(), () async {
      await HiveService.focusDailySummaryBox.delete(summary.date);
      _refreshNotifier?.bump();
    });
  }
}
