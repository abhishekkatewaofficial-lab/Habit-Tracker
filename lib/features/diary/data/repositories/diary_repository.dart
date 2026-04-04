import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/core/services/firestore_sync_service.dart';
import 'package:habit_tracker_ios/features/diary/data/models/diary_entry.dart';

class DiaryRepository {
  List<DiaryEntry> getEntriesForDate(String date) {
    final box = HiveService.diaryBox;
    final List<DiaryEntry> entries = [];
    
    for (var key in box.keys) {
      final value = box.get(key);
      if (value != null && value is Map) {
        final entry = DiaryEntry.fromJson(value);
        if (entry.date == date) {
          entries.add(entry);
        }
      }
    }
    
    // Sort by time: Earliest entry at TOP (ascending time)
    entries.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    return entries;
  }

  Future<void> saveEntry(DiaryEntry entry) async {
    await HiveService.diaryBox.put(entry.id, entry.toJson());
    FirestoreSyncService.pushDiaryEntry(entry);
  }

  Future<void> deleteEntry(String id) async {
    await HiveService.diaryBox.delete(id);
    FirestoreSyncService.deleteDiaryEntry(id);
  }

  List<DiaryEntry> getAllEntries() {
    final box = HiveService.diaryBox;
    final List<DiaryEntry> entries = [];
    
    for (var key in box.keys) {
      final value = box.get(key);
      if (value != null && value is Map) {
        entries.add(DiaryEntry.fromJson(value));
      }
    }
    
    // Sort by timestamp descending (newest first)
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return entries;
  }
}
