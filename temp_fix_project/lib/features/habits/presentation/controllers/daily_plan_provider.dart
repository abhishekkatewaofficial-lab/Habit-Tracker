import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_controller.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/daily_plan_service.dart';

/// Computed once from the current habit state.
/// Re-evaluates whenever habits change (e.g. one is completed).
final dailyPlanProvider = Provider<List<DailyPlanHabit>>((ref) {
  final allHabits = ref.watch(habitProvider);
  return DailyPlanService.computePlan(allHabits);
});
