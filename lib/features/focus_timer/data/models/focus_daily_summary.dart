/// Immutable daily snapshot of total focus seconds.
/// Stored independently so deleting a FocusItem never affects history.
class FocusDailySummary {
  final String date; // 'yyyy-MM-dd'
  final int totalSeconds;
  final Map<String, int> focusDurations; // focusName -> total seconds

  const FocusDailySummary({
    required this.date,
    required this.totalSeconds,
    this.focusDurations = const {},
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'totalSeconds': totalSeconds,
        'focusDurations': focusDurations,
      };

  factory FocusDailySummary.fromJson(Map<dynamic, dynamic> json) {
    Map<String, int> parsedDurations = {};
    if (json['focusDurations'] != null) {
      final dynMap = json['focusDurations'] as Map;
      parsedDurations = dynMap.map((key, value) => MapEntry(key.toString(), value as int));
    }
    
    return FocusDailySummary(
      date: json['date'] as String,
      totalSeconds: json['totalSeconds'] as int? ?? 0,
      focusDurations: parsedDurations,
    );
  }

  /// Rounded hours using the spec rule:
  /// < 30 min → 0h, ≥ 30 min → ceil(seconds / 3600)
  int get roundedHours {
    if (totalSeconds < 1800) return 0;
    return (totalSeconds / 3600).ceil();
  }
}
