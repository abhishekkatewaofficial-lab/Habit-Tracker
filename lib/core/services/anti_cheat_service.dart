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

  /// Rigorously calculate the time state based strictly off centralized UTC metrics.
  /// Bypasses trivial timezone spoofing exploits natively.
  ///
  /// [targetDateStr]  — the YYYY-MM-DD key for the specific habit entry being evaluated.
  /// [habitStartDate] — the habit's own start date (from `habit.startDate`).
  ///                   When provided, any date BEFORE this value immediately returns
  ///                   [HabitEntryState.preStart], short-circuiting all anti-cheat logic.
  static HabitEntryState getEntryState(
    String targetDateStr, {
    DateTime? habitStartDate,
  }) {
    // ── PRIORITY RULE 0: Pre-Start Gate ──────────────────────────────────────
    // This must always be evaluated FIRST and overrides every other state.
    // A date before the habit's creation day is invisible to the system.
    if (habitStartDate != null) {
      DateTime targetDateLocal;
      try {
        final parts = targetDateStr.split('-');
        targetDateLocal = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      } catch (_) {
        return HabitEntryState.preStart;
      }

      // Normalize habitStartDate to midnight for pure calendar-day comparison
      final startMidnight = DateTime(
        habitStartDate.year,
        habitStartDate.month,
        habitStartDate.day,
      );

      if (targetDateLocal.isBefore(startMidnight)) {
        return HabitEntryState.preStart;
      }
    }

    // ── ANTI-CHEAT ENGINE (UTC-safe) ─────────────────────────────────────────
    final nowUtc = DateTime.now().toUtc();

    DateTime targetDateUtc;
    try {
      final parts = targetDateStr.split('-');
      // Binds the localized YYYY-MM-DD uniformly to a rigid UTC day start
      targetDateUtc = DateTime.utc(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      // Structural fallback ensures no cheating bypass through string injection
      return HabitEntryState.lockedFinal;
    }

    // Absolute Day End boundary (UTC midnight + 24 hours)
    final targetEndOfDayUtc = targetDateUtc.add(const Duration(hours: 24));

    // 1. Future Blockage: Time travel forward
    if (nowUtc.isBefore(targetDateUtc)) {
      return HabitEntryState.future;
    }

    // 2. Active "Today" state
    if (nowUtc.isBefore(targetEndOfDayUtc)) {
      return HabitEntryState.editable;
    }

    // 3. The Grace Window Extension (rolling calculate the exact delta)
    final diffHours = nowUtc.difference(targetEndOfDayUtc).inHours;
    if (diffHours <= gracePeriodHours) {
      return HabitEntryState.grace;
    }

    // 4. Default: The window has officially expired permanently.
    return HabitEntryState.lockedFinal;
  }
}
