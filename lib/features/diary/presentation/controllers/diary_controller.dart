import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/features/diary/data/models/diary_entry.dart';
import 'package:habit_tracker_ios/features/diary/data/repositories/diary_repository.dart';
import 'package:habit_tracker_ios/core/services/auth_service.dart';
import 'package:habit_tracker_ios/core/services/firestore_sync_service.dart';

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

  void reloadFromHive() => _loadEntries();

  void _loadEntries() {
    state = _repository.getEntriesForDate(_currentDate);
  }

  Future<void> addEntry(DiaryEntry entry) async {
    await _repository.saveEntry(entry);
    _loadEntries(); // Reload to maintain sort order
  }

  Future<void> deleteEntry(String id) async {
    await _repository.deleteEntry(id);
    _loadEntries();
  }
}

// StateNotifierProvider family that depends on a specific date string (yyyy-mm-dd)
final diaryEntriesProvider = StateNotifierProvider.family<DiaryEntriesNotifier, List<DiaryEntry>, String>((ref, dateStr) {
  final uid = ref.watch(currentUidProvider);
  final repository = ref.watch(diaryRepositoryProvider);
  if (uid == null) return DiaryEntriesNotifier._empty(repository, dateStr);
  
  final notifier = DiaryEntriesNotifier(repository, dateStr);
  ref.listen(syncRefreshProvider, (prev, next) {
    notifier.reloadFromHive();
  });
  return notifier;
});

// Provides ALL diary entries for analytics purposes
final allDiaryEntriesProvider = Provider<List<DiaryEntry>>((ref) {
  final uid = ref.watch(currentUidProvider);
  ref.watch(syncRefreshProvider); // Re-fetch all entries when sync updates
  if (uid == null) return [];
  final repository = ref.watch(diaryRepositoryProvider);
  return repository.getAllEntries();
});
