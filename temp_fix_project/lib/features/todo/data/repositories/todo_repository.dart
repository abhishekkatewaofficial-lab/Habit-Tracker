import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/todo_category.dart';

class TodoRepository {
  final Box _box;

  TodoRepository(this._box);

  List<TodoCategory> getAllCategories() {
    final list = <TodoCategory>[];
    for (var key in _box.keys) {
      final jsonStr = _box.get(key);
      if (jsonStr != null) {
        list.add(TodoCategory.fromJson(jsonDecode(jsonStr)));
      }
    }
    return list;
  }

  Future<void> saveCategory(TodoCategory category) async {
    await _box.put(category.id, jsonEncode(category.toJson()));
  }

  Future<void> deleteCategory(String id) async {
    await _box.delete(id);
  }
}
