import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker_ios/shared_widgets/cupertino_time_picker_sheet.dart';
import 'package:habit_tracker_ios/core/constants/app_colors.dart';
import 'package:habit_tracker_ios/core/constants/app_text_styles.dart';
import 'package:habit_tracker_ios/core/widgets/habit_icon.dart';
import 'package:habit_tracker_ios/features/habits/data/models/habit.dart';
import 'package:habit_tracker_ios/features/habits/presentation/controllers/habit_controller.dart';
import 'package:uuid/uuid.dart';

class AddEditHabitScreen extends ConsumerStatefulWidget {
  final Habit? existingHabit;

  const AddEditHabitScreen({super.key, this.existingHabit});

  @override
  ConsumerState<AddEditHabitScreen> createState() => _AddEditHabitScreenState();
}

class _AddEditHabitScreenState extends ConsumerState<AddEditHabitScreen> {
  late TextEditingController _nameController;
  late String _selectedEmoji;
  late int _selectedColorIndex;
  late double _goalValue;
  late String _selectedUnit;
  late bool _isEveryDay;
  late List<int> _selectedDays;
  late bool _reminderEnabled;
  int? _reminderHour;
  int? _reminderMinute;

  late Map<String, List<String>> _loadedCategories;

  final Map<String, List<String>> _emojiCategories = {};

  final Map<String, double> _unitMaxValues = {
    'times': 50,
    'hours': 24,
    'minutes': 300,
    'sec': 300,
    'Glass': 30,
    'Cup': 30,
    'oz': 50,
    'steps': 50000,
    'km': 100,
    'm': 10000,
    'miles': 100,
    'pages': 50,
    'ml': 5000,
    'g': 10000,
    'mg': 5000,
    'calories': 6000,
    'drink': 50,
    'reps': 100,
  };

  double _getMaxForUnit(String unit) => _unitMaxValues[unit] ?? 100;

  final List<Color> _colors = [
    // 🔴 RED / PINK FAMILY
    const Color(0xFFBF3B31), const Color(0xFFC62D42), const Color(0xFFF03651), const Color(0xFFBF3552),
    const Color(0xFFE83C70), const Color(0xFFF6688E), const Color(0xFFE66771), const Color(0xFFFD9FA2),
    const Color(0xFFFDB0C0), const Color(0xFFFFC5CB), const Color(0xFFFFB2D0), const Color(0xFFF653A6),
    
    // 🟠 ORANGE FAMILY
    const Color(0xFFF66B37), const Color(0xFFF87217), const Color(0xFFE67451), const Color(0xFFE4854F),
    const Color(0xFFFF9966),
    
    // 🟡 YELLOW FAMILY
    const Color(0xFFFFD801), const Color(0xFFFCC01E), const Color(0xFFF9BF58), const Color(0xFFD5B60A),
    
    // 🟢 GREEN FAMILY
    const Color(0xFF004726), const Color(0xFF579A70), const Color(0xFF5EBCA0), const Color(0xFFA6C875),
    const Color(0xFF99C68E), const Color(0xFFD8E68B), const Color(0xFF90B134),
    
    // 🔵 BLUE FAMILY
    const Color(0xFF082567), const Color(0xFF157DEC), const Color(0xFF069AF3), const Color(0xFF45B1E8),
    const Color(0xFF93CCEA), const Color(0xFF99BADD), const Color(0xFF9DBCD4), const Color(0xFFBCD4E6),
    const Color(0xFF728FCE),
    
    // 🟣 PURPLE FAMILY
    const Color(0xFF7563A8), const Color(0xFFC39FE6), const Color(0xFFB2A5D8),
    
    // 🟦 CYAN / TEAL FAMILY
    const Color(0xFF21BFC5), const Color(0xFF1CD9D2), const Color(0xFF96DED1), const Color(0xFF1E9AB0),
    const Color(0xFF105858),
    
    // 🌿 NEUTRAL / MUTED TONES
    const Color(0xFF96BBAB), const Color(0xFFE3A857),
  ];

  final List<String> _units = [
    'times', 'reps', 'steps', 'pages', 'drink', // Count
    'km', 'm', 'miles',                // Distance
    'ml', 'Glass', 'Cup', 'oz',        // Volume
    'g', 'mg',                         // Weight
    'hours', 'minutes', 'sec',         // Time
    'calories',                        // Misc
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.existingHabit;
    _nameController = TextEditingController(text: h?.name ?? '');
    _selectedEmoji = h?.icon ?? '🎯';
    
    // Randomize initial color for new habits; find index for existing ones
    if (h == null) {
      _selectedColorIndex = Random().nextInt(_colors.length);
    } else {
      _selectedColorIndex = 0; // fallback
      for (int i = 0; i < _colors.length; i++) {
        if (_colors[i].toARGB32() == h.colorValue) {
          _selectedColorIndex = i;
          break;
        }
      }
    }

    _goalValue = h?.goalValue.toDouble() ?? 1.0;
    _selectedUnit = h?.goalUnit ?? 'times';
    _isEveryDay = h?.isEveryDay ?? true;
    _selectedDays = List<int>.from(h?.selectedDays ?? []);
    _reminderEnabled = h?.reminderEnabled ?? false;
    _reminderHour = h?.reminderHour;
    _reminderMinute = h?.reminderMinute;

    _loadedCategories = Map.from(_emojiCategories);
    _loadAssetIcons();
  }

  Future<void> _loadAssetIcons() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final iconPaths = manifest.listAssets().where((k) {
        return k.startsWith('assets/habit_icons/') && (k.endsWith('.png') || k.endsWith('.svg'));
      }).toSet().toList();
      if (iconPaths.isEmpty) return;

      final Map<String, List<String>> assetCats = {};
      for (final path in iconPaths) {
        final segments = path.split('/');
        if (segments.length >= 4) {
          // e.g. assets/habit_icons/fitness/dumbbell.png
          String catName = segments[2];
          catName = catName[0].toUpperCase() + catName.substring(1).toLowerCase();
          assetCats.putIfAbsent(catName, () => []).add(path);
        }
      }

      if (mounted) {
        setState(() {
          for (final entry in assetCats.entries) {
            _loadedCategories[entry.key] = entry.value; 
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading asset icons: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatTime(int hour, int minute) {
    final tod = TimeOfDay(hour: hour, minute: minute);
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a habit name')),
      );
      return;
    }
    final habit = Habit(
      id: widget.existingHabit?.id ?? const Uuid().v4(),
      name: name,
      icon: _selectedEmoji,
      colorValue: _colors[_selectedColorIndex].toARGB32(),
      isQuitHabit: false,
      goalValue: _goalValue.toInt(),
      goalUnit: _selectedUnit,
      isEveryDay: _isEveryDay,
      selectedDays: _isEveryDay ? [] : _selectedDays,
      reminderEnabled: _reminderEnabled,
      reminderHour: _reminderEnabled ? _reminderHour : null,
      reminderMinute: _reminderEnabled ? _reminderMinute : null,
      createdAt: widget.existingHabit?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      startDateString: widget.existingHabit?.startDateString,
      dailyProgress: widget.existingHabit?.dailyProgress ?? {},
      // ── Critical: preserve all historical goal snapshots on edit ────────────
      // Without this, every save would discard goalSnapshots and fall back to
      // the new goalValue for ALL past dates, breaking historical reports/streaks.
      goalSnapshots: widget.existingHabit?.goalSnapshots ?? {},
    );

    if (widget.existingHabit == null) {
      try {
        await ref.read(habitProvider.notifier).addHabit(habit);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')), 
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } else {
      ref.read(habitProvider.notifier).updateHabit(habit);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  void _showEmojiPicker() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Emoji Picker',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return _EmojiPickerDialog(
          categories: _loadedCategories,
          selectedEmoji: _selectedEmoji,
          onEmojiSelected: (emoji) {
            setState(() => _selectedEmoji = emoji);
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  void _showColorPickerPopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Color Picker',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return _ColorPickerDialog(
          colors: _colors,
          selectedColorIndex: _selectedColorIndex,
          onColorSelected: (index) {
            setState(() => _selectedColorIndex = index);
            Navigator.pop(context);
          },
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  void _showManualValueDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: _ManualValueDialog(
              initialValue: _goalValue.toInt(),
              unit: _selectedUnit,
              maxValue: _getMaxForUnit(_selectedUnit),
              onSave: (val) {
                setState(() => _goalValue = val.toDouble());
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          widget.existingHabit == null ? 'New habit' : 'Edit habit',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            fontSize: 32,
          ),
        ),
        centerTitle: false,
        actions: [
          Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(CupertinoIcons.clear, color: Theme.of(context).colorScheme.onSurface, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            // Premium Adaptive Doodle Illustration (Create Habit Only)
            if (widget.existingHabit == null) ...[
              Center(
                child: Image.asset(
                  Theme.of(context).brightness == Brightness.light
                      ? 'assets/images/habit_calendar_doodle_light.png'
                      : 'assets/images/habit_calendar_doodle_dark.png',
                  height: 160, // Slightly expanded premium scale
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24), // Premium Breathing Room before input fields
            ],
            // Unified Identity Card (Name, Emoji, Color)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: Theme.of(context).brightness == Brightness.light ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ] : [],
                border: Theme.of(context).brightness == Brightness.dark 
                    ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1) 
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Section: Emoji + Name Input
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _showEmojiPicker,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: _colors[_selectedColorIndex].withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _colors[_selectedColorIndex].withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: HabitIcon(
                            iconStr: _selectedEmoji,
                            size: 30,
                            color: Theme.of(context).brightness == Brightness.dark 
                                ? _colors[_selectedColorIndex] 
                                : _colors[_selectedColorIndex].withValues(alpha: 0.9), // Tints SVG/PNG dynamically!
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: widget.existingHabit == null
                            ? TextField(
                                controller: _nameController,
                                style: GoogleFonts.poppins(
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                  fontSize: 18, 
                                  fontWeight: FontWeight.w600,
                                ),
                                cursorColor: _colors[_selectedColorIndex],
                                decoration: InputDecoration(
                                  hintText: 'Habit name...',
                                  hintStyle: GoogleFonts.poppins(
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? const Color(0xFF6B6B70) 
                                        : const Color(0xFFB0B0B5),
                                    fontSize: 18,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _nameController.text,
                                    style: GoogleFonts.poppins(
                                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                      fontSize: 18, 
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  // Divider
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFE0E0E0),
                  ),
                  const SizedBox(height: 12),
                  
                  const SizedBox(height: 12),
                  // Bottom Section: Color Selector Trigger (NOT inline grid)
                  GestureDetector(
                    onTap: () => _showColorPickerPopup(context),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _colors[_selectedColorIndex].withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.palette_rounded,
                              size: 18,
                              color: _colors[_selectedColorIndex],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Color',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          // Mini Preview
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _colors[_selectedColorIndex],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            CupertinoIcons.chevron_right,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            _SectionLabel(label: widget.existingHabit != null ? 'Change Goal Value' : 'Goal Value'),
            const SizedBox(height: 12),
            
            // Goal Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1B94FF),
                            inactiveTrackColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surfaceContainerHighest,
                            thumbColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1B94FF),
                            trackHeight: 6,
                            overlayColor: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFF1B94FF).withAlpha(40),
                          ),
                            child: Slider(
                              value: _goalValue,
                              min: 1,
                              max: _getMaxForUnit(_selectedUnit),
                              onChanged: (val) => setState(() => _goalValue = val),
                            ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _showManualValueDialog,
                        child: Container(
                          width: 100,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${_goalValue.toInt()} $_selectedUnit',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500, 
                                    fontSize: 16,
                                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D3142),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (widget.existingHabit == null)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.5,
                      ),
                      itemCount: _units.length,
                      itemBuilder: (context, index) {
                        final unit = _units[index];
                        final isSelected = _selectedUnit == unit;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedUnit = unit;
                              final maxVal = _getMaxForUnit(unit);
                              if (_goalValue > maxVal) {
                                _goalValue = maxVal;
                              }
                            });
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected 
                                ? Theme.of(context).brightness == Brightness.dark ? Colors.transparent : const Color(0xFF1B94FF)
                                : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFF1B94FF)
                                      : Theme.of(context).colorScheme.outline),
                            ),
                            child: Text(
                              unit,
                              style: GoogleFonts.fredoka(
                                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            const _SectionLabel(label: 'Time Range'),
            const SizedBox(height: 10),
            
            // Unified Frequency & Reminders Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: Theme.of(context).brightness == Brightness.light ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ] : [],
                border: Theme.of(context).brightness == Brightness.dark 
                    ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1) 
                    : null,
              ),
              child: Column(
                children: [
                  // Frequency Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Every Day', 
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w600, 
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      CupertinoSwitch(
                        value: _isEveryDay,
                        activeTrackColor: CupertinoColors.activeGreen,
                        onChanged: (val) {
                          setState(() {
                            _isEveryDay = val;
                            if (!_isEveryDay && _selectedDays.isEmpty) {
                              _selectedDays = [DateTime.now().weekday % 7];
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (!_isEveryDay)
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: _DaySelector(
                        selectedDays: _selectedDays,
                        onChanged: (days) => setState(() => _selectedDays = days),
                      ),
                    ),
                  
                  // Divider
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE0E0E0),
                    ),
                  ),
                  
                  // Reminders Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Enable Reminders',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface)),
                      CupertinoSwitch(
                        value: _reminderEnabled,
                        activeTrackColor: CupertinoColors.activeGreen,
                        onChanged: (val) async {
                          if (val) {
                            final picked = await showCupertinoTimePickerSheet(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: _reminderHour ?? 8,
                                minute: _reminderMinute ?? 0,
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                _reminderEnabled = true;
                                _reminderHour = picked.hour;
                                _reminderMinute = picked.minute;
                              });
                            }
                          } else {
                            setState(() {
                              _reminderEnabled = false;
                              _reminderHour = null;
                              _reminderMinute = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (_reminderEnabled && _reminderHour != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: InkWell(
                        onTap: () async {
                          final picked = await showCupertinoTimePickerSheet(
                            context: context,
                            initialTime: TimeOfDay(
                                hour: _reminderHour!, minute: _reminderMinute!),
                          );
                          if (picked != null) {
                            setState(() {
                              _reminderHour = picked.hour;
                              _reminderMinute = picked.minute;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(CupertinoIcons.bell_fill,
                                  size: 16,
                                  color: AppColors.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Daily reminder at ${_formatTime(_reminderHour!, _reminderMinute!)}  ·  Tap to change',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 32), // Breathing room before Save
            
            // Scrollable Save Button
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).padding.bottom),
                child: GestureDetector(
                  onTap: _save,
                  child: Container(
                    height: 56,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1B94FF) : const Color(0xFFFD7618),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1B94FF) : const Color(0xFFFD7618)).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Save Habit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: GoogleFonts.fredoka(
          color: isDark ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _EmojiPickerDialog extends StatefulWidget {
  final Map<String, List<String>> categories;
  final String selectedEmoji;
  final Function(String) onEmojiSelected;

  const _EmojiPickerDialog({
    required this.categories,
    required this.selectedEmoji,
    required this.onEmojiSelected,
  });

  @override
  State<_EmojiPickerDialog> createState() => _EmojiPickerDialogState();
}

class _EmojiPickerDialogState extends State<_EmojiPickerDialog> {
  late String _currentCategory;

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.categories.keys.first;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Material(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select Icon',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D3142),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Pill Category Selector
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: widget.categories.keys.map((cat) {
                          final isSelected = _currentCategory == cat;
                          return GestureDetector(
                            onTap: () => setState(() => _currentCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isSelected 
                                  ? Theme.of(context).brightness == Brightness.dark ? Colors.transparent : AppColors.accent.withValues(alpha: 0.15) 
                                  : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected 
                                    ? Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.3) : AppColors.accent.withValues(alpha: 0.3) 
                                    : Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected 
                                    ? Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.accent 
                                    : Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Emoji Grid
                    Expanded(
                      child: GridView.builder(
                        itemCount: widget.categories[_currentCategory]!.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                        itemBuilder: (context, index) {
                          final emoji = widget.categories[_currentCategory]![index];
                          return _EmojiItem(
                            emoji: emoji,
                            onTap: () {
                              widget.onEmojiSelected(emoji);
                              Navigator.pop(context);
                            },
                          );
                        },
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

class _EmojiItem extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _EmojiItem({required this.emoji, required this.onTap});

  @override
  State<_EmojiItem> createState() => _EmojiItemState();
}

class _EmojiItemState extends State<_EmojiItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          alignment: Alignment.center,
          color: Colors.transparent,
          child: HabitIcon(
            iconStr: widget.emoji,
            size: 34,
          ),
        ),
      ),
    );
  }
}

class _ManualValueDialog extends StatefulWidget {
  final int initialValue;
  final String unit;
  final double maxValue;
  final Function(int) onSave;

  const _ManualValueDialog({
    required this.initialValue,
    required this.unit,
    required this.maxValue,
    required this.onSave,
  });

  @override
  State<_ManualValueDialog> createState() => _ManualValueDialogState();
}

class _ManualValueDialogState extends State<_ManualValueDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSave() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    int val = int.tryParse(text) ?? widget.initialValue;
    if (val < 1) val = 1;
    if (val > widget.maxValue) val = widget.maxValue.toInt();

    widget.onSave(val);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
                    Text(
                      'Set Goal Value',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D3142),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null,
                      ),
                      child: IntrinsicWidth(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: TextField(
                                controller: _controller,
                                autofocus: true,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                cursorColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : null,
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D3142),
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.unit,
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFB0B0B5) : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
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
                                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: _onSave,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : AppColors.accent,
                                borderRadius: BorderRadius.circular(12),
                                border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: Colors.white.withValues(alpha: 0.15)) : null,
                              ),
                              child: const Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
    );
  }
}


class _DaySelector extends StatelessWidget {
  final List<int> selectedDays;
  final Function(List<int>) onChanged;

  const _DaySelector({
    required this.selectedDays,
    required this.onChanged,
  });

  static const List<String> _dayNames = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final isSelected = selectedDays.contains(index);
        return GestureDetector(
          onTap: () {
            final newDays = List<int>.from(selectedDays);
            if (isSelected) {
              if (newDays.length > 1) {
                newDays.remove(index);
              }
            } else {
              newDays.add(index);
            }
            onChanged(newDays);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (MediaQuery.of(context).size.width - 80) / 7,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.accent.withValues(alpha: 0.3) : Colors.transparent,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _dayNames[index],
              style: TextStyle(
                color: isSelected ? AppColors.accent : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _PremiumSaveButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PremiumSaveButton({required this.onTap});

  @override
  State<_PremiumSaveButton> createState() => _PremiumSaveButtonState();
}

class _PremiumSaveButtonState extends State<_PremiumSaveButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isDark) const Icon(CupertinoIcons.check_mark, color: Color(0xFF1B94FF), size: 16),
              if (!isDark) const SizedBox(width: 6),
              Text(
                'Save',
                style: TextStyle(
                  color: isDark ? const Color(0xFF32D74B) : const Color(0xFF1B94FF),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorPickerDialog extends StatelessWidget {
  final List<Color> colors;
  final int selectedColorIndex;
  final Function(int) onColorSelected;

  const _ColorPickerDialog({
    super.key,
    required this.colors,
    required this.selectedColorIndex,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 320),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Material(
              color: isDark ? const Color(0xFF1C1C1E).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select Color',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2D3142),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: List.generate(colors.length, (index) {
                        final isSelected = selectedColorIndex == index;
                        return GestureDetector(
                          onTap: () => onColorSelected(index),
                          child: Container(
                            width: 28, // 20% smaller than before (was 36)
                            height: 28,
                            decoration: BoxDecoration(
                              color: colors[index],
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                                width: 2,
                              ) : null,
                            ),
                            child: isSelected
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : null,
                          ),
                        );
                      }),
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
