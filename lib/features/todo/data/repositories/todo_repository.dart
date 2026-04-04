import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/todo_category.dart';

class TodoRepository {
  final Box _box;

  TodoRepository(this._box);

  List<TodoCategory> getAllCategories() {
    final list = <TodoCategory>[];
    for (var key in _box.keys) {
      final value = _box.get(key);
      if (value != null) {
        if (value is String) {
          try {
            list.add(TodoCategory.fromJson(jsonDecode(value)));
          } catch(e) {
            // malformed json string fallback
          }
        } else if (value is Map) {
          list.add(TodoCategory.fromJson(Map<String, dynamic>.from(value)));
        }
      }
    }
    return list;
  }

  Future<void> saveCategory(TodoCategory category) async {
    await _box.put(category.id, category.toJson());
  }

  Future<void> deleteCategory(String id) async {
    await _box.delete(id);
  }
}
