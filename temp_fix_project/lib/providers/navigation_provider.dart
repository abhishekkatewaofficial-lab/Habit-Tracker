import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks the currently selected bottom-nav index.
final navigationIndexProvider = StateProvider<int>((ref) => 0);

/// Tracks if the bottom dock is currently in Planner Sub-Dock mode.
final plannerModeProvider = StateProvider<bool>((ref) => false);

/// Tracks if the bottom dock is currently in Focus Sub-Dock mode.
final focusModeProvider = StateProvider<bool>((ref) => false);
