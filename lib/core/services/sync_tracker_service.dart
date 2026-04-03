import 'package:shared_preferences/shared_preferences.dart';

/// Tracks local modifications to data to enable batched sync.
class SyncTrackerService {
  static const _kConfigHabits = 'sync_config_habits';
  static const _kConfigDiary = 'sync_config_diary';
  static const _kConfigTodos = 'sync_config_todos';
  static const _kConfigEisenhower = 'sync_config_eisenhower';
  static const _kDailyLogs = 'sync_daily_logs'; 

  /// Mark a specific feature configuration as changed.
  /// Type can be: 'habits', 'diary', 'todos', 'eisenhower'
  static Future<void> markConfigChanged(String configType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_config_$configType', true);
  }

  /// Mark a specific date as changed (formats: yyyy-mm-dd)
  static Future<void> markDailyLogChanged(String dateStr) async {
    final prefs = await SharedPreferences.getInstance();
    final logs = prefs.getStringList(_kDailyLogs) ?? [];
    if (!logs.contains(dateStr)) {
      logs.add(dateStr);
      await prefs.setStringList(_kDailyLogs, logs);
    }
  }

  /// Get a snapshot of everything that needs syncing.
  static Future<Map<String, dynamic>> getPendingChanges() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'habits': prefs.getBool(_kConfigHabits) ?? false,
      'diary': prefs.getBool(_kConfigDiary) ?? false,
      'todos': prefs.getBool(_kConfigTodos) ?? false,
      'eisenhower': prefs.getBool(_kConfigEisenhower) ?? false,
      'daily_logs': prefs.getStringList(_kDailyLogs) ?? [],
    };
  }

  /// Clear the tracker after a successful sync to Firestore.
  static Future<void> clearPendingChanges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kConfigHabits);
    await prefs.remove(_kConfigDiary);
    await prefs.remove(_kConfigTodos);
    await prefs.remove(_kConfigEisenhower);
    await prefs.remove(_kDailyLogs);
  }
}
