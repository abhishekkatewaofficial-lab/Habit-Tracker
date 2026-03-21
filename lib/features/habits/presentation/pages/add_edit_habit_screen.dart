import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/constants/app_colors.dart';
import 'package:habit_tracker_ios/core/constants/app_text_styles.dart';
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
  late bool _isQuitHabit;
  late int _selectedColorIndex;
  late double _goalValue;
  late String _selectedUnit;
  late bool _isEveryDay;
  late List<int> _selectedDays;
  late bool _reminderEnabled;

  final Map<String, List<String>> _emojiCategories = {
    'Fitness': ['🏃', '💪', '🧘', '🚴', '🏊', '🚶', '🤸', '⚽', '🏀', '🎾', '🚵', '🏸', '🥋', '🥊', '🛹'],
    'Study': ['📚', '✏️', '🧠', '📝', '📖', '🦉', '🎓', '💻', '🔬', '🎨', '🖋️', '📒', '🧐', '🏫', '💡'],
    'Health': ['💧', '🥗', '🛌', '😴', '💊', '🍎', '🥦', '🥛', '🧼', '🦷', '🥑', '🍌', '🥕', '🧘‍♀️', '🧖‍♂️'],
    'Productivity': ['📈', '⏳', '🎯', '💼', '👁️', '🚀', '📅', '🔔', '🛠️', '⚙️', '📊', '📋', '📁', '💻', '✅'],
    'Lifestyle': ['🎸', '☕', '🌿', '📷', '🐶', '🐱', '🏡', '🚲', '🎭', '🎮', '✈️', '🏝️', '🎬', '🎧', '🍷'],
  };

  final Map<String, double> _unitMaxValues = {
    'times': 10,
    'hours': 24,
    'minutes': 120,
    'Glass': 15,
    'Cup': 15,
    'steps': 20000,
    'km': 10,
    'pages': 50,
    'ml': 5000,
    'calories': 5000,
  };

  double _getMaxForUnit(String unit) => _unitMaxValues[unit] ?? 100;

  final List<Color> _colors = [
    const Color(0xFFA5C9FF), // Light Blue
    const Color(0xFFFFA5A5), // Light Red/Coral
    const Color(0xFF7B8DCC), // Purplish Blue
    const Color(0xFFCEA0E6), // Light Purple
    const Color(0xFF90D590), // Light Green
    const Color(0xFFFFB347), // Orange
    const Color(0xFF6AB7FF), // Brighter Blue
    const Color(0xFFFFE380), // Yellow
    const Color(0xFFFF8AB3), // Pink
    const Color(0xFF5CC0B0), // Teal
    const Color(0xFFFFCC80), // Peach
    const Color(0xFFB39DDB), // Lavender
  ];

  final List<String> _units = [
    'times',
    'hours',
    'minutes',
    'Glass',
    'Cup',
    'steps',
    'km',
    'pages',
    'ml',
    'calories',
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.existingHabit;
    _nameController = TextEditingController(text: h?.name ?? '');
    _selectedEmoji = h?.icon ?? '🎯';
    _isQuitHabit = h?.isQuitHabit ?? false;
    
    // Find color index or default to 0
    _selectedColorIndex = 0;
    if (h != null) {
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
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
      isQuitHabit: _isQuitHabit,
      goalValue: _goalValue.toInt(),
      goalUnit: _selectedUnit,
      isEveryDay: _isEveryDay,
      selectedDays: _isEveryDay ? [] : _selectedDays,
      reminderEnabled: _reminderEnabled,
      createdAt: widget.existingHabit?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      dailyProgress: widget.existingHabit?.dailyProgress ?? {},
    );

    if (widget.existingHabit == null) {
      ref.read(habitProvider.notifier).addHabit(habit);
    } else {
      ref.read(habitProvider.notifier).updateHabit(habit);
    }

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
          categories: _emojiCategories,
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

  void _showManualValueDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Goal Input',
      barrierColor: Colors.black.withValues(alpha: 0.2),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return _ManualValueDialog(
          initialValue: _goalValue.toInt(),
          unit: _selectedUnit,
          maxValue: _getMaxForUnit(_selectedUnit),
          onSave: (val) {
            setState(() => _goalValue = val.toDouble());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 70,
        leading: Center(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(CupertinoIcons.clear, color: Colors.black, size: 20),
            ),
          ),
        ),
        title: Text(
          widget.existingHabit == null ? 'Add New Habit' : 'Edit Habit',
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3142),
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _PremiumSaveButton(onTap: _save),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            
            // Habit Name Input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showEmojiPicker,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _colors[_selectedColorIndex].withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _selectedEmoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      style: AppTextStyles.bodyMedium.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Habit name...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
              const _SectionLabel(label: 'Habit Type'),
              const SizedBox(height: 10),
              
              // Habit Type Toggle
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isQuitHabit = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: !_isQuitHabit 
                                ? const Color(0xFFD2F0DA) // pastel green
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Start Habit',
                            style: TextStyle(
                              color: !_isQuitHabit 
                                  ? const Color(0xFF2E7D32) // dark green
                                  : Colors.grey.shade500,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isQuitHabit = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          decoration: BoxDecoration(
                            color: _isQuitHabit 
                                ? const Color(0xFFFFE0C2) // pastel orange
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Quit Habit',
                            style: TextStyle(
                              color: _isQuitHabit 
                                  ? const Color(0xFFE65100) // dark orange
                                  : Colors.grey.shade500,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              const _SectionLabel(label: 'Color'),
              const SizedBox(height: 16),
            
            // Color Picker
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: List.generate(_colors.length, (index) {
                  final isSelected = _selectedColorIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorIndex = index),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _colors[index],
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.blue.withAlpha(100), width: 2) : null,
                      ),
                      child: isSelected 
                        ? const Icon(Icons.check, color: Colors.blue, size: 20)
                        : null,
                    ),
                  );
                }),
              ),
            ),
            
            const SizedBox(height: 24),
            const _SectionLabel(label: 'Goal'),
            const SizedBox(height: 12),
            
            // Goal Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppColors.accent,
                            inactiveTrackColor: Colors.grey.shade200,
                            thumbColor: AppColors.accent,
                            trackHeight: 6,
                            overlayColor: AppColors.accent.withAlpha(40),
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
                            color: const Color(0xFFF1F4F9),
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
                                  '${_goalValue.toInt()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _selectedUnit,
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                            color: isSelected ? AppColors.accent : Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: isSelected
                                    ? AppColors.accent
                                    : Colors.grey.shade200),
                          ),
                          child: Text(
                            unit,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
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
            
            const SizedBox(height: 20),
            
            // Every Day Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Every Day', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      CupertinoSwitch(
                        value: _isEveryDay,
                        activeTrackColor: AppColors.accent,
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
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Enable Reminders Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Enable Reminders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  CupertinoSwitch(
                    value: _reminderEnabled,
                    activeTrackColor: AppColors.accent,
                    onChanged: (val) => setState(() => _reminderEnabled = val),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 150), // Over-scroll space
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
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey.shade400,
          fontWeight: FontWeight.bold,
          fontSize: 12,
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
              color: Colors.white.withValues(alpha: 0.85),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select Icon',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142),
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
                                color: isSelected ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? AppColors.accent.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected ? AppColors.accent : Colors.grey.shade500,
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
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 34),
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
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Material(
              color: Colors.white.withValues(alpha: 0.85),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Set Goal Value',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
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
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D3142),
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
                                color: Colors.grey.shade500,
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
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _onSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
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
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.check_mark, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
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
