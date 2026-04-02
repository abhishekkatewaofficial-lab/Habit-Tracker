import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedometer/pedometer.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';

// ─── Keys ────────────────────────────────────────────────────────────────────

const _kPermissionKey = 'stepPermissionGranted';
const _kManualOverrideDateKey = 'stepManualOverrideDate_'; // + habitId

// ─── Step Permission State ────────────────────────────────────────────────────

/// Tri-state representing the Motion permission lifecycle.
enum StepPermissionState {
  /// User hasn't seen the request yet.
  notDetermined,
  /// OS permission granted and pedometer is available.
  granted,
  /// User denied the OS permission OR sensor unavailable.
  denied,
}

class StepPermissionNotifier extends Notifier<StepPermissionState> {
  static const _grantedValue = 'granted';
  static const _deniedValue = 'denied';

  @override
  StepPermissionState build() {
    final stored = HiveService.settingsBox.get(_kPermissionKey) as String?;
    if (stored == _grantedValue) return StepPermissionState.granted;
    if (stored == _deniedValue) return StepPermissionState.denied;
    return StepPermissionState.notDetermined;
  }

  void markGranted() {
    state = StepPermissionState.granted;
    HiveService.settingsBox.put(_kPermissionKey, _grantedValue);
  }

  void markDenied() {
    state = StepPermissionState.denied;
    HiveService.settingsBox.put(_kPermissionKey, _deniedValue);
  }

  void reset() {
    state = StepPermissionState.notDetermined;
    HiveService.settingsBox.delete(_kPermissionKey);
  }
}

final stepPermissionProvider =
    NotifierProvider<StepPermissionNotifier, StepPermissionState>(() {
  return StepPermissionNotifier();
});

// ─── Today's Step Count ───────────────────────────────────────────────────────

/// Holds the raw step count fetched once per foreground session.
/// `null` = not yet fetched / unavailable.
final todayStepCountProvider = StateProvider<int?>((ref) => null);

// ─── Step Tracking Service ────────────────────────────────────────────────────

class StepTrackingService {
  StepTrackingService._();

  /// Call this once when the app is foregrounded (or at first init).
  /// Reads the current step count from the pedometer.
  /// Returns the value (also stored in [todayStepCountProvider]).
  static Future<int?> fetchTodaySteps(WidgetRef ref) async {
    final permission = ref.read(stepPermissionProvider);
    if (permission != StepPermissionState.granted) return null;

    try {
      // `stepCountStream` emits an event immediately with the current cumulative
      // step count since the last device reboot.
      // We calculate "steps today" by persisting a "midnight baseline" in Hive.
      final stepEvent = await Pedometer.stepCountStream.first;
      final cumulativeSteps = stepEvent.steps;

      // Baseline management: reset baseline every new calendar day.
      final todayStr = _todayStr();
      final storedDate = HiveService.settingsBox.get('stepBaselineDate') as String?;
      int baseline = 0;

      if (storedDate == todayStr) {
        // Same day — use stored baseline
        baseline = HiveService.settingsBox.get('stepBaseline') as int? ?? cumulativeSteps;
      } else {
        // New day — reset baseline to current cumulative
        baseline = cumulativeSteps;
        HiveService.settingsBox.put('stepBaselineDate', todayStr);
        HiveService.settingsBox.put('stepBaseline', baseline);
      }

      // Steps today = difference from midnight baseline
      // Guard against negative (device reboot mid-day resets the counter)
      final stepsToday = (cumulativeSteps - baseline).clamp(0, 999999);
      ref.read(todayStepCountProvider.notifier).state = stepsToday;
      return stepsToday;
    } catch (_) {
      // Sensor unavailable (simulator, old device, denied at OS level post-grant)
      ref.read(stepPermissionProvider.notifier).markDenied();
      ref.read(todayStepCountProvider.notifier).state = null;
      return null;
    }
  }

  // ─── Manual Override Helpers ────────────────────────────────────────────────

  /// Returns true if the user manually entered steps for [habitId] today,
  /// meaning auto-fill should NOT overwrite the stored progress.
  static bool hasManualOverrideToday(String habitId) {
    final stored = HiveService.settingsBox.get('$_kManualOverrideDateKey$habitId') as String?;
    return stored == _todayStr();
  }

  /// Record that the user manually set progress for [habitId] today.
  static void markManualOverride(String habitId) {
    HiveService.settingsBox.put('$_kManualOverrideDateKey$habitId', _todayStr());
  }

  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
