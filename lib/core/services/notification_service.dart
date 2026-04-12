import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:habit_tracker_ios/core/constants/app_constants.dart';
import 'package:native_geofence/native_geofence.dart';

@pragma('vm:entry-point')
Future<void> geofenceCallback(GeofenceCallbackParams params) async {
  debugPrint('📍 [NotificationService] Geofence event: ${params.event} for: ${params.geofences.map((e) => e.id)}');
  if (params.event == GeofenceEvent.enter) {
    for (final geofence in params.geofences) {
      // Show local notification
      await NotificationService.showImmediate(
        id: geofence.id.hashCode.abs() % 100000,
        title: "📍 Location Reminder",
        body: "You've arrived! Time to check off your task.",
      );
      // Remove it so it doesn't trigger again
      try {
        await NativeGeofenceManager.instance.removeGeofenceById(geofence.id);
      } catch (_) {}
    }
  }
}

/// Wraps [FlutterLocalNotificationsPlugin] for habit and countdown reminders.
/// Simple, stable notifications — no interaction actions.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  
  static final StreamController<String> _notificationStream = StreamController<String>.broadcast();
  static Stream<String> get onNotification => _notificationStream.stream;

  static Future<void> init() async {
    if (_initialized) return;

    try {
      await NativeGeofenceManager.instance.initialize();
      debugPrint('📍 [NotificationService] Native geofencing initialized.');
    } catch (e) {
      debugPrint('📍 [NotificationService] Native geofencing init failed: $e');
    }

    // 1. Initialize timezone data
    tz.initializeTimeZones();

    // 2. Set device local timezone
    try {
      final String currentTimeZone =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(currentTimeZone));
      debugPrint('🔔 [NotificationService] Timezone set to: $currentTimeZone');
    } catch (e) {
      debugPrint(
          '🔔 [NotificationService] Error getting local timezone: $e. Falling back to default.');
    }

    // 3. Android init settings — icon must reference a drawable in the APK
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 4. iOS init settings — clean, no action categories
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;

    // 5. Request permissions explicitly
    await requestPermission();
  }

  static Future<bool> requestPermission() async {
    // Android 13+ request
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
      await android.requestExactAlarmsPermission();
    }

    // iOS request
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;
  }

  // ──────────────────────────────────────────────────────────────
  // Shared notification details
  // ──────────────────────────────────────────────────────────────

  static NotificationDetails _buildNotificationDetails(bool playSound) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'premium_alerts_v2',
        'Direct Alerts',
        channelDescription: 'Time-sensitive app reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: playSound,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: playSound,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Habit-level scheduling (per weekday)
  // ──────────────────────────────────────────────────────────────

  /// Returns a stable, unique notification ID for a habit on a given weekday.
  /// weekday: 1 (Mon) ... 7 (Sun), matching DateTime.weekday.
  static int _notifId(String habitId, int weekday) {
    final base = habitId.hashCode.abs() & 0x3FFF;
    return base * 10 + weekday;
  }

  /// Cancels existing notifications for [habitId] then schedules
  /// one weekly notification per active weekday at [hour]:[minute].
  static Future<void> scheduleHabitReminders({
    required String habitId,
    required String habitName,
    required int hour,
    required int minute,
    required bool isEveryDay,
    required List<int> selectedDays,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_enabled') ?? false)) return;

    await cancelHabitReminders(habitId);

    // Build list of weekdays (DateTime weekday: Mon=1 ... Sun=7)
    final List<int> weekdays;
    if (isEveryDay) {
      weekdays = [1, 2, 3, 4, 5, 6, 7];
    } else {
      // Convert app 0-6 (Sun=0 ... Sat=6) to DateTime weekday (Mon=1 ... Sun=7)
      weekdays = selectedDays.map((d) => d == 0 ? 7 : d).toList();
    }

    for (final weekday in weekdays) {
      final id = _notifId(habitId, weekday);
      final scheduled = _nextInstanceOfWeekdayTime(weekday, hour, minute);

      debugPrint(
          '🔔 [Notification] Habit "$habitName" scheduled for: $scheduled (Timezone: ${tz.local.name})');

      await _plugin.zonedSchedule(
        id,
        habitName,
        'Time to complete your habit! ✅',
        scheduled,
        _buildNotificationDetails(prefs.getBool('sounds_enabled') ?? true),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: 'habit_$habitId',
      );
    }
  }

  /// Cancels all 7 possible weekday notifications for a habit.
  static Future<void> cancelHabitReminders(String habitId) async {
    for (int weekday = 1; weekday <= 7; weekday++) {
      await _plugin.cancel(_notifId(habitId, weekday));
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Countdown-level scheduling (one-shot, fires once on target date)
  // ──────────────────────────────────────────────────────────────

  /// Stable ID for a countdown notification — bit 16 set to avoid habit ID collisions.
  static int _countdownNotifId(String countdownId) {
    return (countdownId.hashCode.abs() & 0xFFFF) | 0x10000;
  }

  /// Schedules a single notification at [targetDate] on [hour]:[minute].
  /// Cancels any existing notification for this countdown first.
  static Future<void> scheduleCountdownReminder({
    required String countdownId,
    required String countdownName,
    required DateTime targetDate,
    required int hour,
    required int minute,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_enabled') ?? false)) return;

    await cancelCountdownReminder(countdownId);

    final scheduledDate = tz.TZDateTime(
      tz.local,
      targetDate.year,
      targetDate.month,
      targetDate.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      debugPrint(
          '🔔 [Notification] Countdown "$countdownName" time $scheduledDate is in the past. Skipping.');
      return;
    }

    debugPrint(
        '🔔 [Notification] Countdown "$countdownName" scheduled ONE-SHOT for: $scheduledDate (Timezone: ${tz.local.name})');

    await _plugin.zonedSchedule(
      _countdownNotifId(countdownId),
      countdownName,
      "Today is the day! 🎉 Your countdown has arrived.",
      scheduledDate,
      _buildNotificationDetails(prefs.getBool('sounds_enabled') ?? true),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // No matchDateTimeComponents → fires exactly once
    );
  }

  /// Cancels the single countdown notification for [countdownId].
  static Future<void> cancelCountdownReminder(String countdownId) async {
    await _plugin.cancel(_countdownNotifId(countdownId));
  }

  // ──────────────────────────────────────────────────────────────
  // To-Do Reminder Scheduling
  // ──────────────────────────────────────────────────────────────

  /// Stable ID for a todo notification — bit 17 set to avoid collisions.
  static int _todoNotifId(String taskId) {
    return (taskId.hashCode.abs() & 0xFFFF) | 0x20000;
  }

  /// Schedules a reminder for a To-Do task.
  static Future<void> scheduleTodoReminder({
    required String taskId,
    required String taskTitle,
    required DateTime targetDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_enabled') ?? false)) return;

    await cancelTodoReminder(taskId);

    final scheduledDate = tz.TZDateTime.from(targetDate, tz.local);

    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      debugPrint(
          '🔔 [Notification] Todo "$taskTitle" time $scheduledDate is in the past. Skipping.');
      return;
    }

    debugPrint(
        '🔔 [Notification] Todo "$taskTitle" scheduled for: $scheduledDate (Timezone: ${tz.local.name})');

    await _plugin.zonedSchedule(
      _todoNotifId(taskId),
      'To-Do Reminder',
      taskTitle,
      scheduledDate,
      _buildNotificationDetails(prefs.getBool('sounds_enabled') ?? true),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // No matchDateTimeComponents → fires exactly once
    );
  }

  /// Cancels the notification for [taskId].
  static Future<void> cancelTodoReminder(String taskId) async {
    await _plugin.cancel(_todoNotifId(taskId));
  }

  // ──────────────────────────────────────────────────────────────
  // AI Coach scheduling
  // ──────────────────────────────────────────────────────────────

  /// Schedules a weekly digest every Sunday at 8 PM.
  static Future<void> scheduleWeeklyDigest() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_enabled') ?? false)) return;

    await cancelWeeklyDigest();

    // 7 = Sunday
    final scheduledDate = _nextInstanceOfWeekdayTime(7, 20, 0);

    debugPrint(
        '🔔 [Notification] AI Coach Weekly Digest scheduled for: $scheduledDate (Timezone: ${tz.local.name})');

    await _plugin.zonedSchedule(
      AppConstants.coachDigestNotifId,
      'Your AI Coach Weekly Digest',
      'Tap to review your progress and get personalized insights for the week ahead! ✨',
      scheduledDate,
      _buildNotificationDetails(prefs.getBool('sounds_enabled') ?? true),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'coach_weekly_digest',
    );
  }

  /// Cancels the weekly digest notification.
  static Future<void> cancelWeeklyDigest() async {
    await _plugin.cancel(AppConstants.coachDigestNotifId);
  }

  // ──────────────────────────────────────────────────────────────
  // Generic helpers
  // ──────────────────────────────────────────────────────────────

  /// Fires a notification immediately (no scheduling).
  /// Used by SmartNudgeService for context-aware nudges.
  static Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_initialized) return;
    await _plugin.show(
      id,
      title,
      body,
      _buildNotificationDetails(prefs.getBool('sounds_enabled') ?? true),
      payload: 'reports', // Smart nudges usually relate to reports/insights
    );
  }

  /// Schedules a single smart nudge at [scheduledTime].
  /// Used by SmartNudgeService to pre-schedule nudges that fire even when
  /// the app is closed or the screen is locked.
  static Future<void> scheduleSmartNudge({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
    required SharedPreferences prefs,
  }) async {
    if (!_initialized) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      _buildNotificationDetails(prefs.getBool('sounds_enabled') ?? true),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'reports',
      // No matchDateTimeComponents → one-shot, fires exactly once today
    );
  }

  static Future<void> cancel(int id) async => _plugin.cancel(id);
  static Future<void> cancelAll() async => _plugin.cancelAll();

  static tz.TZDateTime _nextInstanceOfWeekdayTime(
      int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (candidate.weekday != weekday || candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      _notificationStream.add(response.payload!);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Location-Based Reminders (To-Do)
  // ──────────────────────────────────────────────────────────────

  static Future<void> scheduleLocationReminder({
    required String taskId,
    required double lat,
    required double lng,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_enabled') ?? false)) return;

    final geofence = Geofence(
      id: taskId,
      location: Location(latitude: lat, longitude: lng),
      radiusMeters: 150, // 150 meters radius
      triggers: {GeofenceEvent.enter},
      iosSettings: const IosGeofenceSettings(),
      androidSettings: const AndroidGeofenceSettings(
        initialTriggers: {GeofenceEvent.enter},
      ),
    );

    try {
      await NativeGeofenceManager.instance.createGeofence(geofence, geofenceCallback);
      debugPrint('📍 [Notification] Geofence set for $taskId at $lat, $lng');
    } catch (e) {
      debugPrint('📍 [Notification] Geofence error: $e');
    }
  }

  static Future<void> cancelLocationReminder(String taskId) async {
    try {
      await NativeGeofenceManager.instance.removeGeofenceById(taskId);
      debugPrint('📍 [Notification] Geofence cancelled for $taskId');
    } catch (e) {
      // Ignored if geofence wasn't set or already removed
    }
  }
}
