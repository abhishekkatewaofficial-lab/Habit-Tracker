import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/services/settings_provider.dart';

/// A premium iOS-style wheel date picker bottom sheet.
/// Replaces the standard Material date picker with a Cupertino wheel experience.
Future<DateTime?> showCupertinoDatePickerSheet({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 400),
    ),
    builder: (context) => _CupertinoDatePickerBottomSheet(
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2040),
      isDark: isDark,
    ),
  );
}

class _CupertinoDatePickerBottomSheet extends ConsumerStatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool isDark;

  const _CupertinoDatePickerBottomSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.isDark,
  });

  @override
  ConsumerState<_CupertinoDatePickerBottomSheet> createState() =>
      _CupertinoDatePickerBottomSheetState();
}

class _CupertinoDatePickerBottomSheetState
    extends ConsumerState<_CupertinoDatePickerBottomSheet> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
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
    // Light: #FAFAFA, Dark: #000000 or #121212
    final bgColor = widget.isDark ? const Color(0xFF000000) : const Color(0xFFFAFAFA);
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1A1A1A);
    
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
            
            // Header with Cancel Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: widget.isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ),
                  Text(
                    'Select Date',
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 60), // Space for balancing
                ],
              ),
            ),
            
            // Picker
            Container(
              height: 240,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: GoogleFonts.poppins(
                      fontSize: 22,
                      color: textColor,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selectedDate,
                  minimumDate: widget.firstDate,
                  maximumDate: widget.lastDate,
                  onDateTimeChanged: (DateTime newDate) {
                    _triggerFeedback();
                    setState(() {
                      _selectedDate = newDate;
                    });
                  },
                ),
              ),
            ),
            
            // Confirm Button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: GestureDetector(
                onTap: () => Navigator.pop(context, _selectedDate),
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
}
