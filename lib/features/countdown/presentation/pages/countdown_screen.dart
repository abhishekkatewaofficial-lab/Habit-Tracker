import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker_ios/core/constants/app_colors.dart';
import '../../data/models/countdown_event.dart';
import '../controllers/countdown_controller.dart';

// ── Colored icon data model ────────────────────────────────────────────────────
class _CountdownIcon {
  final IconData icon;
  final Color color;
  final String label;
  const _CountdownIcon(this.icon, this.color, this.label);
  String get code => icon.codePoint.toString();
}

// ── Premium event-based icon registry (28 icons, 6 categories) ─────────────
final List<_CountdownIcon> _iconRegistry = [
  // 🎉 Personal / Celebration
  const _CountdownIcon(CupertinoIcons.gift_fill,        Color(0xFFFF7BAC), 'Birthday'),
  const _CountdownIcon(CupertinoIcons.heart_fill,        Color(0xFFFF6B8A), 'Anniversary'),
  const _CountdownIcon(CupertinoIcons.sparkles,          Color(0xFFFFB347), 'Party'),
  const _CountdownIcon(CupertinoIcons.rosette,           Color(0xFFE891C8), 'Wedding'),
  const _CountdownIcon(CupertinoIcons.music_note,        Color(0xFFB388FF), 'Concert'),

  // 📚 Productivity / Career
  const _CountdownIcon(CupertinoIcons.book_fill,         Color(0xFF5C7CFF), 'Exam'),
  const _CountdownIcon(CupertinoIcons.pencil,            Color(0xFF4FC3F7), 'Study'),
  const _CountdownIcon(CupertinoIcons.flag_fill,         Color(0xFFFF8A65), 'Goal'),
  const _CountdownIcon(CupertinoIcons.briefcase_fill,    Color(0xFF78909C), 'Work'),
  const _CountdownIcon(CupertinoIcons.checkmark_seal_fill, Color(0xFF66BB6A), 'Deadline'),

  // ✈️ Travel
  const _CountdownIcon(CupertinoIcons.airplane,          Color(0xFF29B6F6), 'Flight'),
  const _CountdownIcon(CupertinoIcons.car_fill,          Color(0xFF42A5F5), 'Road Trip'),
  const _CountdownIcon(CupertinoIcons.house_fill,        Color(0xFF26C6DA), 'Stay'),
  const _CountdownIcon(CupertinoIcons.map_fill,          Color(0xFF26A69A), 'Adventure'),

  // 🏃 Health / Fitness
  const _CountdownIcon(CupertinoIcons.flame_fill,        Color(0xFFFF7043), 'Workout'),
  const _CountdownIcon(CupertinoIcons.heart_circle_fill, Color(0xFFF06292), 'Health'),
  const _CountdownIcon(CupertinoIcons.moon_stars_fill,   Color(0xFF9575CD), 'Mindfulness'),
  const _CountdownIcon(CupertinoIcons.sun_max_fill,      Color(0xFFFFCA28), 'Yoga'),
  const _CountdownIcon(CupertinoIcons.sportscourt_fill,  Color(0xFF66BB6A), 'Sport'),

  // 💰 Finance
  const _CountdownIcon(CupertinoIcons.money_dollar_circle_fill, Color(0xFF26A69A), 'Finance'),
  const _CountdownIcon(CupertinoIcons.cart_fill,         Color(0xFFEF5350), 'Shopping'),
  const _CountdownIcon(CupertinoIcons.chart_bar_fill,    Color(0xFF42A5F5), 'Investment'),

  // 🔔 General
  const _CountdownIcon(CupertinoIcons.star_fill,         Color(0xFFFFD54F), 'Star'),
  const _CountdownIcon(CupertinoIcons.bell_fill,         Color(0xFFFF8A65), 'Reminder'),
  const _CountdownIcon(CupertinoIcons.calendar,          Color(0xFF7E57C2), 'Event'),
  const _CountdownIcon(CupertinoIcons.person_2_fill,     Color(0xFF26C6DA), 'Friends'),
  const _CountdownIcon(CupertinoIcons.camera_fill,       Color(0xFFEC407A), 'Photo'),
  const _CountdownIcon(CupertinoIcons.gamecontroller_fill, Color(0xFF66BB6A), 'Gaming'),
];

// ── Helpers ────────────────────────────────────────────────────────────────────
_CountdownIcon _iconEntryFromCode(String code) {
  final idx = int.tryParse(code) ?? 0;
  return _iconRegistry.firstWhere(
    (e) => e.icon.codePoint == idx,
    orElse: () => _iconRegistry.first,
  );
}

IconData _iconFromCode(String code) => _iconEntryFromCode(code).icon;
Color _colorFromCode(String code)   => _iconEntryFromCode(code).color;
String _iconCode(IconData icon)     => icon.codePoint.toString();


// ── Main Screen ────────────────────────────────────────────────────────────────
class CountdownScreen extends ConsumerWidget {
  const CountdownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(countdownProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, // rely on parent
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110), // Same 110px padding as Focus to clear dock
        child: _ScaleOnTap(
          onTap: () => _showAddEditModal(context, ref, null),
          child: isDark 
              ? Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: -4,
                      )
                    ]
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                )
              : const FloatingActionButton(
                  heroTag: 'countdown_fab',
                  onPressed: null, // handled by _ScaleOnTap
                  backgroundColor: Color(0xFF34C759), // Focus Green
                  elevation: 8,
                  shape: CircleBorder(),
                  child: Icon(CupertinoIcons.add, color: Colors.white, size: 28),
                ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header (Calligraphy style)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
              child: Center(
                child: Text(
                  'Countdown',
                  style: GoogleFonts.greatVibes(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF2D264B),
                  ),
                ),
              ),
            ),
            
            Expanded(
              child: events.isEmpty
                  ? _buildEmptyState()
                  : _buildEventsList(context, ref, events),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Decorative illustration
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.04),
                ],
              ),
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    CupertinoIcons.clock,
                    size: 70,
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                  Icon(
                    CupertinoIcons.hourglass,
                    size: 40,
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'No countdowns yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2D264B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first event',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(
    BuildContext context,
    WidgetRef ref,
    List<CountdownEvent> events,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
      itemCount: events.length,
      itemBuilder: (context, index) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _CountdownCard(
            key: ValueKey(events[index].id),
            event: events[index],
            onEdit: () => _showAddEditModal(context, ref, events[index]),
            onDelete: () => ref
                .read(countdownProvider.notifier)
                .deleteEvent(events[index].id),
          ),
        );
      },
    );
  }

  void _showAddEditModal(
    BuildContext context,
    WidgetRef ref,
    CountdownEvent? existing,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditModal(existing: existing, ref: ref),
    );
  }
}

// ── Scale on Tap Animation Wrapper ───────────────────────────────────────────
class _ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ScaleOnTap({required this.child, required this.onTap});

  @override
  State<_ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<_ScaleOnTap> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ── Countdown Card ─────────────────────────────────────────────────────────────
class _CountdownCard extends StatefulWidget {
  final CountdownEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CountdownCard({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<_CountdownCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final days = widget.event.daysLeft;
    final Color daysColor;
    final String daysLabel;

    if (days == 0) {
      daysColor = isDark ? Colors.white : const Color(0xFFEF4444); // RED
      daysLabel = 'Today';
    } else if (days > 0) {
      daysColor = isDark ? Colors.white : const Color(0xFF22C55E); // GREEN
      daysLabel = '$days day${days == 1 ? '' : 's'} left';
    } else {
      daysColor = isDark ? Colors.white : const Color(0xFFF97316); // ORANGE
      daysLabel = '${-days} day${-days == 1 ? '' : 's'} passed';
    }

    final iconEntry = _iconEntryFromCode(widget.event.iconCode);
    final iconColor = isDark ? Colors.white : iconEntry.color;

    final Color displayColor = days == 0 ? (isDark ? Colors.white : const Color(0xFFEF4444)) : iconColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(widget.event.id),
        startActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => widget.onEdit(),
              backgroundColor: const Color(0xFF7F56D9),
              foregroundColor: Colors.white,
              icon: CupertinoIcons.pencil,
              label: 'Edit',
              borderRadius: BorderRadius.circular(20),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => _confirmDelete(context),
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              icon: CupertinoIcons.trash,
              label: 'Delete',
              borderRadius: BorderRadius.circular(20),
            ),
          ],
        ),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.diagonal3Values(
              _pressed ? 0.98 : 1.0,
              _pressed ? 0.98 : 1.0,
              1.0,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _pressed ? 0.05 : 0.08),
                  blurRadius: _pressed ? 6 : 12,
                  offset: Offset(0, _pressed ? 2 : 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  // Colored Icon Pill
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.transparent : displayColor.withValues(alpha: 0.12),
                      border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.2)) : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(iconEntry.icon, color: displayColor, size: 24),
                  ),
                  const SizedBox(width: 14),

                  // Name
                  Expanded(
                    child: Text(
                      widget.event.name,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF2D264B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Days chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.transparent : daysColor.withValues(alpha: 0.1),
                      border: isDark ? Border.all(color: Colors.white.withValues(alpha: 0.2)) : null,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      daysLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: daysColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this countdown?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Add / Edit Modal ───────────────────────────────────────────────────────────
// ── Premium Add/Edit Modal ─────────────────────────────────────────────────────
class _AddEditModal extends StatefulWidget {
  final CountdownEvent? existing;
  final WidgetRef ref;

  const _AddEditModal({required this.existing, required this.ref});

  @override
  State<_AddEditModal> createState() => _AddEditModalState();
}

class _AddEditModalState extends State<_AddEditModal>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _nameCtrl;
  late final FocusNode _nameFocus;
  late DateTime _selectedDate;
  late IconData _selectedIcon;
  bool _nameFocused = false;
  bool _savePressed = false;
  bool _cancelPressed = false;
  bool _reminderEnabled = false;
  int? _reminderHour;
  int? _reminderMinute;

  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _nameFocus = FocusNode();
    _nameFocus.addListener(
        () => setState(() => _nameFocused = _nameFocus.hasFocus));
    _selectedDate =
        e?.targetDate ?? DateTime.now().add(const Duration(days: 7));
    _selectedIcon =
        e != null ? _iconFromCode(e.iconCode) : _iconRegistry.first.icon;
    _reminderHour = e?.reminderHour;
    _reminderMinute = e?.reminderMinute;
    _reminderEnabled = _reminderHour != null;

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack)
        .drive(Tween(begin: 0.92, end: 1.0));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut)
        .drive(Tween(begin: 0.0, end: 1.0));
    _slideAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic).drive(
            Tween(begin: const Offset(0, 0.04), end: Offset.zero));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final isNew = widget.existing == null;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).size.height * 0.12,
                left: 16,
                right: 16,
                bottom: bottomPad + 16,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 60,
                    offset: const Offset(0, 20),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle pill
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Calligraphy header
                      Center(
                        child: Text(
                          isNew ? 'New Countdown' : 'Edit Countdown',
                          style: GoogleFonts.greatVibes(
                            fontSize: 40,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF2D264B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Subtle gradient divider
                      Center(
                        child: Container(
                          width: 60,
                          height: 1.5,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              AppColors.primary.withValues(alpha: 0.3),
                              Colors.transparent,
                            ]),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Event Name ─────────────────────────────
                      const _ModalLabel('Event Name'),
                      const SizedBox(height: 10),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.transparent
                              : (_nameFocused
                                  ? AppColors.primary.withValues(alpha: 0.05)
                                  : const Color(0xFFF5F4FF)),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : (_nameFocused
                                    ? AppColors.primary.withValues(alpha: 0.5)
                                    : Colors.transparent),
                            width: 1.5,
                          ),
                          boxShadow: _nameFocused && !isDark
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.12),
                                    blurRadius: 14,
                                  )
                                ]
                              : [],
                        ),
                        child: TextField(
                          controller: _nameCtrl,
                          focusNode: _nameFocus,
                          cursorColor: isDark ? Colors.white : null,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF2D264B),
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'e.g. Birthday Party',
                            hintStyle: GoogleFonts.poppins(
                              color: isDark ? const Color(0xFF6B6B70) : Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 16),
                            prefixIcon: Padding(
                              padding:
                                  const EdgeInsets.only(left: 14, right: 8),
                              child: Icon(
                                CupertinoIcons.pencil_ellipsis_rectangle,
                                color: isDark
                                    ? (_nameFocused ? Colors.white : const Color(0xFFB0B0B5))
                                    : (_nameFocused
                                        ? AppColors.primary
                                        : Colors.grey.shade400),
                                size: 20,
                              ),
                            ),
                            prefixIconConstraints: const BoxConstraints(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── Date selector ─────────────────────────
                      const _ModalLabel('Target Date'),
                      const SizedBox(height: 10),
                      _PremiumTapCard(
                        onTap: _pickDate,
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(CupertinoIcons.calendar,
                                  color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                _formatDate(_selectedDate),
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF2D264B),
                                ),
                              ),
                            ),
                            Icon(CupertinoIcons.chevron_right,
                                color: Colors.grey.shade400, size: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ── Icon selector ─────────────────────────
                      const _ModalLabel('Choose Icon'),
                      const SizedBox(height: 10),
                      _PremiumTapCard(
                        onTap: _showIconPicker,
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    _colorFromCode(_iconCode(_selectedIcon)).withValues(alpha: 0.18),
                                    _colorFromCode(_iconCode(_selectedIcon)).withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _colorFromCode(_iconCode(_selectedIcon)).withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Icon(_selectedIcon,
                                  color: _colorFromCode(_iconCode(_selectedIcon)), size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Event Icon',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF2D264B),
                                    ),
                                  ),
                                  Text(
                                    'Tap to browse icons',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade400),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(CupertinoIcons.chevron_right,
                                  color: AppColors.primary, size: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Enable Reminder ───────────────────────
                      const _ModalLabel('Reminder'),
                      const SizedBox(height: 10),
                      _PremiumTapCard(
                        onTap: () async {
                          if (_reminderEnabled) {
                            // Turn OFF
                            setState(() {
                              _reminderEnabled = false;
                              _reminderHour = null;
                              _reminderMinute = null;
                            });
                          } else {
                            // Turn ON → show time picker
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: _reminderHour ?? 9,
                                minute: _reminderMinute ?? 0,
                              ),
                            );
                            if (picked != null) {
                              setState(() {
                                _reminderEnabled = true;
                                _reminderHour = picked.hour;
                                _reminderMinute = picked.minute;
                              });
                            }
                          }
                        },
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: (_reminderEnabled
                                        ? AppColors.primary
                                        : Colors.grey.shade300)
                                    .withValues(alpha: _reminderEnabled ? 0.15 : 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                CupertinoIcons.bell_fill,
                                size: 18,
                                color: _reminderEnabled
                                    ? AppColors.primary
                                    : Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enable Reminder',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF2D264B),
                                    ),
                                  ),
                                  if (_reminderEnabled &&
                                      _reminderHour != null)
                                    Text(
                                      _formatReminderTime(
                                          _reminderHour!, _reminderMinute!),
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  else
                                    Text(
                                      'Tap to set a reminder time',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _reminderEnabled,
                              activeTrackColor: AppColors.primary,
                              onChanged: (_) async {
                                if (_reminderEnabled) {
                                  setState(() {
                                    _reminderEnabled = false;
                                    _reminderHour = null;
                                    _reminderMinute = null;
                                  });
                                } else {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay(
                                      hour: _reminderHour ?? 9,
                                      minute: _reminderMinute ?? 0,
                                    ),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _reminderEnabled = true;
                                      _reminderHour = picked.hour;
                                      _reminderMinute = picked.minute;
                                    });
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Action buttons ────────────────────────
                      Row(
                        children: [
                          // Cancel
                          Expanded(
                            child: GestureDetector(
                              onTapDown: (_) =>
                                  setState(() => _cancelPressed = true),
                              onTapUp: (_) {
                                setState(() => _cancelPressed = false);
                                Navigator.pop(context);
                              },
                              onTapCancel: () =>
                                  setState(() => _cancelPressed = false),
                              child: isDark 
                                  ? Container(
                                      height: 54,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : AnimatedContainer(
                                      duration: const Duration(milliseconds: 120),
                                      height: 54,
                                      transform: Matrix4.diagonal3Values(
                                        _cancelPressed ? 0.97 : 1.0,
                                        _cancelPressed ? 0.97 : 1.0,
                                        1.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                            color: Colors.grey.shade200, width: 1),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'Cancel',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Save
                          Expanded(
                            child: GestureDetector(
                              onTapDown: (_) =>
                                  setState(() => _savePressed = true),
                              onTapUp: (_) {
                                setState(() => _savePressed = false);
                                _save();
                              },
                              onTapCancel: () =>
                                  setState(() => _savePressed = false),
                              child: isDark 
                                  ? Container(
                                      height: 54,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.15),
                                        ),
                                      ),
                                      child: const Text(
                                        'Save',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )
                                  : AnimatedContainer(
                                      duration: const Duration(milliseconds: 120),
                                      height: 54,
                                      transform: Matrix4.diagonal3Values(
                                        _savePressed ? 0.97 : 1.0,
                                        _savePressed ? 0.97 : 1.0,
                                        1.0,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.primary,
                                            Color.lerp(AppColors.primary,
                                                const Color(0xFF9B72CF), 0.6)!,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                                alpha: _savePressed ? 0.2 : 0.35),
                                            blurRadius: _savePressed ? 6 : 16,
                                            offset:
                                                Offset(0, _savePressed ? 2 : 6),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                              CupertinoIcons.checkmark_circle_fill,
                                              color: Colors.white,
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Save',
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
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
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      builder: (context, child) {
        bool isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: isDark 
            ? ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.white,
                  onPrimary: Colors.black,
                  surface: Color(0xFF1C1C1E),
                  onSurface: Colors.white,
                ),
                dialogBackgroundColor: const Color(0xFF1C1C1E),
              )
            : Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: Theme.of(context).colorScheme.surface,
                  onSurface: const Color(0xFF2D264B),
                ),
              ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _showIconPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PremiumIconPickerSheet(
        selected: _selectedIcon,
        onSelected: (ic) {
          setState(() => _selectedIcon = ic);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter an event name',
              style: GoogleFonts.poppins(fontSize: 14)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    final existing = widget.existing;
    if (existing != null) {
      widget.ref.read(countdownProvider.notifier).updateEvent(
            existing.copyWith(
              name: name,
              targetDate: _selectedDate,
              iconCode: _iconCode(_selectedIcon),
              reminderHour: _reminderEnabled ? _reminderHour : null,
              reminderMinute: _reminderEnabled ? _reminderMinute : null,
              clearReminder: !_reminderEnabled,
            ),
          );
    } else {
      widget.ref.read(countdownProvider.notifier).addEvent(
            CountdownEvent(
              name: name,
              targetDate: _selectedDate,
              iconCode: _iconCode(_selectedIcon),
              reminderHour: _reminderEnabled ? _reminderHour : null,
              reminderMinute: _reminderEnabled ? _reminderMinute : null,
            ),
          );
    }
    Navigator.pop(context);
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[d.weekday]}, ${months[d.month]} ${d.day}, ${d.year}';
  }

  String _formatReminderTime(int hour, int minute) {
    final period = hour < 12 ? 'AM' : 'PM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return 'Reminder at $h:$m $period  ·  Tap to change';
  }
}

// ── Premium tap-card wrapper ───────────────────────────────────────────────────
class _PremiumTapCard extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _PremiumTapCard({required this.onTap, required this.child});
  @override
  State<_PremiumTapCard> createState() => _PremiumTapCardState();
}

class _PremiumTapCardState extends State<_PremiumTapCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        transform: Matrix4.diagonal3Values(
          _pressed ? 0.98 : 1.0,
          _pressed ? 0.98 : 1.0,
          1.0,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1C1C1E)
              : (_pressed
                  ? AppColors.primary.withValues(alpha: 0.05)
                  : const Color(0xFFF6F5FF)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : (_pressed
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : Colors.transparent),
            width: 1.5,
          ),
          boxShadow: isDark 
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: widget.child,
      ),
    );
  }
}

// ── Premium Icon Picker Sheet ──────────────────────────────────────────────────
class _PremiumIconPickerSheet extends StatelessWidget {
  final IconData selected;
  final ValueChanged<IconData> onSelected;
  const _PremiumIconPickerSheet(
      {required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.15) : Theme.of(context).colorScheme.outline.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(CupertinoIcons.sparkles,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Choose Icon',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF2D264B),
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
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: _iconRegistry.length,
                itemBuilder: (_, i) {
                  final entry = _iconRegistry[i];
                  final isSel = entry.icon.codePoint == selected.codePoint;
                  return GestureDetector(
                    onTap: () => onSelected(entry.icon),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      transform: Matrix4.diagonal3Values(
                          isSel ? 1.08 : 1.0, isSel ? 1.08 : 1.0, 1.0),
                      decoration: BoxDecoration(
                        gradient: isSel && !isDark
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  entry.color.withValues(alpha: 0.18),
                                  entry.color.withValues(alpha: 0.08),
                                ],
                              )
                            : null,
                        color: isSel 
                            ? (isDark ? Colors.transparent : null) 
                            : (isDark ? Colors.transparent : const Color(0xFFF5F4FF)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSel
                              ? (isDark ? Colors.white : entry.color.withValues(alpha: 0.55))
                              : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: isSel && !isDark
                            ? [
                                BoxShadow(
                                  color: entry.color.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        entry.icon,
                        color: isDark
                            ? (isSel ? Colors.white : Colors.white.withValues(alpha: 0.4))
                            : (isSel ? entry.color : Colors.grey.shade500),
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Modal section label ────────────────────────────────────────────────────────
class _ModalLabel extends StatelessWidget {
  final String text;
  const _ModalLabel(this.text);
  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: isDark ? const Color(0xFFB0B0B5) : Colors.grey.shade400,
        letterSpacing: 1.2,
      ),
    );
  }
}
