/// The strict evaluation state of any single habit progress square.
enum HabitEntryState {
  preStart,      // Date is before the habit's own startDate — neutral, no interaction
  future,        // Dates ahead of the exact UTC threshold bounds
  editable,      // Today's actively manipulable habits
  grace,         // In the configurable expiration rolling window
  lockedFinal    // Mathematically expired. Read-only.
}

/// A pure mathematical time isolation engine protecting habit integrity.
class AntiCheatService {
  /// Defines how many hours an entry is allowed to be modified AFTER the physical day ends.
  static const int gracePeriodHours = 48;

  /// Helper to strictly strip off time components for pure local calendar date comparison.
  static DateTime normalize(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Calculates the time state based purely off normalized local time boundaries.
  /// Bypasses timezone overlap by strictly clamping to user conscious dates.
  ///
  /// [targetDateStr]  — the YYYY-MM-DD key for the specific habit entry being evaluated.
  /// [habitStartDate] — the habit's own start date (from `habit.startDate`).
  ///                   When provided, any date BEFORE this value immediately returns
  ///                   [HabitEntryState.preStart], short-circuiting all anti-cheat logic.
  static HabitEntryState getEntryState(
    String targetDateStr, {
    DateTime? habitStartDate,
  }) {
    // Shared Local Target Initialization
    DateTime targetDateLocal;
    try {
      final parts = targetDateStr.split('-');
      targetDateLocal = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      // Structural fallback ensures no cheating bypass through string injection
      return HabitEntryState.lockedFinal;
    }

    // ── PRIORITY RULE 0: Pre-Start Gate ──────────────────────────────────────
    // This must always be evaluated FIRST and overrides every other state.
    // A date before the habit's creation day is invisible to the system.
    if (habitStartDate != null) {

      // Normalize habitStartDate to pure calendar-day comparison
      final startMidnight = normalize(habitStartDate);

      if (targetDateLocal.isBefore(startMidnight)) {
        return HabitEntryState.preStart;
      }
    }

    // ── ANTI-CHEAT ENGINE (Local Normalized) ───────────────────────────────
    final normalizedTarget = normalize(targetDateLocal);
    final today = normalize(DateTime.now());

    // 1. Future Blockage: Prevent clicking strictly ahead of today
    if (normalizedTarget.isAfter(today)) {
      return HabitEntryState.future;
    }

    // 2. Active "Today" state
    if (normalizedTarget.isAtSameMomentAs(today)) {
      return HabitEntryState.editable;
    }

    // 3. The Grace Window Extension
    // Fall back to a standard duration delta natively against the local day termination boundary
    final nowLocal = DateTime.now();
    final targetEndOfDayLocal = DateTime(
      targetDateLocal.year,
      targetDateLocal.month,
      targetDateLocal.day,
      23, 59, 59, // Exactly when the day physically ended locally
    );
    
    final diffHours = nowLocal.difference(targetEndOfDayLocal).inHours;
    if (diffHours <= gracePeriodHours) {
      return HabitEntryState.grace;
    }

    // 4. Default: The window has officially expired permanently.
    return HabitEntryState.lockedFinal;
  }
}
