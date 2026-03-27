import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../data/models/eisenhower_task.dart';
import '../controllers/eisenhower_controller.dart';

const kSubtitleColor = Color(0xFF8E8E93);

class QuadrantCfg {
  final String title;
  final String subtitle;
  final Color color;
  final Color titleColor;
  const QuadrantCfg(this.title, this.subtitle, this.color, this.titleColor);
}

QuadrantCfg getQuadrantConfig(QuadrantType type) {
  switch (type) {
    case QuadrantType.doNow:
      return const QuadrantCfg('Do Now', 'Urgent & Important', Color(0xFFFFB7B7), Color(0xFFB04040));
    case QuadrantType.schedule:
      return const QuadrantCfg('Schedule', 'Not Urgent & Important', Color(0xFFB7D5FF), Color(0xFF3A6EA5));
    case QuadrantType.delegate:
      return const QuadrantCfg('Delegate', 'Urgent & Not Important', Color(0xFFBAA1FF), Color(0xFF6A40A0));
    case QuadrantType.eliminate:
      return const QuadrantCfg('Eliminate', 'Not Urgent & Not Important', Color(0xFFB7EFBF), Color(0xFF4A7A50));
  }
}

class MatrixTaskCard extends ConsumerStatefulWidget {
  final EisenhowerTask task;
  final Color accentColor;
  final bool enableDrag;
  const MatrixTaskCard({
    super.key,
    required this.task,
    required this.accentColor,
    this.enableDrag = true,
  });

  @override
  ConsumerState<MatrixTaskCard> createState() => _MatrixTaskCardState();
}

class _MatrixTaskCardState extends ConsumerState<MatrixTaskCard> with SingleTickerProviderStateMixin {
  late AnimationController _checkController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _punchCheckbox() async {
    await _checkController.forward();
    await _checkController.reverse();
    ref.read(eisenhowerControllerProvider.notifier).toggleComplete(widget.task.id);
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    final content = AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: task.isCompleted ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _punchCheckbox,
              behavior: HitTestBehavior.opaque,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isCompleted ? const Color(0xFF4CAF50) : Colors.transparent,
                    border: Border.all(
                      color: task.isCompleted ? const Color(0xFF4CAF50) : kSubtitleColor,
                      width: 1.8,
                    ),
                  ),
                  child: task.isCompleted
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : null,
                ),
              ),
            ),
            Expanded(
              child: Text(
                task.title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                  decoration: task.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                  decorationColor: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    final cardWithSlidable = GestureDetector(
      onTap: () => showUpsertSheet(context, task: task),
      child: Slidable(
        key: ValueKey(task.id),
        endActionPane: ActionPane(
          extentRatio: 0.22,
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => ref.read(eisenhowerControllerProvider.notifier).deleteTask(task.id),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.redAccent,
              icon: Icons.delete_outline_rounded,
            ),
          ],
        ),
        child: content,
      ),
    );

    if (!widget.enableDrag) return Padding(padding: const EdgeInsets.only(bottom: 6), child: cardWithSlidable);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LongPressDraggable<String>(
        data: task.id,
        delay: const Duration(milliseconds: 400),
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.85,
            child: Container(
              width: 140,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16)],
              ),
              child: Text(task.title,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: content),
        child: cardWithSlidable,
      ),
    );
  }
}

void showUpsertSheet(BuildContext context, {EisenhowerTask? task, QuadrantType? preselected, bool hideSelector = false}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UpsertSheet(task: task, preselected: preselected, hideSelector: hideSelector),
  );
}

class UpsertSheet extends ConsumerStatefulWidget {
  final EisenhowerTask? task;
  final QuadrantType? preselected;
  final bool hideSelector;
  const UpsertSheet({super.key, this.task, this.preselected, this.hideSelector = false});

  @override
  ConsumerState<UpsertSheet> createState() => _UpsertSheetState();
}

class _UpsertSheetState extends ConsumerState<UpsertSheet> {
  late final TextEditingController _ctrl;
  late QuadrantType _quadrant;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.task?.title ?? '');
    _quadrant = widget.task?.quadrant ?? widget.preselected ?? QuadrantType.doNow;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.task != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D1D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            isEdit ? 'Edit Task' : 'New Task',
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            style: GoogleFonts.poppins(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'What needs to be done?',
              hintStyle: GoogleFonts.poppins(color: kSubtitleColor),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          if (!widget.hideSelector) ...[
            const SizedBox(height: 16),
            Text('Quadrant',
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: kSubtitleColor)),
            const SizedBox(height: 10),
            _buildQuadrantGrid(),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(isEdit ? 'Save Changes' : 'Add Task',
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          if (isEdit) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  ref.read(eisenhowerControllerProvider.notifier).deleteTask(widget.task!.id);
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Delete Task',
                    style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuadrantGrid() {
    final options = [
      (QuadrantType.doNow, 'Do Now', const Color(0xFFFFB7B7)),
      (QuadrantType.schedule, 'Schedule', const Color(0xFFB7D5FF)),
      (QuadrantType.delegate, 'Delegate', const Color(0xFFBAA1FF)),
      (QuadrantType.eliminate, 'Eliminate', const Color(0xFFB7EFBF)),
    ];
    return Column(
      children: [
        Row(children: [_quadrantChip(options[0]), const SizedBox(width: 10), _quadrantChip(options[1])]),
        const SizedBox(height: 10),
        Row(children: [_quadrantChip(options[2]), const SizedBox(width: 10), _quadrantChip(options[3])]),
      ],
    );
  }

  Widget _quadrantChip((QuadrantType, String, Color) opt) {
    final (type, label, color) = opt;
    final isSelected = _quadrant == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _quadrant = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.transparent, width: 2),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    final title = _ctrl.text.trim();
    if (title.isEmpty) return;
    final n = ref.read(eisenhowerControllerProvider.notifier);
    if (widget.task == null) {
      n.addTask(title, _quadrant);
    } else {
      n.updateTask(widget.task!.copyWith(title: title, quadrant: _quadrant));
    }
    Navigator.pop(context);
  }
}
