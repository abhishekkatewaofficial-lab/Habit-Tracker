import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:habit_tracker_ios/features/timetable/data/models/routine_template.dart';
import 'package:habit_tracker_ios/features/timetable/presentation/controllers/routine_template_controller.dart';
import 'package:habit_tracker_ios/features/timetable/presentation/controllers/timetable_controller.dart';
import 'package:habit_tracker_ios/features/timetable/presentation/pages/template_editor_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:habit_tracker_ios/features/timetable/data/models/routine_template.dart';
import 'package:habit_tracker_ios/features/timetable/presentation/controllers/routine_template_controller.dart';
import 'package:habit_tracker_ios/features/timetable/presentation/controllers/timetable_controller.dart';

class RoutineTemplatesSheet extends ConsumerStatefulWidget {
  const RoutineTemplatesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const RoutineTemplatesSheet(),
    );
  }

  @override
  ConsumerState<RoutineTemplatesSheet> createState() => _RoutineTemplatesSheetState();
}

class _RoutineTemplatesSheetState extends ConsumerState<RoutineTemplatesSheet> {
  final TextEditingController _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    final selectedDate = ref.read(timetableDateProvider);
    final blocks = ref.read(timetableControllerProvider);

    if (blocks.isEmpty) {
      _showError('No blocks the schedule for this day to save.');
      return;
    }

    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Save Template'),
        content: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 16),
              child: Text('Save today\'s blocks as a reusable template.'),
            ),
            CupertinoTextField(
              controller: _nameCtrl,
              placeholder: 'e.g. Ideal Workday',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Save'),
            onPressed: () {
              final name = _nameCtrl.text.trim();
              if (name.isNotEmpty) {
                ref.read(routineTemplateControllerProvider.notifier).saveCurrentDayAsTemplate(
                  name,
                  '✨',
                  '#7C3AED',
                  selectedDate,
                );
              }
              Navigator.pop(dialogCtx);
              _nameCtrl.clear();
            },
          ),
        ],
      ),
    );
  }

  void _showCreateBlankDialog() {
    showCupertinoDialog(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: const Text('Create Blank Template'),
        content: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 8, bottom: 16),
              child: Text('Start with an empty schedule to build your routine.'),
            ),
            CupertinoTextField(
              controller: _nameCtrl,
              placeholder: 'e.g. Weekend Flow',
              autofocus: true,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Create'),
            onPressed: () async {
              final name = _nameCtrl.text.trim();
              if (name.isNotEmpty) {
                ref.read(routineTemplateControllerProvider.notifier)
                    .createEmptyTemplate(name, '✨', '#7C3AED');
              }
              Navigator.pop(dialogCtx);
              _nameCtrl.clear();
            },
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Oops'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _applyTemplate(RoutineTemplate template) {
    final targetDate = ref.read(timetableDateProvider);
    ref.read(routineTemplateControllerProvider.notifier).applyTemplateToDate(template, targetDate);
    Navigator.pop(context);
    
    // Show a success toast
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(
              '${template.name} applied!',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmDelete(RoutineTemplate template) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Template?'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              ref.read(routineTemplateControllerProvider.notifier).deleteTemplate(template.id);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final templates = ref.watch(routineTemplateControllerProvider);
    final selectedDate = ref.watch(timetableDateProvider);
    final blocks = ref.watch(timetableControllerProvider);
    
    // Bottom sheet max height 80% screen
    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Routines',
                    style: GoogleFonts.nunito(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      CupertinoIcons.clear_circled_solid,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Templates List
            Flexible(
              child: templates.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.square_stack_3d_up,
                            size: 48,
                            color: isDark ? Colors.white30 : Colors.black26,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No templates yet',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Save a day\'s schedule as a template to quickly apply it later.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shrinkWrap: true,
                      itemCount: templates.length,
                      itemBuilder: (context, index) {
                        final template = templates[index];
                        return _buildTemplateCard(template, isDark);
                      },
                    ),
            ),
            
            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showCreateBlankDialog,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.plus_app,
                              color: isDark ? Colors.white : Colors.black87,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Create Blank Template',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showCreateDialog,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: blocks.isEmpty 
                          ? (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05))
                          : (isDark ? Colors.black : const Color(0xFF34C759)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.arrow_down_doc_fill,
                              color: blocks.isEmpty 
                                ? (isDark ? Colors.white30 : Colors.black38)
                                : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Save Today as Template',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: blocks.isEmpty 
                                  ? (isDark ? Colors.white30 : Colors.black38)
                                  : Colors.white,
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
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(RoutineTemplate template, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _applyTemplate(template),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(int.parse('FF${template.colorHex.replaceAll('#', '')}', radix: 16)).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(template.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.name,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${template.blocks.length} blocks',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Edit button
                IconButton(
                  onPressed: () {
                    Navigator.pop(context); // Close sheet
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => TemplateEditorScreen(template: template),
                      ),
                    );
                  },
                  icon: const Icon(CupertinoIcons.pencil, size: 20),
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                
                // Delete button
                IconButton(
                  onPressed: () => _confirmDelete(template),
                  icon: const Icon(CupertinoIcons.trash, size: 20),
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
