import 'dart:async';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/core/services/firestore_sync_service.dart';
import 'package:habit_tracker_ios/core/services/notification_service.dart';
import 'package:habit_tracker_ios/features/focus_timer/data/models/focus_item.dart';
import 'package:habit_tracker_ios/features/focus_timer/data/models/focus_daily_summary.dart';
import 'package:habit_tracker_ios/core/services/auth_service.dart';

import 'package:habit_tracker_ios/core/services/cloud_sync_service.dart';

String _todayStr() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class FocusDashboardNotifier extends StateNotifier<List<FocusItem>> {
  final bool _isGuest;
  Timer? _ticker;

  FocusDashboardNotifier({bool isGuest = false}) : _isGuest = isGuest, super([]) {
    if (!_isGuest) {
      _loadAndCheckReset();
      _startTicker();
    }
  }

  void reloadFromHive() {
     if (!_isGuest) _loadAndCheckReset();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkHourlyMilestones();
    });
  }

  Future<void> _checkHourlyMilestones() async {
    if (!state.any((e) => e.isRunning)) return;

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('hourly_focus_updates') ?? true;
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;

    bool needsSave = false;
    final updatedList = List<FocusItem>.from(state);
    final today = _todayStr();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < updatedList.length; i++) {
      var item = updatedList[i];
      if (!item.isRunning) continue;

      // Live midnight boundary splitting
      if (item.lastResetDate != today && item.startTimeMs != null) {
        final result = _processElapsed(item.accumulatedMs, item.lastResetDate, item.startTimeMs!, now, item.name);
        item = item.copyWith(
          accumulatedMs: result.$1,
          lastResetDate: result.$2,
          startTimeMs: now,
          lastNotifiedHour: 0,
        );
        needsSave = true;
      }

      final elapsedMs = item.currentElapsedMs;
      final currentHour = elapsedMs ~/ 3600000;

      if (currentHour > 0 && currentHour > item.lastNotifiedHour) {
        if (enabled && notificationsEnabled) {
          NotificationService.showImmediate(
            id: (item.id.hashCode.abs() & 0x7FFFFFFF) ^ 0x0F0C05,
            title: 'Focus Update',
            body: '${currentHour} hour${currentHour > 1 ? "s" : ""} of \'${item.name}\' completed',
          );
          HapticFeedback.lightImpact();
        }

        item = item.copyWith(lastNotifiedHour: currentHour);
        HiveService.focusItemsBox.put(item.id, item.toJson());
        updatedList[i] = item;
        needsSave = true;
      } else if (needsSave) {
        // If we only updated the reset date but not the hour milestone
        HiveService.focusItemsBox.put(item.id, item.toJson());
        updatedList[i] = item;
      }
    }

    if (needsSave) {
      state = updatedList;
    }
  }

  /// Load from Hive and perform midnight resets if needed.
  void _loadAndCheckReset() {
    final box = HiveService.focusItemsBox;
    final List<FocusItem> items = [];
    final today = _todayStr();
    bool needsSave = false;

    for (var key in box.keys) {
      final value = box.get(key);
      if (value != null && value is Map) {
        var item = FocusItem.fromJson(value);

        // Check for midnight reset crossing
        if (item.lastResetDate != today) {
          if (item.isRunning && item.startTimeMs != null) {
            final now = DateTime.now().millisecondsSinceEpoch;
            final result = _processElapsed(item.accumulatedMs, item.lastResetDate, item.startTimeMs!, now, item.name);
            item = item.copyWith(
              accumulatedMs: result.$1,
              lastResetDate: result.$2,
              startTimeMs: now,
              lastNotifiedHour: 0,
            );
          } else {
            _snapshotToDailySummary(item.lastResetDate, item.accumulatedMs, item.name);
            item = item.copyWith(
              accumulatedMs: 0,
              isRunning: false,
              startTimeMs: null,
              lastNotifiedHour: 0,
              lastResetDate: today,
            );
          }
          needsSave = true;
        }

        items.add(item);
      }
    }

    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    state = items;

    if (needsSave) {
      for (var item in items) {
        box.put(item.id, item.toJson());
      }
    }
  }

  /// Splits elapsed time across midnights. Pushes past days to Daily Summary.
  /// Returns the accumulatedMs that belongs to the final day, and the date string for that final day.
  (int, String) _processElapsed(int accumulated, String startDateStr, int startMs, int endMs, String focusName) {
    if (startMs >= endMs) return (accumulated, startDateStr);

    int currentChunkStart = startMs;
    int currentAccumulated = accumulated;
    String currentDateStr = startDateStr;

    while (currentChunkStart < endMs) {
      final startDt = DateTime.fromMillisecondsSinceEpoch(currentChunkStart);
      final currentDate = DateTime(startDt.year, startDt.month, startDt.day);
      final nextMidnight = currentDate.add(const Duration(days: 1));
      
      final iterDateStr = '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}';
      
      if (iterDateStr != currentDateStr) {
        _snapshotToDailySummary(currentDateStr, currentAccumulated, focusName);
        currentAccumulated = 0;
        currentDateStr = iterDateStr;
      }
      
      final chunkEndMs = nextMidnight.millisecondsSinceEpoch < endMs 
          ? nextMidnight.millisecondsSinceEpoch 
          : endMs;
          
      final chunkDuration = chunkEndMs - currentChunkStart;
      currentAccumulated += chunkDuration;
      
      currentChunkStart = chunkEndMs;
    }
    
    final endDt = DateTime.fromMillisecondsSinceEpoch(endMs);
    final endDateStr = '${endDt.year}-${endDt.month.toString().padLeft(2, '0')}-${endDt.day.toString().padLeft(2, '0')}';
    if (endDateStr != currentDateStr) {
        _snapshotToDailySummary(currentDateStr, currentAccumulated, focusName);
        currentAccumulated = 0;
        currentDateStr = endDateStr;
    }

    return (currentAccumulated, currentDateStr);
  }

  /// Snapshots elapsed time to the Daily Summary box.
  void _snapshotToDailySummary(String date, int elapsedMs, String focusName) {
    if (elapsedMs == 0) return;
    
    final summaryBox = HiveService.focusDailySummaryBox;
    final existingData = summaryBox.get(date);
    int currentTotalSeconds = 0;
    Map<String, int> durations = {};
    
    if (existingData != null && existingData is Map) {
      final summary = FocusDailySummary.fromJson(existingData);
      currentTotalSeconds = summary.totalSeconds;
      durations = Map<String, int>.from(summary.focusDurations);
    }

    final addedSeconds = (elapsedMs / 1000).floor();
    durations[focusName] = (durations[focusName] ?? 0) + addedSeconds;

    final newSummary = FocusDailySummary(
      date: date,
      totalSeconds: currentTotalSeconds + addedSeconds,
      focusDurations: durations,
    );

    summaryBox.put(date, newSummary.toJson());
    FirestoreSyncService.pushFocusDailySummary(newSummary);
  }

  /// Create a new focus item.
  Future<void> addFocus(String name) async {
    if (_isGuest) return;
    final newItem = FocusItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      lastResetDate: _todayStr(),
      sortOrder: state.length,
    );
    
    await HiveService.focusItemsBox.put(newItem.id, newItem.toJson());
    state = [...state, newItem];
    FirestoreSyncService.pushFocusItem(newItem);
  }

  /// Delete a focus item (does NOT delete daily summaries).
  Future<void> deleteFocus(String id) async {
    if (_isGuest) return;
    // Snapshot any mid-day progress before deleting
    final item = state.firstWhere((e) => e.id == id);
    if (item.currentElapsedMs > 0) {
      _snapshotToDailySummary(item.lastResetDate, item.currentElapsedMs, item.name);
    }
    
    await HiveService.focusItemsBox.delete(id);
    state = state.where((e) => e.id != id).toList();
    FirestoreSyncService.deleteFocusItem(id);
  }

  /// Start a focus item (and auto-pause others).
  Future<void> startFocus(String id) async {
    if (_isGuest) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedList = <FocusItem>[];

    for (var item in state) {
      if (item.id == id) {
        final updated = item.copyWith(isRunning: true, startTimeMs: now);
        await HiveService.focusItemsBox.put(updated.id, updated.toJson());
        updatedList.add(updated);
        FirestoreSyncService.pushFocusItem(updated);
      } else if (item.isRunning) {
        // Auto-pause
        final result = _processElapsed(item.accumulatedMs, item.lastResetDate, item.startTimeMs ?? now, now, item.name);
        final updated = item.copyWith(
          isRunning: false,
          accumulatedMs: result.$1,
          lastResetDate: result.$2,
          startTimeMs: null,
        );
        await HiveService.focusItemsBox.put(updated.id, updated.toJson());
        updatedList.add(updated);
        FirestoreSyncService.pushFocusItem(updated);
      } else {
        updatedList.add(item);
      }
    }

    state = updatedList;
  }

  /// Pause a focus item.
  Future<void> pauseFocus(String id) async {
    if (_isGuest) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedList = <FocusItem>[];

    for (var item in state) {
      if (item.id == id && item.isRunning) {
        final result = _processElapsed(item.accumulatedMs, item.lastResetDate, item.startTimeMs ?? now, now, item.name);
        final updated = item.copyWith(
          isRunning: false,
          accumulatedMs: result.$1,
          lastResetDate: result.$2,
          startTimeMs: null,
        );
        await HiveService.focusItemsBox.put(updated.id, updated.toJson());
        updatedList.add(updated);
        FirestoreSyncService.pushFocusItem(updated);
      } else {
        updatedList.add(item);
      }
    }

    state = updatedList;
  }

  /// Reorder focus items.
  Future<void> reorderFocus(int oldIndex, int newIndex) async {
    if (_isGuest) return;
    if (oldIndex < newIndex) {
      newIndex -= 1; // adjust for removed item
    }

    final items = List<FocusItem>.from(state);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // Update sortOrder for all items and save to Hive
    for (int i = 0; i < items.length; i++) {
      items[i] = items[i].copyWith(sortOrder: i);
      await HiveService.focusItemsBox.put(items[i].id, items[i].toJson());
      FirestoreSyncService.pushFocusItem(items[i]);
    }

    state = items;
  }
}

final focusDashboardProvider =
    StateNotifierProvider<FocusDashboardNotifier, List<FocusItem>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return FocusDashboardNotifier(isGuest: true);
  
  final notifier = FocusDashboardNotifier();
  
  // Instantly reflect state pulled from Firestore sync
  ref.listen(syncRefreshProvider, (prev, next) {
    notifier.reloadFromHive();
  });
  
  return notifier;
});
