import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/features/diary/data/models/diary_entry.dart';
import 'package:habit_tracker_ios/features/diary/data/repositories/diary_repository.dart';
import 'package:habit_tracker_ios/core/services/sync_tracker_service.dart';
import 'package:habit_tracker_ios/core/services/auth_service.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepository();
});

// Provides state for selected date across the app, specifically for diary
final selectedDiaryDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

class DiaryEntriesNotifier extends StateNotifier<List<DiaryEntry>> {
  final DiaryRepository _repository;
  final String _currentDate;

  DiaryEntriesNotifier(this._repository, this._currentDate) : super([]) {
    _loadEntries();
  }
  
  DiaryEntriesNotifier._empty(this._repository, this._currentDate) : super([]);

  void _loadEntries() {
    state = _repository.getEntriesForDate(_currentDate);
  }

  Future<void> addEntry(DiaryEntry entry) async {
    await _repository.saveEntry(entry);
    _loadEntries(); // Reload to maintain sort order
    SyncTrackerService.markDailyLogChanged(entry.date);
    SyncTrackerService.markConfigChanged('diary');
  }

  Future<void> deleteEntry(String id) async {
    await _repository.deleteEntry(id);
    _loadEntries();
    SyncTrackerService.markDailyLogChanged(_currentDate);
    SyncTrackerService.markConfigChanged('diary');
  }
}

// StateNotifierProvider family that depends on a specific date string (yyyy-mm-dd)
final diaryEntriesProvider = StateNotifierProvider.family<DiaryEntriesNotifier, List<DiaryEntry>, String>((ref, dateStr) {
  final uid = ref.watch(currentUidProvider);
  final repository = ref.watch(diaryRepositoryProvider);
  if (uid == null) return DiaryEntriesNotifier._empty(repository, dateStr);
  return DiaryEntriesNotifier(repository, dateStr);
});

// Provides ALL diary entries for analytics purposes
final allDiaryEntriesProvider = Provider<List<DiaryEntry>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return [];
  final repository = ref.watch(diaryRepositoryProvider);
  return repository.getAllEntries();
});
