import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../controllers/todo_controller.dart';
import '../../data/models/todo_category.dart';
import 'todo_detail_screen.dart';


class TodoHomeScreen extends ConsumerWidget {
  const TodoHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(todoControllerProvider);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Container(
          width: double.infinity,
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width > 600 ? 700 : double.infinity,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Bar
                  Row(
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
                  const SizedBox(height: 32),

                  // Categories List
                  Expanded(
                    child: categories.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: categories.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return _CategoryCard(category: category);
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

class _CategoryCard extends ConsumerWidget {
  final TodoCategory category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Slidable(
      key: ValueKey(category.id),
      startActionPane: ActionPane(
        extentRatio: 0.25,
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _showEditDialog(context, ref),
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF6B7280),
            icon: Icons.edit_rounded,
          ),
        ],
      ),
      endActionPane: ActionPane(
        extentRatio: 0.25,
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              ref.read(todoControllerProvider.notifier).deleteCategory(category.id);
            },
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.redAccent,
            icon: Icons.delete_outline_rounded,
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => TodoDetailScreen(categoryId: category.id)),
          );
        },
        child: Container(
          height: 70, // Reduced from 100
          width: double.infinity,
          decoration: Theme.of(context).brightness == Brightness.dark
            ? BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              )
            : BoxDecoration(
                color: category.color,
                borderRadius: BorderRadius.circular(20), // Slightly smaller radius for compact card
                boxShadow: [
                  BoxShadow(
                    color: category.color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                category.name,
                style: Theme.of(context).brightness == Brightness.dark
                    ? GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )
                    : GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D264B),
                      ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.chevron_right,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2D264B),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: category.name);
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
            placeholder: 'e.g., Shopping, Work, Study...',
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
                  id: category.id,
                  name: controller.text,
                  color: category.color,
                  emoji: category.emoji,
                  tasks: category.tasks,
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
}

class _AddCategoryDialog extends ConsumerStatefulWidget {
  const _AddCategoryDialog();

  @override
  ConsumerState<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<_AddCategoryDialog> {
  final _controller = TextEditingController();
  Color _selectedColor = const Color(0xFFFABBDA);
  final String _selectedEmoji = '📝';

  final List<Color> _colors = [
    const Color(0xFFFABBDA), // Pink
    const Color(0xFFBAA1FF), // Purple
    const Color(0xFFB7D5FF), // Blue
    const Color(0xFFB7FFBF), // Green
    const Color(0xFFFFB7B7), // Light Red
    const Color(0xFFFFE2B7), // Orange
    const Color(0xFFFCFFB7), // Yellow
  ];

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
                  hintText: 'e.g., Shopping, Work, Study...',
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
              const SizedBox(height: 24),
              
              // Color Picker
              if (Theme.of(context).brightness != Brightness.dark) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: _colors.map((color) {
                    final isSelected = _selectedColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isSelected ? 36 : 32,
                        height: isSelected ? 36 : 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected ? Border.all(color: const Color(0xFF2D264B), width: 2) : null,
                          boxShadow: isSelected ? [
                            BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))
                          ] : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
              ],
              
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
                                final assignedColor = Theme.of(context).brightness == Brightness.dark 
                                    ? _colors[Random().nextInt(_colors.length)] 
                                    : _selectedColor;
                                final category = TodoCategory(
                                  name: _controller.text,
                                  color: assignedColor,
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
                                  color: _selectedColor,
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
