import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker_ios/core/constants/app_constants.dart';
import 'package:habit_tracker_ios/features/eisenhower/data/models/eisenhower_task.dart';

/// Manages Hive initialisation and provides typed box accessors.
class HiveService {
  HiveService._();

  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Register Adapters
    Hive.registerAdapter(QuadrantTypeAdapter());
    Hive.registerAdapter(EisenhowerTaskAdapter());

    // Boxes that need specific handling or are likely to have schema changes
    try {
      await Hive.openBox<EisenhowerTask>(AppConstants.eisenhowerBox);
    } catch (e) {
      // If we have a schema mismatch (common after adding non-nullable fields), 
      // we'll clear the box for a fresh start.
      await Hive.deleteBoxFromDisk(AppConstants.eisenhowerBox);
      await Hive.openBox<EisenhowerTask>(AppConstants.eisenhowerBox);
    }

    await Future.wait([
      Hive.openBox(AppConstants.habitsBox),
      Hive.openBox(AppConstants.diaryBox),
      Hive.openBox(AppConstants.settingsBox),
      Hive.openBox(AppConstants.groupsBox),
      Hive.openBox(AppConstants.focusSessionsBox),
      Hive.openBox<String>(AppConstants.dailyMoodsBox),
      Hive.openBox(AppConstants.todoBox),
      Hive.openBox(AppConstants.countdownBox),
      Hive.openBox(AppConstants.stopwatchBox),
      Hive.openBox(AppConstants.pomodoroBox),
      Hive.openBox(AppConstants.focusItemsBox),
      Hive.openBox(AppConstants.focusDailySummaryBox),
    ]);
  }

  static Box get habitsBox => Hive.box(AppConstants.habitsBox);
  static Box get diaryBox => Hive.box(AppConstants.diaryBox);
  static Box get settingsBox => Hive.box(AppConstants.settingsBox);
  static Box get groupsBox => Hive.box(AppConstants.groupsBox);
  static Box get focusSessionsBox => Hive.box(AppConstants.focusSessionsBox);
  static Box<String> get dailyMoodsBox => Hive.box<String>(AppConstants.dailyMoodsBox);
  static Box get todoBox => Hive.box(AppConstants.todoBox);
  static Box<EisenhowerTask> get eisenhowerBox => Hive.box<EisenhowerTask>(AppConstants.eisenhowerBox);
  static Box get countdownBox => Hive.box(AppConstants.countdownBox);
  static Box get stopwatchBox => Hive.box(AppConstants.stopwatchBox);
  static Box get pomodoroBox => Hive.box(AppConstants.pomodoroBox);
  static Box get focusItemsBox => Hive.box(AppConstants.focusItemsBox);
  static Box get focusDailySummaryBox => Hive.box(AppConstants.focusDailySummaryBox);

  static Future<void> closeAll() async => Hive.close();
}
