import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import '../../data/models/countdown_event.dart';

class CountdownController extends StateNotifier<List<CountdownEvent>> {
  CountdownController() : super([]) {
    _loadFromHive();
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
    final box = HiveService.countdownBox;
    await box.put(event.id, event.toJson());
    _loadFromHive();
  }

  Future<void> updateEvent(CountdownEvent event) async {
    final box = HiveService.countdownBox;
    await box.put(event.id, event.toJson());
    _loadFromHive();
  }

  Future<void> deleteEvent(String id) async {
    final box = HiveService.countdownBox;
    await box.delete(id);
    _loadFromHive();
  }
}

final countdownProvider =
    StateNotifierProvider<CountdownController, List<CountdownEvent>>(
  (ref) => CountdownController(),
);
