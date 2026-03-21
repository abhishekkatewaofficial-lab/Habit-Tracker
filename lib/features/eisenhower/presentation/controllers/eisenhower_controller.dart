import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker_ios/core/services/hive_service.dart';
import '../../data/models/eisenhower_task.dart';
import '../../data/repositories/eisenhower_repository.dart';

final eisenhowerRepositoryProvider = Provider<EisenhowerRepository>((ref) {
  return EisenhowerRepository(HiveService.eisenhowerBox);
});

final eisenhowerControllerProvider = StateNotifierProvider<EisenhowerController, List<EisenhowerTask>>((ref) {
  final repository = ref.watch(eisenhowerRepositoryProvider);
  return EisenhowerController(repository);
});

class EisenhowerController extends StateNotifier<List<EisenhowerTask>> {
  final EisenhowerRepository _repository;

  EisenhowerController(this._repository) : super([]) {
    _loadTasks();
  }

  void _loadTasks() {
    state = _repository.getAllTasks();
  }

  Future<void> addTask(String title, QuadrantType quadrant, {DateTime? dueDate, int priority = 2}) async {
    final task = EisenhowerTask(
      title: title,
      quadrant: quadrant,
      dueDate: dueDate,
      priority: priority,
    );
    await _repository.saveTask(task);
    state = [...state, task];
  }

  Future<void> updateTask(EisenhowerTask task) async {
    await _repository.updateTask(task);
    state = [
      for (final t in state)
        if (t.id == task.id) task else t
    ];
  }

  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
    state = state.where((t) => t.id != id).toList();
  }

  Future<void> moveTask(String id, QuadrantType newQuadrant) async {
    final taskIndex = state.indexWhere((t) => t.id == id);
    if (taskIndex != -1) {
      final updatedTask = state[taskIndex].copyWith(quadrant: newQuadrant);
      await _repository.updateTask(updatedTask);
      state = [
        for (final t in state)
          if (t.id == id) updatedTask else t
      ];
    }
  }

  List<EisenhowerTask> getTasksForQuadrant(QuadrantType quadrant) {
    return state.where((t) => t.quadrant == quadrant).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> toggleComplete(String id) async {
    final taskIndex = state.indexWhere((t) => t.id == id);
    if (taskIndex != -1) {
      final toggled = state[taskIndex].copyWith(isCompleted: !state[taskIndex].isCompleted);
      await _repository.updateTask(toggled);
      state = [
        for (final t in state)
          if (t.id == id) toggled else t
      ];
    }
  }
}
