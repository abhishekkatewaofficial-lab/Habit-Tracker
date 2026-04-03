import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/features/focus_timer/data/models/focus_item.dart';
import 'package:habit_tracker_ios/features/focus_timer/data/models/focus_daily_summary.dart';
import 'package:habit_tracker_ios/core/services/auth_service.dart';

String _todayStr() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class FocusDashboardNotifier extends StateNotifier<List<FocusItem>> {
  final bool _isGuest;

  FocusDashboardNotifier({bool isGuest = false}) : _isGuest = isGuest, super([]) {
    if (!_isGuest) _loadAndCheckReset();
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
          // 1. Snapshot yesterday's total into the Daily Summaries Box
          _snapshotToDailySummary(item.lastResetDate, item.currentElapsedMs, item.name);

          // 2. Reset the item for today
          item = item.copyWith(
            accumulatedMs: 0,
            isRunning: false,
            startTimeMs: null,
            lastResetDate: today,
          );
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
      } else if (item.isRunning) {
        // Auto-pause
        final elapsed = now - (item.startTimeMs ?? now);
        final updated = item.copyWith(
          isRunning: false,
          accumulatedMs: item.accumulatedMs + elapsed,
          startTimeMs: null,
        );
        await HiveService.focusItemsBox.put(updated.id, updated.toJson());
        updatedList.add(updated);
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
        final elapsed = now - (item.startTimeMs ?? now);
        final updated = item.copyWith(
          isRunning: false,
          accumulatedMs: item.accumulatedMs + elapsed,
          startTimeMs: null,
        );
        await HiveService.focusItemsBox.put(updated.id, updated.toJson());
        updatedList.add(updated);
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
    }

    state = items;
  }
}

final focusDashboardProvider =
    StateNotifierProvider<FocusDashboardNotifier, List<FocusItem>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return FocusDashboardNotifier(isGuest: true);
  return FocusDashboardNotifier();
});
