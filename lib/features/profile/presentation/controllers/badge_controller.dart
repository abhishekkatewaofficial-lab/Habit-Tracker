import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_controller.dart';

class BadgeData {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final Color glowColor;
  final bool isUnlocked;

  BadgeData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.glowColor,
    required this.isUnlocked,
  });
}

// Emits unlocked badge IDs to trigger the UI popups.
final badgePopupQueueProvider = StateProvider<List<BadgeData>>((ref) => []);

final badgeControllerProvider = StateNotifierProvider<BadgeController, List<BadgeData>>((ref) {
  return BadgeController(ref);
});

class BadgeController extends StateNotifier<List<BadgeData>> {
  final Ref _ref;
  late final Box _settingsBox;
  
  BadgeController(this._ref) : super([]) {
    _settingsBox = HiveService.settingsBox;
    _evaluateBadges(_ref.read(habitProvider));
    
    // Listen to habit changes for new unlocks
    _ref.listen<List<Habit>>(habitProvider, (previous, next) {
      _evaluateBadges(next);
    });
  }

  void _evaluateBadges(List<Habit> habits) {
    // 1. Data Engine for Badges
    int bestStreak = 0;
    int tempStreak = 0;
    int totalCompletions = 0;

    final today = DateTime.now();
    for (int i = 365 * 2; i >= 0; i--) { // Look back up to 2 years for global streak
      final date = today.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      double dayPossible = 0;
      double dayActual = 0;
      
      for (final habit in habits) {
        final appWeekday = date.weekday % 7;
        final isActiveDay = habit.isEveryDay || habit.selectedDays.contains(appWeekday);
        
        if (isActiveDay && !habit.isQuitHabit) {
          double goal = habit.goalValue > 0 ? habit.goalValue.toDouble() : 1.0;
          double prog = (habit.dailyProgress[dateKey] ?? 0).clamp(0, habit.goalValue).toDouble();
          
          dayPossible += 1.0;
          dayActual += prog / goal;
          
          if (prog >= goal) totalCompletions++;
        }
      }
      
      if (dayPossible > 0) {
         if (dayActual >= (dayPossible - 0.001)) { // Perfect day
            tempStreak++;
            if (tempStreak > bestStreak) bestStreak = tempStreak;
         } else {
            tempStreak = 0;
         }
      }
    }
    
    // Persistent unlocked cache
    final List<String> unlockedIds = List<String>.from(_settingsBox.get('unlocked_badges', defaultValue: <String>[]));

    // Dynamic checks
    final conditions = {
      'first_step': totalCompletions >= 1,
      'streak_7': bestStreak >= 7,
      'streak_30': bestStreak >= 30,
      'streak_100': bestStreak >= 100,
      'master_100': totalCompletions >= 100,
      'master_500': totalCompletions >= 500,
    };
    
    List<BadgeData> newUnlocks = [];
    bool stateChanged = false;

    for (final entry in conditions.entries) {
      if (entry.value && !unlockedIds.contains(entry.key)) {
        unlockedIds.add(entry.key);
        stateChanged = true;
        // add to queue
        newUnlocks.add(_getBadgeConfig(entry.key, true)); 
      }
    }
    
    if (stateChanged) {
        _settingsBox.put('unlocked_badges', unlockedIds);
    }
    
    // Always build the full state array
    final newState = conditions.keys.map((id) {
       final isUnlocked = unlockedIds.contains(id);
       return _getBadgeConfig(id, isUnlocked);
    }).toList();

    state = newState;
    
    if (newUnlocks.isNotEmpty) {
      // Trigger side effect for popup
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentQueue = _ref.read(badgePopupQueueProvider);
        _ref.read(badgePopupQueueProvider.notifier).state = [...currentQueue, ...newUnlocks];
      });
    }
  }

  BadgeData _getBadgeConfig(String id, bool isUnlocked) {
     switch (id) {
      case 'first_step':
        return BadgeData(
          id: id,
          title: 'First Step',
          subtitle: '1 Habit',
          icon: CupertinoIcons.star_fill,
          gradientColors: const [Color(0xFFCD7F32), Color(0xFFFFDAB9), Color(0xFFB87333), Color(0xFFFCF6BA)],
          glowColor: const Color(0xFFCD7F32),
          isUnlocked: isUnlocked,
        );
      case 'streak_7':
        return BadgeData(
          id: id,
          title: '7-Day Streak',
          subtitle: 'Silver',
          icon: CupertinoIcons.flame_fill,
          gradientColors: const [Color(0xFFB5B5B5), Color(0xFFFFFFFF), Color(0xFF9E9E9E), Color(0xFFE0E0E0)],
          glowColor: const Color(0xFFE5E5EA),
          isUnlocked: isUnlocked,
        );
      case 'streak_30':
        return BadgeData(
          id: id,
          title: '30-Day Fire',
          subtitle: 'Gold',
          icon: CupertinoIcons.sun_max_fill,
          gradientColors: const [Color(0xFFBF953F), Color(0xFFFCF6BA), Color(0xFFB38728), Color(0xFFFBF5B7)],
          glowColor: const Color(0xFFFCF6BA),
          isUnlocked: isUnlocked,
        );
      case 'streak_100':
        return BadgeData(
          id: id,
          title: 'Centurion',
          subtitle: 'Platinum',
          icon: CupertinoIcons.shield_fill,
          gradientColors: const [Color(0xFF94A3B8), Color(0xFFF1F5F9), Color(0xFF64748B), Color(0xFFE2E8F0)],
          glowColor: const Color(0xFFF1F5F9),
          isUnlocked: isUnlocked,
        );
      case 'master_100':
        return BadgeData(
          id: id,
          title: 'Focus 100',
          subtitle: '100 Logs',
          icon: CupertinoIcons.check_mark_circled_solid,
          gradientColors: const [Color(0xFF10B981), Color(0xFFD1FAE5), Color(0xFF047857), Color(0xFFECFDF5)],
          glowColor: const Color(0xFF10B981),
          isUnlocked: isUnlocked,
        );
      case 'master_500':
        return BadgeData(
          id: id,
          title: 'Titan',
          subtitle: '500 Logs',
          icon: CupertinoIcons.star_circle_fill,
          gradientColors: const [Color(0xFF8B5CF6), Color(0xFFDDD6FE), Color(0xFF6D28D9), Color(0xFFEDE9FE)],
          glowColor: const Color(0xFF8B5CF6),
          isUnlocked: isUnlocked,
        );
      default:
        throw Exception('Unknown badge id: $id');
     }
  }
}
