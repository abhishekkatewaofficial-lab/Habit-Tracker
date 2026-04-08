/// App-wide constants for habit_tracker_ios.
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Habit Tracker';
  static const String appVersion = '1.0.0';

  // Hive box names
  static const String habitsBox = 'habits_box';
  static const String diaryBox = 'diary_box';
  static const String settingsBox = 'settings_box';
  static const String groupsBox = 'groups_box';
  static const String focusSessionsBox = 'focus_sessions_box';
  static const String dailyMoodsBox = 'daily_moods_box';
  static const String stopwatchBox = 'stopwatch_box';
  static const String pomodoroBox = 'pomodoro_box';
  static const String focusItemsBox = 'focus_items_box';
  static const String focusDailySummaryBox = 'focus_daily_summary_box';
  static const String coachBox = 'coach_box';

  // Notification channel
  static const String notificationChannelId = 'habit_tracker_channel';
  static const String notificationChannelName = 'Habit Reminders';
  static const String notificationChannelDesc =
      'Notifications for daily habit reminders.';

  // Notification IDs
  static const int coachDigestNotifId = 0x30000;

  // Focus timer defaults (in minutes)
  static const int defaultFocusDuration = 25;
  static const int defaultShortBreak = 5;
  static const int defaultLongBreak = 15;
  static const int sessionsBeforeLongBreak = 4;

  // Durations
  static const Duration animationFast = Duration(milliseconds: 200);
  static const Duration animationMedium = Duration(milliseconds: 350);
  static const Duration animationSlow = Duration(milliseconds: 600);

  // Padding / sizing
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  static const double radiusS = 8.0;
  static const double radiusM = 16.0;
  static const double radiusL = 24.0;
  static const double radiusXL = 32.0;

  // Bottom nav
  static const int navIndexHome = 0;
  static const int navIndexFocus = 1;
  static const int navIndexDiary = 2;
  static const int navIndexPlanner = 3;
  static const int navIndexReports = 4;
  
  static const int navIndexPlannerTodo = 5;
  static const int navIndexPlannerEisenhower = 6;
  
  // Focus Sub-Dock Indices
  static const int navIndexFocusDashboard = 7;
  static const int navIndexFocusPomodoro = 8;
  static const int navIndexFocusStopwatch = 9;
  static const int navIndexFocusCountdown = 10;

  static const String todoBox = 'todo_box';
  static const String eisenhowerBox = 'eisenhower_box';
  static const String countdownBox = 'countdown_box';
}
