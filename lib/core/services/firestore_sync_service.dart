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
        debugPrint('🔄 habits: DELETED ${change.doc.id}');
        changed = true;
      } else {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final habit = Habit.fromJson(data);
        await HiveService.habitsBox.put(habit.id, habit.toJson());
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
        await HiveService.todoBox.delete(change.doc.id);
        debugPrint('🔄 todos: DELETED ${change.doc.id}');
        changed = true;
      } else {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final cat = TodoCategory.fromJson(data);
        await HiveService.todoBox.put(cat.id, cat.toJson());
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
        debugPrint('🔄 countdowns: DELETED ${change.doc.id}');
        changed = true;
      } else {
        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final event = CountdownEvent.fromJson(data);
        await HiveService.countdownBox.put(event.id, event.toJson());
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
    }
    _refreshNotifier?.bump();
  }

  // ── Push Methods (called from repositories on every write) ────────────────

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static Future<void> pushHabit(Habit habit) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .doc('users/$uid/habits/${habit.id}')
          .set(habit.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ pushHabit error: $e');
    }
  }

  static Future<void> deleteHabit(String habitId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.doc('users/$uid/habits/$habitId').delete();
    } catch (e) {
      debugPrint('⚠️ deleteHabit error: $e');
    }
  }

  static Future<void> pushTodo(TodoCategory category) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .doc('users/$uid/todos/${category.id}')
          .set(category.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ pushTodo error: $e');
    }
  }

  static Future<void> deleteTodo(String categoryId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.doc('users/$uid/todos/$categoryId').delete();
    } catch (e) {
      debugPrint('⚠️ deleteTodo error: $e');
    }
  }

  static Future<void> pushDiaryEntry(DiaryEntry entry) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .doc('users/$uid/diary/${entry.id}')
          .set(entry.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ pushDiaryEntry error: $e');
    }
  }

  static Future<void> deleteDiaryEntry(String entryId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.doc('users/$uid/diary/$entryId').delete();
    } catch (e) {
      debugPrint('⚠️ deleteDiaryEntry error: $e');
    }
  }

  static Future<void> pushEisenhowerTask(EisenhowerTask task) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .doc('users/$uid/eisenhower/${task.id}')
          .set(task.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ pushEisenhowerTask error: $e');
    }
  }

  static Future<void> deleteEisenhowerTask(String taskId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.doc('users/$uid/eisenhower/$taskId').delete();
    } catch (e) {
      debugPrint('⚠️ deleteEisenhowerTask error: $e');
    }
  }

  static Future<void> pushCountdownEvent(CountdownEvent event) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .doc('users/$uid/countdowns/${event.id}')
          .set(event.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ pushCountdownEvent error: $e');
    }
  }

  static Future<void> deleteCountdownEvent(String eventId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.doc('users/$uid/countdowns/$eventId').delete();
    } catch (e) {
      debugPrint('⚠️ deleteCountdownEvent error: $e');
    }
  }

  static Future<void> pushMood(String dateStr, String emoji) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .doc('users/$uid/moods/$dateStr')
          .set({'emoji': emoji}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ pushMood error: $e');
    }
  }

  static Future<void> deleteMood(String dateStr) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.doc('users/$uid/moods/$dateStr').delete();
    } catch (e) {
      debugPrint('⚠️ deleteMood error: $e');
    }
  }

  static Future<void> pushProfile(String? name, String? imagePath) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.doc('users/$uid/profile/info').set({
        if (name != null) 'name': name,
        if (imagePath != null) 'imagePath': imagePath,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ pushProfile error: $e');
    }
  }

  static Future<void> pushFocusItem(FocusItem item) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .doc('users/$uid/focus_items/${item.id}')
          .set(item.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ pushFocusItem error: $e');
    }
  }

  static Future<void> deleteFocusItem(String itemId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.doc('users/$uid/focus_items/$itemId').delete();
    } catch (e) {
      debugPrint('⚠️ deleteFocusItem error: $e');
    }
  }

  static Future<void> pushFocusSession(FocusSession session) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .doc('users/$uid/focus_sessions/${session.id}')
          .set(session.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ pushFocusSession error: $e');
    }
  }

  static Future<void> deleteFocusSession(String sessionId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.doc('users/$uid/focus_sessions/$sessionId').delete();
    } catch (e) {
      debugPrint('⚠️ deleteFocusSession error: $e');
    }
  }

  static Future<void> pushFocusDailySummary(FocusDailySummary summary) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      // The doc ID is the date ('yyyy-MM-dd')
      await _db
          .doc('users/$uid/focus_summary/${summary.date}')
          .set(summary.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('⚠️ pushFocusDailySummary error: $e');
    }
  }
}
