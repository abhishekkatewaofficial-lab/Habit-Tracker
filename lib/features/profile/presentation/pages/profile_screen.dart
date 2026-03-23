import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:habit_tracker_ios/core/constants/app_colors.dart';
import 'package:habit_tracker_ios/core/constants/app_text_styles.dart';
import 'package:habit_tracker_ios/core/theme/theme_provider.dart';
import '../controllers/profile_controller.dart';

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
    final profile = ref.read(profileProvider);
    _nameController = TextEditingController(text: profile.name);
    _focusNode.addListener(() {
      setState(() {
        _isEditing = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Photo',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Photo',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (croppedFile != null) {
        ref.read(profileProvider.notifier).updateImagePath(croppedFile.path);
      }
    }
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
          style: GoogleFonts.greatVibes(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Avatar
            GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              onTap: _pickImage,
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
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      image: profile.imagePath != null
                          ? DecorationImage(
                              image: FileImage(File(profile.imagePath!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: profile.imagePath == null
                        ? const Icon(
                            CupertinoIcons.person_fill,
                            size: 60,
                            color: Color(0xFF3A3A3C),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to change photo',
              style: AppTextStyles.labelSmall.copyWith(
                color: const Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 48),
            // Name Field
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: _isEditing ? 0.5 : 0.3),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: _isEditing ? 0.6 : 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  if (_isEditing)
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NAME',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ),
                  TextField(
                    controller: _nameController,
                    focusNode: _focusNode,
                    textAlign: TextAlign.left,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
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
                    onSubmitted: (val) {
                      _focusNode.unfocus();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // ─── Appearance Section ────────────────────────────────────────────
            _AppearanceSection(),
            const SizedBox(height: 100),
          ],
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
    final cs = Theme.of(context).colorScheme;

    const modes = [ThemeModeType.light, ThemeModeType.system, ThemeModeType.dark];
    const labels = ['Light', 'System', 'Dark'];
    const icons = [CupertinoIcons.sun_max_fill, CupertinoIcons.circle_lefthalf_fill, CupertinoIcons.moon_fill];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3), width: 1.5),
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
              Icon(CupertinoIcons.paintbrush_fill, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Appearance',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Segmented Control
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: List.generate(3, (i) {
                final isSelected = themeMode == modes[i];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => ref.read(themeProvider.notifier).setMode(modes[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: isSelected ? cs.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [BoxShadow(color: cs.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icons[i],
                            size: 16,
                            color: isSelected ? Colors.white : cs.onSurfaceVariant,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            labels[i],
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
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
