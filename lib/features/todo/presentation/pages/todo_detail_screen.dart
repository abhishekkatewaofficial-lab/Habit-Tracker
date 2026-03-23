import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../data/models/todo_category.dart';
import '../../data/models/todo_task.dart';
import '../controllers/todo_controller.dart';

class TodoDetailScreen extends ConsumerStatefulWidget {
  final String categoryId;
  const TodoDetailScreen({super.key, required this.categoryId});

  @override
  ConsumerState<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends ConsumerState<TodoDetailScreen> {
  final _taskController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _taskController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTask() {
    if (_taskController.text.isNotEmpty) {
      ref.read(todoControllerProvider.notifier).addTask(
        widget.categoryId,
        _taskController.text,
      );
      _taskController.clear();
      // Keep focus if desired, or unfocus
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(todoControllerProvider);
    final category = categories.firstWhere((c) => c.id == widget.categoryId, orElse: () => TodoCategory(name: '', color: Colors.grey));

    if (category.name.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, category),
            
            Expanded(
              child: category.tasks.isEmpty
                ? _buildEmptyTasksState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    physics: const BouncingScrollPhysics(),
                    itemCount: category.tasks.length,
                    itemBuilder: (context, index) {
                      final task = category.tasks[index];
                      return _TaskItem(
                        task: task,
                        categoryId: category.id,
                        color: category.color,
                      );
                    },
                  ),
            ),
            
            _buildBottomInput(context, category.color),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, TodoCategory category) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(CupertinoIcons.chevron_left, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D264B), size: 28),
              ),
              const SizedBox(width: 12),
              Text(
                category.name,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D264B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Progress Bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    // Dark mode: muted grey base so filled (white) portion stands out
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: category.progress,
                    child: Container(
                      decoration: BoxDecoration(
                        // Dark mode: pure white fill vs grey base = clear progress contrast
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : category.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${category.completedCount}/${category.tasks.length}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTasksState() {
    return const SizedBox.shrink();
  }

  Widget _buildBottomInput(BuildContext context, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Theme.of(context).brightness == Brightness.dark
            ? Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _taskController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _addTask(),
                style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                decoration: const InputDecoration(
                  hintText: 'Add a new task...',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _AnimatedAddButton(onTap: _addTask, color: color),
        ],
      ),
    );
  }
}

class _AnimatedAddButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color color;
  const _AnimatedAddButton({required this.onTap, required this.color});

  @override
  State<_AnimatedAddButton> createState() => _AnimatedAddButtonState();
}

class _AnimatedAddButtonState extends State<_AnimatedAddButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
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
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 60,
          height: 60,
          decoration: Theme.of(context).brightness == Brightness.dark
              ? const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                )
              : BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color,
                      widget.color.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
          child: Icon(
            Theme.of(context).brightness == Brightness.dark ? Icons.arrow_forward : CupertinoIcons.arrow_up, 
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.white, 
            size: Theme.of(context).brightness == Brightness.dark ? 28 : 30
          ),
        ),
      ),
    );
  }
}

class _TaskItem extends ConsumerWidget {
  final TodoTask task;
  final String categoryId;
  final Color color;

  const _TaskItem({
    required this.task,
    required this.categoryId,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(task.id),
        startActionPane: ActionPane(
          extentRatio: 0.2, // Small swipe distance
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _showEditDialog(context, ref),
              backgroundColor: Colors.transparent,
              foregroundColor: const Color(0xFF9CA3AF),
              icon: Icons.edit_rounded,
            ),
          ],
        ),
        endActionPane: ActionPane(
          extentRatio: 0.2, // Small swipe distance
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => ref.read(todoControllerProvider.notifier).deleteTask(categoryId, task.id),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.redAccent,
              icon: Icons.delete_outline_rounded,
            ),
          ],
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: task.isCompleted ? 0.6 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: Theme.of(context).brightness == Brightness.dark
                ? BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  )
                : BoxDecoration(
                    color: color.withValues(alpha: 0.25), // Brighter pastel as requested
                    borderRadius: BorderRadius.circular(16),
                  ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => ref.read(todoControllerProvider.notifier).toggleTask(categoryId, task.id),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: task.isCompleted
                        ? Icon(Icons.check_rounded, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : color, size: 18)
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    task.title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600, // Semi-bold as requested
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D264B),
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                      decorationColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D264B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: task.title);
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Edit Task'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Save'),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(todoControllerProvider.notifier).editTask(categoryId, task.id, controller.text);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
