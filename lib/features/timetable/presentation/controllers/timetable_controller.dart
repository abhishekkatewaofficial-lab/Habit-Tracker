import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:habit_tracker_ios/core/services/auth_service.dart';
import 'package:habit_tracker_ios/core/services/firestore_sync_service.dart';
import '../../data/models/time_block.dart';
import '../../data/repositories/timetable_repository.dart';

// ── Date helper ──────────────────────────────────────────────────────────────
String _dateKey(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

// ── Repository provider ───────────────────────────────────────────────────────
final timetableRepositoryProvider = Provider<TimetableRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return TimetableRepository();
});

// ── Selected date provider ────────────────────────────────────────────────────
final timetableDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// ── Main controller provider ──────────────────────────────────────────────────
final timetableControllerProvider =
    StateNotifierProvider<TimetableController, List<TimeBlock>>((ref) {
  final repository = ref.watch(timetableRepositoryProvider);
  if (repository == null) return TimetableController._empty();

  final controller = TimetableController(repository, ref);

  // Reload from Hive when cloud sync fires
  ref.listen(syncRefreshProvider, (_, __) {
    debugPrint('📅 timetable: sync refresh fired → reloading');
    controller.reloadFromHive();
  });

  // Reload when the selected date changes
  ref.listen(timetableDateProvider, (_, __) {
    debugPrint('📅 timetable: date changed → reloading');
    controller.reloadFromHive();
  });

  return controller;
});

// ── Controller ────────────────────────────────────────────────────────────────
class TimetableController extends StateNotifier<List<TimeBlock>> {
  final TimetableRepository? _repository;
  final Ref? _ref;

  TimetableController(TimetableRepository repository, Ref ref)
      : _repository = repository,
        _ref = ref,
        super([]) {
    _load();
  }

  TimetableController._empty()
      : _repository = null,
        _ref = null,
        super([]);

  String get _currentDateKey {
    final date = _ref?.read(timetableDateProvider) ?? DateTime.now();
    return _dateKey(date);
  }

  void _load() {
    if (_repository == null) return;
    final date = _currentDateKey;
    final blocks = _repository.getBlocksForDate(date);
    debugPrint('📅 timetable _load(): date=$date found=${blocks.length} blocks');
    state = blocks;
  }

  void reloadFromHive() => _load();

  Future<void> addBlock(TimeBlock block) async {
    if (_repository == null) return;
    // ① Optimistic update — show immediately
    state = [...state, block]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    debugPrint('📅 timetable: optimistic add "${block.title}"');
    // ② Persist to Hive + push to Firestore
    await _repository.saveBlock(block);
    // ③ Reload from Hive to confirm
    _load();
  }

  Future<void> updateBlock(TimeBlock block) async {
    if (_repository == null) return;
    // Optimistic update
    state = [
      for (final b in state) (b.id == block.id ? block : b),
    ]..sort((a, b) => a.startTime.compareTo(b.startTime));
    await _repository.saveBlock(block);
    _load();
  }

  Future<void> deleteBlock(String id) async {
    if (_repository == null) return;
    // Optimistic update
    state = state.where((b) => b.id != id).toList();
    await _repository.deleteBlock(id);
    _load();
  }

  Future<void> toggleComplete(String id) async {
    if (_repository == null) return;
    final idx = state.indexWhere((b) => b.id == id);
    if (idx == -1) return;
    final updated = state[idx].copyWith(isCompleted: !state[idx].isCompleted);
    // Optimistic update
    state = [
      for (final b in state) (b.id == id ? updated : b),
    ];
    await _repository.saveBlock(updated);
    _load();
  }

  Future<void> clearCurrentDate() async {
    if (_repository == null) return;
    final blocksToDelete = List.from(state);
    
    // Optimistic update
    state = [];
    
    for (var b in blocksToDelete) {
      await _repository.deleteBlock(b.id);
    }
    _load();
  }
}
