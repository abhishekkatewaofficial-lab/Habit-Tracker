import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habit_tracker_ios/core/services/notification_service.dart';

const _kNotificationsEnabledKey = 'notifications_enabled';

class NotificationNotifier extends Notifier<bool> {
  @override
  bool build() {
    _loadFromPrefs();
    return false; 
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kNotificationsEnabledKey) ?? false;
  }

  Future<bool> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (enabled) {
      // 1. Request OS permission
      final granted = await NotificationService.requestPermission();
      
      // 2. Denied -> Revert safely
      if (!granted) {
        state = false;
        await prefs.setBool(_kNotificationsEnabledKey, false);
        return false;
      }
      
      // 3. Granted -> Save locally
      state = true;
      await prefs.setBool(_kNotificationsEnabledKey, true);
      return true;
    } else {
      // 1. Save OFF locally
      state = false;
      await prefs.setBool(_kNotificationsEnabledKey, false);
      
      // 2. Aggressively cancel all scheduled tasks immediately
      await NotificationService.cancelAll();
      return true;
    }
  }
}

final notificationProvider = NotifierProvider<NotificationNotifier, bool>(
  NotificationNotifier.new,
);
