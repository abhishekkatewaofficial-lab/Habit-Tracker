import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../data/models/time_block.dart';
import '../../data/models/routine_template.dart';
import '../controllers/routine_template_controller.dart';
import '../controllers/timetable_controller.dart';
import 'routine_templates_sheet.dart';

class _BlockLayoutInfo {
  final TimeBlock block;
  int columnIndex;
  int totalColumns;

  _BlockLayoutInfo({
    required this.block,
    required this.columnIndex,
    required this.totalColumns,
  });
}


// ── Constants ────────────────────────────────────────────────────────────────
const double _kHourHeight = 80.0; // px per hour on the timeline
const double _kTimeColWidth = 56.0;
const int _kTotalHours = 24;

// ── Preset colours for block picker ─────────────────────────────────────────
const List<String> _kBlockColors = [
  '#7C3AED', '#10B981', '#0D9488', '#3B82F6',
  '#F59E0B', '#EF4444', '#EC4899', '#6366F1',
  '#64748B', '#06B6D4',
];

// ── Preset emojis ────────────────────────────────────────────────────────────
const List<String> _kEmojis = [
  '📌', '🏃', '🧘', '💻', '📚', '🥗', '🌙', '🎯',
  '💪', '🎨', '🛌', '📞', '✈️', '🍕', '🎵', '💊',
];

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
final templateEditorBlocksProvider = StateProvider.autoDispose<List<TimeBlock>>((ref) => []);

class TemplateEditorScreen extends ConsumerStatefulWidget {
  final RoutineTemplate template;
  const TemplateEditorScreen({super.key, required this.template});

  @override
  ConsumerState<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late ScrollController _scrollController;
  Timer? _nowTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(templateEditorBlocksProvider.notifier).state = widget.template.blocks;
      _scrollToNow();
    });
    _nowTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }


  void _scrollToNow() {
    final hour = _now.hour + _now.minute / 60.0;
    final offset = (hour * _kHourHeight) - 120; // centre viewport a bit above now
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _dateLabel(DateTime dt) {
    final today = DateTime.now();
    if (_isSameDay(dt, today)) return 'Today';
    if (_isSameDay(dt, today.add(const Duration(days: 1)))) return 'Tomorrow';
    if (_isSameDay(dt, today.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(dt);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _goPrev() {
    final cur = ref.read(timetableDateProvider);
    ref.read(timetableDateProvider.notifier).state =
        cur.subtract(const Duration(days: 1));
  }

  void _goNext() {
    final cur = ref.read(timetableDateProvider);
    ref.read(timetableDateProvider.notifier).state =
        cur.add(const Duration(days: 1));
  }

  void _openAddSheet({DateTime? prefilledStart}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBlockSheet(prefilledStart: prefilledStart),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedDate = ref.watch(timetableDateProvider);
    final blocks = ref.watch(templateEditorBlocksProvider);
    final isToday = _isSameDay(selectedDate, DateTime.now());
    debugPrint('🎨 TemplateEditorScreen building with ${blocks.length} blocks for date: ${selectedDate.toIso8601String()}');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF0D0D1A)]
                : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark, selectedDate),
              Expanded(
                child: _buildTimeline(isDark, blocks, isToday, selectedDate),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFab(isDark),
    );
  }

  Widget _buildHeader(bool isDark, DateTime selectedDate) {
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(CupertinoIcons.back, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'Editing ${widget.template.name}',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          TextButton(
            onPressed: () {
              final blocks = ref.read(templateEditorBlocksProvider);
              ref.read(routineTemplateControllerProvider.notifier)
                  .updateTemplateBlocks(widget.template.id, blocks);
              Navigator.pop(context);
            },
            child: Text('Save', style: GoogleFonts.poppins(color: const Color(0xFF7C3AED), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
      bool isDark, List<TimeBlock> blocks, bool isToday, DateTime selectedDate) {
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final lineColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    // "now" offset in px
    final nowOffset =
        (_now.hour + _now.minute / 60.0) * _kHourHeight;

    if (blocks.isEmpty && !isToday) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.calendar_badge_plus,
              size: 64,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              'No blocks for this day',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => RoutineTemplatesSheet.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.square_grid_2x2, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Apply Template',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final layoutInfos = _calculateLayout(blocks);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - _kTimeColWidth - 20;

        return Stack(
          children: [
            // Scrollable timeline
            SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            height: _kHourHeight * _kTotalHours + 40,
            child: Stack(
              children: [
                // Hour grid lines + labels
                for (int h = 0; h < _kTotalHours; h++)
                  Positioned(
                    top: h * _kHourHeight,
                    left: 0,
                    right: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: _kTimeColWidth,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8, top: 0),
                            child: Text(
                              _hourLabel(h),
                              textAlign: TextAlign.right,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: textColor.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            margin: const EdgeInsets.only(top: 8),
                            color: lineColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),

                // Time blocks
                for (final info in layoutInfos)
                  _buildBlock(info, isDark, textColor, availableWidth),

                // "Now" red line (today only)
                if (isToday)
                  Positioned(
                    top: nowOffset - 1,
                    left: _kTimeColWidth,
                    right: 16,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Invisible non-positioned child to force Stack to take full width
                Positioned.fill(
                  child: Container(),
                ),
                Container(width: double.infinity, height: 40),
              ],
            ),
          ),
        ),
      ],
    );
      },
    );
  }

  String _hourLabel(int h) {
    if (h == 0) return '12 AM';
    if (h < 12) return '$h AM';
    if (h == 12) return '12 PM';
    return '${h - 12} PM';
  }

  Widget _buildBlock(_BlockLayoutInfo info, bool isDark, Color textColor, double availableWidth) {
    final block = info.block;
    final startMinutes =
        block.startTime.hour * 60 + block.startTime.minute;
    final durationMinutes = block.duration.inMinutes.clamp(15, 1440);

    final top = (startMinutes / 60.0) * _kHourHeight;
    final height = (durationMinutes / 60.0) * _kHourHeight;

    final blockColor = block.color;
    final isShort = height < 48;

    // Calculate horizontal positioning based on columns
    final columnWidth = availableWidth / info.totalColumns;
    final leftPos = _kTimeColWidth + 4 + (info.columnIndex * columnWidth);
    
    // Slight padding between columns
    final actualWidth = info.totalColumns > 1 ? columnWidth - 4 : columnWidth;

    return Positioned(
      top: top,
      left: leftPos,
      width: actualWidth,
      height: height,
      child: GestureDetector(
        onTap: () => _showBlockOptions(block),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: block.isCompleted
                ? blockColor.withValues(alpha: 0.35)
                : blockColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: blockColor,
              width: block.isCompleted ? 1 : 0,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final isVeryNarrow = box.maxWidth < 60;
              return ClipRect(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: isShort
                        ? Row(
                            children: [
                              if (!isVeryNarrow) ...[
                                Text(block.emoji, style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 4),
                              ],
                              Expanded(
                                child: Text(
                                  block.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    decoration: block.isCompleted ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (!isVeryNarrow) ...[
                                    Text(block.emoji, style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      block.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        decoration: block.isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  if (block.isCompleted && !isVeryNarrow)
                                    const Icon(Icons.check_circle, color: Colors.white, size: 16),
                                ],
                              ),
                              if (height > 56 && !isVeryNarrow) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${_timeStr(block.startTime)} – ${_timeStr(block.endTime)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _timeStr(DateTime dt) => DateFormat.jm().format(dt);

  void _showBlockOptions(TimeBlock block) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text('${block.emoji} ${block.title}'),
        message: Text(
            '${_timeStr(block.startTime)} – ${_timeStr(block.endTime)}'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              ref.read(templateEditorBlocksProvider.notifier).update((s) => s.map((b) => b.id == block.id ? b.copyWith(isCompleted: !b.isCompleted) : b).toList());
            },
            child: Text(block.isCompleted ? 'Mark Incomplete' : 'Mark Complete ✓'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _AddBlockSheet(editBlock: block),
              );
            },
            child: const Text('Edit'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              ref.read(templateEditorBlocksProvider.notifier).update((s) => s.where((b) => b.id != block.id).toList());
            },
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Widget _buildFab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 115),
      child: GestureDetector(
        onTap: _openAddSheet,
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
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.1) 
                      : Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: isDark ? Colors.white : const Color(0xFF3A3A3C),
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
  List<_BlockLayoutInfo> _calculateLayout(List<TimeBlock> blocks) {
    if (blocks.isEmpty) return [];

    final sorted = List<TimeBlock>.from(blocks)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    List<_BlockLayoutInfo> results = [];
    List<TimeBlock> currentGroup = [];
    DateTime? groupEnd;

    for (final block in sorted) {
      if (groupEnd == null || block.startTime.isAfter(groupEnd) || block.startTime.isAtSameMomentAs(groupEnd)) {
        _layoutGroup(currentGroup, results);
        currentGroup = [block];
        groupEnd = block.endTime;
      } else {
        currentGroup.add(block);
        if (block.endTime.isAfter(groupEnd)) {
          groupEnd = block.endTime;
        }
      }
    }
    _layoutGroup(currentGroup, results);
    return results;
  }

  void _layoutGroup(List<TimeBlock> group, List<_BlockLayoutInfo> results) {
    if (group.isEmpty) return;

    List<DateTime> columns = [];
    List<_BlockLayoutInfo> temp = [];

    for (final block in group) {
      int col = -1;
      for (int i = 0; i < columns.length; i++) {
        if (block.startTime.isAfter(columns[i]) || block.startTime.isAtSameMomentAs(columns[i])) {
          col = i;
          columns[i] = block.endTime;
          break;
        }
      }
      if (col == -1) {
        col = columns.length;
        columns.add(block.endTime);
      }
      temp.add(_BlockLayoutInfo(
        block: block,
        columnIndex: col,
        totalColumns: 0,
      ));
    }

    final totalCols = columns.length;
    for (final info in temp) {
      info.totalColumns = totalCols;
      results.add(info);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _NavButton(
      {required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            size: 18,
            color: isDark
                ? Colors.white.withValues(alpha: 0.7)
                : Colors.black.withValues(alpha: 0.6)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD / EDIT BLOCK BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _AddBlockSheet extends ConsumerStatefulWidget {
  final TimeBlock? editBlock;
  final DateTime? prefilledStart;

  const _AddBlockSheet({this.editBlock, this.prefilledStart});

  @override
  ConsumerState<_AddBlockSheet> createState() => _AddBlockSheetState();
}

class _AddBlockSheetState extends ConsumerState<_AddBlockSheet> {
  late TextEditingController _titleCtrl;
  late DateTime _start;
  late DateTime _end;
  late String _colorHex;
  late String _emoji;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final roundedNow = DateTime(now.year, now.month, now.day, now.hour);

    if (widget.editBlock != null) {
      final b = widget.editBlock!;
      _titleCtrl = TextEditingController(text: b.title);
      _start = b.startTime;
      _end = b.endTime;
      _colorHex = b.colorHex;
      _emoji = b.emoji;
    } else {
      _titleCtrl = TextEditingController();
      _start = widget.prefilledStart ?? roundedNow;
      _end = _start.add(const Duration(hours: 1));
      _colorHex = _kBlockColors[0];
      _emoji = _kEmojis[0];
    }
  }


  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    if (_end.isBefore(_start) || _end.isAtSameMomentAs(_start)) {
      _showError('End time must be after start time.');
      return;
    }

    final selectedDate = ref.read(timetableDateProvider);
    final dateKey = DateFormat('yyyy-MM-dd').format(selectedDate);

    // Anchor times to selected date
    final start = DateTime(
      selectedDate.year, selectedDate.month, selectedDate.day,
      _start.hour, _start.minute,
    );
    final end = DateTime(
      selectedDate.year, selectedDate.month, selectedDate.day,
      _end.hour, _end.minute,
    );

    final block = TimeBlock(
      id: widget.editBlock?.id ??
          'tb_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      emoji: _emoji,
      startTime: start,
      endTime: end,
      colorHex: _colorHex,
      date: dateKey,
      isCompleted: widget.editBlock?.isCompleted ?? false,
    );

    if (widget.editBlock != null) {
      ref.read(templateEditorBlocksProvider.notifier).update((s) => s.map((b) => b.id == block.id ? block : b).toList());
    } else {
      ref.read(templateEditorBlocksProvider.notifier).update((s) => [...s, block]);
    }

    Navigator.pop(context);
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Invalid Time'),
        content: Text(msg),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.editBlock != null ? 'Edit Block' : 'New Block',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _save,
                    child: Text(
                      'Save',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7C3AED),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Emoji row
              Text('Emoji',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.6))),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _kEmojis.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final e = _kEmojis[i];
                    final selected = e == _emoji;
                    return GestureDetector(
                      onTap: () => setState(() => _emoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF7C3AED)
                                : textColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Center(
                            child: Text(e,
                                style: const TextStyle(fontSize: 22))),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text('Title',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.6))),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _titleCtrl,
                placeholder: 'e.g., Deep Work, Morning Run…',
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                style: GoogleFonts.poppins(color: textColor, fontSize: 15),
                placeholderStyle: GoogleFonts.poppins(
                    color: textColor.withValues(alpha: 0.35), fontSize: 15),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(height: 20),

              // Time row
              Row(
                children: [
                  Expanded(
                    child: _TimePicker(
                      label: 'Start',
                      time: _start,
                      isDark: isDark,
                      textColor: textColor,
                      onChanged: (dt) => setState(() => _start = dt),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimePicker(
                      label: 'End',
                      time: _end,
                      isDark: isDark,
                      textColor: textColor,
                      onChanged: (dt) => setState(() => _end = dt),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Colour picker
              Text('Color',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.6))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _kBlockColors.map((hex) {
                  final selected = hex == _colorHex;
                  final color = Color(int.parse('FF${hex.replaceAll('#', '')}',
                      radix: 16));
                  return GestureDetector(
                    onTap: () => setState(() => _colorHex = hex),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8)
                              ]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Time Picker Widget ────────────────────────────────────────────────────────
class _TimePicker extends StatelessWidget {
  final String label;
  final DateTime time;
  final bool isDark;
  final Color textColor;
  final ValueChanged<DateTime> onChanged;

  const _TimePicker({
    required this.label,
    required this.time,
    required this.isDark,
    required this.textColor,
    required this.onChanged,
  });

  void _pick(BuildContext context) {
    DateTime temp = time;
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 260,
        color:
            isDark ? const Color(0xFF1C1C1E) : CupertinoColors.systemBackground,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton(
                  child: const Text('Done'),
                  onPressed: () {
                    onChanged(temp);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: time,
                use24hFormat: false,
                onDateTimeChanged: (dt) => temp = dt,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.5))),
            const SizedBox(height: 4),
            Text(
              DateFormat.jm().format(time),
              style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
