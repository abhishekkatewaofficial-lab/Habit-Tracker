import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/core/services/firestore_sync_service.dart';
import 'package:habit_tracker_ios/features/focus_timer/data/models/focus_session.dart';

class FocusRepository {
  List<FocusSession> getAllSessions() {
    final box = HiveService.focusSessionsBox;
    final List<FocusSession> sessions = [];
    
    for (var key in box.keys) {
      final value = box.get(key);
      if (value != null && value is Map) {
        sessions.add(FocusSession.fromJson(value));
      }
    }
    
    // Sort by timestamp descending
    sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return sessions;
  }

  Future<void> saveSession(FocusSession session) async {
    final box = HiveService.focusSessionsBox;
    await box.put(session.id, session.toJson());
    FirestoreSyncService.pushFocusSession(session);
  }

  Future<void> deleteSession(String id) async {
    final box = HiveService.focusSessionsBox;
    await box.delete(id);
    FirestoreSyncService.deleteFocusSession(id);
  }
}
