import 'package:hive_flutter/hive_flutter.dart';
import '../models/eisenhower_task.dart';

class EisenhowerRepository {
  final Box<EisenhowerTask> _box;

  EisenhowerRepository(this._box);

  List<EisenhowerTask> getAllTasks() {
    return _box.values.toList();
  }

  Future<void> saveTask(EisenhowerTask task) async {
    await _box.put(task.id, task);
  }

  Future<void> deleteTask(String id) async {
    await _box.delete(id);
  }

  Future<void> updateTask(EisenhowerTask task) async {
    await _box.put(task.id, task);
  }

  Future<void> clearAll() async {
    await _box.clear();
  }
}
