import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker_ios/core/constants/app_colors.dart';
import 'package:habit_tracker_ios/core/constants/app_constants.dart';
import 'package:habit_tracker_ios/core/constants/app_text_styles.dart';
import 'package:habit_tracker_ios/shared_widgets/app_bottom_nav_bar.dart';
import 'package:habit_tracker_ios/providers/navigation_provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:habit_tracker_ios/features/focus_timer/presentation/pages/focus_timer_screen.dart';
import 'package:habit_tracker_ios/features/focus_timer/presentation/pages/focus_dashboard_screen.dart';
import 'package:habit_tracker_ios/features/diary/presentation/pages/diary_screen.dart';
import 'package:habit_tracker_ios/features/reports/presentation/pages/reports_screen.dart';
import 'package:habit_tracker_ios/features/habits/presentation/pages/add_edit_habit_screen.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_controller.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_filter_controller.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/daily_plan_provider.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/daily_plan_service.dart';
import 'package:habit_tracker_ios/features/mood/presentation/controllers/mood_controller.dart';
import 'package:habit_tracker_ios/features/todo/presentation/pages/todo_home_screen.dart';
import 'package:habit_tracker_ios/features/eisenhower/presentation/pages/eisenhower_matrix_screen.dart';
import 'package:habit_tracker_ios/features/countdown/presentation/pages/countdown_screen.dart';
import 'package:habit_tracker_ios/features/focus_timer/presentation/pages/stopwatch_screen.dart';
import 'package:habit_tracker_ios/features/profile/presentation/controllers/badge_controller.dart';
import 'package:habit_tracker_ios/features/profile/presentation/pages/profile_screen.dart';
import 'package:habit_tracker_ios/features/profile/presentation/controllers/profile_controller.dart';
import 'package:habit_tracker_ios/shared_widgets/adaptive_layout.dart';
import 'package:habit_tracker_ios/core/services/anti_cheat_service.dart';
import 'package:habit_tracker_ios/features/profile/presentation/controllers/global_reward_tracker.dart';
import 'package:habit_tracker_ios/features/profile/presentation/controllers/coin_controller.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/streak_protection_controller.dart';
import 'package:habit_tracker_ios/core/services/step_tracking_service.dart';
import 'package:habit_tracker_ios/features/habits/presentation/pages/step_permission_screen.dart';

/// Root scaffold that owns the bottom nav and swaps feature screens.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const List<Widget> _screens = [
    _HabitsTab(),
    SizedBox.shrink(), // Index 1: Focus Main Tab (Dummy, opens sub-dock)
    DiaryScreen(),
    SizedBox.shrink(), // Index 3: Planner Main Tab (Dummy, opens sub-dock)
    ReportsScreen(), // Index 4: Reports
    TodoHomeScreen(), // Index 5
    EisenhowerMatrixScreen(), // Index 6
    FocusDashboardScreen(), // Index 7
    FocusTimerScreen(), // Index 8: Pomodoro
    StopwatchScreen(), // Index 9: Stopwatch
    CountdownScreen(), // Index 10: Countdown
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Badge Unlock Listener (Event-Driven Popup System) ──
    ref.listen<List<BadgeData>>(badgePopupQueueProvider, (previous, next) {
      if (next.isNotEmpty &&
          (previous == null ||
              previous.length < next.length ||
              previous.first.id != next.first.id)) {
        final badge = next.first;
        showGeneralDialog(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'Badge Unlocked',
          barrierColor: Colors.black.withValues(alpha: 0.85),
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, anim1, anim2) =>
              _BadgeUnlockPopup(badge: badge),
          transitionBuilder: (context, anim1, anim2, child) {
            return ScaleTransition(
              scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
              child: FadeTransition(opacity: anim1, child: child),
            );
          },
        ).then((_) {
          // Dequeue after popup is dismissed
          final currentQueue = ref.read(badgePopupQueueProvider);
          if (currentQueue.isNotEmpty) {
            ref.read(badgePopupQueueProvider.notifier).state =
                currentQueue.sublist(1);
          }
        });
      }
    });

    // ── Reward Cap Notification Listener ──────────────────────────────────────────
    // Fires at most ONCE per day when the user completes their 6th+ habit.
    // The controller tracks the date — prevents repeated popups on same day.
    ref.listen<bool>(rewardCapNotifyProvider, (_, notify) {
      if (!notify) return;
      ref.read(rewardCapNotifyProvider.notifier).state = false; // reset pulse
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Daily reward limit reached',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2C2C2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(seconds: 3),
        ),
      );
    });

    // ── +10 Coins Reward Animation ───────────────────────────────────────────
    // Fires a premium animated toast whenever coins are successfully granted.
    ref.listen<bool>(coinRewardedProvider, (_, rewarded) {
      if (!rewarded) return;
      ref.read(coinRewardedProvider.notifier).state = false; // reset pulse
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient gold coin icon inline
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFD700), Color(0xFFFFC300)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.star_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                '+10 Coins',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1C1C1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(milliseconds: 1800),
          elevation: 8,
        ),
      );
    });

    // ── First-time Onboarding Welcome Coins ──────────────────────────────────
    ref.listen<bool>(welcomeCoinsGrantedProvider, (_, granted) {
      if (!granted) return;
      ref.read(welcomeCoinsGrantedProvider.notifier).state = false; // Reset
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF9333EA),
                      Color(0xFFC084FC)
                    ], // Purple magic
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF9333EA).withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.redeem_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome!',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    '🎁 You received 1000 coins',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1C1C1E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(seconds: 4),
          elevation: 8,
        ),
      );
    });

    // ── -50 Coins Deduction Toast ────────────────────────────────────────────
    // Fires when streak protection is purchased with coins.
    ref.listen<bool>(coinDeductedProvider, (_, deducted) {
      if (!deducted) return;
      ref.read(coinDeductedProvider.notifier).state = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFC9A227), Color(0xFFFFD700)],
                  ),
                ),
                child: const Icon(Icons.star_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                '-50 Coins',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF3A3A3C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(milliseconds: 1800),
          elevation: 8,
        ),
      );
    });

    // ── Streak Protection Modal Trigger ─────────────────────────────────────
    final streakCandidates = ref.watch(streakBreakCandidatesProvider);
    final reminderState = ref.watch(streakReminderStateProvider);

    if (streakCandidates.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!context.mounted) return;

        final candidates = ref.read(streakBreakCandidatesProvider);
        if (candidates.isEmpty) return;

        final notifier = ref.read(streakReminderStateProvider.notifier);
        if (!notifier.shouldShowReminder()) return;

        // Compute the "what if it was protected" streak for all candidates
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
        final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);

        final streakAtRiskMap = <String, int>{};
        final currentProtected = ref.read(streakProtectionProvider);
        for (final habit in candidates) {
          final mockProtected = {
            ...currentProtected,
            '${habit.id}_$yesterdayStr'
          };
          streakAtRiskMap[habit.id] =
              calculateHabitStreakWithProtection(habit, mockProtected);
        }

        // Mark it as shown (increments count, sets timestamp)
        notifier.markShown();

        final savedCount = await _showStreakProtectionModal(
            context, ref, candidates, yesterdayStr, streakAtRiskMap);

        if (!context.mounted) return;

        if (savedCount != null) {
          // Flow finalized (user clicked Use Coins or Let it break)
          notifier.dismissPermanently();

          if (savedCount > 0) {
            ref.read(streakReminderProvider.notifier).state = null;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 10),
                    Text(
                      'Saved $savedCount streak${savedCount > 1 ? 's' : ''}!',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFFFF6B35),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                margin:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                duration: const Duration(seconds: 3),
                elevation: 8,
              ),
            );
          }
        } else {
          // User soft-dismissed (tapped outside) → set soft reminder banner for first habit
          ref.read(streakReminderProvider.notifier).state = candidates.first;
        }
      });
    }

    final index = ref.watch(navigationIndexProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody:
          true, // CRITICAL: Allows content to scroll behind the floating dock
      body: _LazyIndexedStack(index: index, children: _screens),
      bottomNavigationBar: const AppBottomNavBar(),
      floatingActionButton: index == AppConstants.navIndexHome
          ? _GlassAddButton(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEditHabitScreen()),
                );
              },
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ── Habits tab ────────────────────────────────────────────────────────────────
class _HabitsTab extends ConsumerWidget {
  const _HabitsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(filteredHabitsProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final todayStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final activeFilter = ref.watch(habitFilterProvider);
    // Protected days: used by streak chip to show accurate protected streak
    final protectedDays = ref.watch(streakProtectionProvider);

    // entryState is evaluated per-habit inside _HabitCard (uses habit.startDate)

    double totalProgressSum = 0;
    int validHabitsCount = 0;
    for (final habit in habits) {
      final dailyGoal = habit.goalFor(todayStr);
      if (dailyGoal > 0) {
        final currentVal = habit.dailyProgress[todayStr] ?? 0;
        final p = (currentVal / dailyGoal).clamp(0.0, 1.0);
        totalProgressSum += p;
        validHabitsCount++;
      }
    }
    final overallProgress =
        validHabitsCount == 0 ? 0.0 : totalProgressSum / validHabitsCount;

    // ── Step auto-fill: fetch once per foreground session ──────────────────────
    // Only runs if permission is already granted. Does NOT show permission screen
    // here — that's triggered from the habit card on first tap/view.
    final stepPermission = ref.watch(stepPermissionProvider);
    if (stepPermission == StepPermissionState.granted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (ref.read(todayStepCountProvider) == null) {
          await StepTrackingService.fetchTodaySteps(ref);
        }
      });
    }

    return AdaptiveBody(
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left: Greeting Section
                    const Expanded(
                      child: _GreetingSection(padding: EdgeInsets.zero),
                    ),
                    const SizedBox(width: 16),
                    // Right (Vertical Stack): Profile/Mood + Filter Button
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ProfileButton(),
                            SizedBox(width: 12),
                            _MoodSelectorButton(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _FilterButton(activeFilter: activeFilter),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const SliverToBoxAdapter(child: _DateStrip()),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
                child: _SemiCircleProgress(progress: overallProgress)),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            const SliverToBoxAdapter(
                child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SmartDailyPlanCard(),
            )),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            // Soft streak reminder banner (shown after modal is dismissed)
            const SliverToBoxAdapter(child: _StreakReminderBanner()),
            if (habits.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Text(
                      'No habits yet. Tap + to start!',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 16),
                    ),
                  ),
                ),
              )
            else
              SliverReorderableList(
                itemBuilder: (context, i) =>
                    ReorderableDelayedDragStartListener(
                  key: ValueKey(habits[i].id),
                  index: i,
                  child:
                      _HabitCard(habit: habits[i], dateStr: todayStr, index: i),
                ),
                itemCount: habits.length,
                onReorder: (oldIndex, newIndex) {
                  ref
                      .read(habitProvider.notifier)
                      .reorderHabits(oldIndex, newIndex);
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

// ── Lazy Indexed Stack ────────────────────────────────────────────────────────
// Builds each tab's widget tree only the first time it is selected, then keeps
// it alive with Offstage so state (scroll position, providers) is preserved.
// This prevents all 11 screens from initializing simultaneously on cold launch,
// which was a major cause of the Android black screen.
class _LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _LazyIndexedStack({
    required this.index,
    required this.children,
  });

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late final List<bool> _activated;

  @override
  void initState() {
    super.initState();
    // Only the initial tab is built on startup; all others are deferred
    _activated = List.generate(
      widget.children.length,
      (i) => i == widget.index,
    );
  }

  @override
  void didUpdateWidget(_LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Mark the newly selected tab as activated (builds it for the first time)
    if (!_activated[widget.index]) {
      setState(() => _activated[widget.index] = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(widget.children.length, (i) {
        if (!_activated[i]) return const SizedBox.shrink();
        return Offstage(
          offstage: i != widget.index,
          child: TickerMode(
            enabled: i == widget.index,
            child: widget.children[i],
          ),
        );
      }),
    );
  }
}

// ── Smart Daily Plan Card ─────────────────────────────────────────────────────

class SmartDailyPlanCard extends ConsumerStatefulWidget {
  const SmartDailyPlanCard({super.key});

  @override
  ConsumerState<SmartDailyPlanCard> createState() => _SmartDailyPlanCardState();
}

class _SmartDailyPlanCardState extends ConsumerState<SmartDailyPlanCard> {
  bool _expanded = false;
  final Set<String> _fadingOut = {};

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(dailyPlanProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allHabits = ref.watch(habitProvider);
    final today = DateTime.now();

    final todayHabitsExist = allHabits.any((h) {
      if (h.isEveryDay) return true;
      final appDay = today.weekday % 7;
      return h.selectedDays.contains(appDay);
    });

    if (!todayHabitsExist) return const SizedBox.shrink();

    final allDone = plan.isEmpty;

    // ── THEME TOKENS ──────────────────────────────────────────────
    final primaryText = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final subtleText =
        isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF6B6B6B);

    // Light-mode tag colors per reason
    Color tagBg(DailyPlanTag tag) {
      if (isDark) return Colors.white.withValues(alpha: 0.08);
      switch (tag) {
        case DailyPlanTag.missedYesterday:
          return const Color(0xFFFFF1F1);
        case DailyPlanTag.atRisk:
          return const Color(0xFFFFF6E5);
        case DailyPlanTag.weakConsistency:
          return const Color(0xFFEEF3FF);
        case DailyPlanTag.doNow:
          return const Color(0xFFF0F0F5);
      }
    }

    Color tagText(DailyPlanTag tag) {
      if (isDark) return Colors.white.withValues(alpha: 0.55);
      switch (tag) {
        case DailyPlanTag.missedYesterday:
          return const Color(0xFFE05A5A);
        case DailyPlanTag.atRisk:
          return const Color(0xFFD98C00);
        case DailyPlanTag.weakConsistency:
          return const Color(0xFF4A6CF7);
        case DailyPlanTag.doNow:
          return Colors.black.withValues(alpha: 0.45);
      }
    }

    Widget tagChip(DailyPlanHabit p) {
      if (isDark) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: tagBg(p.tag),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            p.tagLabel,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: tagText(p.tag),
            ),
          ),
        );
      }
      // Light mode → pure text
      return Text(
        p.tagLabel,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: tagText(p.tag),
        ),
      );
    }

    Widget priorityBadge() {
      if (isDark) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'Priority today',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        );
      }
      // Light mode → pure text
      return Text(
        'Priority today',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFFD7618),
          letterSpacing: 0.2,
        ),
      );
    }

    // ── CARD WRAPPER ─────────────────────────────────────────────
    Widget cardContent = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ───────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!allDone) const Text('🔥', style: TextStyle(fontSize: 15)),
              if (!allDone) const SizedBox(width: 8),
              Expanded(
                child: allDone
                    ? Row(
                        children: [
                          const Text('✅ ', style: TextStyle(fontSize: 15)),
                          Expanded(
                            child: Text(
                              'All habits completed today',
                              style: GoogleFonts.fredoka(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: primaryText,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _expanded
                                ? "Today's Plan"
                                : "Focus today  ·  ${plan.map((p) => p.habit.name).join(' • ')}",
                            style: GoogleFonts.fredoka(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: primaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!_expanded)
                            Text(
                              'Tap to see your priority habits',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: subtleText,
                              ),
                            ),
                        ],
                      ),
              ),
              if (!allDone) ...[
                const SizedBox(width: 6),
                priorityBadge(),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 280),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: subtleText,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),

          // ── Expanded habit list ──────────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: _expanded && !allDone
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Stay consistent today',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: subtleText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...plan.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final p = entry.value;
                        final isFading = _fadingOut.contains(p.habit.id);
                        final isFirst = idx == 0;

                        return AnimatedOpacity(
                          key: ValueKey(p.habit.id),
                          opacity: isFading ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOut,
                          child: AnimatedSlide(
                            offset:
                                isFading ? const Offset(-0.05, 0) : Offset.zero,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOut,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.habit.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: isFirst && !isDark ? 14 : 13,
                                        fontWeight: isFirst && !isDark
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: primaryText,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  tagChip(p),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );

    // ── CARD DECORATION (light vs dark) ─────────────────────────
    if (isDark) {
      return GestureDetector(
        onTap: allDone ? null : () => setState(() => _expanded = !_expanded),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: cardContent,
        ),
      );
    }

    // ── LIGHT MODE: glassmorphism + accent strip + soft shadow ─────
    return GestureDetector(
      onTap: allDone ? null : () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), // softer shadow
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: cardContent,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Greeting Section ───────────────────────────────────────────────────────────
class _GreetingSection extends ConsumerWidget {
  final EdgeInsetsGeometry padding;
  const _GreetingSection(
      {this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 12)});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final userName = profile.name.trim();
    final greeting = _getGreeting();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Line 1: "Good morning," — prominent, bold
          Text(
            userName.isNotEmpty ? '$greeting,' : greeting,
            style: isDark
                ? const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEEEEEE),
                    height: 1.2,
                  )
                : GoogleFonts.nunito(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A1A),
                    height: 1.2,
                  ),
          ),
          // Line 2: Name — very large, ultra-bold, dominant
          if (userName.isNotEmpty)
            Text(
              userName,
              style: isDark
                  ? const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                    )
                  : GoogleFonts.nunito(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                      height: 1.15,
                    ),
            ),
        ],
      ),
    );
  }
}

// ── Semi-Circle Progress ───────────────────────────────────────────────────────
class _SemiCircleProgress extends StatelessWidget {
  final double progress; // 0.0 – 1.0
  const _SemiCircleProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arcColor = isDark ? const Color(0xFF4DA6FF) : const Color(0xFFF5A623);
    final trackColor =
        isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA);
    final pctColor = isDark ? Colors.white : Colors.black;
    final subColor = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF333333);
    final percent = (progress * 100).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: SizedBox(
          width: 280,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Arc painter — fixed size, no dynamic scaling
              CustomPaint(
                size: const Size(280, 140),
                painter: _ArcPainter(
                  progress: progress,
                  trackColor: trackColor,
                  arcColor: arcColor,
                  strokeWidth: 18,
                ),
              ),
              // Center text
              Positioned(
                bottom: 4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: isDark
                          ? TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: pctColor,
                              height: 1.0,
                            )
                          : GoogleFonts.nunito(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              color: pctColor,
                              height: 1.0,
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Plans made today',
                      style: isDark
                          ? TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: subColor,
                            )
                          : GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: subColor,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color arcColor;
  final double strokeWidth;

  const _ArcPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const center = Offset(140, 130); // Fixed center based on 280x140 container
    const radius = 120.0; // Fixed radius — never recalculates

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Full half-circle track (180°)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi, // start at 9-o'clock (left)
      math.pi, // sweep 180° to 3-o'clock (right)
      false,
      trackPaint,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.arcColor != arcColor;
}

// ── Date Strip ────────────────────────────────────────────────────────────────
class _DateStrip extends ConsumerStatefulWidget {
  const _DateStrip();

  @override
  ConsumerState<_DateStrip> createState() => _DateStripState();
}

class _DateStripState extends ConsumerState<_DateStrip> {
  late ScrollController _scrollController;
  final int _range = 1000; // Large range for scrolling (past and future)
  late DateTime _todayMidnight;
  late List<DateTime> _dates;
  late int _todayIndex;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _todayMidnight = DateTime(today.year, today.month, today.day);

    // Generate dates: Today is in the middle of the range
    _todayIndex = _range ~/ 2;
    _dates = List.generate(
        _range, (i) => _todayMidnight.add(Duration(days: i - _todayIndex)));

    _scrollController = ScrollController();

    // Auto-scroll to Today (centered) after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth = screenWidth / 7;
      // We want TODAY to be the 4th item (index 3 in a 0-6 view)
      final targetOffset = (_todayIndex * itemWidth) - (3 * itemWidth);
      _scrollController.jumpTo(targetOffset);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final itemWidth = MediaQuery.of(context).size.width / 7;

    return SizedBox(
      height: 80,
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _dates.length,
        itemBuilder: (context, i) {
          final date = _dates[i];
          final isSelected = DateFormat('yyyy-MM-dd').format(date) ==
              DateFormat('yyyy-MM-dd').format(selectedDate);

          return SizedBox(
            width: itemWidth,
            child: GestureDetector(
              onTap: () => ref.read(selectedDateProvider.notifier).state = date,
              child: _DateChip(date: date, isSelected: isSelected),
            ),
          );
        },
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date, required this.isSelected});
  final DateTime date;
  final bool isSelected;

  static const _days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = date.day == today.day &&
        date.month == today.month &&
        date.year == today.year;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isDark) {
      // Light Mode Override: Premium Rounded Square Theme
      final todayMidnight = DateTime(today.year, today.month, today.day);
      final chipDate = DateTime(date.year, date.month, date.day);
      final isPast = chipDate.isBefore(todayMidnight);

      Color bgColor;
      Color textColor;

      if (isSelected) {
        bgColor = const Color(0xFF1A1A1A); // Soft black
        textColor = Colors.white;
      } else if (isPast || isToday) {
        // Highlighted Days (Past and Today, assuming past habits complete)
        bgColor = const Color(0xFFB9EB6F); // Updated pastel green
        textColor = const Color(0xFF1A1A1A); // Match soft black text
      } else {
        // Normal Future Days
        bgColor = const Color(0xFFF2F2F2); // Light grey
        textColor = const Color(0xFF1A1A1A); // Match soft black text
      }

      const daysLight = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: GoogleFonts.nunito(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                daysLight[date.weekday - 1],
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ORIGINAL DARK MODE UI (UNTOUCHED)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _days[date.weekday - 1],
            style: AppTextStyles.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.accent)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppColors.outline.withAlpha(100)),
                width: isSelected ? 2 : 1,
              ),
              color: isSelected
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.transparent)
                  : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: Text(
              '${date.day}',
              style: AppTextStyles.labelLarge.copyWith(
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.accent)
                    : (isDark
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          if (isToday)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.green,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Habit Card ────────────────────────────────────────────────────────────────
class _HabitCard extends ConsumerWidget {
  final Habit habit;
  final String dateStr;
  final int index;

  const _HabitCard({
    required this.habit,
    required this.dateStr,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawProgress = habit.dailyProgress[dateStr] ?? 0;
    final dailyGoal = habit.goalFor(dateStr);

    // ── Step Auto-fill (sensor takes effect only if no manual override today) ──
    int currentProgressValue = rawProgress;
    if (habit.goalUnit == 'steps') {
      final stepPermission = ref.read(stepPermissionProvider);
      if (stepPermission == StepPermissionState.notDetermined) {
        // First time: show permission screen instead of blocking render.
        // We schedule it post-frame to not interfere with Flutter's build pass.
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!context.mounted) return;
          // Check again — another card may have already triggered the flow.
          if (ref.read(stepPermissionProvider) !=
              StepPermissionState.notDetermined) return;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const StepPermissionScreen()),
          );
          if (!context.mounted) return;
          // Fetch immediately after permission granted
          if (ref.read(stepPermissionProvider) == StepPermissionState.granted) {
            await StepTrackingService.fetchTodaySteps(ref);
          }
        });
      } else if (stepPermission == StepPermissionState.granted) {
        // Manual override takes priority — don't overwrite if user set it manually today.
        final hasManual = StepTrackingService.hasManualOverrideToday(habit.id);
        if (!hasManual) {
          final sensorSteps = ref.watch(todayStepCountProvider);
          if (sensorSteps != null && sensorSteps > rawProgress) {
            currentProgressValue = sensorSteps.clamp(0, dailyGoal);
          }
        }
      }
    }
    final isCompletedToday = currentProgressValue >= dailyGoal;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = Color(habit.colorValue);
    final progress = (currentProgressValue / dailyGoal).clamp(0.0, 1.0);

    // Per-habit entry state: preStart gate fires first, then anti-cheat local logic
    final entryState = AntiCheatService.getEntryState(
      dateStr,
      habitStartDate: habit.startDate,
    );

    // Derive individual flags from centralized entry state
    final isPreStart = entryState == HabitEntryState.preStart;
    final isFuture = entryState == HabitEntryState.future;
    final isLockedPast = entryState == HabitEntryState.lockedFinal;
    final isGrace = entryState == HabitEntryState.grace;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        // preStart should not look disabled or ghosted, just neutral
        opacity: isFuture ? 0.6 : (isLockedPast ? 0.75 : 1.0),
        child: Slidable(
          key: ValueKey(habit.id),
          enabled: !isFuture && !isLockedPast && !isPreStart,
          startActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: 0.2,
            children: [
              SlidableAction(
                onPressed: (context) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditHabitScreen(existingHabit: habit),
                    ),
                  );
                },
                backgroundColor: const Color(0xFF3B82F6).withAlpha(40),
                foregroundColor: const Color(0xFF3B82F6),
                icon: Icons.edit_rounded,
                borderRadius: BorderRadius.circular(16),
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            extentRatio: 0.2,
            children: [
              SlidableAction(
                onPressed: (context) async {
                  final confirmed = await showCupertinoDialog<bool>(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text('Delete Habit?'),
                      content: Text(
                          'Are you sure you want to delete "${habit.name}"?'),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    ref.read(habitProvider.notifier).deleteHabit(habit.id);
                  }
                },
                backgroundColor: const Color(0xFFEF4444).withAlpha(40),
                foregroundColor: const Color(0xFFEF4444),
                icon: Icons.delete_outline_rounded,
                borderRadius: BorderRadius.circular(16),
              ),
            ],
          ),
          child: GestureDetector(
            onLongPress: () => _showHabitAnalytics(context, habit),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 72,
                  color: isDark
                      ? Theme.of(context).colorScheme.surface
                      : baseColor.withValues(alpha: 0.18),
                  child: Stack(
                    children: [
                      // Internal Progress Bar
                      AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        widthFactor: progress,
                        heightFactor: 1.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : baseColor.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      // Content
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(habit.icon ?? '✨',
                                style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Habit name
                                  Text(
                                    habit.name,
                                    style: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          )
                                        : GoogleFonts.nunito(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                          ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  // Progress pill + streak chip side by side
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      _ProgressPill(
                                        current: currentProgressValue,
                                        total: dailyGoal,
                                        unit: habit.goalUnit,
                                        color: isDark
                                            ? Colors.transparent
                                            : baseColor,
                                      ),
                                      Consumer(builder: (context, ref, _) {
                                        final protectedDays =
                                            ref.watch(streakProtectionProvider);
                                        final streak =
                                            calculateHabitStreakWithProtection(
                                                habit, protectedDays);
                                        if (streak == 0)
                                          return const SizedBox.shrink();
                                        return Container(
                                          margin:
                                              const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surface
                                                .withValues(alpha: 0.85),
                                            borderRadius:
                                                BorderRadius.circular(100),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.white
                                                      .withValues(alpha: 0.15)
                                                  : baseColor.withValues(
                                                      alpha: 0.5),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                CupertinoIcons.flame_fill,
                                                size: 10,
                                                color: isDark
                                                    ? Colors.white70
                                                    : baseColor,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '${streak}d',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            _PremiumCompleteButton(
                              isCompleted: isCompletedToday,
                              entryState: entryState,
                              color: baseColor,
                              onTap: () {
                                // Pre-start: completely silent — no snackbar, no interaction
                                if (isPreStart) return;
                                if (isLockedPast) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Past records are locked to maintain accuracy."),
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                if (isFuture) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "You can't update future habits"),
                                      behavior: SnackBarBehavior.floating,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                if (isGrace) {
                                  // Grace window: allow update but show subtle reminder
                                  ScaffoldMessenger.of(context)
                                      .clearSnackBars();
                                }
                                if (dailyGoal == 1) {
                                  final current =
                                      habit.dailyProgress[dateStr] ?? 0;
                                  final newValue = current >= 1 ? 0 : 1;

                                  if (newValue == 1 &&
                                      current == 0 &&
                                      habit.rewardsClaimed[dateStr] == true) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: const [
                                            Icon(Icons.check_circle_outline,
                                                color: Colors.white, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                                "Reward already claimed for today"),
                                          ],
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                        backgroundColor: Colors.grey[800],
                                      ),
                                    );
                                  }
                                  ref
                                      .read(habitProvider.notifier)
                                      .setHabitProgress(
                                          habit.id, dateStr, newValue);
                                } else {
                                  _showUpdateProgressPopup(
                                      context, ref, habit, dateStr);
                                }
                              },
                            ),
                            const SizedBox(width: 12),
                            ReorderableDragStartListener(
                              index: index,
                              child: Icon(
                                CupertinoIcons.line_horizontal_3,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.3),
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showUpdateProgressPopup(
      BuildContext context, WidgetRef ref, Habit habit, String dateStr) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Update Progress',
      barrierColor: Colors.black.withValues(alpha: 0.3), // matches request
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        final dailyGoal = habit.goalFor(dateStr);
        final current = habit.dailyProgress[dateStr] ?? 0;
        return _UpdateProgressPopup(
          habit: habit,
          dateStr: dateStr,
          currentValue: current,
          onSave: (val) {
            if (val >= dailyGoal &&
                current < dailyGoal &&
                habit.rewardsClaimed[dateStr] == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: const [
                      Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text("Reward already claimed for today"),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.grey[800],
                ),
              );
            }
            ref
                .read(habitProvider.notifier)
                .setHabitProgress(habit.id, dateStr, val);
            // Mark manual override so sensor auto-fill doesn't overwrite this today
            if (habit.goalUnit == 'steps') {
              StepTrackingService.markManualOverride(habit.id);
            }
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }
}

class _ProgressPill extends StatelessWidget {
  final int current;
  final int total;
  final String unit;
  final Color color;

  const _ProgressPill({
    required this.current,
    required this.total,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '$current/$total $unit',
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _PremiumCompleteButton extends StatefulWidget {
  final bool isCompleted;
  final HabitEntryState entryState;
  final Color color;
  final VoidCallback onTap;

  const _PremiumCompleteButton({
    required this.isCompleted,
    required this.entryState,
    required this.color,
    required this.onTap,
  });

  @override
  State<_PremiumCompleteButton> createState() => _PremiumCompleteButtonState();
}

class _PremiumCompleteButtonState extends State<_PremiumCompleteButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isPreStart = widget.entryState == HabitEntryState.preStart;
    final isFuture = widget.entryState == HabitEntryState.future;
    final isLockedPast = widget.entryState == HabitEntryState.lockedFinal;
    final isGrace = widget.entryState == HabitEntryState.grace;
    final isDisabled = isPreStart || isFuture || isLockedPast;

    // Amber tint for grace window
    const amberGrace = Color(0xFFF59E0B);

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _controller.forward(),
      onTapUp: isDisabled ? null : (_) => _controller.reverse(),
      onTapCancel: isDisabled ? null : () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // preStart: soft neutral grey circle (very light grey)
            color: isPreStart
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05))
                : isLockedPast
                    ? Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.5)
                    : isFuture
                        ? Colors.grey.withValues(alpha: 0.2)
                        : (widget.isCompleted
                            ? (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : AppColors.success)
                            : Theme.of(context)
                                .colorScheme
                                .surface
                                .withAlpha(200)),
            border: isPreStart
                ? null
                : (isGrace && !widget.isCompleted
                    ? Border.all(
                        color: amberGrace.withValues(alpha: 0.7), width: 1.5)
                    : (widget.isCompleted && isDark
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.0)
                        : null)),
            boxShadow: [
              if (!isDisabled) ...[
                if (isGrace && !widget.isCompleted)
                  BoxShadow(
                    color: amberGrace.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                else if (!widget.isCompleted || !isDark)
                  BoxShadow(
                    color: (widget.isCompleted
                            ? AppColors.success
                            : Theme.of(context).colorScheme.shadow)
                        .withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                if (widget.isCompleted)
                  BoxShadow(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : AppColors.success.withValues(alpha: 80),
                    blurRadius: isDark ? 10 : 12,
                    spreadRadius: isDark ? 0 : 1,
                  ),
              ]
            ],
          ),
          // preStart: no icon at all — completely blank circle
          child: isPreStart
              ? const SizedBox.shrink()
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    isLockedPast
                        ? CupertinoIcons.lock_fill
                        : widget.isCompleted
                            ? CupertinoIcons.checkmark_alt
                            : CupertinoIcons.add,
                    key: ValueKey('${widget.isCompleted}_${widget.entryState}'),
                    color: isLockedPast
                        ? Colors.grey.withValues(alpha: 0.4)
                        : isFuture
                            ? Colors.grey.withValues(alpha: 0.5)
                            : (widget.isCompleted
                                ? Colors.white
                                : (isGrace
                                    ? amberGrace.withValues(alpha: 0.8)
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7))),
                    size: 18,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Filter Button ─────────────────────────────────────────────────────────────
class _FilterButton extends StatefulWidget {
  final HabitFilter activeFilter;
  const _FilterButton({required this.activeFilter});

  @override
  State<_FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<_FilterButton> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  String get _filterTitle {
    switch (widget.activeFilter) {
      case HabitFilter.all:
        return 'All';
      case HabitFilter.completed:
        return 'Completed';
      case HabitFilter.pending:
        return 'Pending';
    }
  }

  void _toggleDropdown() {
    if (_overlayEntry == null) {
      _showDropdown();
    } else {
      _hideDropdown();
    }
  }

  void _showDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: _hideDropdown,
            behavior: HitTestBehavior.translucent,
            child: Container(
              color: Colors.transparent,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
            ),
          ),
          Positioned(
            width: 200,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(size.width - 200, size.height + 8),
              child: _FilterDropdownMenu(
                onSelected: (filter) {
                  _hideDropdown();
                  // ref is not available here easily if we are a regular State,
                  // but we'll use a ConsumerStatefulWidget instead.
                },
                activeFilter: widget.activeFilter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : AppColors.accent,
            borderRadius: BorderRadius.circular(20),
            border: isDark
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.1), width: 1)
                : null,
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  _filterTitle,
                  style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterDropdownMenu extends ConsumerStatefulWidget {
  final Function(HabitFilter) onSelected;
  final HabitFilter activeFilter;
  const _FilterDropdownMenu(
      {required this.onSelected, required this.activeFilter});

  @override
  ConsumerState<_FilterDropdownMenu> createState() =>
      _FilterDropdownMenuState();
}

class _FilterDropdownMenuState extends ConsumerState<_FilterDropdownMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ScaleTransition(
        scale: _animation,
        alignment: Alignment.topLeft,
        child: FadeTransition(
          opacity: _animation,
          child: Container(
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildOption(
                          HabitFilter.all, 'All', CupertinoIcons.layers_fill),
                      _buildOption(HabitFilter.completed, 'Completed',
                          CupertinoIcons.checkmark_circle_fill),
                      _buildOption(HabitFilter.pending, 'Pending',
                          CupertinoIcons.clock_fill),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption(HabitFilter filter, String title, IconData icon) {
    final isSelected = widget.activeFilter == filter;
    return GestureDetector(
      onTap: () {
        ref.read(habitFilterProvider.notifier).state = filter;
        widget.onSelected(filter);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? AppColors.accent
                  : Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.accent
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              const Icon(CupertinoIcons.checkmark_alt,
                  size: 16, color: AppColors.accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpdateProgressPopup extends StatefulWidget {
  final Habit habit;
  final String dateStr;
  final int currentValue;
  final Function(int) onSave;

  const _UpdateProgressPopup({
    required this.habit,
    required this.dateStr,
    required this.currentValue,
    required this.onSave,
  });

  @override
  State<_UpdateProgressPopup> createState() => _UpdateProgressPopupState();
}

class _UpdateProgressPopupState extends State<_UpdateProgressPopup> {
  late double _currentSelection;

  @override
  void initState() {
    super.initState();
    _currentSelection = widget.currentValue.toDouble();
  }

  void _onManualInput() {
    showDialog(
      context: context,
      builder: (context) {
        final controller =
            TextEditingController(text: _currentSelection.toInt().toString());
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Manual Entry',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  cursorColor: isDark ? Colors.white : Colors.blue,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final val = int.tryParse(controller.text) ??
                              _currentSelection.toInt();
                          final dailyGoal =
                              widget.habit.goalFor(widget.dateStr);
                          setState(() => _currentSelection =
                              val.clamp(0, dailyGoal).toDouble());
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.transparent : Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                            border: isDark
                                ? Border.all(
                                    color: Colors.white.withValues(alpha: 0.15))
                                : null,
                          ),
                          child: Text('Set',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Material(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1C1C1E)
                  : Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.92),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Update Progress',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : const Color(0xFF1C1C1E),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Value Display + Manual Input Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_currentSelection.toInt()}',
                          style: GoogleFonts.poppins(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Color(widget.habit.colorValue),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.habit.goalUnit,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFB0B0B5)
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _onManualInput,
                          icon: Icon(CupertinoIcons.pencil_circle_fill,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              size: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Color(widget.habit.colorValue),
                        inactiveTrackColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Color(widget.habit.colorValue)
                                    .withValues(alpha: 0.2),
                        thumbColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Color(widget.habit.colorValue),
                        trackHeight: 8,
                        overlayColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Color(widget.habit.colorValue)
                                    .withValues(alpha: 0.1),
                      ),
                      child: Slider(
                        value: _currentSelection,
                        min: 0,
                        max: widget.habit.goalFor(widget.dateStr).toDouble(),
                        onChanged: (val) =>
                            setState(() => _currentSelection = val),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Quick Add Presets
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [20, 40, 60, 80, 100].map((pct) {
                        final val =
                            (pct / 100 * widget.habit.goalFor(widget.dateStr))
                                .round();
                        return GestureDetector(
                          onTap: () => setState(
                              () => _currentSelection = val.toDouble()),
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFD2F0DA),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '$val',
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : const Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.onSave(_currentSelection.toInt());
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Color(widget.habit.colorValue),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Update Now',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Mood Radial Picker ──────────────────────────────────────────────────────

class _MoodSelectorButton extends ConsumerWidget {
  const _MoodSelectorButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMood = ref.watch(
        dailyMoodsProvider)[DateFormat('yyyy-MM-dd').format(DateTime.now())];

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.3),
          builder: (context) => const _MoodRadialPicker(),
        );
      },
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: currentMood != null
              ? (Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : AppColors.pastelYellow)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          boxShadow: [
            if (currentMood != null)
              BoxShadow(
                color: AppColors.pastelYellow.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          currentMood ?? '😐',
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}

class _ProfileButton extends ConsumerWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const ProfileScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      },
      child: Hero(
        tag: 'profile_avatar',
        child: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            image: profile.imagePath != null
                ? DecorationImage(
                    image: AssetImage(profile.imagePath!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          alignment: Alignment.center,
          child: profile.imagePath == null
              ? const Icon(
                  CupertinoIcons.person_fill,
                  size: 20,
                  color: Color(0xFF3A3A3C),
                )
              : null,
        ),
      ),
    );
  }
}

class _MoodRadialPicker extends ConsumerStatefulWidget {
  const _MoodRadialPicker();

  @override
  ConsumerState<_MoodRadialPicker> createState() => _MoodRadialPickerState();
}

class _MoodRadialPickerState extends ConsumerState<_MoodRadialPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  final List<String> _emojis = ['🤩', '😁', '🙂', '😐', '😔', '😫', '😡'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectMood(String emoji) async {
    await _controller.reverse();
    ref.read(dailyMoodsProvider.notifier).setTodayMood(emoji);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentMood = ref.watch(
        dailyMoodsProvider)[DateFormat('yyyy-MM-dd').format(DateTime.now())];

    return GestureDetector(
      onTap: () async {
        await _controller.reverse();
        if (mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.2),
                            width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Center text prompt
                          Text(
                            'How are you\nfeeling?',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          ...List.generate(_emojis.length, (index) {
                            final emoji = _emojis[index];
                            final isSelected = currentMood == emoji;

                            // Calculate radial position
                            final double angle =
                                (index * (2 * math.pi / _emojis.length)) -
                                    (math.pi / 2);
                            const double radius =
                                95.0; // Adjusted for better fit
                            final double x = radius * math.cos(angle);
                            final double y = radius * math.sin(angle);

                            return Transform.translate(
                              offset: Offset(x, y),
                              child: GestureDetector(
                                onTap: () => _selectMood(emoji),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.6),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.pastelYellow
                                                  .withValues(alpha: 0.8),
                                              blurRadius: 15,
                                              spreadRadius: 2,
                                            )
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.05),
                                              blurRadius: 5,
                                            )
                                          ],
                                    border: isSelected
                                        ? Border.all(
                                            color: AppColors.pastelYellow,
                                            width: 2)
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                        begin: 0.8,
                                        end: isSelected ? 1.4 : 1.0),
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutBack,
                                    builder: (context, scale, child) {
                                      return Transform.scale(
                                        scale: scale,
                                        child: Text(emoji,
                                            style:
                                                const TextStyle(fontSize: 24)),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ANALYTICS BOTTOM SHEET
// ─────────────────────────────────────────────

void _showHabitAnalytics(BuildContext context, Habit habit) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => _HabitAnalyticsSheet(habit: habit),
  );
}

class _HabitAnalyticsSheet extends StatefulWidget {
  final Habit habit;
  const _HabitAnalyticsSheet({required this.habit});

  @override
  State<_HabitAnalyticsSheet> createState() => _HabitAnalyticsSheetState();
}

class _HabitAnalyticsSheetState extends State<_HabitAnalyticsSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Returns last 7 days normalized progress values (0.0–1.0) and their date strings.
  // offset 0 = last 7 days, -1 = previous 7 days.
  List<Map<String, dynamic>> _weekData(int offset) {
    final now = DateTime.now();
    final h = widget.habit;

    return List.generate(7, (i) {
      final daysToSubtract = 6 - i + (offset == -1 ? 7 : 0);
      final date = now.subtract(Duration(days: daysToSubtract));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final done = (h.dailyProgress[dateStr] ?? 0).toDouble();
      final snapGoal =
          h.goalFor(dateStr) > 0 ? h.goalFor(dateStr).toDouble() : 1.0;
      return {
        'dateStr': dateStr,
        'date': date,
        'value': (done / snapGoal).clamp(0.0, 1.0),
        'done': done,
        'goal': snapGoal,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final last7Days = _weekData(0);
    final prev7Days = _weekData(-1);

    const thisWeekColor = Color(0xFF65D282); // Green
    const lastWeekColor = Color(0xFFFFB067); // Orange

    // Check if there is absolutely no activity
    final bool isEmpty = last7Days.every((d) => d['value'] == 0.0) &&
        prev7Days.every((d) => d['value'] == 0.0);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1C1C1E).withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                : null,
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, -6),
                ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag indicator
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Habit header
              Row(
                children: [
                  Text(widget.habit.icon ?? '✨',
                      style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(
                    widget.habit.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // ── Weekly Performance ──────────────────────
              Text(
                'Weekly Performance',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: isDark ? Colors.transparent : const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: AnimatedBuilder(
                  animation: _progress,
                  builder: (_, __) => CustomPaint(
                    painter: _WeeklyBarChartPainter(
                      values:
                          last7Days.map((d) => d['value'] as double).toList(),
                      labels: last7Days
                          .map((d) => DateFormat('E')
                              .format(d['date'] as DateTime)
                              .substring(0, 1))
                          .toList(),
                      color: Color(widget.habit.colorValue),
                      animProgress: _progress.value,
                      isDark: isDark,
                    ),
                    child: Container(),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Weekly Comparison ────────────────────────
              Text(
                'Weekly Comparison',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                ),
              ),
              const SizedBox(height: 10),

              // ── Premium Interactive Graph ─────────────────────────────────
              Container(
                height: 220,
                width: double.infinity,
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: isEmpty
                    ? Center(
                        child: Text(
                          'No activity yet',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade400,
                          ),
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: 6,
                          minY: 0,
                          maxY: 1.1, // give some headroom for tooltips
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 0.5,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.05),
                                strokeWidth: 1,
                                dashArray: [4, 4],
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 38,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index < 0 || index >= last7Days.length)
                                    return const SizedBox.shrink();

                                  final isToday =
                                      index == 6; // Always the last item
                                  final date =
                                      last7Days[index]['date'] as DateTime;
                                  final dayStr = DateFormat('E')
                                      .format(date)
                                      .substring(0, 3);

                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    space: 12,
                                    child: isToday
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: thisWeekColor.withValues(
                                                  alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              dayStr,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? thisWeekColor
                                                    : thisWeekColor
                                                        .withAlpha(200),
                                              ),
                                            ),
                                          )
                                        : Text(
                                            dayStr,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isDark
                                                  ? Colors.grey.shade500
                                                  : Colors.grey.shade400,
                                            ),
                                          ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              maxContentWidth: 140,
                              tooltipRoundedRadius: 10,
                              tooltipPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              getTooltipColor: (_) => isDark
                                  ? const Color(0xFF2C2C2E)
                                  : Colors.white,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final isPrev = spot.barIndex == 0;
                                  final dataList =
                                      isPrev ? prev7Days : last7Days;
                                  final data = dataList[spot.x.toInt()];
                                  final done = data['done'] as double;
                                  final goal = data['goal'] as double;
                                  final doneStr = done % 1 == 0
                                      ? done.toInt().toString()
                                      : done.toStringAsFixed(1);
                                  final goalStr = goal % 1 == 0
                                      ? goal.toInt().toString()
                                      : goal.toStringAsFixed(1);
                                  final unit = widget.habit.goalUnit;

                                  return LineTooltipItem(
                                    '$doneStr / $goalStr $unit',
                                    GoogleFonts.poppins(
                                      color: isPrev
                                          ? lastWeekColor
                                          : (isDark
                                              ? Colors.white
                                              : Colors.black),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                            handleBuiltInTouches: true,
                            getTouchedSpotIndicator: (LineChartBarData barData,
                                List<int> spotIndexes) {
                              return spotIndexes.map((index) {
                                return TouchedSpotIndicatorData(
                                  FlLine(
                                    color:
                                        barData.color?.withValues(alpha: 0.3) ??
                                            Colors.transparent,
                                    strokeWidth: 2,
                                    dashArray: [4, 4],
                                  ),
                                  FlDotData(
                                    show: true,
                                    getDotPainter:
                                        (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        radius: 6,
                                        color:
                                            barData.color ?? Colors.transparent,
                                        strokeWidth: 2,
                                        strokeColor: isDark
                                            ? const Color(0xFF1C1C1E)
                                            : Colors.white,
                                      );
                                    },
                                  ),
                                );
                              }).toList();
                            },
                          ),
                          lineBarsData: [
                            // Previous Week Line
                            LineChartBarData(
                              spots: prev7Days.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(),
                                    e.value['value'] as double);
                              }).toList(),
                              isCurved: true,
                              curveSmoothness: 0.35,
                              color: lastWeekColor,
                              barWidth: 2.0,
                              dashArray: [5, 5],
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(show: false),
                            ),
                            // Current Week Line
                            LineChartBarData(
                              spots: last7Days.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(),
                                    e.value['value'] as double);
                              }).toList(),
                              isCurved: true,
                              curveSmoothness: 0.35,
                              color: thisWeekColor,
                              barWidth: 3.5,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 3.5,
                                    color: thisWeekColor,
                                    strokeWidth: 1.5,
                                    strokeColor: isDark
                                        ? const Color(0xFF1C1C1E)
                                        : Colors.white,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    thisWeekColor.withValues(alpha: 0.25),
                                    thisWeekColor.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              // Legend
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: thisWeekColor, label: 'This Week'),
                  SizedBox(width: 20),
                  _LegendDot(color: lastWeekColor, label: 'Last Week'),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFB0B0B5)
                : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ─── Bar Chart CustomPainter ───────────────────────────
class _WeeklyBarChartPainter extends CustomPainter {
  final List<double> values; // 7 values for the last 7 days, 0.0-1.0
  final List<String> labels; // 7 label letters representing the days
  final Color color;
  final double animProgress;
  final bool isDark;

  _WeeklyBarChartPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.animProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 22.0;
    final chartH = size.height - labelH;
    final barW = (size.width - 24) / 7;
    const barInnerW = 18.0;
    const radius = Radius.circular(6);

    final bgPaint = Paint()
      ..color =
          isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200;
    final filledPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, color.withValues(alpha: 0.65)],
      ).createShader(Rect.fromLTWH(0, 0, barInnerW, chartH));

    final labelStyle = GoogleFonts.poppins(
      fontSize: 11,
      color: isDark ? const Color(0xFFB0B0B5) : Colors.grey.shade500,
      fontWeight: FontWeight.w500,
    );

    for (int i = 0; i < 7; i++) {
      final cx = 12 + i * barW + barW / 2;
      final v = (values[i] * animProgress).clamp(0.0, 1.0);
      final x = cx - barInnerW / 2;

      // Background bar (full height, grey)
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(x, 0, x + barInnerW, chartH,
            topLeft: radius, topRight: radius),
        bgPaint,
      );

      // Filled bar
      if (v > 0) {
        final top = chartH * (1 - v);
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(x, top, x + barInnerW, chartH,
              topLeft: radius, topRight: radius),
          filledPaint,
        );
      }

      // Label
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, chartH + 6));
    }
  }

  @override
  bool shouldRepaint(_WeeklyBarChartPainter old) =>
      old.animProgress != animProgress ||
      old.values != values ||
      old.labels != labels;
}

// ─────────────────────────────────────────────────────────────────────────────
// Streak Reminder Banner
// ─────────────────────────────────────────────────────────────────────────────

/// Soft reminder shown on the home screen after a user dismisses the streak
/// protection modal. Disappears when tapped (re-opens the modal) or when
/// the X is tapped (clears permanently for this session).
class _StreakReminderBanner extends ConsumerWidget {
  const _StreakReminderBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = ref.watch(streakReminderProvider);
    if (habit == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(yesterday);
    // Compute live streak-at-risk for accurate display
    final protectedDays = ref.watch(streakProtectionProvider);
    final mockProtected = {...protectedDays, '${habit.id}_$yesterdayStr'};
    final streakAtRisk =
        calculateHabitStreakWithProtection(habit, mockProtected);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: () async {
          ref.read(streakReminderProvider.notifier).state = null;
          final savedCount = await _showStreakProtectionModal(
              context, ref, [habit], yesterdayStr, {habit.id: streakAtRisk});
          if (savedCount != null && savedCount == 0 && context.mounted) {
            // Re-set reminder if still dismissed
            ref.read(streakReminderProvider.notifier).state = habit;
          } else if (savedCount != null && savedCount > 0) {
            ref.read(streakReminderProvider.notifier).state = null;
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isDark
                  ? [
                      const Color(0xFFFF6B35).withValues(alpha: 0.18),
                      const Color(0xFFFF4500).withValues(alpha: 0.12),
                    ]
                  : [
                      const Color(0xFFFFF3ED),
                      const Color(0xFFFFEDE0),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF6B35).withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Save your streak ($streakAtRisk days) · 50 coins',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFFF8C42)
                        : const Color(0xFFD4521A),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () =>
                    ref.read(streakReminderProvider.notifier).state = null,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : const Color(0xFFD4521A).withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// Streak Protection Modal
// ─────────────────────────────────────────────────────────────────────────────

/// Shows the streak protection dialog. Returns `int` representing the number of
/// streaks saved. Returns `null` if the user soft-dismissed (tapped barrier).
/// Returns `0` if the user explicitly clicked "Let it break".
Future<int?> _showStreakProtectionModal(
  BuildContext context,
  WidgetRef ref,
  List<Habit> candidates,
  String yesterdayStr,
  Map<String, int> streakAtRiskMap,
) {
  return showDialog<int?>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => _StreakProtectionDialog(
      candidates: candidates,
      yesterdayStr: yesterdayStr,
      streakAtRiskMap: streakAtRiskMap,
    ),
  );
}

class _StreakProtectionDialog extends ConsumerStatefulWidget {
  final List<Habit> candidates;
  final String yesterdayStr;
  final Map<String, int> streakAtRiskMap;

  const _StreakProtectionDialog({
    required this.candidates,
    required this.yesterdayStr,
    required this.streakAtRiskMap,
  });

  @override
  ConsumerState<_StreakProtectionDialog> createState() =>
      _StreakProtectionDialogState();
}

class _StreakProtectionDialogState
    extends ConsumerState<_StreakProtectionDialog> {
  late Set<String> _selectedHabits;

  @override
  void initState() {
    super.initState();
    _selectedHabits = widget.candidates.map((h) => h.id).toSet();
  }

  void _toggleHabit(String id) {
    setState(() {
      if (_selectedHabits.contains(id)) {
        _selectedHabits.remove(id);
      } else {
        _selectedHabits.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final coins = ref.watch(coinProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final costPerHabit = StreakProtectionNotifier.protectionCost;
    final totalCost = _selectedHabits.length * costPerHabit;
    final canAfford = coins >= totalCost;
    final canProtect = _selectedHabits.isNotEmpty && canAfford;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      elevation: 16,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Fire header ──
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF8C42), Color(0xFFFF4500)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                    child: Text('🔥', style: TextStyle(fontSize: 36))),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ──
            Text(
              widget.candidates.length == 1
                  ? '🔥 Your streak is about to break'
                  : '🔥 Streaks are about to break',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 10),

            // ── Body ──
            Text(
              widget.candidates.length == 1
                  ? 'You missed yesterday. This streak will reset.'
                  : 'You missed ${widget.candidates.length} habits yesterday.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.85)
                    : const Color(0xFF374151),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // ── List of habits ──
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFE5E7EB)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: widget.candidates.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFFE5E7EB),
                    ),
                    itemBuilder: (context, index) {
                      final habit = widget.candidates[index];
                      final isSelected = _selectedHabits.contains(habit.id);
                      final streak = widget.streakAtRiskMap[habit.id] ?? 0;

                      return InkWell(
                        onTap: () => _toggleHabit(habit.id),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Color(habit.colorValue)
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(habit.icon ?? '🎯',
                                      style: const TextStyle(fontSize: 14)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      habit.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1F2937),
                                      ),
                                    ),
                                    Text(
                                      '$streak-day streak',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFFFF6B35),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Custom Checkbox
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFF6B35)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFFF6B35)
                                        : (isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.3)
                                            : const Color(0xFFD1D5DB)),
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        size: 16, color: Colors.white)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Coin balance pill ──
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: canProtect
                      ? (isDark
                          ? const Color(0xFFFFD700).withValues(alpha: 0.12)
                          : const Color(0xFFFFFDE7))
                      : (isDark
                          ? Colors.red.withValues(alpha: 0.12)
                          : const Color(0xFFFFF0F0)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: canProtect
                        ? const Color(0xFFFFD700).withValues(alpha: 0.4)
                        : Colors.red.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: canProtect ? const Color(0xFFFFD700) : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedHabits.isEmpty
                          ? 'Select habits to save (you have $coins)'
                          : canAfford
                              ? 'Need $totalCost coins (you have $coins)'
                              : 'Need $totalCost coins (you have $coins)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: canProtect
                            ? (isDark
                                ? const Color(0xFFFFD700)
                                : const Color(0xFFB8860B))
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Primary button: Use coins ──
            SizedBox(
              height: 50,
              child: ElevatedButton(
                // Truly disabled — no tap handler when cannot protect
                onPressed: canProtect
                    ? () {
                        // Deduct coins
                        ref.read(coinProvider.notifier).removeCoins(totalCost);

                        // Apply protection for EACH selected habit
                        for (final cid in _selectedHabits) {
                          ref
                              .read(streakProtectionProvider.notifier)
                              .protect(cid, widget.yesterdayStr);
                        }

                        ref.read(coinDeductedProvider.notifier).state = true;
                        Navigator.of(context).pop(_selectedHabits.length);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canProtect
                      ? const Color(0xFFFF6B35)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFF3F4F6)),
                  disabledBackgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF3F4F6),
                  elevation: canProtect ? 4 : 0,
                  shadowColor: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _selectedHabits.isEmpty
                      ? 'Select habits'
                      : canAfford
                          ? 'Use $totalCost Coins to save ${_selectedHabits.length}'
                          : 'Need $totalCost coins',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: canProtect
                        ? Colors.white
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.25)
                            : const Color(0xFFBBBBBB)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Secondary: Let it break ──
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pop(0), // 0 indicates explicitly dismissed permanently
              child: Text(
                'SKIP',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Glass Add Button ──────────────────────────────────────────────────────────
class _GlassAddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _GlassAddButton({required this.onTap});

  @override
  State<_GlassAddButton> createState() => _GlassAddButtonState();
}

class _GlassAddButtonState extends State<_GlassAddButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutBack,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: Color(0xFF3A3A3C), // Soft dark secondary tint
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Badge Unlock Popup ──
class _BadgeUnlockPopup extends StatelessWidget {
  final BadgeData badge;

  const _BadgeUnlockPopup({required this.badge});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.1), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: badge.glowColor.withValues(alpha: 0.35),
                blurRadius: 50,
                spreadRadius: 15,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'BADGE UNLOCKED!',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                  color: badge.gradientColors.first,
                ),
              ),
              const SizedBox(height: 32),
              // The exact premium badge UI
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: badge.gradientColors,
                    stops: const [0.0, 0.45, 0.55, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: badge.glowColor.withValues(alpha: 0.8),
                        blurRadius: 40,
                        spreadRadius: 5),
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 10)),
                  ],
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9), width: 2),
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white,
                        Colors.white.withValues(alpha: 0.8)
                      ],
                    ).createShader(bounds),
                    child: Icon(badge.icon, color: Colors.white, size: 70),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                badge.title,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You earned the ${badge.subtitle} tier!',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: Text(
                    'Awesome',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
