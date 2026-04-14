import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker_ios/core/constants/app_constants.dart';
import 'package:habit_tracker_ios/features/eisenhower/data/models/eisenhower_task.dart';

/// Manages Hive initialisation and provides typed box accessors.
class HiveService {
  HiveService._();

  static String? _currentUid;

  static String _scopedName(String baseName) {
    if (_currentUid == null || _currentUid!.isEmpty) {
      throw StateError('Attempted to access Hive box $baseName without a logged in user UI. HiveService must be initialized with a UID first.');
    }
    return '${baseName}_$_currentUid';
  }

  static Future<void> init(String uid) async {
    _currentUid = uid;

    // Bypass path_provider (and its objective_c FFI dependency) entirely.
    // On iOS simulators with beta runtimes, path_provider crashes due to a
    // missing 'DOBJC_initializeApi' symbol. We construct the path ourselves
    // from the HOME environment variable which is always set by the OS.
    try {
      await Hive.initFlutter();
    } catch (_) {
      // Fallback: derive the documents path without path_provider
      String hivePath;
      try {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          hivePath = '$home/Documents';
          await Directory(hivePath).create(recursive: true);
        } else {
          hivePath = Directory.systemTemp.path;
        }
      } catch (_) {
        hivePath = Directory.systemTemp.path;
      }
      // ignore: avoid_print
      print('[HiveService] path_provider unavailable — using fallback: $hivePath');
      Hive.init(hivePath);
    }

    
    // Register Adapters if not already registered
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(QuadrantTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(EisenhowerTaskAdapter());
    }

    final scopedEisenhower = _scopedName(AppConstants.eisenhowerBox);

    // Boxes that need specific handling or are likely to have schema changes
    try {
      await Hive.openBox<EisenhowerTask>(scopedEisenhower);
    } catch (e) {
      // If we have a schema mismatch (common after adding non-nullable fields), 
      // we'll clear the box for a fresh start.
      await Hive.deleteBoxFromDisk(scopedEisenhower);
      await Hive.openBox<EisenhowerTask>(scopedEisenhower);
    }

    await Future.wait([
      Hive.openBox(_scopedName(AppConstants.habitsBox)),
      Hive.openBox(_scopedName(AppConstants.diaryBox)),
      Hive.openBox(_scopedName(AppConstants.settingsBox)),
      Hive.openBox(_scopedName(AppConstants.groupsBox)),
      Hive.openBox(_scopedName(AppConstants.focusSessionsBox)),
      Hive.openBox<String>(_scopedName(AppConstants.dailyMoodsBox)),
      Hive.openBox(_scopedName(AppConstants.todoBox)),
      Hive.openBox(_scopedName(AppConstants.countdownBox)),
      Hive.openBox(_scopedName(AppConstants.stopwatchBox)),
      Hive.openBox(_scopedName(AppConstants.pomodoroBox)),
      Hive.openBox(_scopedName(AppConstants.focusItemsBox)),
      Hive.openBox(_scopedName(AppConstants.focusDailySummaryBox)),
      Hive.openBox(_scopedName(AppConstants.coachBox)),
      Hive.openBox(_scopedName(AppConstants.timetableBox)),
      Hive.openBox(_scopedName(AppConstants.routineTemplatesBox)),
    ]);
  }

  static Box get habitsBox => Hive.box(_scopedName(AppConstants.habitsBox));
  static Box get diaryBox => Hive.box(_scopedName(AppConstants.diaryBox));
  static Box get settingsBox => Hive.box(_scopedName(AppConstants.settingsBox));
  static Box get groupsBox => Hive.box(_scopedName(AppConstants.groupsBox));
  static Box get focusSessionsBox => Hive.box(_scopedName(AppConstants.focusSessionsBox));
  static Box<String> get dailyMoodsBox => Hive.box<String>(_scopedName(AppConstants.dailyMoodsBox));
  static Box get todoBox => Hive.box(_scopedName(AppConstants.todoBox));
  static Box<EisenhowerTask> get eisenhowerBox => Hive.box<EisenhowerTask>(_scopedName(AppConstants.eisenhowerBox));
  static Box get countdownBox => Hive.box(_scopedName(AppConstants.countdownBox));
  static Box get stopwatchBox => Hive.box(_scopedName(AppConstants.stopwatchBox));
  static Box get pomodoroBox => Hive.box(_scopedName(AppConstants.pomodoroBox));
  static Box get focusItemsBox => Hive.box(_scopedName(AppConstants.focusItemsBox));
  static Box get focusDailySummaryBox => Hive.box(_scopedName(AppConstants.focusDailySummaryBox));
  static Box get coachBox => Hive.box(_scopedName(AppConstants.coachBox));
  static Box get timetableBox => Hive.box(_scopedName(AppConstants.timetableBox));
  static Box get routineTemplatesBox => Hive.box(_scopedName(AppConstants.routineTemplatesBox));

  static Future<void> closeAll() async {
    await Hive.close();
    _currentUid = null;
  }
}
