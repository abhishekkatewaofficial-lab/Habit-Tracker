import 'package:flutter/foundation.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/core/services/firestore_sync_service.dart';
import '../models/time_block.dart';

class TimetableRepository {
  List<TimeBlock> getBlocksForDate(String date) {
    final box = HiveService.timetableBox;
    final List<TimeBlock> blocks = [];
    for (final key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw == null) continue;
        // Hive returns Map<dynamic, dynamic>; normalise to Map<String, dynamic>
        final Map<String, dynamic> map =
            Map<String, dynamic>.from(raw as Map);
        final block = TimeBlock.fromJson(map);
        if (block.date == date) blocks.add(block);
      } catch (e) {
        debugPrint('⚠️ TimetableRepository: skipping malformed block [$key]: $e');
      }
    }
    blocks.sort((a, b) => a.startTime.compareTo(b.startTime));
    return blocks;
  }

  List<TimeBlock> getAllBlocks() {
    final box = HiveService.timetableBox;
    final List<TimeBlock> blocks = [];
    for (final key in box.keys) {
      try {
        final raw = box.get(key);
        if (raw == null) continue;
        final Map<String, dynamic> map =
            Map<String, dynamic>.from(raw as Map);
        blocks.add(TimeBlock.fromJson(map));
      } catch (e) {
        debugPrint('⚠️ TimetableRepository: skipping malformed block [$key]: $e');
      }
    }
    return blocks;
  }

  Future<void> saveBlock(TimeBlock block) async {
    await HiveService.timetableBox.put(block.id, block.toJson());
    debugPrint('💾 Hive: saved block "${block.title}" (id: ${block.id}, date: ${block.date})');
    FirestoreSyncService.pushTimeBlock(block);
  }

  Future<void> deleteBlock(String id) async {
    await HiveService.timetableBox.delete(id);
    FirestoreSyncService.deleteTimeBlock(id);
  }
}
