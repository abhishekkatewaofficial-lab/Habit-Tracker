import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/features/focus_timer/data/models/focus_session.dart';
import 'package:habit_tracker_ios/features/focus_timer/data/repositories/focus_repository.dart';

final focusRepositoryProvider = Provider<FocusRepository>((ref) {
  return FocusRepository();
});

class FocusSessionsNotifier extends StateNotifier<List<FocusSession>> {
  final FocusRepository _repository;

  FocusSessionsNotifier(this._repository) : super([]) {
    _loadSessions();
  }

  void _loadSessions() {
    state = _repository.getAllSessions();
  }

  Future<void> addSession(FocusSession session) async {
    await _repository.saveSession(session);
    _loadSessions();
  }

  Future<void> deleteSession(String id) async {
    await _repository.deleteSession(id);
    _loadSessions();
  }
}

final focusSessionsProvider = StateNotifierProvider<FocusSessionsNotifier, List<FocusSession>>((ref) {
  final repository = ref.watch(focusRepositoryProvider);
  return FocusSessionsNotifier(repository);
});
