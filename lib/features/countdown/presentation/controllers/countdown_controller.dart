import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/core/services/notification_service.dart';
import 'package:habit_tracker_ios/core/services/firestore_sync_service.dart';
import '../../data/models/countdown_event.dart';

class CountdownController extends StateNotifier<List<CountdownEvent>> {
  CountdownController() : super([]) {
    _loadFromHive();
  }

  Future<void> reloadFromHive() async {
    final oldEvents = List<CountdownEvent>.from(state);
    _loadFromHive();
    
    // Resync OS notifications safely.
    for (final oldE in oldEvents) {
      await NotificationService.cancelCountdownReminder(oldE.id);
    }
    for (final newE in state) {
      if (newE.reminderHour != null && newE.reminderMinute != null) {
        await NotificationService.scheduleCountdownReminder(
          countdownId: newE.id,
          countdownName: newE.name,
          targetDate: newE.targetDate,
          hour: newE.reminderHour!,
          minute: newE.reminderMinute!,
        );
      }
    }
  }

  void _loadFromHive() {
    final box = HiveService.countdownBox;
    final events = box.values
        .map((e) => CountdownEvent.fromJson(e as Map<dynamic, dynamic>))
        .toList();
    // Sort ascending by daysLeft (nearest event first)
    events.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    state = events;
  }

  Future<void> addEvent(CountdownEvent event) async {
    await HiveService.countdownBox.put(event.id, event.toJson());
    if (event.reminderHour != null && event.reminderMinute != null) {
      await NotificationService.scheduleCountdownReminder(
        countdownId: event.id,
        countdownName: event.name,
        targetDate: event.targetDate,
        hour: event.reminderHour!,
        minute: event.reminderMinute!,
      );
    }
    FirestoreSyncService.pushCountdownEvent(event);
    _loadFromHive();
  }

  Future<void> updateEvent(CountdownEvent event) async {
    await NotificationService.cancelCountdownReminder(event.id);
    await HiveService.countdownBox.put(event.id, event.toJson());
    if (event.reminderHour != null && event.reminderMinute != null) {
      await NotificationService.scheduleCountdownReminder(
        countdownId: event.id,
        countdownName: event.name,
        targetDate: event.targetDate,
        hour: event.reminderHour!,
        minute: event.reminderMinute!,
      );
    }
    FirestoreSyncService.pushCountdownEvent(event);
    _loadFromHive();
  }

  Future<void> deleteEvent(String id) async {
    await NotificationService.cancelCountdownReminder(id);
    await HiveService.countdownBox.delete(id);
    FirestoreSyncService.deleteCountdownEvent(id);
    _loadFromHive();
  }
}

final countdownProvider =
    StateNotifierProvider<CountdownController, List<CountdownEvent>>((ref) {
  final controller = CountdownController();
  
  ref.listen(syncRefreshProvider, (prev, next) {
    controller.reloadFromHive();
  });
  
  return controller;
});
