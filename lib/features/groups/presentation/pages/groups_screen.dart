import 'package:flutter/material.dart';
import 'package:habit_tracker_ios/core/constants/app_colors.dart';
import 'package:habit_tracker_ios/core/constants/app_text_styles.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Groups', style: AppTextStyles.displaySmall),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(
                color: AppColors.pastelGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.group_rounded,
                  size: 48, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            Text('Habit Groups', style: AppTextStyles.headlineLarge),
            const SizedBox(height: 8),
            Text('Group challenges coming soon.',
                style: AppTextStyles.secondary),
          ],
        ),
      ),
    );
  }
}
