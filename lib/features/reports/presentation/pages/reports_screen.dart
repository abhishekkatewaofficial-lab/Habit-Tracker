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

  final List<String> _tabs = ['Weekly', 'Monthly', 'Yearly', 'Focus', 'Mood'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Content Area
          Padding(
            padding: const EdgeInsets.only(top: 100),
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                const WeeklyReportView(),
                const MonthlyReportView(),
                const YearlyReportView(),
                const FocusReportView(),
                const MoodReportView(),
              ],
            ),
          ),

          // Top Floating Dock
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
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
            ),
          ),
        ],
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
              const Text('☀️', style: TextStyle(fontSize: 18)),
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
        color: Colors.white,
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
                      color: const Color(0xFF9CA3AF),
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
                              color: const Color(0xFF374151),
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
                    final isSkipped = !isHabitScheduledOn(habit, date);
                    final progressVal = habit.dailyProgress[dateStr] ?? 0;
                    final goal = habit.goalValue > 0 ? habit.goalValue : 1;
                    final progressPercent = (progressVal / goal).clamp(0.0, 1.0);
                    final baseColor = Color(habit.colorValue);

                    Color cellColor;
                    Widget? cellChild;

                    if (isSkipped) {
                      // Not scheduled — show subtle X
                      cellColor = const Color(0xFFEDEDED);
                      cellChild = const Icon(CupertinoIcons.xmark, size: 9, color: Color(0xFFC7C7CC));
                    } else if (progressPercent <= 0) {
                      cellColor = const Color(0xFFF9FAFB);
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
                              color: (!isSkipped && progressPercent <= 0) ? const Color(0xFFF3F4F6) : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: cellChild != null ? Center(child: cellChild) : null,
                        ),
                      ),
                    );
                  }).toList(),
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
              Text('Less', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
              const SizedBox(width: 8),
              ...[0.0, 0.2, 0.4, 0.6, 0.8, 1.0].map((v) => Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: v == 0 
                      ? const Color(0xFFF9FAFB) 
                      : const Color(0xFF22C55E).withValues(alpha: v == 1.0 ? 1.0 : v),
                  borderRadius: BorderRadius.circular(2),
                  border: v == 0 ? Border.all(color: const Color(0xFFF3F4F6), width: 0.5) : null,
                ),
              )),
              const SizedBox(width: 8),
              Text('More', style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
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

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF9CA3AF),
            ),
          ),
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
            color: Colors.white.withValues(alpha: 0.25), // lighter for the purple bg
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
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
                        ? Colors.white.withValues(alpha: 0.9) 
                        : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tabs[index],
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? const Color(0xFFFF85A1) : Colors.black54,
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

    final double cellSize = 12.0;
    final double spacing = 4.0;
    final double colWidth = cellSize + spacing;
    final double gridHeight = (7 * cellSize) + (6 * spacing);
    final double gridWidth = (numCols * cellSize) + ((numCols - 1) * spacing);

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
                color: Colors.white,
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
                          color: const Color(0xFF374151),
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
                    child: SizedBox(
                      height: 24.0 + gridHeight, // 24px header + grid
                      width: gridWidth,
                      child: Stack(
                        children: [
                          // Months Header
                          ...List.generate(numCols, (colIndex) {
                            final cellIndex = colIndex * 7;
                            if (cellIndex < startOffset) return const SizedBox.shrink();
                            final date = startDate.add(Duration(days: cellIndex - startOffset));
                            final prevDate = date.subtract(const Duration(days: 7));
                            
                            // Only show if month changes
                            if (colIndex == 0 || date.month != prevDate.month) {
                              return Positioned(
                                left: colIndex * colWidth,
                                top: 0,
                                child: Text(
                                  DateFormat('MMM').format(date),
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: const Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }),
                          
                          // Heatmap Grid
                          Positioned(
                            top: 24,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Wrap(
                              direction: Axis.vertical,
                              spacing: spacing, // vertical gap between cells in a column
                              runSpacing: spacing, // horizontal gap between columns
                              children: List.generate(totalCells, (index) {
                                if (index < startOffset) {
                                  return SizedBox(width: cellSize, height: cellSize);
                                }
                                
                                final dayIndex = index - startOffset;
                                final date = startDate.add(Duration(days: dayIndex));
                                final dateStr = DateFormat('yyyy-MM-dd').format(date);
                                final bool isSkipped = !isHabitScheduledOn(habit, date);

                                final progress = habit.dailyProgress[dateStr] ?? 0;
                                final goal = habit.goalValue > 0 ? habit.goalValue : 1;
                                final progressPercent = (progress / goal).clamp(0.0, 1.0);

                                Color cellColor;
                                Widget? cellChild;

                                if (isSkipped) {
                                  cellColor = const Color(0xFFEDEDED);
                                  cellChild = const Icon(CupertinoIcons.xmark, size: 6, color: Color(0xFFC7C7CC));
                                } else if (progressPercent <= 0) {
                                  cellColor = const Color(0xFFF3F4F6); // 0%
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

                                return Container(
                                  width: cellSize,
                                  height: cellSize,
                                  decoration: BoxDecoration(
                                    color: cellColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: cellChild != null ? Center(child: cellChild) : null,
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
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
                  color: const Color(0xFF374151),
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
        color: Colors.white,
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
                    color: const Color(0xFF374151),
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
                final bool isSkipped = !isHabitScheduledOn(habit, date);
                final int done = habit.dailyProgress[dateStr] ?? 0;
                final double goal = habit.goalValue > 0 ? habit.goalValue.toDouble() : 1.0;
                final double progressPercent = (done / goal).clamp(0.0, 1.0);

                Color cellColor;
                Widget? cellChild;

                if (isSkipped) {
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
                  border: Border.all(color: const Color(0xFFDBEAFE), width: 1),
                ),
                alignment: Alignment.center,
                child: display != null 
                    ? Text(display, style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6)))
                    : null,
              ),
            ),
          );
        }).toList(),
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
    final baseDate = ref.watch(reportDateProvider);
    final focusItems = ref.watch(focusDashboardProvider);
    
    // Calculate Monday-start week using normalized dates
    final normalizedBase = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final int mondayOffset = normalizedBase.weekday - 1;
    final DateTime monday = normalizedBase.subtract(Duration(days: mondayOffset));
    final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));

    
    final today = DateTime.now();
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

        if (dateStr == todayStr) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderSection(monday),
          const SizedBox(height: 24),
          
          // The Table
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
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
          Icon(CupertinoIcons.chart_bar, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Start focusing to see reports',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    final range = "${DateFormat('MMM d').format(monday)} - ${DateFormat('MMM d').format(sunday)}, ${monday.year}";
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Focus Breakdown',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D264B),
          ),
        ),
        Text(
          range,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: Colors.grey.shade50,
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
      color: isEven ? Colors.white : Colors.grey.shade50.withValues(alpha: 0.5),
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
            color: color ?? (isHeader ? Colors.grey.shade500 : const Color(0xFF4B5563)),
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

    int daysLogged = moods.length;
    int currentStreak = 0;
    
    final sortedDates = moods.keys.toList()..sort((a,b) => b.compareTo(a));
    
    if (sortedDates.isNotEmpty) {
      DateTime checkDate = DateTime.now();
      String checkStr = DateFormat('yyyy-MM-dd').format(checkDate);
      if (!moods.containsKey(checkStr)) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        checkStr = DateFormat('yyyy-MM-dd').format(checkDate);
      }
      
      while (moods.containsKey(checkStr)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
        checkStr = DateFormat('yyyy-MM-dd').format(checkDate);
      }
    }

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
                  color: const Color(0xFF374151),
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
              color: Colors.white,
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
                            color: const Color(0xFF9CA3AF),
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
                        color: isToday ? const Color(0xFFFEF3C7) : (emoji != null ? const Color(0xFFF9FAFB) : Colors.transparent),
                      ),
                      alignment: Alignment.center,
                      child: emoji != null
                          ? Text(emoji, style: const TextStyle(fontSize: 20))
                          : Text(
                              '$day',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                color: isToday ? const Color(0xFFD97706) : const Color(0xFF4B5563),
                              ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Bottom Stats
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Days Logged',
                  value: '$daysLogged',
                  color: const Color(0xFF6366F1), // Indigo
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  label: 'Current Streak',
                  value: '${currentStreak}d',
                  color: const Color(0xFFF59E0B), // Amber
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Recent Logs
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Recent Logs',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF374151),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          if (sortedDates.isEmpty)
             const Center(
               child: Padding(
                 padding: EdgeInsets.all(32),
                 child: Text('No mood logs yet!', style: TextStyle(color: Colors.grey)),
               ),
             )
          else
            ...sortedDates.map((dateStr) {
               final date = DateTime.parse(dateStr);
               final formattedDate = DateFormat('MMMM d, yyyy').format(date);
               final emoji = moods[dateStr];
               
               return Container(
                 margin: const EdgeInsets.only(bottom: 12),
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                 decoration: BoxDecoration(
                   color: Colors.white,
                   borderRadius: BorderRadius.circular(16),
                   boxShadow: [
                     BoxShadow(
                       color: Colors.black.withValues(alpha: 0.02),
                       blurRadius: 8,
                       offset: const Offset(0, 4),
                     ),
                   ],
                 ),
                 child: Row(
                   children: [
                     Text(emoji ?? '😐', style: const TextStyle(fontSize: 24)),
                     const SizedBox(width: 16),
                     Text(
                       formattedDate,
                       style: GoogleFonts.poppins(
                         fontSize: 14,
                         fontWeight: FontWeight.w600,
                         color: const Color(0xFF4B5563),
                       ),
                     ),
                     const Spacer(),
                     const Icon(CupertinoIcons.heart_fill, color: Color(0xFFFCA5A5), size: 18),
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
