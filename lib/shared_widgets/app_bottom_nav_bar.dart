import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/constants/app_colors.dart';
import 'package:habit_tracker_ios/core/constants/app_text_styles.dart';
import 'package:habit_tracker_ios/core/constants/app_constants.dart';
import 'package:habit_tracker_ios/providers/navigation_provider.dart';

/// App-wide bottom navigation bar.
class AppBottomNavBar extends ConsumerWidget {
  const AppBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);
    final isPlannerMode = ref.watch(plannerModeProvider);
    final isFocusMode = ref.watch(focusModeProvider);

    return SafeArea(
      bottom: true,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offsetAnimation = Tween<Offset>(
              begin: const Offset(0, 0.5),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: offsetAnimation,
                child: child,
              ),
            );
          },
          child: isPlannerMode 
            ? _buildSubDock(context, ref, currentIndex)
            : isFocusMode
                ? _buildFocusSubDock(context, ref, currentIndex)
                : _buildMainDock(context, ref, currentIndex),
        ),
      ),
    );
  }

  Widget _buildMainDock(BuildContext context, WidgetRef ref, int currentIndex) {
    return Container(
      key: const ValueKey('main_dock'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25), 
                width: 1.5
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                
                // Determine actual navigation index based on item label
                int targetIndex = index;
                if (item.label == 'Reports') targetIndex = AppConstants.navIndexReports;
                if (item.label == 'Planner') targetIndex = AppConstants.navIndexPlanner;
                
                final isSelected = targetIndex == currentIndex;

                return _NavItem(
                  icon: item.icon,
                  activeIcon: item.activeIcon,
                  label: item.label,
                  isSelected: isSelected,
                  onTap: () {
                    if (item.label == 'Planner') {
                      ref.read(plannerModeProvider.notifier).state = true;
                      ref.read(navigationIndexProvider.notifier).state = AppConstants.navIndexPlannerTodo;
                    } else if (item.label == 'Focus') {
                      ref.read(focusModeProvider.notifier).state = true;
                      ref.read(navigationIndexProvider.notifier).state = AppConstants.navIndexFocusDashboard;
                    } else {
                      ref.read(navigationIndexProvider.notifier).state = targetIndex;
                    }
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubDock(BuildContext context, WidgetRef ref, int currentIndex) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      key: const ValueKey('sub_dock'),
      margin: EdgeInsets.zero, // Anchored along with the main dock
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          // Ambient soft glow
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 40,
            offset: const Offset(0, 15),
          ),
          // Deeper drop shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              // Semi-transparent glassy base
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3), // Light reflection edge
                width: 1.5,
              ),
              gradient: RadialGradient(
                center: const Alignment(0, -1.2),
                radius: 1.5,
                colors: [
                  Colors.white.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. ToDo
                _SubNavItem(
                  icon: CupertinoIcons.check_mark_circled,
                  label: 'ToDo',
                  isSelected: currentIndex == AppConstants.navIndexPlannerTodo,
                  onTap: () => ref.read(navigationIndexProvider.notifier).state = AppConstants.navIndexPlannerTodo,
                ),

                // 2. Home (Center Elevated)
                GestureDetector(
                  onTap: () {
                    ref.read(plannerModeProvider.notifier).state = false;
                    ref.read(navigationIndexProvider.notifier).state = AppConstants.navIndexHome;
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    width: 52,
                    height: 52,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.house_fill,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),

                // 3. Matrix
                _SubNavItem(
                  icon: CupertinoIcons.square_grid_2x2,
                  label: 'Matrix',
                  isSelected: currentIndex == AppConstants.navIndexPlannerEisenhower,
                  onTap: () => ref.read(navigationIndexProvider.notifier).state = AppConstants.navIndexPlannerEisenhower,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFocusSubDock(BuildContext context, WidgetRef ref, int currentIndex) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      key: const ValueKey('focus_sub_dock'),
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          // Ambient soft glow (Sync with Planner color)
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15), 
            blurRadius: 40,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1.5,
              ),
              gradient: RadialGradient(
                center: const Alignment(0, -1.2),
                radius: 1.5,
                colors: [
                  Colors.white.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                // 1. Focus
                _SubNavItem(
                  icon: CupertinoIcons.sparkles,
                  label: 'Focus',
                  isSelected: currentIndex == AppConstants.navIndexFocusDashboard,
                  onTap: () => ref.read(navigationIndexProvider.notifier).state = AppConstants.navIndexFocusDashboard,
                ),
                
                // 2. Pomodoro
                _SubNavItem(
                  icon: CupertinoIcons.stopwatch,
                  label: 'Pomodoro',
                  isSelected: currentIndex == AppConstants.navIndexFocusPomodoro,
                  onTap: () => ref.read(navigationIndexProvider.notifier).state = AppConstants.navIndexFocusPomodoro,
                ),

                // 3. Home (Center Elevated)
                GestureDetector(
                  onTap: () {
                    ref.read(focusModeProvider.notifier).state = false;
                    ref.read(navigationIndexProvider.notifier).state = AppConstants.navIndexHome;
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    width: 52,
                    height: 52,
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary, 
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.house_fill,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),

                // 4. Stopwatch
                _SubNavItem(
                  icon: CupertinoIcons.timer,
                  label: 'Stopwatch',
                  isSelected: currentIndex == AppConstants.navIndexFocusStopwatch,
                  onTap: () => ref.read(navigationIndexProvider.notifier).state = AppConstants.navIndexFocusStopwatch,
                ),

                // 5. Countdown
                _SubNavItem(
                  icon: CupertinoIcons.hourglass,
                  label: 'Countdown',
                  isSelected: currentIndex == AppConstants.navIndexFocusCountdown,
                  onTap: () => ref.read(navigationIndexProvider.notifier).state = AppConstants.navIndexFocusCountdown,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        transform: Matrix4.diagonal3Values(
          isSelected ? 1.05 : 1.0, 
          isSelected ? 1.05 : 1.0, 
          1.0
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.6),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const List<_NavItemData> _navItems = [
  _NavItemData(
    icon: CupertinoIcons.house,
    activeIcon: CupertinoIcons.house_fill,
    label: 'Home',
  ),
  _NavItemData(
    icon: CupertinoIcons.timer,
    activeIcon: CupertinoIcons.timer_fill,
    label: 'Focus',
  ),
  _NavItemData(
    icon: CupertinoIcons.square_pencil,
    activeIcon: CupertinoIcons.square_pencil_fill,
    label: 'Diary',
  ),
  _NavItemData(
    icon: CupertinoIcons.calendar_today,
    activeIcon: CupertinoIcons.calendar_today,
    label: 'Planner',
  ),
  _NavItemData(
    icon: CupertinoIcons.chart_bar,
    activeIcon: CupertinoIcons.chart_bar_fill,
    label: 'Reports',
  ),
];

class _SubNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        transform: Matrix4.diagonal3Values(
          isSelected ? 1.05 : 1.0, 
          isSelected ? 1.05 : 1.0, 
          1.0
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon in glowing soft circle when active
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ] : [],
              ),
              child: Icon(
                icon,
                color: color,
                size: isSelected ? 24 : 22, // Minimal modern line icon feel
              ),
            ),
            const SizedBox(height: 4),
            // Clean label
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
