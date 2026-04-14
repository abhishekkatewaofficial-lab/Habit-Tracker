import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import '../controllers/todo_controller.dart';
import '../../data/models/todo_category.dart';
import 'dart:ui';
import '../../data/models/todo_task.dart';
import 'package:habit_tracker_ios/features/eisenhower/presentation/pages/eisenhower_matrix_screen.dart';
import 'package:habit_tracker_ios/features/eisenhower/presentation/widgets/matrix_components.dart';


class TodoHomeScreen extends ConsumerStatefulWidget {
  const TodoHomeScreen({super.key});

  @override
  ConsumerState<TodoHomeScreen> createState() => _TodoHomeScreenState();
}

class _TodoHomeScreenState extends ConsumerState<TodoHomeScreen> {
  /// 0 = List view, 1 = Matrix view
  int _viewMode = 0;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(todoControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF2D264B);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isDark ? const Color(0xFF333336) : const Color(0xFFF3F4F6),
                isDark ? const Color(0xFF1A1A1D) : const Color(0xFFB0B0B5),
              ],
            ),
          ),
          child: SafeArea(
            child: Container(
              width: double.infinity,
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width > 600 ? 700 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top Bar ────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _viewMode == 0 ? 'To-Do' : 'Matrix',
                            style: GoogleFonts.greatVibes(
                              fontSize: 48,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          
                          // ── List / Matrix Toggle ───────────────────────────────
                          CupertinoSlidingSegmentedControl<int>(
                            groupValue: _viewMode,
                            thumbColor: isDark ? const Color(0xFF3A3A3C) : Colors.white,
                            backgroundColor: isDark
                                ? const Color(0xFF1C1C1E)
                                : CupertinoColors.tertiarySystemFill,
                            children: {
                              0: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Icon(CupertinoIcons.list_bullet,
                                      size: 14,
                                      color: _viewMode == 0
                                          ? (isDark ? Colors.white : const Color(0xFF2D264B))
                                          : Colors.grey),
                              ),
                              1: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Icon(CupertinoIcons.square_grid_2x2,
                                      size: 14,
                                      color: _viewMode == 1
                                          ? (isDark ? Colors.white : const Color(0xFF2D264B))
                                          : Colors.grey),
                              ),
                            },
                            onValueChanged: (val) {
                              if (val != null) setState(() => _viewMode = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Content ───────────────────────────────────────────
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _viewMode == 1
                            ? const EisenhowerMatrixScreen(key: ValueKey('matrix'), isEmbedded: true)
                            : (categories.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                    key: const ValueKey('list'),
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: categories.length,
                                    itemBuilder: (context, index) {
                                      final category = categories[index];
                                      return _CategoryCard(
                                        category: category,
                                        index: index,
                                        totalCount: categories.length,
                                      );
                                    },
                                  )),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 115),
          child: _GlassAddButton(
            onTap: () => _viewMode == 0 ? _showAddCategoryDialog(context, ref) : showUpsertSheet(context),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.square_list, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No categories yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const _AddCategoryDialog(),
    );
  }
}

class _CategoryCard extends ConsumerStatefulWidget {
  final TodoCategory category;
  final int index;
  final int totalCount;
  
  const _CategoryCard({
    required this.category,
    required this.index,
    required this.totalCount,
  });

  @override
  ConsumerState<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends ConsumerState<_CategoryCard> {
  bool _isExpanded = false;
  bool _isAddingTask = false;
  final _taskController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _taskController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (!_isExpanded) {
        _isAddingTask = false;
      }
    });
  }

  void _submitTask() {
    final text = _taskController.text.trim();
    if (text.isNotEmpty) {
      ref.read(todoControllerProvider.notifier).addTask(widget.category.id, text);
      _taskController.clear();
      _focusNode.requestFocus(); // Auto-focus again for the next item
    } else {
      setState(() => _isAddingTask = false);
    }
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.category.name);
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Edit Category'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            placeholder: 'e.g., Shop, Work, Home',
            onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final updated = TodoCategory(
                  id: widget.category.id,
                  name: controller.text,
                  color: widget.category.color,
                  emoji: widget.category.emoji,
                  tasks: widget.category.tasks,
                );
                ref.read(todoControllerProvider.notifier).updateCategory(updated);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double t = widget.totalCount <= 1 ? 0.0 : (widget.index / (widget.totalCount - 1));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final Color startColor = isDark ? const Color(0xFF333336) : const Color(0xFFF3F4F6);
    final Color endColor = isDark ? const Color(0xFF1A1A1D) : const Color(0xFFB0B0B5);
    final Color backgroundColor = Color.lerp(startColor, endColor, t)!;
    final Color textColor = isDark ? Colors.white : Colors.black;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (widget.index * 50).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 15 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Slidable(
        key: ValueKey(widget.category.id),
        startActionPane: ActionPane(
          extentRatio: 0.25,
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              autoClose: false,
              onPressed: (context) {
                  final slidable = Slidable.of(context);
                  slidable?.close();
                  Future.delayed(const Duration(milliseconds: 50), () {
                    _showEditDialog(context);
                  });
              },
              backgroundColor: const Color(0xFF3A3A3C),
              foregroundColor: Colors.white,
              icon: Icons.edit_rounded,
            ),
          ],
        ),
        endActionPane: ActionPane(
          extentRatio: 0.25,
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              autoClose: false,
              onPressed: (context) {
                final slidable = Slidable.of(context);
                slidable?.close();
                Future.delayed(const Duration(milliseconds: 50), () {
                  ref.read(todoControllerProvider.notifier).deleteCategory(widget.category.id);
                });
              },
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline_rounded,
            ),
          ],
        ),
        child: GestureDetector(
          onTap: _toggleExpand,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Category Title)
                Container(
                  height: 96,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.category.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: textColor,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: _isExpanded ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          CupertinoIcons.chevron_right,
                          color: textColor.withValues(alpha: 0.4),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Expandable Body
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity, height: 0),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Task List
                        if (widget.category.tasks.isNotEmpty) ...[
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            itemCount: widget.category.tasks.length,
                            itemBuilder: (context, index) {
                               return _buildTaskItem(widget.category.tasks[index], textColor);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Add Task Input Flow
                        if (_isAddingTask)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                margin: const EdgeInsets.only(top: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: textColor.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _taskController,
                                  focusNode: _focusNode,
                                  style: GoogleFonts.poppins(
                                    color: textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  cursorColor: textColor,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submitTask(),
                                  decoration: InputDecoration(
                                    hintText: 'Type task...',
                                    hintStyle: GoogleFonts.poppins(color: textColor.withValues(alpha: 0.4)),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    filled: false,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() => _isAddingTask = true);
                              _focusNode.requestFocus();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.add, color: textColor.withValues(alpha: 0.5), size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Add a task...',
                                    style: GoogleFonts.poppins(
                                      color: textColor.withValues(alpha: 0.5),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 350),
                  sizeCurve: Curves.easeOutCubic,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(TodoTask task, Color textColor) {
    return Slidable(
      key: ValueKey(task.id),
      endActionPane: ActionPane(
        extentRatio: 0.25,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              ref.read(todoControllerProvider.notifier).deleteTask(widget.category.id, task.id);
            },
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
          ),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(todoControllerProvider.notifier).toggleTask(widget.category.id, task.id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: task.isCompleted ? const Color(0xFF34C759) : Colors.transparent,
                  border: Border.all(
                    color: task.isCompleted ? const Color(0xFF34C759) : textColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: task.isCompleted ? textColor.withValues(alpha: 0.4) : textColor,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                        fontWeight: FontWeight.w500,
                      ),
                      child: Text(task.title),
                    ),
                    if (task.reminderTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.alarm,
                              size: 14,
                              color: task.reminderTime!.isBefore(DateTime.now()) && !task.isCompleted
                                  ? Colors.redAccent
                                  : textColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatReminderTime(task.reminderTime!),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: task.reminderTime!.isBefore(DateTime.now()) && !task.isCompleted
                                    ? Colors.redAccent
                                    : textColor.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (task.reminderLocationName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.location_solid,
                              size: 14,
                              color: textColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                task.reminderLocationName!,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: textColor.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Alarm Button
              GestureDetector(
                onTap: () => _showReminderPicker(context, task, ref),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2, right: 4),
                  child: Icon(
                    (task.reminderTime != null || task.reminderLat != null) ? CupertinoIcons.alarm_fill : CupertinoIcons.alarm,
                    color: (task.reminderTime != null || task.reminderLat != null)
                        ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFA191FF) : const Color(0xFF6F52FF))
                        : textColor.withValues(alpha: 0.3),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  String _formatReminderTime(DateTime time) {
    final now = DateTime.now();
    final isToday = time.year == now.year && time.month == now.month && time.day == now.day;
    final isTomorrow = time.year == now.year && time.month == now.month && time.day == now.day + 1;
    
    final timeStr = DateFormat.jm().format(time); // "10:30 AM"
    
    if (isToday) return timeStr;
    if (isTomorrow) return 'Tomorrow, $timeStr';
    
    return '${DateFormat('MMM d').format(time)}, $timeStr';
  }

  void _showReminderPicker(BuildContext context, TodoTask task, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationReminderModal(
        task: task,
        categoryId: widget.category.id,
        ref: ref,
      ),
    );
  }
}

class _LocationReminderModal extends StatefulWidget {
  final TodoTask task;
  final String categoryId;
  final WidgetRef ref;

  const _LocationReminderModal({
    required this.task,
    required this.categoryId,
    required this.ref,
  });

  @override
  State<_LocationReminderModal> createState() => _LocationReminderModalState();
}

class _LocationReminderModalState extends State<_LocationReminderModal> {
  int _segmentedValue = 0; // 0: Time, 1: Location
  late DateTime _selectedTime;
  final TextEditingController _locCtrl = TextEditingController();
  bool _isSearching = false;

  double? _lat;
  double? _lng;
  String? _locName;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.task.reminderTime ?? DateTime.now().add(const Duration(minutes: 5));
    if (widget.task.reminderLocationName != null) {
      _locCtrl.text = widget.task.reminderLocationName!;
      _lat = widget.task.reminderLat;
      _lng = widget.task.reminderLng;
      _locName = widget.task.reminderLocationName;
      _segmentedValue = 1;
    }
  }

  @override
  void dispose() {
    _locCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_locCtrl.text.trim().isEmpty) return;
    setState(() => _isSearching = true);
    try {
      List<Location> locations = await locationFromAddress(_locCtrl.text.trim());
      if (locations.isNotEmpty) {
        setState(() {
          _lat = locations.first.latitude;
          _lng = locations.first.longitude;
          _locName = _locCtrl.text.trim();
        });
      }
    } catch (e) {
      setState(() {
        _lat = null;
        _lng = null;
        _locName = null;
      });
      debugPrint("Geocoding failed: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _save() {
    if (_segmentedValue == 0) {
      if (_selectedTime.isAfter(DateTime.now())) {
        widget.ref.read(todoControllerProvider.notifier).updateTaskReminder(
              widget.categoryId,
              widget.task.id,
              _selectedTime,
            );
        Navigator.pop(context);
      }
    } else {
      if (_lat != null && _lng != null) {
        widget.ref.read(todoControllerProvider.notifier).updateTaskLocation(
              widget.categoryId,
              widget.task.id,
              _lat,
              _lng,
              _locName,
            );
        Navigator.pop(context);
      }
    }
  }

  void _clear() {
    if (_segmentedValue == 0) {
      widget.ref.read(todoControllerProvider.notifier).updateTaskReminder(widget.categoryId, widget.task.id, null);
    } else {
      widget.ref.read(todoControllerProvider.notifier).updateTaskLocation(widget.categoryId, widget.task.id, null, null, null);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Add padding for bottom keyboard visibility
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: 480 + bottomInset,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey, fontSize: 16)),
                  ),
                  Text('Set Reminder', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
                  TextButton(
                    onPressed: _save,
                    child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: CupertinoColors.activeBlue, fontSize: 16)),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            CupertinoSlidingSegmentedControl<int>(
              groupValue: _segmentedValue,
              thumbColor: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFFFFFFF),
              backgroundColor: isDark ? const Color(0xFF1C1C1E) : CupertinoColors.tertiarySystemFill,
              children: {
                0: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text('Time', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                ),
                1: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text('Location', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                ),
              },
              onValueChanged: (val) {
                if (val != null) setState(() => _segmentedValue = val);
              },
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: _segmentedValue == 0
                  ? CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.dateAndTime,
                      initialDateTime: _selectedTime,
                      minimumDate: _selectedTime.isBefore(DateTime.now()) ? _selectedTime : DateTime.now(),
                      onDateTimeChanged: (val) => _selectedTime = val,
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(CupertinoIcons.location_solid, size: 48, color: isDark ? const Color(0xFFA191FF) : const Color(0xFF6F52FF)),
                          const SizedBox(height: 16),
                          Text(
                            "Remind me when I arrive at:",
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 16),
                          CupertinoTextField(
                            controller: _locCtrl,
                            placeholder: "e.g. 1 Infinite Loop, Cupertino",
                            padding: const EdgeInsets.all(16),
                            clearButtonMode: OverlayVisibilityMode.editing,
                            onSubmitted: (_) => _search(),
                            suffix: _isSearching
                                ? const Padding(
                                    padding: EdgeInsets.only(right: 12),
                                    child: CupertinoActivityIndicator(),
                                  )
                                : CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: _search,
                                    child: const Icon(CupertinoIcons.search),
                                  ),
                          ),
                          const SizedBox(height: 16),
                          if (_lat != null && _lng != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeGreen.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(CupertinoIcons.check_mark_circled_solid, color: CupertinoColors.activeGreen),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Found: $_locName",
                                      style: GoogleFonts.inter(color: CupertinoColors.activeGreen, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (_locCtrl.text.isNotEmpty && !_isSearching)
                            Text(
                              "Press Search to find location",
                              style: GoogleFonts.inter(color: CupertinoColors.destructiveRed, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
            ),

            // Clear Button
            if ((_segmentedValue == 0 && widget.task.reminderTime != null) ||
                (_segmentedValue == 1 && widget.task.reminderLat != null))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
                child: CupertinoButton(
                  color: CupertinoColors.destructiveRed.withOpacity(0.1),
                  onPressed: _clear,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(CupertinoIcons.trash, color: CupertinoColors.destructiveRed, size: 18),
                      const SizedBox(width: 8),
                      Text('Remove Reminder', style: GoogleFonts.inter(color: CupertinoColors.destructiveRed, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _AddCategoryDialog extends ConsumerStatefulWidget {
  const _AddCategoryDialog();

  @override
  ConsumerState<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<_AddCategoryDialog> {
  final _controller = TextEditingController();
  final String _selectedEmoji = '📝';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'New Category',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              
              // Input
              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                cursorColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : null,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g., Shop, Work, Home',
                  labelStyle: Theme.of(context).brightness == Brightness.dark ? const TextStyle(color: Color(0xFFB0B0B5)) : null,
                  hintStyle: Theme.of(context).brightness == Brightness.dark ? const TextStyle(color: Color(0xFF6B6B70)) : GoogleFonts.poppins(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: Theme.of(context).brightness == Brightness.dark
                        ? GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          )
                        : TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              'Cancel',
                              style: GoogleFonts.poppins(
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Theme.of(context).brightness == Brightness.dark
                        ? GestureDetector(
                            onTap: () {
                              if (_controller.text.isNotEmpty) {
                                // Default color assigned for db backwards compatibility
                                final category = TodoCategory(
                                  name: _controller.text,
                                  color: Colors.transparent,
                                  emoji: _selectedEmoji,
                                );
                                ref.read(todoControllerProvider.notifier).addCategory(category);
                                Navigator.pop(context);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              if (_controller.text.isNotEmpty) {
                                final category = TodoCategory(
                                  name: _controller.text,
                                  color: Colors.transparent,
                                  emoji: _selectedEmoji,
                                );
                                ref.read(todoControllerProvider.notifier).addCategory(category);
                                Navigator.pop(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D264B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                            ),
                            child: Text(
                              'Create',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
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
    );
  }
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

