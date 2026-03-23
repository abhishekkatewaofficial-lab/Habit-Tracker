import 'dart:io';
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
import 'package:habit_tracker_ios/features/focus_timer/presentation/pages/focus_timer_screen.dart';
import 'package:habit_tracker_ios/features/focus_timer/presentation/pages/focus_dashboard_screen.dart';
import 'package:habit_tracker_ios/features/diary/presentation/pages/diary_screen.dart';
import 'package:habit_tracker_ios/features/reports/presentation/pages/reports_screen.dart';
import 'package:habit_tracker_ios/features/habits/presentation/pages/add_edit_habit_screen.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_controller.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_filter_controller.dart';
import 'package:habit_tracker_ios/features/mood/presentation/controllers/mood_controller.dart';
import 'package:habit_tracker_ios/features/todo/presentation/pages/todo_home_screen.dart';
import 'package:habit_tracker_ios/features/eisenhower/presentation/pages/eisenhower_matrix_screen.dart';
import 'package:habit_tracker_ios/features/countdown/presentation/pages/countdown_screen.dart';
import 'package:habit_tracker_ios/features/focus_timer/presentation/pages/stopwatch_screen.dart';
import 'package:habit_tracker_ios/features/profile/presentation/controllers/profile_controller.dart';
import 'package:habit_tracker_ios/features/profile/presentation/pages/profile_screen.dart';

/// Root scaffold that owns the bottom nav and swaps feature screens.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const List<Widget> _screens = [
    _HabitsTab(),
    SizedBox.shrink(), // Index 1: Focus Main Tab (Dummy, opens sub-dock)
    DiaryScreen(),
    SizedBox.shrink(), // Index 3: Planner Main Tab (Dummy, opens sub-dock)
    ReportsScreen(),   // Index 4: Reports
    TodoHomeScreen(),  // Index 5
    EisenhowerMatrixScreen(), // Index 6
    FocusDashboardScreen(), // Index 7
    FocusTimerScreen(), // Index 8: Pomodoro
    StopwatchScreen(),  // Index 9: Stopwatch
    CountdownScreen(), // Index 10: Countdown
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navigationIndexProvider);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true, // CRITICAL: Allows content to scroll behind the floating dock
      body: IndexedStack(index: index, children: _screens),
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
    
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final selectedMidnight = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isFuture = selectedMidnight.isAfter(todayMidnight);

    return SafeArea(
      bottom: false, // CRITICAL: Stop SafeArea from adding background block behind dock
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Left: Filter Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _FilterButton(activeFilter: activeFilter),
                    ),
                    // Center: Title
                    Text(
                      DateFormat('d MMM').format(selectedDate) == DateFormat('d MMM').format(DateTime.now()) 
                          ? 'Today' 
                          : DateFormat('d MMM').format(selectedDate), 
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.w800, 
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    // Right: Daily Mood & Profile
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ProfileButton(),
                          SizedBox(width: 12),
                          _MoodSelectorButton(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: _DateStrip()),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          if (habits.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(
                    'No habits yet. Tap + to start!',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                  ),
                ),
              ),
            )
          else
            SliverReorderableList(
              itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
                key: ValueKey(habits[i].id),
                index: i,
                child: _HabitCard(
                  habit: habits[i], 
                  dateStr: todayStr, 
                  isFuture: isFuture,
                  index: i
                ),
              ),
              itemCount: habits.length,
              onReorder: (oldIndex, newIndex) {
                ref.read(habitProvider.notifier).reorderHabits(oldIndex, newIndex);
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)), // Increased bottom padding
        ],
      ),
    );
  }
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
    _dates = List.generate(_range, (i) => _todayMidnight.add(Duration(days: i - _todayIndex)));
    
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
          final isSelected = DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(selectedDate);
          
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
    final isToday = date.day == today.day && date.month == today.month && date.year == today.year;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    ? (isDark ? Colors.white.withValues(alpha: 0.7) : AppColors.accent)
                    : (isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.outline.withAlpha(100)),
                width: isSelected ? 2 : 1,
              ),
              color: isSelected 
                  ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.transparent) 
                  : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: Text(
              '${date.day}',
              style: AppTextStyles.labelLarge.copyWith(
                color: isSelected 
                    ? (isDark ? Colors.white : AppColors.accent) 
                    : (isDark ? Colors.white : Theme.of(context).colorScheme.onSurface),
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
  final bool isFuture;
  final int index;

  const _HabitCard({
    required this.habit,
    required this.dateStr,
    required this.isFuture,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProgressValue = habit.dailyProgress[dateStr] ?? 0;
    final isCompletedToday = currentProgressValue >= habit.goalValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = Color(habit.colorValue);
    final progress = (currentProgressValue / habit.goalValue).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isFuture ? 0.6 : 1.0,
        child: Slidable(
          key: ValueKey(habit.id),
          enabled: !isFuture,
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
                      content: Text('Are you sure you want to delete "${habit.name}"?'),
                      actions: [
                        CupertinoDialogAction(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  color: isDark ? Theme.of(context).colorScheme.surface : baseColor.withValues(alpha: 0.18),
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
                            Text(habit.icon ?? '✨', style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Habit name
                                  Text(
                                    habit.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              const SizedBox(height: 4),
                              // Progress pill + streak chip side by side
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _ProgressPill(
                                    current: currentProgressValue,
                                    total: habit.goalValue,
                                    unit: habit.goalUnit,
                                    color: isDark ? Colors.transparent : baseColor,
                                  ),
                                  Builder(builder: (_) {
                                    final streak = calculateHabitStreak(habit);
                                    if (streak == 0) return const SizedBox.shrink();
                                    return Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(100),
                                        border: Border.all(
                                          color: isDark ? Colors.white.withValues(alpha: 0.15) : baseColor.withValues(alpha: 0.5),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons.flame_fill, 
                                            size: 10, 
                                            color: isDark ? Colors.white70 : baseColor,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${streak}d',
                                            style: GoogleFonts.poppins(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: Theme.of(context).colorScheme.onSurface,
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
                          isFuture: isFuture,
                          color: baseColor,
                          onTap: () {
                            if (isFuture) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("You can't update future habits"),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            if (habit.goalValue == 1) {
                              final current = habit.dailyProgress[dateStr] ?? 0;
                              final newValue = current >= 1 ? 0 : 1;
                              ref.read(habitProvider.notifier).setHabitProgress(habit.id, dateStr, newValue);
                            } else {
                              _showUpdateProgressPopup(context, ref, habit, dateStr);
                            }
                          },
                        ),
                      const SizedBox(width: 12),
                      ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          CupertinoIcons.line_horizontal_3,
                                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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


  void _showUpdateProgressPopup(BuildContext context, WidgetRef ref, Habit habit, String dateStr) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Update Progress',
      barrierColor: Colors.black.withValues(alpha: 0.3), // matches request
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        final currentProgress = habit.dailyProgress[dateStr] ?? 0;
        return _UpdateProgressPopup(
          habit: habit,
          currentValue: currentProgress,
          onSave: (val) {
            ref.read(habitProvider.notifier).setHabitProgress(habit.id, dateStr, val);
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
  final bool isFuture;
  final Color color;
  final VoidCallback onTap;

  const _PremiumCompleteButton({
    required this.isCompleted,
    required this.isFuture,
    required this.color,
    required this.onTap,
  });

  @override
  State<_PremiumCompleteButton> createState() => _PremiumCompleteButtonState();
}

class _PremiumCompleteButtonState extends State<_PremiumCompleteButton> with SingleTickerProviderStateMixin {
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

    return GestureDetector(
      onTapDown: widget.isFuture ? null : (_) => _controller.forward(),
      onTapUp: widget.isFuture ? null : (_) => _controller.reverse(),
      onTapCancel: widget.isFuture ? null : () => _controller.reverse(),
      onTap: widget.isFuture ? widget.onTap : widget.onTap, // Still allow tap to show Sanckbar if we want
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isFuture 
                ? Colors.grey.withValues(alpha: 0.2)
                : (widget.isCompleted 
                    ? (isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.success)
                    : Theme.of(context).colorScheme.surface.withAlpha(200)),
            border: widget.isCompleted && isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.0)
                : null,
            boxShadow: [
              if (!widget.isFuture) ...[
                if (!widget.isCompleted || !isDark)
                  BoxShadow(
                    color: (widget.isCompleted ? AppColors.success : Theme.of(context).colorScheme.shadow).withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                if (widget.isCompleted)
                  BoxShadow(
                    color: isDark ? Colors.white.withValues(alpha: 0.15) : AppColors.success.withValues(alpha: 80),
                    blurRadius: isDark ? 10 : 12,
                    spreadRadius: isDark ? 0 : 1,
                  ),
              ]
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
            child: Icon(
              widget.isCompleted ? CupertinoIcons.checkmark_alt : CupertinoIcons.add,
              key: ValueKey(widget.isCompleted),
              color: widget.isFuture 
                  ? Colors.grey.withValues(alpha: 0.5)
                  : (widget.isCompleted 
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
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
      case HabitFilter.all: return 'All';
      case HabitFilter.completed: return 'Completed';
      case HabitFilter.pending: return 'Pending';
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
              offset: Offset(0, size.height + 8),
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
            color: isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : AppColors.accent,
            borderRadius: BorderRadius.circular(20),
            border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1) : null,
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
                    color: Colors.white,
                    fontWeight: FontWeight.w600
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
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
  const _FilterDropdownMenu({required this.onSelected, required this.activeFilter});

  @override
  ConsumerState<_FilterDropdownMenu> createState() => _FilterDropdownMenuState();
}

class _FilterDropdownMenuState extends ConsumerState<_FilterDropdownMenu> with SingleTickerProviderStateMixin {
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
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
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
                      _buildOption(HabitFilter.all, 'All', CupertinoIcons.layers_fill),
                      _buildOption(HabitFilter.completed, 'Completed', CupertinoIcons.checkmark_circle_fill),
                      _buildOption(HabitFilter.pending, 'Pending', CupertinoIcons.clock_fill),
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
          color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              size: 18, 
              color: isSelected ? AppColors.accent : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.accent : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              const Icon(CupertinoIcons.checkmark_alt, size: 16, color: AppColors.accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpdateProgressPopup extends StatefulWidget {
  final Habit habit;
  final int currentValue;
  final Function(int) onSave;

  const _UpdateProgressPopup({
    required this.habit,
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
        final controller = TextEditingController(text: _currentSelection.toInt().toString());
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Manual Entry', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  cursorColor: isDark ? Colors.white : Colors.blue,
                  decoration: InputDecoration(
                     filled: true,
                     fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
                            border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.3)),
                          ),
                          child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final val = int.tryParse(controller.text) ?? _currentSelection.toInt();
                          setState(() => _currentSelection = val.clamp(0, widget.habit.goalValue).toDouble());
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.transparent : Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                            border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.15)) : null,
                          ),
                          child: Text('Set', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
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
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1C1C1E),
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
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(widget.habit.colorValue),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.habit.goalUnit,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFB0B0B5) : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _onManualInput,
                          icon: Icon(CupertinoIcons.pencil_circle_fill, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant, size: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(widget.habit.colorValue),
                        inactiveTrackColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Color(widget.habit.colorValue).withValues(alpha: 0.2),
                        thumbColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color(widget.habit.colorValue),
                        trackHeight: 8,
                        overlayColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Color(widget.habit.colorValue).withValues(alpha: 0.1),
                      ),
                      child: Slider(
                        value: _currentSelection,
                        min: 0,
                        max: widget.habit.goalValue.toDouble(),
                        onChanged: (val) => setState(() => _currentSelection = val),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Quick Add Presets
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [20, 40, 60, 80, 100].map((pct) {
                        final val = (pct / 100 * widget.habit.goalValue).round();
                        return GestureDetector(
                          onTap: () => setState(() => _currentSelection = val.toDouble()),
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
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
                                color: Theme.of(context).brightness == Brightness.dark
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
                          backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Color(widget.habit.colorValue),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
    final currentMood = ref.watch(dailyMoodsProvider)[DateFormat('yyyy-MM-dd').format(DateTime.now())];

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
            pageBuilder: (context, animation, secondaryAnimation) => const ProfileScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
                    image: FileImage(File(profile.imagePath!)),
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

class _MoodRadialPickerState extends ConsumerState<_MoodRadialPicker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  final List<String> _emojis = ['🤩', '😁', '🙂', '😐', '😔', '😫', '😡'];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
    final currentMood = ref.watch(dailyMoodsProvider)[DateFormat('yyyy-MM-dd').format(DateTime.now())];

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
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), width: 1),
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
                            final double angle = (index * (2 * math.pi / _emojis.length)) - (math.pi / 2);
                            const double radius = 95.0; // Adjusted for better fit
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
                                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                    boxShadow: isSelected ? [
                                      BoxShadow(
                                        color: AppColors.pastelYellow.withValues(alpha: 0.8),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                      )
                                    ] : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 5,
                                      )
                                    ],
                                    border: isSelected ? Border.all(color: AppColors.pastelYellow, width: 2) : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0.8, end: isSelected ? 1.4 : 1.0),
                                    duration: const Duration(milliseconds: 200),
                                    curve: Curves.easeOutBack,
                                    builder: (context, scale, child) {
                                      return Transform.scale(
                                        scale: scale,
                                        child: Text(emoji, style: const TextStyle(fontSize: 24)),
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Returns Mon-Sun progress values (0.0–1.0) for the given week offset.
  // offset 0 = this week, offset -1 = last week.
  List<double> _weekData(int offset) {
    final now = DateTime.now();
    // Monday of the target week
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1))
        .add(Duration(days: offset * 7));

    final h = widget.habit;
    final goal = h.goalValue > 0 ? h.goalValue.toDouble() : 1.0;

    return List.generate(7, (i) {
      final date = monday.add(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final done = (h.dailyProgress[dateStr] ?? 0).toDouble();
      return (done / goal).clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentWeek = _weekData(0);
    final prevWeek = _weekData(-1);
    const chartGreen = Color(0xFF65D282);
    const chartOrange = Color(0xFFFFB067);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white.withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, -6),
                ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
                  Text(widget.habit.icon ?? '✨', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(
                    widget.habit.name,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1C1C1E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

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
                      values: currentWeek,
                      color: chartGreen,
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
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: isDark ? Colors.transparent : const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                child: AnimatedBuilder(
                  animation: _progress,
                  builder: (_, __) => CustomPaint(
                    painter: _WeeklyLineChartPainter(
                      current: currentWeek,
                      previous: prevWeek,
                      color: chartGreen,
                      prevColor: chartOrange,
                      animProgress: _progress.value,
                      isDark: isDark,
                    ),
                    child: Container(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Legend
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(color: chartGreen, label: 'This Week'),
                  SizedBox(width: 20),
                  _LegendDot(color: chartOrange, label: 'Last Week'),
                ],
              ),
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
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFB0B0B5) : Colors.grey.shade600),
        ),
      ],
    );
  }
}

// ─── Bar Chart CustomPainter ───────────────────────────
class _WeeklyBarChartPainter extends CustomPainter {
  final List<double> values; // 7 values, Mon–Sun, 0.0–1.0
  final Color color;
  final double animProgress;
  final bool isDark;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  _WeeklyBarChartPainter({
    required this.values,
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

    final bgPaint = Paint()..color = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200;
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
        text: TextSpan(text: _labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, chartH + 6));
    }
  }

  @override
  bool shouldRepaint(_WeeklyBarChartPainter old) =>
      old.animProgress != animProgress || old.values != values;
}

// ─── Line Chart CustomPainter ──────────────────────────
class _WeeklyLineChartPainter extends CustomPainter {
  final List<double> current;
  final List<double> previous;
  final Color color;
  final Color prevColor;
  final double animProgress;
  final bool isDark;

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  _WeeklyLineChartPainter({
    required this.current,
    required this.previous,
    required this.color,
    required this.prevColor,
    required this.animProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const labelH = 24.0;
    const sidePad = 16.0;
    final chartH = size.height - labelH;
    final chartW = size.width - (sidePad * 2);

    // Determine value range (max of all values, min 1.0 so we always have headroom)
    final allVals = [...current, ...previous];
    final maxVal = allVals.reduce((a, b) => a > b ? a : b).clamp(0.01, double.infinity);
    // Round up to a nice grid ceiling
    final yMax = (maxVal * 1.1).ceilToDouble().clamp(1.0, double.infinity);

    Offset pt(int i, double v) {
      final x = sidePad + i * (chartW / 6);
      final y = chartH - (v / yMax) * chartH;
      return Offset(x, y);
    }

    // ── Grid lines ───────────────────────────────────
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)
      ..strokeWidth = 1;

    for (int g = 0; g <= 4; g++) {
      final v = yMax * g / 4;
      final y = chartH - (v / yMax) * chartH;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // ── Previous week line (pastel orange, thin) ──
    final prevPaint = Paint()
      ..color = prevColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final prevPath = Path();
    for (int i = 0; i < 7; i++) {
      final p = pt(i, previous[i]);
      if (i == 0) {
        prevPath.moveTo(p.dx, p.dy);
      } else {
        prevPath.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(_clipPathByProgress(prevPath, size, animProgress), prevPaint);

    // ── Current week area fill ───────────────────────
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartH))
      ..style = PaintingStyle.fill;

    final areaPath = Path();
    areaPath.moveTo(pt(0, 0).dx, chartH);
    for (int i = 0; i < 7; i++) {
      final p = pt(i, current[i]);
      if (i == 0) {
        areaPath.lineTo(p.dx, p.dy);
      } else {
        areaPath.lineTo(p.dx, p.dy);
      }
    }
    areaPath.lineTo(pt(6, 0).dx, chartH);
    areaPath.close();
    canvas.drawPath(_clipPathByProgress(areaPath, size, animProgress), fillPaint);

    // ── Current week line (green) ────────────────────
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final linePath = Path();
    for (int i = 0; i < 7; i++) {
      final p = pt(i, current[i]);
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(_clipPathByProgress(linePath, size, animProgress), linePaint);

    // ── Dots on last week ────────────────────────────
    final prevDotStroke = Paint()
      ..color = prevColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final prevDotFill = Paint()
      ..color = isDark ? const Color(0xFF1C1C1E) : Colors.white
      ..style = PaintingStyle.fill;
      
    for (int i = 0; i < 7; i++) {
      if (i / 6 > animProgress) break;
      final p = pt(i, previous[i]);
      canvas.drawCircle(p, 4, prevDotFill);
      canvas.drawCircle(p, 4, prevDotStroke);
    }

    // ── Dots on current week ─────────────────────────
    final dotFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 7; i++) {
      if (i / 6 > animProgress) break;
      final p = pt(i, current[i]);
      canvas.drawCircle(p, 5, dotFill);
    }

    // ── X-axis labels ────────────────────────────────
    final labelStyle = GoogleFonts.poppins(fontSize: 10, color: isDark ? const Color(0xFFB0B0B5) : Colors.grey.shade500);
    for (int i = 0; i < 7; i++) {
      final tp = TextPainter(
        text: TextSpan(text: _labels[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pt(i, 0).dx - tp.width / 2, chartH + 6));
    }
  }

  // Clips a path to the left portion based on animation progress (left-to-right reveal)
  Path _clipPathByProgress(Path path, Size size, double progress) {
    if (progress >= 1.0) return path;
    final clipRect = Rect.fromLTWH(0, -10, size.width * progress, size.height + 20);
    return Path.combine(PathOperation.intersect, path, Path()..addRect(clipRect));
  }

  @override
  bool shouldRepaint(_WeeklyLineChartPainter old) =>
      old.animProgress != animProgress ||
      old.current != current ||
      old.previous != previous;
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
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
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
