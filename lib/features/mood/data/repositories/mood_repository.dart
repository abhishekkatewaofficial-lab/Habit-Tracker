import 'package:hive_flutter/hive_flutter.dart';

/// Repository for managing daily moods.
class MoodRepository {
  final Box<String> _box;

  MoodRepository(this._box);

  /// Get all logged moods as a Map<YYYY-MM-DD, Emoji>
  Map<String, String> getAllMoods() {
    final map = <String, String>{};
    for (var key in _box.keys) {
      map[key.toString()] = _box.get(key)!;
    }
    return map;
  }

  /// Save or overwrite a mood for a specific date
  Future<void> saveMood(String dateStr, String emoji) async {
    await _box.put(dateStr, emoji);
  }

  /// Delete a mood for a specific date
  Future<void> deleteMood(String dateStr) async {
    await _box.delete(dateStr);
  }
}
