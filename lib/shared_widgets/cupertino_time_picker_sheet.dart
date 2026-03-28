import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/settings_provider.dart';

/// A premium iOS-style wheel time picker bottom sheet.
/// Replaces the standard Material time picker with a Cupertino wheel experience.
Future<TimeOfDay?> showCupertinoTimePickerSheet({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 400),
    ),
    builder: (context) => _CupertinoTimePickerBottomSheet(
      initialTime: initialTime,
      isDark: isDark,
    ),
  );
}

class _CupertinoTimePickerBottomSheet extends ConsumerStatefulWidget {
  final TimeOfDay initialTime;
  final bool isDark;

  const _CupertinoTimePickerBottomSheet({
    required this.initialTime,
    required this.isDark,
  });

  @override
  ConsumerState<_CupertinoTimePickerBottomSheet> createState() =>
      _CupertinoTimePickerBottomSheetState();
}

class _CupertinoTimePickerBottomSheetState
    extends ConsumerState<_CupertinoTimePickerBottomSheet> {
  late int _selectedHour;
  late int _selectedMinute;
  late int _selectedAmPm; // 0 for AM, 1 for PM

  @override
  void initState() {
    super.initState();
    int hour = widget.initialTime.hour;
    _selectedAmPm = hour >= 12 ? 1 : 0;
    _selectedHour = hour % 12;
    if (_selectedHour == 0) _selectedHour = 12;
    _selectedMinute = widget.initialTime.minute;
  }

  void _triggerFeedback() {
    final hapticsOn = ref.read(hapticsProvider);
    final soundsOn = ref.read(soundsProvider);

    if (hapticsOn) {
      HapticFeedback.selectionClick();
    }
    
    if (soundsOn) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Light: #FAFAFA, Dark: #000000
    final bgColor = widget.isDark ? const Color(0xFF000000) : const Color(0xFFFAFAFA);
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1A1A1A);
    final highlightColor = widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05);

    // Confirm Button Styling
    final btnBgColor = widget.isDark ? const Color(0xFF1C1C1E) : const Color(0xFF34C759); // iOS Green
    final btnTextColor = Colors.white;
    final btnBorder = widget.isDark 
        ? Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1) 
        : null;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.grey[800] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              'Select Time',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            
            // Premium Spaced Picker
            Container(
              height: 240,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Hour Picker
                  Expanded(
                    child: _buildPicker(
                      itemCount: 12,
                      initialIndex: _selectedHour - 1,
                      onChanged: (index) {
                        _triggerFeedback();
                        setState(() => _selectedHour = index + 1);
                      },
                      itemBuilder: (context, i) => _buildPickerItem(context, '${i + 1}', textColor),
                      highlightColor: highlightColor,
                    ),
                  ),
                  
                  const SizedBox(width: 20), // Premium Gap
                  
                  // Minute Picker
                  Expanded(
                    child: _buildPicker(
                      itemCount: 60,
                      initialIndex: _selectedMinute,
                      onChanged: (index) {
                        _triggerFeedback();
                        setState(() => _selectedMinute = index);
                      },
                      itemBuilder: (context, i) => _buildPickerItem(context, i.toString().padLeft(2, '0'), textColor),
                      highlightColor: highlightColor,
                    ),
                  ),
                  
                  const SizedBox(width: 20), // Premium Gap
                  
                  // AM/PM Picker
                  Expanded(
                    child: _buildPicker(
                      itemCount: 2,
                      initialIndex: _selectedAmPm,
                      onChanged: (index) {
                        _triggerFeedback();
                        setState(() => _selectedAmPm = index);
                      },
                      itemBuilder: (context, i) => _buildPickerItem(context, i == 0 ? 'AM' : 'PM', textColor),
                      highlightColor: highlightColor,
                    ),
                  ),
                ],
              ),
            ),
            
            // Confirm Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: GestureDetector(
                onTap: () {
                  int finalHour = _selectedHour;
                  if (_selectedAmPm == 1 && finalHour < 12) finalHour += 12;
                  if (_selectedAmPm == 0 && finalHour == 12) finalHour = 0;
                  
                  Navigator.pop(
                    context,
                    TimeOfDay(hour: finalHour, minute: _selectedMinute),
                  );
                },
                child: Container(
                  height: 56,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: btnBgColor,
                    borderRadius: BorderRadius.circular(28),
                    border: btnBorder,
                    boxShadow: !widget.isDark ? [
                      BoxShadow(
                        color: btnBgColor.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ] : [],
                  ),
                  child: Text(
                    'Confirm',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: btnTextColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPicker({
    required int itemCount,
    required int initialIndex,
    required ValueChanged<int> onChanged,
    required IndexedWidgetBuilder itemBuilder,
    required Color highlightColor,
  }) {
    return CupertinoPicker.builder(
      scrollController: FixedExtentScrollController(initialItem: initialIndex),
      itemExtent: 44,
      onSelectedItemChanged: onChanged,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
        background: highlightColor,
        capEndEdge: true,
        capStartEdge: true,
      ),
      childCount: itemCount,
      itemBuilder: (context, index) => itemBuilder(context, index),
    );
  }

  Widget _buildPickerItem(BuildContext context, String text, Color color) {
    return Center(
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
