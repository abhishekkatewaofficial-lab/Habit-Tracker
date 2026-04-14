import re

with open('lib/features/timetable/presentation/pages/template_editor_screen.dart', 'r') as f:
    content = f.read()

# Replace ScheduleScreen with TemplateEditorScreen
content = content.replace('ScheduleScreen', 'TemplateEditorScreen')

# Replace _ScheduleScreenState with _TemplateEditorScreenState
content = content.replace('_ScheduleScreenState', '_TemplateEditorScreenState')

# Add editing template parameter
content = re.sub(
    r'class TemplateEditorScreen extends ConsumerStatefulWidget \{.*?const TemplateEditorScreen\(\{super\.key\}\);',
    'class TemplateEditorScreen extends ConsumerStatefulWidget {\n  final RoutineTemplate template;\n  const TemplateEditorScreen({super.key, required this.template});',
    content,
    flags=re.DOTALL
)

# Add local provider
provider_code = "final templateEditorBlocksProvider = StateProvider.autoDispose<List<TimeBlock>>((ref) => []);\n\nclass TemplateEditorScreen"
content = content.replace("class TemplateEditorScreen", provider_code)

# Add init state logic
init_state = """  @override
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
"""
content = re.sub(r'  @override\n  void initState\(\) \{.*?\n  \}', init_state, content, flags=re.DOTALL)

# Header changes - show Save button
header_code = """  Widget _buildHeader(bool isDark, DateTime selectedDate) {
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
  }"""
content = re.sub(r'  Widget _buildHeader\(bool isDark, DateTime selectedDate\) \{.*?\n  \}', header_code, content, count=1, flags=re.DOTALL)

# Replace timetableControllerProvider reading
content = content.replace('ref.watch(timetableControllerProvider)', 'ref.watch(templateEditorBlocksProvider)')

# Action sheet edits
content = content.replace(
    'ref\n                  .read(timetableControllerProvider.notifier)\n                  .deleteBlock(block.id);',
    'ref.read(templateEditorBlocksProvider.notifier).update((s) => s.where((b) => b.id != block.id).toList());'
)
content = content.replace(
    'ref\n                  .read(timetableControllerProvider.notifier)\n                  .toggleComplete(block.id);',
    'ref.read(templateEditorBlocksProvider.notifier).update((s) => s.map((b) => b.id == block.id ? b.copyWith(isCompleted: !b.isCompleted) : b).toList());'
)

# Add block sheet edits
content = content.replace(
    'ref.read(timetableControllerProvider.notifier).updateBlock(block);',
    'ref.read(templateEditorBlocksProvider.notifier).update((s) => s.map((b) => b.id == block.id ? block : b).toList());'
)
content = content.replace(
    'ref.read(timetableControllerProvider.notifier).addBlock(block);',
    'ref.read(templateEditorBlocksProvider.notifier).update((s) => [...s, block]);'
)

with open('lib/features/timetable/presentation/pages/template_editor_screen.dart', 'w') as f:
    f.write(content)
