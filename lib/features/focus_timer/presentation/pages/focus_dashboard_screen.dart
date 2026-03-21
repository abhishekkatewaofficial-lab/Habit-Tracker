import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:habit_tracker_ios/features/focus_timer/data/models/focus_item.dart';
import 'package:habit_tracker_ios/features/focus_timer/presentation/controllers/focus_dashboard_controller.dart';

class FocusDashboardScreen extends ConsumerStatefulWidget {
  const FocusDashboardScreen({super.key});

  @override
  ConsumerState<FocusDashboardScreen> createState() => _FocusDashboardScreenState();
}

class _FocusDashboardScreenState extends ConsumerState<FocusDashboardScreen> {
  void _showAddModal() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const _AddFocusModal();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10 * animation.value,
            sigmaY: 10 * animation.value,
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double scale = 1.0 + (0.03 * animValue);
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final focusItems = ref.watch(focusDashboardProvider);
    final h = MediaQuery.of(context).size.height;
    final topGap = h * 0.04;

    return Scaffold(
      backgroundColor: Colors.transparent, // rely on parent
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110), // Sub-dock clearance (88px) + 22px
        child: _ScaleOnTap(
          onTap: _showAddModal,
          child: FloatingActionButton(
            heroTag: 'focus_fab',
            onPressed: null, // handled by _ScaleOnTap
            backgroundColor: const Color(0xFF34C759), // Premium Soft Green
            elevation: 8,
            shape: const CircleBorder(),
            child: const Icon(CupertinoIcons.add, color: Colors.white, size: 28),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(20, topGap, 20, 24),
              child: Center(
                child: Text(
                  'Focus',
                  style: GoogleFonts.greatVibes(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D264B),
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: focusItems.isEmpty
                  ? _buildEmptyState()
                  : Theme(
                      data: Theme.of(context).copyWith(
                        canvasColor: Colors.transparent, // Prevents white background during drag
                      ),
                      child: ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8)
                            .copyWith(bottom: 120),
                        itemCount: focusItems.length,
                        buildDefaultDragHandles: false,
                        proxyDecorator: _proxyDecorator,
                        onReorder: (oldIndex, newIndex) {
                          ref.read(focusDashboardProvider.notifier).reorderFocus(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final item = focusItems[index];
                          return _FocusCard(
                            key: ValueKey(item.id),
                            item: item,
                            index: index,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              CupertinoIcons.sparkles,
              size: 50,
              color: Color(0xFFB0BEC5), // Soft greyish blue
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No focus sessions yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2D264B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first focus',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Focus Card ───────────────────────────────────────────────────────────────

class _FocusCard extends ConsumerStatefulWidget {
  final FocusItem item;
  final int index;
  const _FocusCard({super.key, required this.item, required this.index});

  @override
  ConsumerState<_FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends ConsumerState<_FocusCard>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (mounted) {
        setState(() {
          _updateElapsed();
        });
      }
    });
    
    // Initial sync
    _updateElapsed();
    
    if (widget.item.isRunning) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant _FocusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.isRunning != oldWidget.item.isRunning) {
      if (widget.item.isRunning) {
        if (!_ticker.isTicking) _ticker.start();
      } else {
        if (_ticker.isTicking) _ticker.stop();
      }
    }
    _updateElapsed();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _updateElapsed() {
    _elapsed = Duration(milliseconds: widget.item.currentElapsedMs);
  }

  String _formatTime(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  void _showDeleteDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Focus?'),
        content: const Text(
            'This removes it from the dashboard, but your past daily log history will remain intact.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              ref.read(focusDashboardProvider.notifier).deleteFocus(widget.item.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = widget.item.isRunning;
    
    // Active → Highlighted soft green. Inactive → Soft grey
    final bgColor = isActive 
        ? const Color(0xFFE8F5E9) // Soft premium light green
        : Colors.white;
    
    final borderColor = isActive
        ? const Color(0xFFA5D6A7) // Soft green border
        : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(widget.item.id),
        endActionPane: ActionPane(
          extentRatio: 0.25,
          motion: const DrawerMotion(),
          children: [
            CustomSlidableAction(
              onPressed: (context) => _showDeleteDialog(),
              backgroundColor: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: CupertinoColors.destructiveRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const Icon(CupertinoIcons.delete, color: Colors.white),
              ),
            ),
          ],
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFFA5D6A7).withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                )
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Row(
        children: [
          // Name
          Expanded(
            flex: 3,
            child: Text(
              widget.item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: const Color(0xFF2D264B),
              ),
            ),
          ),
          
          // Time Box
          Expanded(
            flex: 4,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.spaceMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isActive ? const Color(0xFF388E3C) : const Color(0xFF2D264B),
                  letterSpacing: -0.5,
                ),
                child: Text(_formatTime(_elapsed)),
              ),
            ),
          ),

          // Controls
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () {
                    if (isActive) {
                      ref.read(focusDashboardProvider.notifier).pauseFocus(widget.item.id);
                    } else {
                      ref.read(focusDashboardProvider.notifier).startFocus(widget.item.id);
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? const Color(0xFF388E3C) : const Color(0xFFE0E0E0),
                    ),
                    child: Icon(
                      isActive ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                      color: isActive ? Colors.white : Colors.grey.shade600,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ReorderableDragStartListener(
                  index: widget.index,
                  child: Icon(
                    CupertinoIcons.line_horizontal_3,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
      ),
    );
  }
}

// ── Add Modal ────────────────────────────────────────────────────────────────

class _AddFocusModal extends ConsumerStatefulWidget {
  const _AddFocusModal();

  @override
  ConsumerState<_AddFocusModal> createState() => _AddFocusModalState();
}

class _AddFocusModalState extends ConsumerState<_AddFocusModal> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      ref.read(focusDashboardProvider.notifier).addFocus(text);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'New Focus',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D264B),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: const Color(0xFF2D264B),
                ),
                decoration: InputDecoration(
                  hintText: 'e.g., DSA, Reading...',
                  hintStyle: GoogleFonts.poppins(
                    color: Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: CupertinoColors.destructiveRed.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.destructiveRed,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF2D264B),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
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

