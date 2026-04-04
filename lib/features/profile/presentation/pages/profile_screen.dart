import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:habit_tracker_ios/core/services/cloud_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker_ios/core/constants/app_colors.dart';
import 'package:habit_tracker_ios/core/constants/app_text_styles.dart';
import 'package:habit_tracker_ios/core/theme/theme_provider.dart';
import 'package:habit_tracker_ios/core/services/notification_provider.dart';
import 'package:habit_tracker_ios/core/services/settings_provider.dart';
import 'package:habit_tracker_ios/core/services/auth_service.dart';

import 'package:habit_tracker_ios/shared_widgets/adaptive_layout.dart';
import '../controllers/profile_controller.dart';
import '../controllers/badge_controller.dart';
import '../controllers/coin_controller.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_controller.dart';
import 'package:habit_tracker_ios/core/services/personality_engine.dart';


class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameController;
  final FocusNode _focusNode = FocusNode();
  bool _isEditing = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _focusNode.addListener(() {
      setState(() {
        _isEditing = _focusNode.hasFocus;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sync the text controller whenever the profile provider rebuilds
    // (covers the initial load AND user-switch reinitialisation).
    final name = ref.read(profileProvider).name;
    if (_nameController.text != name) {
      _nameController.text = name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openAvatarSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _AvatarSelectionSheet(),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, dynamic profile) {
    final authUser = ref.watch(currentUserProvider);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            GestureDetector(
               onTapDown: (_) => setState(() => _isPressed = true),
               onTapUp: (_) => setState(() => _isPressed = false),
               onTapCancel: () => setState(() => _isPressed = false),
               onTap: _openAvatarSelection,
               child: Hero(
                 tag: 'profile_avatar',
                 child: AnimatedScale(
                   scale: _isPressed ? 0.95 : 1.0,
                   duration: const Duration(milliseconds: 150),
                   child: Container(
                     width: 140,
                     height: 140,
                     decoration: BoxDecoration(
                       shape: BoxShape.circle,
                       color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                       border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 4),
                       boxShadow: [
                         if (Theme.of(context).brightness == Brightness.dark)
                           BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10))
                         else
                           BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
                       ],
                       image: profile.imagePath != null
                           ? DecorationImage(image: AssetImage(profile.imagePath!), fit: BoxFit.cover)
                           : null,
                     ),
                     child: profile.imagePath == null
                         ? const Icon(CupertinoIcons.person_fill, size: 60, color: Color(0xFF3A3A3C))
                         : null,
                   ),
                 ),
               ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: _isEditing ? 0.5 : 0.0),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isEditing ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.6) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _nameController,
                  focusNode: _focusNode,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    ref.read(profileProvider.notifier).updateName(val);
                  },
                  onSubmitted: (val) => _focusNode.unfocus(),
                ),
              ),
            ),
            // ── Google Account Email ────────────────────────────────────────
            if (authUser?.email != null && authUser!.email.isNotEmpty) ...
            [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.mail_solid, size: 13, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 6),
                  Text(
                    authUser.email,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: AdaptiveBody(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
            const SizedBox(height: 20),
            _buildPremiumHeader(context, profile),
            const SizedBox(height: 24),
            const _PersonalityShowcase(),
            const SizedBox(height: 24),
            
            const _BadgesShowcase(),
            const SizedBox(height: 20),
            const _CoinBalanceCard(),
            const SizedBox(height: 32),
              
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const _AppearanceSection(),
                  const SizedBox(height: 32),
                  const _GroupedSettings(),
                  const SizedBox(height: 32),
                  const _SyncButton(),
                  const SizedBox(height: 16),
                  const _LogoutButton(),
                  const SizedBox(height: 48),
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

/// Premium Appearance Section — Light / System / Dark theme toggle.
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const modes = [ThemeModeType.light, ThemeModeType.system, ThemeModeType.dark];
    const labels = ['Light', 'System', 'Dark'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.paintbrush_fill, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Appearance',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1) : null,
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: List.generate(3, (i) {
                final isSelected = themeMode == modes[i];
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ref.read(themeProvider.notifier).setMode(modes[i]),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected 
                           ? (isDark ? const Color(0xFF2C2C2E) : Colors.white)
                           : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected && !isDark
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          labels[i],
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected 
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF6B7280)),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarSelectionSheet extends ConsumerStatefulWidget {
  const _AvatarSelectionSheet();

  @override
  ConsumerState<_AvatarSelectionSheet> createState() => _AvatarSelectionSheetState();
}

class _AvatarSelectionSheetState extends ConsumerState<_AvatarSelectionSheet> {
  // We generated 6 beautiful distinct premium avatars
  final List<String> _avatars = List.generate(
    6,
    (index) => 'assets/images/avatars/avatar_${index + 1}.png',
  );

  int? _pressedIndex;

  @override
  Widget build(BuildContext context) {
    final currentAvatar = ref.watch(profileProvider).imagePath;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 40),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Select Avatar',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose your identity',
              style: AppTextStyles.bodyMedium.copyWith(
                color: const Color(0xFF9CA3AF),
              ),
            ),
            const SizedBox(height: 32),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1,
              ),
              itemCount: _avatars.length,
              itemBuilder: (context, index) {
                final avatarPath = _avatars[index];
                final isSelected = currentAvatar == avatarPath;
                final isPressed = _pressedIndex == index;

                return GestureDetector(
                  onTapDown: (_) => setState(() => _pressedIndex = index),
                  onTapUp: (_) => setState(() => _pressedIndex = null),
                  onTapCancel: () => setState(() => _pressedIndex = null),
                  onTap: () {
                    ref.read(profileProvider.notifier).updateImagePath(avatarPath);
                    Navigator.of(context).pop();
                  },
                  child: AnimatedScale(
                    scale: isPressed ? 0.9 : (isSelected ? 1.05 : 1.0),
                    duration: const Duration(milliseconds: 150),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: AppColors.primary, width: 4)
                            : Border.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                width: 2,
                              ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : [],
                        image: DecorationImage(
                          image: AssetImage(avatarPath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Badges Engine & UI
// ─────────────────────────────────────────────────────────────────────────────


class _GroupedSettings extends ConsumerWidget {
  const _GroupedSettings();
  
  Widget _buildGroup(BuildContext context, String title, List<Widget> items) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF9CA3AF))),
          const SizedBox(height: 12),
          Container(
             decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 5))],
             ),
             child: Column(children: items),
          ),
       ],
     );
  }

  Widget _buildTile(BuildContext context, String title, IconData icon, [bool showToggle = false, bool isLast = false]) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     return Column(
       children: [
         ListTile(
           leading: Icon(icon, color: isDark ? Colors.white : const Color(0xFF374151)),
           title: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
           trailing: showToggle 
               ? CupertinoSwitch(value: true, onChanged: (v){}, activeTrackColor: CupertinoColors.activeGreen)
               : Icon(CupertinoIcons.chevron_right, size: 16, color: const Color(0xFF9CA3AF)),
         ),
         if (!isLast) Divider(height: 1, indent: 56, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
       ],
     );
  }

  Widget _buildNotificationTile(BuildContext context, WidgetRef ref, bool isLast) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     final isSettingsOn = ref.watch(notificationProvider);
     
     return Column(
       children: [
         ListTile(
           contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
           leading: Padding(
             padding: const EdgeInsets.only(top: 4),
             child: Icon(CupertinoIcons.bell_fill, color: isDark ? Colors.white : const Color(0xFF374151)),
           ),
           title: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text('Reminders', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
               const SizedBox(height: 2),
               Text(
                 isSettingsOn ? "You'll receive reminders for your habits" : "Reminders are turned off",
                 style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w400, color: const Color(0xFF9CA3AF)),
               ),
             ],
           ),
           trailing: CupertinoSwitch(
             value: isSettingsOn,
             onChanged: (v) {
               ref.read(notificationProvider.notifier).setEnabled(v);
             },
             activeTrackColor: CupertinoColors.activeGreen,
           ),
         ),
         if (!isLast) Divider(height: 1, indent: 56, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
       ],
     );
  }

  Widget _buildSoundsTile(BuildContext context, WidgetRef ref) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     final isNotifOn = ref.watch(notificationProvider);
     final isSoundsOn = ref.watch(soundsProvider);
     
     return Column(
       children: [
         Opacity(
           opacity: isNotifOn ? 1.0 : 0.4,
           child: ListTile(
             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
             leading: Padding(
               padding: const EdgeInsets.only(top: 4),
               child: Icon(CupertinoIcons.speaker_2_fill, color: isDark ? Colors.white : const Color(0xFF374151)),
             ),
             title: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text('Sounds', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
                 if (!isNotifOn) ...[
                   const SizedBox(height: 2),
                   Text("Enable reminders to use sounds", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w400, color: const Color(0xFF9CA3AF))),
                 ],
               ],
             ),
             trailing: CupertinoSwitch(
               value: isSoundsOn,
               onChanged: isNotifOn ? (v) => ref.read(soundsProvider.notifier).setEnabled(v) : null,
               activeTrackColor: CupertinoColors.activeGreen,
             ),
           ),
         ),
         Divider(height: 1, indent: 56, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
       ],
     );
  }

  Widget _buildSmartNudgesTile(BuildContext context, WidgetRef ref) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     final isNotifOn = ref.watch(notificationProvider);
     final isSmartOn = ref.watch(smartNudgesProvider);

     return Column(
       children: [
         Opacity(
           opacity: isNotifOn ? 1.0 : 0.4,
           child: ListTile(
             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
             leading: Padding(
               padding: const EdgeInsets.only(top: 4),
               child: Icon(CupertinoIcons.lightbulb_fill, color: isDark ? Colors.white : const Color(0xFF374151)),
             ),
             title: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text('Smart Nudges', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
                 const SizedBox(height: 2),
                 Text(
                   isNotifOn
                       ? (isSmartOn ? 'Intelligent reminders based on your habits' : 'Smart nudges are off')
                       : 'Enable reminders to use smart nudges',
                   style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w400, color: const Color(0xFF9CA3AF)),
                 ),
               ],
             ),
             trailing: CupertinoSwitch(
               value: isSmartOn,
               onChanged: isNotifOn ? (v) => ref.read(smartNudgesProvider.notifier).setEnabled(v) : null,
               activeTrackColor: CupertinoColors.activeGreen,
             ),
           ),
         ),
         Divider(height: 1, indent: 56, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1)),
       ],
     );
  }

  Widget _buildHapticsTile(BuildContext context, WidgetRef ref) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     final isNotifOn = ref.watch(notificationProvider);
     final isHapticsOn = ref.watch(hapticsProvider);
     
     return Column(
       children: [
         Opacity(
           opacity: isNotifOn ? 1.0 : 0.4,
           child: ListTile(
             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
             leading: Padding(
               padding: const EdgeInsets.only(top: 4),
               child: Icon(CupertinoIcons.waveform_path, color: isDark ? Colors.white : const Color(0xFF374151)), 
             ),
             title: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text('Haptics', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
                 if (!isNotifOn) ...[
                   const SizedBox(height: 2),
                   Text("Enable reminders to use haptics", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w400, color: const Color(0xFF9CA3AF))),
                 ],
               ],
             ),
             trailing: CupertinoSwitch(
               value: isHapticsOn,
               onChanged: isNotifOn ? (v) => ref.read(hapticsProvider.notifier).setEnabled(v) : null,
               activeTrackColor: CupertinoColors.activeGreen,
             ),
           ),
         ),
       ],
     );
  }


  Widget _buildHourlyUpdatesTile(BuildContext context, WidgetRef ref) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     final isNotifOn = ref.watch(notificationProvider);
     final isHourlyOn = ref.watch(hourlyFocusUpdatesProvider);

     return Column(
       children: [
         Opacity(
           opacity: isNotifOn ? 1.0 : 0.4,
           child: ListTile(
             contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
             leading: Padding(
               padding: const EdgeInsets.only(top: 4),
               child: Icon(CupertinoIcons.timer, color: isDark ? Colors.white : const Color(0xFF374151)),
             ),
             title: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text('Hourly Focus Updates', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
                 const SizedBox(height: 2),
                 Text(
                   isNotifOn
                       ? (isHourlyOn ? 'Milestone notifications during open focus' : 'Hourly updates are off')
                       : 'Enable reminders to use focus updates',
                   style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w400, color: const Color(0xFF9CA3AF)),
                 ),
               ],
             ),
             trailing: CupertinoSwitch(
               value: isHourlyOn,
               onChanged: isNotifOn ? (v) => ref.read(hourlyFocusUpdatesProvider.notifier).setEnabled(v) : null,
               activeTrackColor: CupertinoColors.activeGreen,
             ),
           ),
         ),
       ],
     );
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
     return Column(
       children: [
         _buildGroup(context, 'APP SETTINGS', [
            _buildNotificationTile(context, ref, false),
            _buildSoundsTile(context, ref),
            _buildSmartNudgesTile(context, ref),
            _buildHapticsTile(context, ref),
             _buildHourlyUpdatesTile(context, ref),
         ]),
         const SizedBox(height: 24),
         _buildGroup(context, 'ACCOUNT', [
            _buildTile(context, 'Edit Name', CupertinoIcons.pencil, false, false),
            _buildTile(context, 'Backup & Sync', CupertinoIcons.cloud_upload_fill, false, false),
            _buildTile(context, 'Export Data', CupertinoIcons.doc_text_fill, false, true),
         ]),
         const SizedBox(height: 24),
         _buildGroup(context, 'PRIVACY', [
            _buildTile(context, 'Data Control', CupertinoIcons.lock_shield_fill, false, false),
            _buildTile(context, 'Permissions', CupertinoIcons.hand_draw_fill, false, true),
         ]),
       ],
     );
  }
}



class _BadgesShowcase extends ConsumerWidget {
  const _BadgesShowcase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(badgeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Row(
                children: [
                  const Icon(CupertinoIcons.rosette, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Premium Badges', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 154, 
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: badges.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: _PremiumBadge(badge: badges[index], isDark: isDark),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  final BadgeData badge;
  final bool isDark;

  const _PremiumBadge({required this.badge, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (!badge.isUnlocked) {
      // 🔒 LOCKED STATE
      return Opacity(
        opacity: 0.5,
        child: Column(
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1), width: 2),
              ),
              child: Center(
                child: Icon(CupertinoIcons.lock_fill, color: isDark ? const Color(0xFF636366) : const Color(0xFF9CA3AF), size: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              badge.title,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF8E8E93) : const Color(0xFF6B7280)),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            Text(
              badge.subtitle,
              style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w500, color: isDark ? const Color(0xFF636366) : const Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      );
    }

    // ✨ UNLOCKED STATE (DOPAMINE LEVEL)
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: badge.gradientColors,
              stops: const [0.0, 0.45, 0.55, 1.0], // Creates a sharp metallic reflection band
            ),
            boxShadow: [
              // Outer Premium Glow
              BoxShadow(
                color: badge.glowColor.withValues(alpha: isDark ? 0.4 : 0.6),
                blurRadius: 24,
                spreadRadius: 2,
              ),
              // Inner Depth Drop Shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.2),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8), // Inner shine highlight edge
              width: 1.5,
            ),
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.white.withValues(alpha: 0.8)],
              ).createShader(bounds),
              child: Icon(
                badge.icon,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          badge.title,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
        Text(
          badge.subtitle,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: badge.gradientColors[0], // Subtitle matches the metallic primary color
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Coin Balance Card
// ─────────────────────────────────────────────────────────────────────────────

class _CoinBalanceCard extends ConsumerWidget {
  const _CoinBalanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coins = ref.watch(coinProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatted = coins.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? const Color(0xFFFFD700).withValues(alpha: 0.25)
                : const Color(0xFFFFD700).withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          children: [
            // ── Premium Gradient Gold Coin Icon ──
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFFC9A227), const Color(0xFFFFD700)]
                      : [const Color(0xFFFFD700), const Color(0xFFFFC300)],
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Inner shine spot
                  Positioned(
                    top: 6,
                    left: 9,
                    child: Container(
                      width: 10,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  // Embossed star
                  const Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // ── Balance Display ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coin Balance',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
                Text(
                  '$formatted Coins',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Earn coins by completing habits',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.35)
                        : const Color(0xFFB0B0B5),
                  ),
                ),
              ],
            ),
            const Spacer(),
            // ── Pill showing daily cap ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFFFFD700).withValues(alpha: 0.12)
                    : const Color(0xFFFFFDE7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Text(
                '+10/habit',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFFFD700) : const Color(0xFFB8860B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sync Button
// ─────────────────────────────────────────────────────────────────────────────

class _SyncButton extends ConsumerStatefulWidget {
  const _SyncButton();

  @override
  ConsumerState<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends ConsumerState<_SyncButton> {
  bool _isPressed = false;
  bool _isSyncing = false;

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    
    try {
      // Add artificial delay to show user the sync is happening
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Manual sync is technically instant and continuous now, 
      // but we bump the UI refresher to ensure all providers are fresh.
      ref.read(syncRefreshProvider.notifier).bump();
      
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Data Synced', style: TextStyle(fontWeight: FontWeight.w600)),
            content: const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text('Your habit data has been successfully synchronized.'),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: const Text('Sync Error'),
            content: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(e.toString()),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _handleSync,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E7EB),
              width: 1,
            ),
            boxShadow: isDark ? [] : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSyncing)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              else
                Icon(
                  CupertinoIcons.arrow_2_circlepath,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              const SizedBox(width: 12),
              Text(
                _isSyncing ? 'Syncing Data...' : 'Manual Data Sync',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
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
// Logout Button
// ─────────────────────────────────────────────────────────────────────────────

class _LogoutButton extends ConsumerStatefulWidget {
  const _LogoutButton();

  @override
  ConsumerState<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends ConsumerState<_LogoutButton> {
  bool _isPressed = false;

  Future<void> _handleLogout() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out of your Google account?'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: false,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authProvider.notifier).signOut();
      // Clear the navigation stack so the root widget (OnboardingScreen) becomes visible
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _handleLogout,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF3A1010) : const Color(0xFFFFEBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF7A2020) : const Color(0xFFFFCCCC),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                CupertinoIcons.square_arrow_left,
                size: 20,
                color: isDark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F),
              ),
              const SizedBox(width: 10),
              Text(
                'Sign Out',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalityShowcase extends ConsumerWidget {
  const _PersonalityShowcase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitProvider);
    final personalities = PersonalityEngine.analyze(habits);

    if (personalities.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text('Your Habit Style', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: personalities.map((p) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Text(p.icon, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(p.description, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white))),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                        backgroundColor: p.color,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isDark ? p.color.withValues(alpha: 0.3) : p.color.withValues(alpha: 0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p.icon, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(
                          p.title,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: p.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
