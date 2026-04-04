/// Live-tracking model for a named Focus session.
class FocusItem {
  final String id;
  final String name;
  final bool isRunning;
  final int? startTimeMs; // epoch millis when last started (null if paused)
  final int accumulatedMs; // total ms TODAY before current run
  final String lastResetDate; // 'yyyy-MM-dd' — used to detect midnight crossing
  final int sortOrder;
  final int lastNotifiedHour; // tracks spam prevention

  const FocusItem({
    required this.id,
    required this.name,
    this.isRunning = false,
    this.startTimeMs,
    this.accumulatedMs = 0,
    required this.lastResetDate,
    this.sortOrder = 0,
    this.lastNotifiedHour = 0,
  });

  FocusItem copyWith({
    String? id,
    String? name,
    bool? isRunning,
    Object? startTimeMs = _sentinel,
    int? accumulatedMs,
    String? lastResetDate,
    int? sortOrder,
    int? lastNotifiedHour,
  }) {
    return FocusItem(
      id: id ?? this.id,
      name: name ?? this.name,
      isRunning: isRunning ?? this.isRunning,
      startTimeMs: startTimeMs == _sentinel
          ? this.startTimeMs
          : startTimeMs as int?,
      accumulatedMs: accumulatedMs ?? this.accumulatedMs,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      sortOrder: sortOrder ?? this.sortOrder,
      lastNotifiedHour: lastNotifiedHour ?? this.lastNotifiedHour,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isRunning': isRunning,
        'startTimeMs': startTimeMs,
        'accumulatedMs': accumulatedMs,
        'lastResetDate': lastResetDate,
        'sortOrder': sortOrder,
        'lastNotifiedHour': lastNotifiedHour,
      };

  factory FocusItem.fromJson(Map<dynamic, dynamic> json) => FocusItem(
        id: json['id'] as String,
        name: json['name'] as String,
        isRunning: json['isRunning'] as bool? ?? false,
        startTimeMs: json['startTimeMs'] as int?,
        accumulatedMs: json['accumulatedMs'] as int? ?? 0,
        lastResetDate: json['lastResetDate'] as String? ?? _todayStr(),
        sortOrder: json['sortOrder'] as int? ?? 0,
        lastNotifiedHour: json['lastNotifiedHour'] as int? ?? 0,
      );

  /// Current elapsed milliseconds including live running time.
  int get currentElapsedMs {
    if (isRunning && startTimeMs != null) {
      return accumulatedMs +
          (DateTime.now().millisecondsSinceEpoch - startTimeMs!);
    }
    return accumulatedMs;
  }
}

// Sentinel for optional null in copyWith
const Object _sentinel = Object();

String _todayStr() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}
