import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import '../../data/models/eisenhower_task.dart';
import '../../data/repositories/eisenhower_repository.dart';
import 'package:habit_tracker_ios/core/services/auth_service.dart';

import 'package:habit_tracker_ios/core/services/firestore_sync_service.dart';

final eisenhowerRepositoryProvider = Provider<EisenhowerRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return EisenhowerRepository(HiveService.eisenhowerBox);
});

final eisenhowerControllerProvider = StateNotifierProvider<EisenhowerController, List<EisenhowerTask>>((ref) {
  final repository = ref.watch(eisenhowerRepositoryProvider);
  if (repository == null) return EisenhowerController._empty();
  
  final controller = EisenhowerController(repository);
  ref.listen(syncRefreshProvider, (prev, next) {
    controller.reloadFromHive();
  });
  return controller;
});

class EisenhowerController extends StateNotifier<List<EisenhowerTask>> {
  final EisenhowerRepository? _repository;

  EisenhowerController(this._repository) : super([]) {
    _loadTasks();
  }
  
  void reloadFromHive() => _loadTasks();
  
  EisenhowerController._empty() : _repository = null, super([]);

  void _loadTasks() {
    if (_repository == null) return;
    state = _repository!.getAllTasks();
  }

  Future<void> addTask(String title, QuadrantType quadrant, {DateTime? dueDate, int priority = 2}) async {
    if (_repository == null) return;
    final task = EisenhowerTask(
      title: title,
      quadrant: quadrant,
      dueDate: dueDate,
      priority: priority,
    );
    await _repository!.saveTask(task);
    state = [...state, task];
    FirestoreSyncService.pushEisenhowerTask(task);
  }

  Future<void> updateTask(EisenhowerTask task) async {
    if (_repository == null) return;
    await _repository!.updateTask(task);
    state = [
      for (final t in state)
        if (t.id == task.id) task else t
    ];
    FirestoreSyncService.pushEisenhowerTask(task);
  }

  Future<void> deleteTask(String id) async {
    if (_repository == null) return;
    await _repository!.deleteTask(id);
    state = state.where((t) => t.id != id).toList();
    FirestoreSyncService.deleteEisenhowerTask(id);
  }

  Future<void> moveTask(String id, QuadrantType newQuadrant) async {
    if (_repository == null) return;
    final taskIndex = state.indexWhere((t) => t.id == id);
    if (taskIndex != -1) {
      final updatedTask = state[taskIndex].copyWith(quadrant: newQuadrant);
      await _repository!.updateTask(updatedTask);
      state = [
        for (final t in state)
          if (t.id == id) updatedTask else t
      ];
      FirestoreSyncService.pushEisenhowerTask(updatedTask);
    }
  }

  List<EisenhowerTask> getTasksForQuadrant(QuadrantType quadrant) {
    return state.where((t) => t.quadrant == quadrant).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> toggleComplete(String id) async {
    if (_repository == null) return;
    final taskIndex = state.indexWhere((t) => t.id == id);
    if (taskIndex != -1) {
      final toggled = state[taskIndex].copyWith(isCompleted: !state[taskIndex].isCompleted);
      await _repository!.updateTask(toggled);
      state = [
        for (final t in state)
          if (t.id == id) toggled else t
      ];
      FirestoreSyncService.pushEisenhowerTask(toggled);
    }
  }
}
