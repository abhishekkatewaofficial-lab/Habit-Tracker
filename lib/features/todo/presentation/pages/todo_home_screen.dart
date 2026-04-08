import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../controllers/todo_controller.dart';
import '../../data/models/todo_category.dart';
import '../../data/models/todo_task.dart';


class TodoHomeScreen extends ConsumerWidget {
  const TodoHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(todoControllerProvider);

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
                Theme.of(context).brightness == Brightness.dark ? const Color(0xFF333336) : const Color(0xFFF3F4F6),
                Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1A1D) : const Color(0xFFB0B0B5),
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
                // Top Bar (with padding)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'To-Do',
                        style: GoogleFonts.greatVibes(
                          fontSize: 48,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D264B),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showAddCategoryDialog(context, ref),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.onSurface, size: 28),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Categories List (no padding, full width)
                Expanded(
                  child: categories.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
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
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
   ));
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
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: task.isCompleted ? textColor.withValues(alpha: 0.4) : textColor,
                    decoration: task.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                    fontWeight: FontWeight.w500,
                  ),
                  child: Text(task.title),
                ),
              ),
            ],
          ),
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
