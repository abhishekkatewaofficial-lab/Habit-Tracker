import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/features/diary/data/models/diary_entry.dart';
import 'package:habit_tracker_ios/features/diary/data/repositories/diary_repository.dart';

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
  final repository = ref.watch(diaryRepositoryProvider);
  return DiaryEntriesNotifier(repository, dateStr);
});

// Provides ALL diary entries for analytics purposes
final allDiaryEntriesProvider = Provider<List<DiaryEntry>>((ref) {
  final repository = ref.watch(diaryRepositoryProvider);
  return repository.getAllEntries();
});
