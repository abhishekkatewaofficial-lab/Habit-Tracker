import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/hive_service.dart';
import '../../../../core/services/firestore_sync_service.dart';
import '../../data/models/todo_category.dart';
import '../../data/models/todo_task.dart';
import '../../data/repositories/todo_repository.dart';
import '../../../../core/services/auth_service.dart';

final todoRepositoryProvider = Provider<TodoRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return TodoRepository(HiveService.todoBox);
});

final todoControllerProvider = StateNotifierProvider<TodoController, List<TodoCategory>>((ref) {
  final repository = ref.watch(todoRepositoryProvider);
  if (repository == null) return TodoController._empty();
  final notifier = TodoController(repository);
  // Reload from Hive whenever cloud pull completes
  ref.listen(syncRefreshProvider, (_, __) => notifier.reloadFromHive());
  return notifier;
});

class TodoController extends StateNotifier<List<TodoCategory>> {
  final TodoRepository? _repository;

  TodoController(this._repository) : super(_repository!.getAllCategories());
  
  TodoController._empty() : _repository = null, super([]);

  /// Public reload — called after cloud pull hydration to refresh UI from Hive.
  void reloadFromHive() {
    if (_repository != null) state = _repository!.getAllCategories();
  }

  // --- Category Actions ---

  Future<void> addCategory(TodoCategory category) async {
    if (_repository == null) return;
    await _repository!.saveCategory(category);
    state = [...state, category];
    FirestoreSyncService.pushTodo(category);
  }

  Future<void> updateCategory(TodoCategory category) async {
    if (_repository == null) return;
    await _repository!.saveCategory(category);
    state = [
      for (final cat in state)
        if (cat.id == category.id) category else cat
    ];
    FirestoreSyncService.pushTodo(category);
  }

  Future<void> deleteCategory(String id) async {
    if (_repository == null) return;
    await _repository!.deleteCategory(id);
    state = state.where((cat) => cat.id != id).toList();
    FirestoreSyncService.deleteTodo(id);
  }

  // --- Task Actions ---

  Future<void> addTask(String categoryId, String title) async {
    final catIndex = state.indexWhere((c) => c.id == categoryId);
    if (catIndex == -1) return;

    final category = state[catIndex];
    final newTask = TodoTask(title: title);
    final updatedCategory = category.copyWith(
      tasks: [...category.tasks, newTask],
    );

    await updateCategory(updatedCategory);
  }

  Future<void> toggleTask(String categoryId, String taskId) async {
    final catIndex = state.indexWhere((c) => c.id == categoryId);
    if (catIndex == -1) return;

    final category = state[catIndex];
    final updatedTasks = [
      for (final task in category.tasks)
        if (task.id == taskId)
          task.copyWith(isCompleted: !task.isCompleted)
        else
          task
    ];

    // Sort: Incomplete first, then completed by creation date
    updatedTasks.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    final updatedCategory = category.copyWith(tasks: updatedTasks);
    await updateCategory(updatedCategory);
  }

  Future<void> deleteTask(String categoryId, String taskId) async {
    final catIndex = state.indexWhere((c) => c.id == categoryId);
    if (catIndex == -1) return;

    final category = state[catIndex];
    final updatedCategory = category.copyWith(
      tasks: category.tasks.where((t) => t.id != taskId).toList(),
    );

    await updateCategory(updatedCategory);
  }

  Future<void> editTask(String categoryId, String taskId, String newTitle) async {
    final catIndex = state.indexWhere((c) => c.id == categoryId);
    if (catIndex == -1) return;

    final category = state[catIndex];
    final updatedCategory = category.copyWith(
      tasks: [
        for (final task in category.tasks)
          if (task.id == taskId) task.copyWith(title: newTitle) else task
      ],
    );

    await updateCategory(updatedCategory);
  }
}
