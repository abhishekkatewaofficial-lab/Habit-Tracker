import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:habit_tracker_ios/features/mood/presentation/controllers/mood_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_controller.dart';
import 'package:habit_tracker_ios/features/focus_timer/presentation/controllers/focus_dashboard_controller.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_filter_controller.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import 'package:habit_tracker_ios/features/focus_timer/data/models/focus_daily_summary.dart';

final reportDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _selectedIndex = 0; // Default to Weekly

  final List<String> _tabs = ['Weekly', 'Monthly', 'Yearly', 'Insights', 'Focus', 'Mood'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width > 600 ? 700 : double.infinity,
            ),
            child: Column(
              children: [
                // Top Floating Dock
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: _ReportsTopDock(
                    tabs: _tabs,
                    selectedIndex: _selectedIndex,
                    onTabSelected: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                  ),
                ),
                // Content Area
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: const [
                      WeeklyReportView(),
                      MonthlyReportView(),
                      YearlyReportView(),
                      InsightsReportView(),
                      FocusReportView(),
                      MoodReportView(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WeeklyReportView extends ConsumerWidget {
  const WeeklyReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitProvider);
    final baseDate = ref.watch(reportDateProvider);
    
    // Calculate week range (Sunday start)
    final sundayOffset = baseDate.weekday % 7;
    final sunday = baseDate.subtract(Duration(days: sundayOffset));
    final saturday = sunday.add(const Duration(days: 6));

    final weekDays = List.generate(7, (i) => sunday.add(Duration(days: i)));
    final rangeText = "${DateFormat('M/dd').format(sunday)} ~ ${DateFormat('M/dd').format(saturday)}";

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          // Header: Stylish "Habit Tracker"
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Theme.of(context).brightness == Brightness.dark
                  ? const ColorFiltered(
                      colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      child: Text('☀️', style: TextStyle(fontSize: 18)),
                    )
                  : const Text('☀️', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Habit Tracker',
                style: GoogleFonts.dancingScript(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF85A1), // Warm pink from screenshot
                ),
              ),
              const SizedBox(width: 8),
              const Text('🌙', style: TextStyle(fontSize: 18)),
            ],
          ),
          const SizedBox(height: 12),
          
          // Date Range Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => ref.read(reportDateProvider.notifier).state = baseDate.subtract(const Duration(days: 7)),
                icon: const Icon(CupertinoIcons.chevron_left, size: 18, color: Color(0xFFFF85A1)),
              ),
              Text(
                rangeText,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
              IconButton(
                onPressed: () => ref.read(reportDateProvider.notifier).state = baseDate.add(const Duration(days: 7)),
                icon: const Icon(CupertinoIcons.chevron_right, size: 18, color: Color(0xFFFF85A1)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Main Heatmap Card
          _HeatmapCard(habits: habits, weekDays: weekDays),
          
          const SizedBox(height: 120), // Padding for bottom dock
        ],
      ),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  final List<Habit> habits;
  final List<DateTime> weekDays;
  const _HeatmapCard({
    required this.habits, 
    required this.weekDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Days Header
          Row(
            children: [
              const SizedBox(width: 105), // Increased width for habit labels
              ...['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )),
            ],
          ),
          const SizedBox(height: 12),
          
          // Habit Rows
          ...habits.asMap().entries.map((entry) {
            final habit = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8), // Vertical gap
              child: Row(
                children: [
                  // Habit Label (Expanded)
                  SizedBox(
                    width: 105, // matches header gap
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(habit.icon ?? '✨', style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            habit.name,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Heatmap Squares
                  ...weekDays.map((date) {
                    final dateStr = DateFormat('yyyy-MM-dd').format(date);
                    final isBeforeStart = date.isBefore(habit.startDate);
                    final isSkipped = !isHabitScheduledOn(habit, date);
                    final progressVal = habit.dailyProgress[dateStr] ?? 0;
                    final goal = habit.goalValue > 0 ? habit.goalValue : 1;
                    final progressPercent = (progressVal / goal).clamp(0.0, 1.0);
                    final baseColor = Color(habit.colorValue);

                    Color cellColor;
                    Widget? cellChild;

                    if (isBeforeStart) {
                      cellColor = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
                    } else if (isSkipped) {
                      // Not scheduled — show subtle X
                      cellColor = Theme.of(context).colorScheme.surfaceContainerHighest;
                      cellChild = const Icon(CupertinoIcons.xmark, size: 9, color: Color(0xFFC7C7CC));
                    } else if (progressPercent <= 0) {
                      cellColor = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
                    } else if (progressPercent >= 1.0) {
                      cellColor = baseColor;
                      cellChild = const Icon(CupertinoIcons.checkmark, size: 12, color: Colors.white);
                    } else if (progressPercent <= 0.20) {
                      cellColor = baseColor.withValues(alpha: 0.2);
                    } else if (progressPercent <= 0.40) {
                      cellColor = baseColor.withValues(alpha: 0.4);
                    } else if (progressPercent <= 0.60) {
                      cellColor = baseColor.withValues(alpha: 0.6);
                    } else {
                      cellColor = baseColor.withValues(alpha: 0.8);
                    }

                    return Expanded(
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: cellColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (!isBeforeStart && !isSkipped && progressPercent <= 0) ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.5) : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: cellChild != null ? Center(child: cellChild) : null,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

          // Legend
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text('Pre-start', style: GoogleFonts.poppins(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const Spacer(),
              Text('Less', style: GoogleFonts.poppins(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              ...[0.0, 0.2, 0.4, 0.6, 0.8, 1.0].map((v) => Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: v == 0 
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : const Color(0xFF22C55E).withValues(alpha: v == 1.0 ? 1.0 : v),
                  borderRadius: BorderRadius.circular(2),
                  border: v == 0 ? Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5), width: 0.5) : null,
                ),
              )),
              const SizedBox(width: 8),
              Text('More', style: GoogleFonts.poppins(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),

          // Focus Row (Dynamic)
          const SizedBox(height: 16),
          _FocusRow(weekDays: weekDays),
        ],
      ),
    );
  }
}

class _ReportsTopDock extends StatelessWidget {
  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const _ReportsTopDock({
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(tabs.length, (index) {
                final isSelected = selectedIndex == index;
                return GestureDetector(
                  onTap: () => onTabSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? Theme.of(context).brightness == Brightness.dark
                            ? Colors.transparent
                            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.9) 
                        : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Theme.of(context).brightness == Brightness.dark
                        ? Border.all(
                            color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                            width: 1,
                          )
                        : null,
                    ),
                    child: Text(
                      tabs[index],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark
                          ? isSelected ? Colors.white : const Color(0xFFB0B0B5)
                          : isSelected ? const Color(0xFFFF85A1) : Colors.black54,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}




class FadeInTransition extends StatefulWidget {
  final Widget child;
  const FadeInTransition({super.key, required this.child});

  @override
  State<FadeInTransition> createState() => _FadeInTransitionState();
}

class _FadeInTransitionState extends State<FadeInTransition> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(FadeInTransition oldWidget) {
    _controller.reset();
    _controller.forward();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fadeAnimation, child: widget.child);
  }
}

class YearlyReportView extends ConsumerWidget {
  const YearlyReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitProvider);
    final today = DateTime.now();
    final startDate = today.subtract(const Duration(days: 364));
    final startOffset = startDate.weekday % 7; // Sunday = 0
    final totalCells = startOffset + 365;
    final numCols = (totalCells / 7).ceil();

    const double cellSize = 12.0;
    const double spacing = 4.0;
    const double gridHeight = (7 * cellSize) + (6 * spacing);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...habits.map((habit) {
            int completedDays = 0;
            double totalProgressSum = 0.0;
            int scheduledDaysCount = 0; // denominator: how many days in the year the habit was due

            // Iterate all 365 days; exclude non-scheduled days entirely for custom habits
            for (int i = 0; i < 365; i++) {
              final date = startDate.add(Duration(days: i));
              final dateStr = DateFormat('yyyy-MM-dd').format(date);
              final bool daySkipped = !isHabitScheduledOn(habit, date);

              // Non-scheduled days are completely ignored for custom habits
              if (daySkipped) continue;

              scheduledDaysCount++;
              final done = habit.dailyProgress[dateStr] ?? 0;
              final goal = habit.goalValue > 0 ? habit.goalValue : 1;
              totalProgressSum += (done / goal).clamp(0.0, 1.0);
              if (habit.goalValue > 0 && done >= habit.goalValue) {
                completedDays++;
              }
            }

            // Denominator: scheduled days for custom habits, all 365 days for everyday habits
            final int denominator = habit.isEveryDay ? 365 : scheduledDaysCount;
            final int percent = denominator > 0 ? ((totalProgressSum / denominator) * 100).toInt().clamp(0, 100) : 0;
            final baseColor = Color(habit.colorValue);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji + Name
                  Row(
                    children: [
                      Text(habit.icon ?? '✨', style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        habit.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Heatmap Area
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true, // Auto-scroll to current day!
                    physics: const BouncingScrollPhysics(),
                    child: Builder(
                      builder: (context) {
                        List<Widget> headerPositioned = [];
                        List<Widget> columnPositioned = [];
                        
                        for (int colIndex = 0; colIndex < numCols; colIndex++) {
                          final cellIndex = colIndex * 7;
                          final date = startDate.add(Duration(days: cellIndex - startOffset));
                          final prevDate = date.subtract(const Duration(days: 7));
                          
                          final double currentX = colIndex * (cellSize + spacing);

                          // Month Header (Only if month changes)
                          if (colIndex == 0 || date.month != prevDate.month) {
                            if (cellIndex >= startOffset || colIndex == 0) {
                              headerPositioned.add(
                                Positioned(
                                  left: currentX,
                                  top: 0,
                                  child: Text(
                                    DateFormat('MMM').format(date),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }
                          }

                          // Strict 7-Row Column
                          List<Widget> cells = [];
                          for (int row = 0; row < 7; row++) {
                            final flatIndex = (colIndex * 7) + row;
                            if (flatIndex < startOffset || flatIndex >= totalCells) {
                              cells.add(const SizedBox(width: cellSize, height: cellSize));
                            } else {
                              final dayIndex = flatIndex - startOffset;
                              final dayDate = startDate.add(Duration(days: dayIndex));
                              final dateStr = DateFormat('yyyy-MM-dd').format(dayDate);
                              final bool isBeforeStart = dayDate.isBefore(habit.startDate);
                              final bool isSkipped = !isHabitScheduledOn(habit, dayDate);
                              
                              final progress = habit.dailyProgress[dateStr] ?? 0;
                              final goal = habit.goalValue > 0 ? habit.goalValue : 1;
                              final progressPercent = (progress / goal).clamp(0.0, 1.0);

                              Color cellColor;
                              Widget? cellChild;

                              if (isBeforeStart) {
                                cellColor = Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF1C1C1E)
                                    : const Color(0xFFF9FAFB);
                              } else if (isSkipped) {
                                cellColor = Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2C2C2E)
                                    : const Color(0xFFEDEDED);
                                cellChild = const Icon(CupertinoIcons.xmark, size: 6, color: Color(0xFF9E9E9E));
                              } else if (progressPercent <= 0) {
                                cellColor = Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF3A3A3C)
                                    : const Color(0xFFF3F4F6); // 0%
                              } else if (progressPercent >= 1.0) {
                                cellColor = baseColor; // 100%
                              } else if (progressPercent <= 0.20) {
                                cellColor = baseColor.withValues(alpha: 0.20);
                              } else if (progressPercent <= 0.40) {
                                cellColor = baseColor.withValues(alpha: 0.40);
                              } else if (progressPercent <= 0.60) {
                                cellColor = baseColor.withValues(alpha: 0.60);
                              } else {
                                cellColor = baseColor.withValues(alpha: 0.80);
                              }

                              cells.add(
                                Container(
                                  width: cellSize,
                                  height: cellSize,
                                  decoration: BoxDecoration(
                                    color: cellColor,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : ((!isBeforeStart && !isSkipped && progressPercent <= 0) 
                                              ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.5) 
                                              : Colors.transparent),
                                      width: 1,
                                    ),
                                  ),
                                  child: cellChild != null ? Center(child: cellChild) : null,
                                )
                              );
                            }
                            
                            if (row < 6) {
                              cells.add(const SizedBox(height: spacing));
                            }
                          }

                          columnPositioned.add(
                            Positioned(
                              left: currentX,
                              top: 24,
                              child: Column(
                                children: cells,
                              ),
                            ),
                          );
                        }

                        final dynamicGridWidth = numCols * (cellSize + spacing) - spacing;
                        
                        return SizedBox(
                          height: 24.0 + gridHeight, 
                          width: dynamicGridWidth,
                          child: Stack(
                            children: [
                              ...headerPositioned,
                              ...columnPositioned,
                            ],
                          ),
                        );
                      }
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bottom Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$percent% Complete',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: baseColor,
                        ),
                      ),
                      Text(
                        '${completedDays}d',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

class MonthlyReportView extends ConsumerWidget {
  const MonthlyReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitProvider);
    final baseDate = ref.watch(reportDateProvider);
    
    final year = baseDate.year;
    final month = baseDate.month;
    final monthName = DateFormat('MMMM yyyy').format(baseDate);

    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOffset = firstDay.weekday % 7; // Sunday = 0

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          // Month navigation header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => ref.read(reportDateProvider.notifier).state = DateTime(year, month - 1, 1),
                icon: const Icon(CupertinoIcons.chevron_left, size: 18, color: Color(0xFF6B7280)),
              ),
              const SizedBox(width: 16),
              Text(
                monthName,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => ref.read(reportDateProvider.notifier).state = DateTime(year, month + 1, 1),
                icon: const Icon(CupertinoIcons.chevron_right, size: 18, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Habits 2-Column Grid
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 6,
              childAspectRatio: 0.82,
            ),
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];
              return _MonthlyHabitCard(
                habit: habit,
                year: year,
                month: month,
                daysInMonth: daysInMonth,
                firstDayOffset: firstDayOffset,
              );
            },
          ),
          
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

class _MonthlyHabitCard extends StatelessWidget {
  final Habit habit;
  final int year;
  final int month;
  final int daysInMonth;
  final int firstDayOffset;

  const _MonthlyHabitCard({
    required this.habit,
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.firstDayOffset,
  });

  @override
  Widget build(BuildContext context) {
    int completedDays = 0;  // fully completed scheduled days only (for display)
    double totalProgressSum = 0.0;  // sum of progress on scheduled days only
    int scheduledDaysCount = 0; // denominator: how many days in this month the habit was due
    final double goal = habit.goalValue > 0 ? habit.goalValue.toDouble() : 1.0;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final bool daySkipped = !isHabitScheduledOn(habit, date);

      // Non-scheduled days are completely ignored in the calculation
      if (daySkipped) continue;

      scheduledDaysCount++;
      final int done = habit.dailyProgress[dateStr] ?? 0;

      // Continuous progress (0.0 – 1.0)
      final double dailyProgress = (done / goal).clamp(0.0, 1.0);
      totalProgressSum += dailyProgress;

      // Count fully completed days (for the Xd display stat)
      if (habit.goalValue > 0 && done >= habit.goalValue) {
        completedDays++;
      }
    }

    // Denominator: scheduled days for custom habits, all days for everyday habits
    final int denominator = habit.isEveryDay ? daysInMonth : scheduledDaysCount;
    final int percent = denominator > 0 ? ((totalProgressSum / denominator) * 100).round().clamp(0, 100) : 0;
    final baseColor = Color(habit.colorValue);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Emoji + Name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(habit.icon ?? '✨', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  habit.name,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF374151),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Days Header (Su Mo Tu...)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          
          // Calendar Grid
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 1.0,
              ),
              itemCount: firstDayOffset + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstDayOffset) {
                  return const SizedBox.shrink(); // Empty slot
                }
                final day = index - firstDayOffset + 1;
                final date = DateTime(year, month, day);
                final dateStr = DateFormat('yyyy-MM-dd').format(date);
                final bool isBeforeStart = date.isBefore(habit.startDate);
                final bool isSkipped = !isHabitScheduledOn(habit, date);
                final int done = habit.dailyProgress[dateStr] ?? 0;
                final double goal = habit.goalValue > 0 ? habit.goalValue.toDouble() : 1.0;
                final double progressPercent = (done / goal).clamp(0.0, 1.0);

                Color cellColor;
                Widget? cellChild;

                if (isBeforeStart) {
                  cellColor = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3);
                } else if (isSkipped) {
                  cellColor = const Color(0xFFEDEDED);
                  cellChild = const Icon(CupertinoIcons.xmark, size: 7, color: Color(0xFFC7C7CC));
                } else if (progressPercent <= 0) {
                  cellColor = const Color(0xFFF3F4F6);
                } else if (progressPercent >= 1.0) {
                  cellColor = baseColor;
                } else if (progressPercent <= 0.20) {
                  cellColor = baseColor.withValues(alpha: 0.2);
                } else if (progressPercent <= 0.40) {
                  cellColor = baseColor.withValues(alpha: 0.4);
                } else if (progressPercent <= 0.60) {
                  cellColor = baseColor.withValues(alpha: 0.6);
                } else {
                  cellColor = baseColor.withValues(alpha: 0.8);
                }

                return Container(
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: cellChild != null ? Center(child: cellChild) : null,
                );
              },
            ),
          ),
          
          // Bottom Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Percent
              Row(
                children: [
                  Icon(CupertinoIcons.chart_pie_fill, size: 14, color: baseColor),
                  const SizedBox(width: 4),
                  Text(
                    '$percent%',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: baseColor,
                    ),
                  ),
                ],
              ),
              // Right: Days Count
              Row(
                children: [
                  const Icon(CupertinoIcons.square_grid_2x2_fill, size: 14, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text(
                    '${completedDays}d',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}



class _FocusRow extends ConsumerWidget {
  final List<DateTime> weekDays;

  const _FocusRow({required this.weekDays});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveFocusItems = ref.watch(focusDashboardProvider);
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Row(
      children: [
        SizedBox(
          width: 105, 
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF), 
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.timer, size: 10, color: Color(0xFF3B82F6)),
                const SizedBox(width: 3),
                Text(
                  'Focus',
                  style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF3B82F6)),
                ),
              ],
            ),
          ),
        ),
        ...weekDays.map((date) {
          final dateStr = DateFormat('yyyy-MM-dd').format(date);
          final boxData = HiveService.focusDailySummaryBox.get(dateStr);
          int totalSeconds = 0;
          if (boxData != null && boxData is Map) {
            totalSeconds = FocusDailySummary.fromJson(boxData).totalSeconds;
          }
          
          if (dateStr == todayStr) {
            int liveMs = 0;
            for (var item in liveFocusItems) {
              if (item.lastResetDate == todayStr) {
                liveMs += item.currentElapsedMs;
              }
            }
            totalSeconds += (liveMs / 1000).floor();
          }

          String? display;
          if (totalSeconds > 0) {
            final summary = FocusDailySummary(date: dateStr, totalSeconds: totalSeconds);
            display = summary.roundedHours > 0 ? '${summary.roundedHours}h' : '0h';
          }

          return Expanded(
            child: Center(
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: totalSeconds > 0 ? const Color(0xFFDBEAFE) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: (dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now()))
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: display != null 
                    ? Text(display, style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6)))
                    : null,
              ),
            ),
          );
        }),
      ],
    );
  }
}
class FocusReportView extends ConsumerStatefulWidget {
  const FocusReportView({super.key});

  @override
  ConsumerState<FocusReportView> createState() => _FocusReportViewState();
}

class _FocusReportViewState extends ConsumerState<FocusReportView> {
  Timer? _ticker;
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final focusItems = ref.read(focusDashboardProvider);
        if (focusItems.any((item) => item.isRunning)) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return "00:00";
    final int h = totalSeconds ~/ 3600;
    final int m = (totalSeconds % 3600) ~/ 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final focusItems = ref.watch(focusDashboardProvider);
    
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final int mondayOffsetDay = normalizedToday.weekday - 1;
    final DateTime currentMonday = normalizedToday.subtract(Duration(days: mondayOffsetDay));
    final DateTime targetMonday = currentMonday.add(Duration(days: 7 * _weekOffset));
    
    final weekDays = List.generate(7, (i) => targetMonday.add(Duration(days: i)));

    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    // Data aggregation
    Map<String, List<int>> focusDataMap = {}; 
    for (var item in focusItems) {
      focusDataMap[item.name] = List.filled(7, 0);
    }

    List<int> dailyTotals = List.filled(7, 0);
    bool hasDataForTable = focusItems.isNotEmpty;

    for (int i = 0; i < 7; i++) {
      final day = weekDays[i];
      final dateStr = DateFormat('yyyy-MM-dd').format(day);
      final boxData = HiveService.focusDailySummaryBox.get(dateStr);
      
      FocusDailySummary? summary;
      if (boxData != null && boxData is Map) {
        summary = FocusDailySummary.fromJson(boxData);
      }

      // Column Total: ONLY sum active focuses (no deleted focus data)
      int colTotal = 0;
      
      for (var item in focusItems) {
        int cellSeconds = 0;
        int historicalSeconds = summary?.focusDurations[item.name] ?? 0;

        if (dateStr == todayStr && _weekOffset == 0) {
          // For today: Use live elapsed time (includes accumulated + running)
          cellSeconds = (item.currentElapsedMs / 1000).floor();
        } else {
          // For past days: Use Hive snapshot
          cellSeconds = historicalSeconds;
        }

        focusDataMap[item.name]![i] = cellSeconds;
        colTotal += cellSeconds;
      }
      
      dailyTotals[i] = colTotal;
    }


    if (!hasDataForTable) {
      return _buildEmptyState();
    }

    // Sort focus names by their weekly total (descending)
    final List<String> sortedNames = focusDataMap.keys.toList()
      ..sort((a, b) {
        final sumA = focusDataMap[a]!.reduce((v, e) => v + e);
        final sumB = focusDataMap[b]!.reduce((v, e) => v + e);
        return sumB.compareTo(sumA);
      });

    final int weeklyGrandTotal = dailyTotals.reduce((v, e) => v + e);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderSection(targetMonday),
          const SizedBox(height: 24),
          
          // The Table
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildTableHeader(),
                    const Divider(height: 1, thickness: 1),
                    ...sortedNames.asMap().entries.map((entry) {
                      final name = entry.value;
                      final isEven = entry.key % 2 == 0;
                      final durations = focusDataMap[name]!;
                      final rowTotal = durations.reduce((v, e) => v + e);
                      return _buildTableRow(name, durations, rowTotal, isEven);
                    }),
                    const Divider(height: 1, thickness: 1),
                    _buildTableFooter(dailyTotals, weeklyGrandTotal),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.chart_bar, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Start focusing to see reports',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    final range = "${DateFormat('d MMM').format(monday)} - ${DateFormat('d MMM').format(sunday)}";
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            'Weekly Focus Breakdown',
            style: GoogleFonts.fredoka(
              fontSize: 22,
              fontWeight: FontWeight.w600, // Simulates Fredoka One weight
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: iconColor),
              onPressed: () => setState(() => _weekOffset--),
            ),
            const SizedBox(width: 8),
            Text(
              "Week $range",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.chevron_right, color: _weekOffset < 0 ? iconColor : Colors.transparent),
              onPressed: _weekOffset < 0 ? () => setState(() => _weekOffset++) : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          _buildCell('Focus', isHeader: true, width: 100, isLeft: true),
          _buildCell('Mon', isHeader: true),
          _buildCell('Tue', isHeader: true),
          _buildCell('Wed', isHeader: true),
          _buildCell('Thu', isHeader: true),
          _buildCell('Fri', isHeader: true),
          _buildCell('Sat', isHeader: true),
          _buildCell('Sun', isHeader: true),
          _buildCell('Total', isHeader: true, color: const Color(0xFF3B82F6)),
        ],
      ),
    );
  }

  Widget _buildTableRow(String name, List<int> days, int total, bool isEven) {
    return Container(
      color: isEven ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _buildCell(name, width: 100, isLeft: true, isBold: true),
          ...days.map((d) => _buildCell(_formatDuration(d))),
          _buildCell(_formatDuration(total), isBold: true, color: const Color(0xFF3B82F6)),
        ],
      ),
    );
  }

  Widget _buildTableFooter(List<int> dailyTotals, int grandTotal) {
    return Container(
      color: const Color(0xFFEFF6FF), // Soft highlighted blue
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          _buildCell('Total', width: 100, isLeft: true, isBold: true, color: const Color(0xFF1E40AF)),
          ...dailyTotals.map((t) => _buildCell(_formatDuration(t), isBold: true, color: const Color(0xFF1E40AF))),
          _buildCell(_formatDuration(grandTotal), isBold: true, color: const Color(0xFF1E40AF)),
        ],
      ),
    );
  }

  Widget _buildCell(String text, {
    bool isHeader = false, 
    double width = 65, 
    bool isLeft = false, 
    bool isBold = false,
    Color? color,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          text,
          textAlign: isLeft ? TextAlign.left : TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: isHeader ? 11 : 12,
            fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.w500,
            color: color ?? (isHeader ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class MoodReportView extends ConsumerWidget {
  const MoodReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseDate = ref.watch(reportDateProvider);
    final moods = ref.watch(dailyMoodsProvider);
    
    final year = baseDate.year;
    final month = baseDate.month;
    final monthName = DateFormat('MMMM yyyy').format(baseDate);

    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstDayOffset = firstDay.weekday % 7; 
    
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => ref.read(reportDateProvider.notifier).state = DateTime(year, month - 1, 1),
                icon: const Icon(CupertinoIcons.chevron_left, size: 18, color: Color(0xFF6B7280)),
              ),
              const SizedBox(width: 16),
              Text(
                monthName,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => ref.read(reportDateProvider.notifier).state = DateTime(year, month + 1, 1),
                icon: const Icon(CupertinoIcons.chevron_right, size: 18, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Calendar Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                // Days Header (Su Mo Tu...)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((day) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                
                // Calendar Grid
                GridView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: firstDayOffset + daysInMonth,
                  itemBuilder: (context, index) {
                    if (index < firstDayOffset) {
                      return const SizedBox.shrink();
                    }
                    
                    final day = index - firstDayOffset + 1;
                    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime(year, month, day));
                    final isToday = dateStr == todayStr;
                    final emoji = moods[dateStr];

                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isToday ? Theme.of(context).colorScheme.primaryContainer : (emoji != null ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.transparent),
                      ),
                      alignment: Alignment.center,
                      child: emoji != null
                          ? Text(emoji, style: const TextStyle(fontSize: 20))
                          : Text(
                              '$day',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // --- NEW: Premium Average Mood Card ---
          if (moods.isNotEmpty) ...[
            Builder(builder: (context) {
              int totalScore = 0;
              int count = 0;
              
              int getMoodScore(String emoji) {
                const high = ['🤩','🥰','😁','🥳','✨','🔥'];
                const good = ['🙂','😊','😌','✌️','🎉'];
                const neutral = ['😐','😶','☁️','🤔'];
                const low = ['😕','🫤','🥱','🌧️'];
                const veryLow = ['😭','😢','😞','☹️','😠','💔'];
              
                if (high.contains(emoji)) return 10;
                if (good.contains(emoji)) return 7;
                if (neutral.contains(emoji)) return 5;
                if (low.contains(emoji)) return 3;
                if (veryLow.contains(emoji)) return 1;
                return 5; // fallback
              }

              // Only calculate for current month
              moods.forEach((dateStr, emoji) {
                final date = DateTime.tryParse(dateStr);
                if (date != null && date.month == month && date.year == year) {
                  totalScore += getMoodScore(emoji);
                  count++;
                }
              });

              if (count == 0) return const SizedBox.shrink();

              final avg = (totalScore / count).round();
              
              String label = 'Neutral';
              List<Color> bgColors = [const Color(0xFFEFEFEF), const Color(0xFFE0E0E0)];
              
              if (avg >= 9) {
                label = 'Excellent';
                bgColors = [const Color(0xFFFFF0C2), const Color(0xFFFFD1A9)]; // Warm peach/yellow
              } else if (avg >= 6) {
                label = 'Positive';
                bgColors = [const Color(0xFFE8F5E9), const Color(0xFFC8E6C9)]; // Soft fresh green
              } else if (avg >= 3) {
                label = 'Neutral';
                bgColors = [const Color(0xFFF5F5F5), const Color(0xFFE0E0E0)]; // Beige/light grey
              } else {
                label = 'Low';
                bgColors = [const Color(0xFFE3F2FD), const Color(0xFFD1C4E9)]; // Soft blue/lavender
              }

              final isDark = Theme.of(context).brightness == Brightness.dark;

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: isDark ? const Color(0xFF0D0D0D) : null,
                  gradient: isDark 
                      ? null 
                      : LinearGradient(
                          colors: bgColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: bgColors.last.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      )
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Text Side
                    Expanded(
                      flex: isDark ? 100 : 60,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Average Mood',
                            style: GoogleFonts.fredoka(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            label,
                            style: GoogleFonts.fredoka(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                              color: isDark ? Colors.white : const Color(0xFF2D264B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'This month so far',
                            style: GoogleFonts.fredoka(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white.withValues(alpha: 0.70) : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Right Art Side (Light Mode Only)
                    if (!isDark)
                      Expanded(
                        flex: 40,
                        child: Container(
                          height: 90,
                          alignment: Alignment.centerRight,
                          child: _PremiumMoodArt(moodLabel: label, isDark: isDark),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
            
          const SizedBox(height: 120),
        ],
      ),
    );
  }
}

// ── Premium Abstract Mood Art (No Emojis, Wallpaper Style) ──────────────────

class _PremiumMoodArt extends StatelessWidget {
  final String moodLabel;
  final bool isDark;

  const _PremiumMoodArt({required this.moodLabel, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: CustomPaint(
        painter: _MoodArtPainter(moodLabel: moodLabel, isDark: isDark),
      ),
    );
  }
}

class _MoodArtPainter extends CustomPainter {
  final String moodLabel;
  final bool isDark;

  _MoodArtPainter({required this.moodLabel, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // Determine visual style based on label mapping
    if (moodLabel == 'Excellent' || moodLabel == 'Positive') {
      _drawPositive(canvas, size);
    } else if (moodLabel == 'Neutral') {
      _drawNeutral(canvas, size);
    } else {
      _drawLow(canvas, size);
    }
  }

  void _drawPositive(Canvas canvas, Size size) {
    // Warm sun glow + fresh flowing wave
    final sunColor = (isDark ? const Color(0xFFFDE68A) : const Color(0xFFFFD166)).withValues(alpha: 0.85);
    final waveColor = (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFFF9F1C)).withValues(alpha: 0.65);
    
    final paint1 = Paint()
      ..color = sunColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      
    final paint2 = Paint()
      ..color = waveColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    // Glowing sun top right
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.25), size.height * 0.45, paint1);

    // Flowing smooth wave
    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.9);
    path.quadraticBezierTo(size.width * 0.4, size.height * 0.4, size.width * 0.9, size.height * 0.7);
    path.lineTo(size.width * 0.9, size.height * 1.2);
    path.lineTo(size.width * 0.1, size.height * 1.2);
    path.close();
    canvas.drawPath(path, paint2);
  }

  void _drawNeutral(Canvas canvas, Size size) {
    // Balanced, airy cloud-like shapes / symmetry
    final baseColor = (isDark ? const Color(0xFF9CA3AF) : const Color(0xFFB0BEC5)).withValues(alpha: 0.75);
    final accentColor = (isDark ? const Color(0xFF6B7280) : const Color(0xFFCFD8DC)).withValues(alpha: 0.6);

    final paint1 = Paint()
      ..color = baseColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final paint2 = Paint()
      ..color = accentColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // Two balanced interlocking blobs
    canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.5), size.height * 0.4, paint1);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.6), size.height * 0.35, paint2);
  }

  void _drawLow(Canvas canvas, Size size) {
    // Soft, minimal, blurred wave at bottom
    final toneColor = (isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : const Color(0xFF90CAF9).withValues(alpha: 0.7));
    final darkColor = (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFF64B5F6).withValues(alpha: 0.6));

    final paint1 = Paint()
      ..color = toneColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      
    final paint2 = Paint()
      ..color = darkColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);

    // Drooping soft abstract oval
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.7), width: size.width * 0.8, height: size.height * 0.5),
      paint2,
    );
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.6), size.height * 0.35, paint1);
  }

  @override
  bool shouldRepaint(covariant _MoodArtPainter oldDelegate) {
    return oldDelegate.moodLabel != moodLabel || oldDelegate.isDark != isDark;
  }
}

class _SmartInsight {
  final String text;
  final IconData icon;
  final Color color;
  final int priority;
  _SmartInsight(this.text, this.icon, this.color, this.priority);
}

class InsightsReportView extends ConsumerWidget {
  const InsightsReportView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitProvider);
    final today = DateTime.now();

    // ────────────────────────────────────────────────────────────────
    // 1. Core State & Trackers (Normalized & Mathematically Audited)
    // ────────────────────────────────────────────────────────────────
    double totalPossibleCompletions = 0;
    double totalActualCompletions = 0;
    int perfectDaysCount = 0;

    final Map<int, double> dayScoresSumByWeekday = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    final Map<int, int> validDaysByWeekday = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};

    final Map<String, double> habitPossible = {};
    final Map<String, double> habitActual = {};
    final Map<String, int> habitScheduledDays = {};
    final Map<String, String> habitNames = {};

    double morningPossible = 0, morningActual = 0; int morningDays = 0;
    double afternoonPossible = 0, afternoonActual = 0; int afternoonDays = 0;
    double eveningPossible = 0, eveningActual = 0; int eveningDays = 0;

    double last7DayScoresSum = 0; int last7ValidDays = 0;
    double prev7DayScoresSum = 0; int prev7ValidDays = 0;

    double todayPossible = 0;
    double todayActual = 0;

    final List<double> heatmapDensities = List.filled(30, 0.0);

    int currentGlobalStreak = 0;
    int bestGlobalStreak = 0;
    int tempStreak = 0;
    int streakYesterday = 0;

    List<int> brokenStreaks = [];

    // Iterate over the last 30 days
    final last30Days = List.generate(30, (i) => today.subtract(Duration(days: 29 - i)));

    for (int i = 0; i < last30Days.length; i++) {
      final date = last30Days[i];
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      double dayPossible = 0;
      double dayActual = 0;

      for (final habit in habits) {
        if (date.isBefore(habit.startDate)) continue;
        final appWeekday = date.weekday % 7;
        final isActiveDay = habit.isEveryDay || habit.selectedDays.contains(appWeekday);
        
        if (isActiveDay && !habit.isQuitHabit) {
          // Normalization: Every active habit counts as precisely 1.0 point per day
          if (habit.goalValue <= 0) continue;
          double goal = habit.goalValue.toDouble();
          double progressRaw = (habit.dailyProgress[dateKey] ?? 0).toDouble();
          double normalizedProgress = (progressRaw / goal).clamp(0.0, 1.0);

          dayPossible += 1.0;
          dayActual += normalizedProgress;

          habitPossible[habit.id] = (habitPossible[habit.id] ?? 0) + 1.0;
          habitActual[habit.id] = (habitActual[habit.id] ?? 0) + normalizedProgress;
          habitScheduledDays[habit.id] = (habitScheduledDays[habit.id] ?? 0) + 1;
          habitNames[habit.id] = habit.name;

          if (habit.reminderHour != null) {
            int h = habit.reminderHour!;
            if (h >= 5 && h < 12) {
              morningPossible += 1.0; morningActual += normalizedProgress; morningDays++;
            } else if (h >= 12 && h < 17) {
              afternoonPossible += 1.0; afternoonActual += normalizedProgress; afternoonDays++;
            } else {
              eveningPossible += 1.0; eveningActual += normalizedProgress; eveningDays++;
            }
          }
        }
      }

      if (i == 29) {
        todayPossible = dayPossible;
        todayActual = dayActual;
      }

      totalPossibleCompletions += dayPossible;
      totalActualCompletions += dayActual;

      if (dayPossible > 0) {
        double currentDayScore = dayActual / dayPossible;
        
        dayScoresSumByWeekday[date.weekday] = (dayScoresSumByWeekday[date.weekday] ?? 0) + currentDayScore;
        validDaysByWeekday[date.weekday] = (validDaysByWeekday[date.weekday] ?? 0) + 1;
        
        if (i >= 23 && i <= 29) { 
          last7DayScoresSum += currentDayScore; 
          last7ValidDays++; 
        }
        if (i >= 16 && i <= 22) { 
          prev7DayScoresSum += currentDayScore; 
          prev7ValidDays++; 
        }

        bool isPerfect = dayActual >= (dayPossible - 0.001); // Float safety
        if (isPerfect) {
          perfectDaysCount++;
          tempStreak++;
          if (tempStreak > bestGlobalStreak) bestGlobalStreak = tempStreak;
        } else {
          if (tempStreak > 0 && i < 29) brokenStreaks.add(tempStreak);
          tempStreak = 0;
        }
        heatmapDensities[i] = (dayActual / dayPossible).clamp(0.0, 1.0);
      } else {
        // Neutral Day: Streak is not broken, nor increased mathematically.
      }
      
      if (i == 28) streakYesterday = tempStreak;
    }
    
    currentGlobalStreak = tempStreak;
    int consistencyScore = totalPossibleCompletions > 0 
        ? ((totalActualCompletions / totalPossibleCompletions) * 100).round() : 0;

    // ────────────────────────────────────────────────────────────────
    // 2. Intelligent Coach — Priority Engine & Edge Case Guards
    // ────────────────────────────────────────────────────────────────
    List<_SmartInsight> generatedInsights = [];
    int totalScheduledDays = habitScheduledDays.values.fold(0, (a, b) => a + b); // Baseline proxy

    if (totalScheduledDays < 5) {
      // 🔇 INSUFFICIENT DATA SILENCE: Completely abort insights for highly new users
      generatedInsights.add(_SmartInsight("Keep building your routine! Insights unlock soon.", CupertinoIcons.lock_fill, const Color(0xFF6B7280), 10));
    } else {
      // [100] Risk Insight
      if (todayPossible > 0) {
        bool todayIsPerfect = todayActual >= (todayPossible - 0.001);
        if (streakYesterday >= 2 && !todayIsPerfect && last30Days[29].hour >= 18) {
          generatedInsights.add(_SmartInsight(
            "⚠️ You are at risk of breaking your $streakYesterday-day streak today!", 
            CupertinoIcons.exclamationmark_triangle_fill, const Color(0xFFEF4444), 100
          ));
        }
      }

      // [90] Hardest / Easiest Habit
      String? hardest, easiest;
      double minRate = 2.0, maxRate = -1.0;
      for (var id in habitPossible.keys) {
        if ((habitScheduledDays[id] ?? 0) >= 5) { // Needs sufficient absolute days
          double r = habitActual[id]! / habitPossible[id]!;
          if (r < minRate) { minRate = r; hardest = habitNames[id]; }
          if (r > maxRate) { maxRate = r; easiest = habitNames[id]; }
        }
      }
      if (hardest != null && minRate <= 0.5) {
        generatedInsights.add(_SmartInsight("Hardest Habit: $hardest (${(minRate*100).round()}%)", CupertinoIcons.flame_fill, const Color(0xFFEF4444), 90));
      } else if (easiest != null && maxRate >= 0.85) {
        generatedInsights.add(_SmartInsight("Strongest Habit: $easiest (${(maxRate*100).round()}%)", CupertinoIcons.star_fill, const Color(0xFFF59E0B), 85));
      }

      // [70] Weekly Trend
      if (prev7ValidDays > 0 && last7ValidDays > 0 && totalScheduledDays >= 14) {
        double currentWk = last7DayScoresSum / last7ValidDays;
        double prevWk = prev7DayScoresSum / prev7ValidDays;
        double diff = currentWk - prevWk;
        if (diff >= 0.10 && currentWk > 0.3) {
          generatedInsights.add(_SmartInsight("Great improvement this week! 🚀", CupertinoIcons.rocket_fill, const Color(0xFF8B5CF6), 70));
        } else if (diff <= -0.10 && prevWk > 0.3) {
          generatedInsights.add(_SmartInsight("Slight drop this week.", CupertinoIcons.chart_pie_fill, const Color(0xFFF59E0B), 70));
        }
      }

      // [60] Streak Break Analysis
      if (brokenStreaks.length >= 2) {
        double avgBreak = brokenStreaks.reduce((a, b) => a + b) / brokenStreaks.length;
        if (avgBreak >= 3 && currentGlobalStreak < avgBreak) {
          generatedInsights.add(_SmartInsight("You usually break your streak around ${avgBreak.round()} days. Push through!", CupertinoIcons.shield_lefthalf_fill, const Color(0xFF3B82F6), 60));
        }
      }

      // [50] Time-based Performance
      if (morningDays >= 5 || afternoonDays >= 5 || eveningDays >= 5) {
        double mRate = morningPossible > 0 ? morningActual / morningPossible : 0;
        double aRate = afternoonPossible > 0 ? afternoonActual / afternoonPossible : 0;
        double eRate = eveningPossible > 0 ? eveningActual / eveningPossible : 0;
        
        if (mRate > aRate && mRate > eRate && mRate > 0.6 && morningDays >= 5) {
          generatedInsights.add(_SmartInsight("You perform heavily best with Morning habits.", CupertinoIcons.sun_max_fill, const Color(0xFFEAB308), 50));
        } else if (eRate > mRate && eRate > aRate && eRate > 0.6 && eveningDays >= 5) {
          generatedInsights.add(_SmartInsight("You are highly consistent with Evening habits.", CupertinoIcons.moon_fill, const Color(0xFF6366F1), 50));
        } else if (aRate > mRate && aRate > eRate && aRate > 0.6 && afternoonDays >= 5) {
          generatedInsights.add(_SmartInsight("Afternoon is your most active time currently.", CupertinoIcons.sun_haze_fill, const Color(0xFFF97316), 50));
        }
      }

      // [40] Weekday Pattern
      if (totalPossibleCompletions > 0) {
        int bestDay = 1, worstDay = 1;
        double bestRate = -1.0, worstRate = 2.0;

        for (int day = 1; day <= 7; day++) {
          if ((validDaysByWeekday[day] ?? 0) >= 3) { // Require at least 3 occurrences
            double rate = (dayScoresSumByWeekday[day] ?? 0) / validDaysByWeekday[day]!;
            if (rate > bestRate) { bestRate = rate; bestDay = day; }
            if (rate < worstRate) { worstRate = rate; worstDay = day; }
          }
        }
        final dayNames = {1: 'Mondays', 2: 'Tuesdays', 3: 'Wednesdays', 4: 'Thursdays', 5: 'Fridays', 6: 'Saturdays', 7: 'Sundays'};
        if (bestRate >= 0.8 && bestRate > worstRate + 0.3) {
          generatedInsights.add(_SmartInsight("You perform absolutely best on ${dayNames[bestDay]}.", CupertinoIcons.checkmark_seal_fill, const Color(0xFF10B981), 40));
        }
        if (worstRate <= 0.5 && worstDay != bestDay) {
          generatedInsights.add(_SmartInsight("You miss habits mostly on ${dayNames[worstDay]}.", CupertinoIcons.calendar_today, const Color(0xFF6B7280), 45));
        }
      }

      // Fallbacks
      if (generatedInsights.isEmpty) {
        generatedInsights.add(_SmartInsight("Small daily habits lead to massive long-term results.", CupertinoIcons.chart_bar_fill, const Color(0xFF6366F1), 10));
      }
    }

    // Sort by priority and take Top 3
    generatedInsights.sort((a, b) => b.priority.compareTo(a.priority));
    final displayInsights = generatedInsights.take(3).toList();

    // ────────────────────────────────────────────────────────────────
    // 2.5. Weekly Insights Calculations (Progress Feedback Upgrade)
    // ────────────────────────────────────────────────────────────────
    String weeklyImprovementText = "Keep tracking to unlock insights";
    bool hasImprovementData = totalScheduledDays >= 10;
    Color improvementColor = const Color(0xFF9CA3AF);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (prev7ValidDays >= 4 && last7ValidDays >= 4) {
      double currentWeekAvg = last7DayScoresSum / last7ValidDays;
      double previousWeekAvg = prev7DayScoresSum / prev7ValidDays;
      
      if (previousWeekAvg == 0) {
        weeklyImprovementText = "Getting started";
        improvementColor = isDark ? Colors.white : const Color(0xFF6B7280);
      } else {
        double improvement = (((currentWeekAvg - previousWeekAvg) / previousWeekAvg) * 100).roundToDouble();
        if (improvement > 2.0) {
          weeklyImprovementText = "Great improvement this week";
          improvementColor = isDark ? Colors.white : const Color(0xFF10B981); // Green in Light, White in Dark
        } else if (improvement < -2.0) {
          weeklyImprovementText = "Slight drop this week";
          improvementColor = isDark ? Colors.white : const Color(0xFFEF4444); // Red in Light, White in Dark
        } else {
          weeklyImprovementText = "You stayed consistent this week";
          improvementColor = isDark ? Colors.white : const Color(0xFF6B7280);
        }
      }
    } else {
      weeklyImprovementText = "Keep tracking to unlock insights";
      improvementColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF9CA3AF);
    }

    String bestDayText = "Not enough data";
    String weakestDayText = "Not enough data";
    
    if (totalPossibleCompletions > 0) {
      int bestDay = 1, worstDay = 1;
      double bestRate = -1.0, worstRate = 2.0;

      for (int day = 1; day <= 7; day++) {
        if ((validDaysByWeekday[day] ?? 0) >= 3) {
          double rate = (dayScoresSumByWeekday[day] ?? 0) / validDaysByWeekday[day]!;
          if (rate > bestRate) { bestRate = rate; bestDay = day; }
          if (rate < worstRate) { worstRate = rate; worstDay = day; }
        }
      }
      
      final dayNames = {1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday', 5: 'Friday', 6: 'Saturday', 7: 'Sunday'};
      
      if (bestRate >= 0) {
        bestDayText = dayNames[bestDay] ?? "Unknown";
      }
      if (worstRate <= 1.0 && bestDay != worstDay && worstRate >= 0) {
        weakestDayText = dayNames[worstDay] ?? "Unknown";
      } else if (worstRate <= 1.0 && bestRate >= 0) {
      // If all days are perfectly equal or not enough occurrences for a distinct worst day
        weakestDayText = "None"; 
      }
    }

    // ────────────────────────────────────────────────────────────────
    // 3. UI Layout Integration
    // ────────────────────────────────────────────────────────────────
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [


          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  context: context,
                  isDark: isDark,
                  title: 'Global Streak',
                  value: '$currentGlobalStreak',
                  unit: ' days',
                  subtitle: 'Top: $bestGlobalStreak days',
                  icon: CupertinoIcons.flame_fill,
                  iconColor: const Color(0xFFF97316),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInsightCard(
                  context: context,
                  isDark: isDark,
                  title: 'Perfect Days',
                  value: '$perfectDaysCount',
                  unit: '',
                  subtitle: 'Over 30 days',
                  icon: CupertinoIcons.star_fill,
                  iconColor: const Color(0xFFEAB308),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildConsistencyCard(context, isDark, consistencyScore),
          const SizedBox(height: 24),
          
          // Weekly Insights Card (New Upgrade)
          if (hasImprovementData) ...[
            _buildWeeklyInsightsCard(
              context: context, 
              isDark: isDark, 
              improvementText: weeklyImprovementText,
              improvementColor: improvementColor,
              bestDay: bestDayText,
              weakestDay: weakestDayText,
            ),
            const SizedBox(height: 24),
          ],

          // Smart Findings Section
          Text(
            'Smart Findings',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 16),
          
          ...displayInsights.map((insight) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSmartTextCard(context, isDark, insight.text, insight.icon, insight.color),
          )),
          
          const SizedBox(height: 20),

          // 30-Day Heatmap
          Text(
            '30-Day Density',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 16),
          _buildHeatmapGrid(context, isDark, heatmapDensities),
          
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildInsightCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String value,
    required String unit,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              if (unit.isNotEmpty)
                Text(
                  unit,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF636366) : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsistencyCard(BuildContext context, bool isDark, int score) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consistency Score',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$score%',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                Text(
                  'Based on last 30 days',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF636366) : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            height: 80,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    score >= 80 ? const Color(0xFF10B981) :
                    score >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                  ),
                ),
                Center(
                  child: Icon(
                    score >= 80 ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.chart_bar_alt_fill,
                    color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF9CA3AF),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartTextCard(BuildContext context, bool isDark, String text, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFE5E5EA) : const Color(0xFF1F2937),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid(BuildContext context, bool isDark, List<double> densities) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.0,
        ),
        itemCount: 30, // We have exactly 30 days
        itemBuilder: (context, index) {
          final density = densities[index];
          final baseColor = Theme.of(context).colorScheme.primary;
          Color cellColor;
          if (density <= 0) {
            cellColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF3F4F6);
          } else if (density >= 1.0) {
            cellColor = baseColor;
          } else if (density <= 0.3) {
            cellColor = baseColor.withValues(alpha: 0.3);
          } else if (density <= 0.6) {
            cellColor = baseColor.withValues(alpha: 0.6);
          } else {
            cellColor = baseColor.withValues(alpha: 0.8);
          }

          return Container(
            decoration: BoxDecoration(
              color: cellColor,
              borderRadius: BorderRadius.circular(6),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyInsightsCard({
    required BuildContext context,
    required bool isDark,
    required String improvementText,
    required Color improvementColor,
    required String bestDay,
    required String weakestDay,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.chart_bar_alt_fill, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Weekly Insights',
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            improvementText,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: improvementColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Best day: ',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              Text(
                bestDay,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Needs attention: ',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              Text(
                weakestDay,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
