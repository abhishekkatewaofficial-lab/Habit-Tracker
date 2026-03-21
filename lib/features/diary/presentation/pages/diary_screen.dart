import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/constants/app_text_styles.dart';
import 'package:habit_tracker_ios/features/diary/data/models/diary_entry.dart';
import 'package:habit_tracker_ios/features/diary/presentation/controllers/diary_controller.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  final TextEditingController _contentController = TextEditingController();
  String _selectedMood = '😊';
  String? _editingEntryId; // Track if we are editing an existing entry
  int? _editingTimestamp; // Keep original time when editing
  final FocusNode _contentFocusNode = FocusNode(); // Focus tracking for keyboard bar
  
  static const List<(String, String)> _moods = [
    ('😊', 'Happy'),
    ('😄', 'Grin'),
    ('😐', 'Neutral'),
    ('😔', 'Sad'),
    ('😤', 'Angry'),
    ('😴', 'Sleepy'),
    ('😎', 'Cool'),
    ('😇', 'Angel'),
    ('😡', 'Mad'),
    ('🤩', 'Excited'),
  ];



  void _saveEntry(String dateStr) {
    final text = _contentController.text.trim();
    if (text.isEmpty) return;

    final entry = DiaryEntry(
      id: _editingEntryId ?? const Uuid().v4(),
      date: dateStr,
      timestamp: _editingTimestamp ?? DateTime.now().millisecondsSinceEpoch,
      mood: _selectedMood,
      content: text,
    );

    ref.read(diaryEntriesProvider(dateStr).notifier).addEntry(entry);
    
    _resetInput();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_editingEntryId != null ? 'Entry updated!' : 'Entry saved!', style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: const Color(0xFF73D8A5),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _resetInput() {
    _contentController.clear();
    setState(() {
      _selectedMood = '😊';
      _editingEntryId = null;
      _editingTimestamp = null;
    });
  }

  void _onEditEntry(DiaryEntry entry) {
    setState(() {
      _contentController.text = entry.content;
      _selectedMood = entry.mood;
      _editingEntryId = entry.id;
      _editingTimestamp = entry.timestamp;
    });
    // Scroll to top to see the input UI
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _contentController.dispose();
    _scrollController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDiaryDateProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final entries = ref.watch(diaryEntriesProvider(dateStr));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // ── Header ──────────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 2, bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 40), // Balance the icon on the right
                      const Spacer(),
                      Text(
                        'Diary',
                        style: AppTextStyles.diaryTitle.copyWith(
                          fontSize: 34,
                          color: const Color(0xFF2D3142),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const _HeaderIcon(),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                
                // ── Date Strip ──────────────────────────────────────────────────────
                _DateStrip(selectedDate: selectedDate),
                
                const SizedBox(height: 20),
                
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // ── Main Card (Input Container) ──────────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 12), // Reduced top from 24
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mood Section
                              const _HeaderLabel(
                                icon: Icons.sentiment_satisfied_alt_rounded,
                                label: 'How are you feeling?',
                              ),
                              const SizedBox(height: 6),
                              _MoodSelector(
                                selectedMood: _selectedMood,
                                moods: _moods.map((m) => m.$1).toList(),
                                onMoodSelected: (mood) => setState(() => _selectedMood = mood),
                              ),
                              
                              const SizedBox(height: 18), // Increased by 1.5x from 12
                              
                              // Writing Section
                              const _HeaderLabel(
                                icon: Icons.edit_note_rounded,
                                label: 'Write your thoughts',
                              ),
                              const SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F4F9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: TextField(
                                  controller: _contentController,
                                  focusNode: _contentFocusNode,
                                  maxLines: 3, // Reduced from 5 (approx 60% visual height)
                                  style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF2D3142), fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Describe your day, feelings, or anything on your mind...',
                                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                                      color: const Color(0xFF94A3B8), 
                                      fontSize: 12, // Reduced from 13
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(20),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 12), // Reduced gap
                              
                              // Save Button
                              SizedBox(
                                width: double.infinity,
                                height: 50, // Reduced height (0.9x approx)
                                child: ElevatedButton(
                                  onPressed: () => _saveEntry(dateStr),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF73D8A5),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  child: Text(
                                    _editingEntryId != null ? 'Update Entry' : 'Save Entry',
                                    style: AppTextStyles.labelLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800, // Stronger weight
                                      fontSize: 14, // Slightly reduced
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // ── Entries or Empty State ──────────────────────────────────
                        if (entries.isEmpty)
                          _EmptyState(onAddPressed: () {
                            _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOutBack,
                            );
                          })
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: entries.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8), // Reduced gap to 50%
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              final timeStr = DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(entry.timestamp));
                              return Slidable(
                                key: Key(entry.id),
                                // Swipe Right -> Edit
                                startActionPane: ActionPane(
                                  motion: const ScrollMotion(),
                                  extentRatio: 0.25,
                                  children: [
                                    SlidableAction(
                                      onPressed: (context) => _onEditEntry(entry),
                                      backgroundColor: const Color(0xFF3B82F6).withAlpha(40),
                                      foregroundColor: const Color(0xFF3B82F6),
                                      icon: Icons.edit_rounded,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ],
                                ),
                                // Swipe Left -> Delete
                                endActionPane: ActionPane(
                                  motion: const ScrollMotion(),
                                  extentRatio: 0.25,
                                  dismissible: DismissiblePane(
                                    confirmDismiss: () async {
                                      return await showCupertinoDialog<bool>(
                                        context: context,
                                        builder: (context) => CupertinoAlertDialog(
                                          title: const Text('Delete Entry?'),
                                          content: const Text('Are you sure you want to delete this entry?'),
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
                                      ) ?? false;
                                    },
                                    onDismissed: () {
                                      ref.read(diaryEntriesProvider(dateStr).notifier).deleteEntry(entry.id);
                                    },
                                  ),
                                  children: [
                                    SlidableAction(
                                      onPressed: (context) async {
                                        final confirmed = await showCupertinoDialog<bool>(
                                          context: context,
                                          builder: (context) => CupertinoAlertDialog(
                                            title: const Text('Delete Entry?'),
                                            content: const Text('Are you sure you want to delete this entry?'),
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
                                        if (confirmed == true && context.mounted) {
                                          ref.read(diaryEntriesProvider(dateStr).notifier).deleteEntry(entry.id);
                                        }
                                      },
                                      backgroundColor: const Color(0xFFEF4444).withAlpha(40),
                                      foregroundColor: const Color(0xFFEF4444),
                                      icon: Icons.delete_outline_rounded,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  margin: const EdgeInsets.symmetric(horizontal: 4), // Add margin to avoid slidable buttons overlapping with card edges visually
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            timeStr,
                                            style: AppTextStyles.labelSmall.copyWith(
                                              color: Colors.black, // Dark black
                                              fontWeight: FontWeight.w700, // Bold
                                              fontSize: 10, // Balanced size
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFF1F4F9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(entry.mood, style: const TextStyle(fontSize: 14)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        entry.content,
                                        style: AppTextStyles.bodyMedium.copyWith(
                                          color: const Color(0xFF2D3142), 
                                          height: 1.4, 
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          
                        const SizedBox(height: 120), // Reserve space for BottomNav
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // ── Keyboard Accessory Bar (iOS Style) ──────────────────────────
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 0,
              right: 0,
              child: ListenableBuilder(
                listenable: _contentFocusNode,
                builder: (context, _) {
                  final isFocused = _contentFocusNode.hasFocus;
                  final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
                  
                  return AnimatedOpacity(
                    opacity: isFocused && isKeyboardOpen ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Visibility(
                      visible: isFocused && isKeyboardOpen,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F4F9),
                          border: Border(top: BorderSide(color: Colors.black.withAlpha(10))),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(5),
                              blurRadius: 4,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              onPressed: () => FocusScope.of(context).unfocus(),
                              child: Text(
                                'Done',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: const Color(0xFF73D8A5),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF73D8A5).withAlpha(40),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.edit_note_rounded, color: Color(0xFF73D8A5), size: 18),
    );
  }
}

class _HeaderLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderLabel({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF73D8A5), size: 22),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTextStyles.headlineSmall.copyWith(
            fontSize: 12, // Reduced from 13
            fontWeight: FontWeight.bold,
            color: Colors.black, // Pure dark black
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddPressed;
  const _EmptyState({required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // ── Decorative Illustration ──────────────────────────────────────────
          SizedBox(
            height: 200,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Floating Pastel Blobs
                Positioned(
                  top: 20,
                  left: MediaQuery.of(context).size.width * 0.2,
                  child: _DecorativeBlob(color: const Color(0xFF73D8A5).withAlpha(30), size: 100),
                ),
                Positioned(
                  bottom: 30,
                  right: MediaQuery.of(context).size.width * 0.15,
                  child: _DecorativeBlob(color: const Color(0xFF3B82F6).withAlpha(20), size: 120),
                ),
                Positioned(
                  top: 50,
                  right: MediaQuery.of(context).size.width * 0.25,
                  child: _DecorativeBlob(color: const Color(0xFFFACC15).withAlpha(15), size: 80),
                ),
                
                // Journal Illustration
                Container(
                  width: 100,
                  height: 130,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 25,
                        decoration: const BoxDecoration(
                          color: Color(0xFF73D8A5),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (i) => Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: const BoxDecoration(color: Colors.white38, shape: BoxShape.circle),
                          )),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(5, (i) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              height: 3,
                              width: i == 4 ? 40 : double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F4F9),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            )),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Floating Mood Icon
                Positioned(
                  top: 60,
                  left: MediaQuery.of(context).size.width * 0.3,
                  child: const _FloatingIcon(icon: '✍️', delay: 0),
                ),
                Positioned(
                  bottom: 50,
                  right: MediaQuery.of(context).size.width * 0.3,
                  child: const _FloatingIcon(icon: '✨', delay: 1),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // ── Content ─────────────────────────────────────────────────────────
          Text(
            'No entries for this day',
            style: AppTextStyles.headlineSmall.copyWith(
              color: const Color(0xFF1F2937),
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Write your first entry and track your mood!',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: const Color(0xFF6B7280),
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // ── Action Button ────────────────────────────────────────────────────
          ElevatedButton(
            onPressed: onAddPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF73D8A5),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Add Entry',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _DecorativeBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _DecorativeBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  final String icon;
  final int delay;
  const _FloatingIcon({required this.icon, required this.delay});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(seconds: 1 + delay),
      curve: Curves.easeInOutSine,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1.0 - (value * 2 - 1.0).abs())),
          child: child,
        );
      },
      child: Text(icon, style: const TextStyle(fontSize: 24)),
    );
  }
}

class _MoodSelector extends StatelessWidget {
  final String selectedMood;
  final List<String> moods;
  final Function(String) onMoodSelected;

  const _MoodSelector({
    required this.selectedMood,
    required this.moods,
    required this.onMoodSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: moods.map((mood) {
          final isSelected = selectedMood == mood;
          return GestureDetector(
            onTap: () => onMoodSelected(mood),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              width: 45, // Reduced from 56 (0.8x)
              height: 45, // Reduced from 56 (0.8x)
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF73D8A5).withAlpha(40) : const Color(0xFFF1F4F9),
                shape: BoxShape.circle,
                border: isSelected ? Border.all(color: const Color(0xFF73D8A5), width: 2) : null,
              ),
              alignment: Alignment.center,
              child: Text(mood, style: const TextStyle(fontSize: 22)), // Reduced from 28 (0.8x)
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DateStrip extends ConsumerWidget {
  const _DateStrip({required this.selectedDate});
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    
    return SizedBox(
      height: 55, // Reduced further from 70
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 14,
        itemBuilder: (_, i) {
          final day = today.subtract(Duration(days: 7 - i));
          final isSelected = day.year == selectedDate.year && 
                             day.month == selectedDate.month && 
                             day.day == selectedDate.day;
          return _DateCard(
            date: day, 
            isSelected: isSelected,
            onTap: () => ref.read(selectedDiaryDateProvider.notifier).state = day,
          );
        },
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({required this.date, required this.isSelected, required this.onTap});
  final DateTime date;
  final bool isSelected;
  final VoidCallback onTap;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        width: 44, // Reduced from 52
        padding: const EdgeInsets.symmetric(vertical: 6), // Reduced from 10
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF73D8A5) : Colors.white,
          borderRadius: BorderRadius.circular(10), // tighter rounded corner
          boxShadow: [
            BoxShadow(
              color: isSelected ? const Color(0xFF73D8A5).withAlpha(100) : Colors.black.withAlpha(5),
              blurRadius: 4,
              offset: isSelected ? const Offset(0, 2) : const Offset(0, 1),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _days[date.weekday - 1],
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? Colors.white : const Color(0xFF64748B), // Slightly darker unselected
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 9.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: AppTextStyles.headlineLarge.copyWith(
                color: isSelected ? Colors.white : const Color(0xFF111827), // Near black
                fontWeight: FontWeight.w700, // Bold
                fontSize: 11, // Reduced to 0.7x (approx)
                height: 1.0, 
              ),
            ),
          ],
        ),
      ),
    );
  }
}
