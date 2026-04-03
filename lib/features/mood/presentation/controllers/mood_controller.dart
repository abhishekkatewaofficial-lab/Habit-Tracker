import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../core/services/sync_tracker_service.dart';
import '../../data/repositories/mood_repository.dart';

import '../../../../core/services/auth_service.dart';

/// Provide the repository
final moodRepositoryProvider = Provider<MoodRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return MoodRepository(HiveService.dailyMoodsBox);
});

/// Provide the daily moods mapping
final dailyMoodsProvider = StateNotifierProvider<MoodNotifier, Map<String, String>>((ref) {
  final repository = ref.watch(moodRepositoryProvider);
  if (repository == null) return MoodNotifier._empty();
  return MoodNotifier(repository);
});

class MoodNotifier extends StateNotifier<Map<String, String>> {
  final MoodRepository? _repository;

  MoodNotifier(this._repository) : super(_repository!.getAllMoods());
  
  MoodNotifier._empty() : _repository = null, super({});

  /// Get today's mood, if set
  String? get currentMood {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return state[todayStr];
  }

  /// Save or update a mood for a specific date
  Future<void> setMood(DateTime date, String emoji) async {
    if (_repository == null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    await _repository!.saveMood(dateStr, emoji);
    
    // Update state to trigger UI rebuild
    state = {...state, dateStr: emoji};
    SyncTrackerService.markDailyLogChanged(dateStr);
  }

  /// Save or update today's mood
  Future<void> setTodayMood(String emoji) async {
    await setMood(DateTime.now(), emoji);
  }

  /// Delete a mood
  Future<void> removeMood(DateTime date) async {
    if (_repository == null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    await _repository!.deleteMood(dateStr);
    
    final newState = Map<String, String>.from(state);
    newState.remove(dateStr);
    state = newState;
    SyncTrackerService.markDailyLogChanged(dateStr);
  }
}
