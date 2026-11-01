import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';

/// يخزّن المهام محلياً على الجهاز.
class TaskStore extends ChangeNotifier {
  static const _key = 'tasks_v1';
  final List<Task> _tasks = [];

  List<Task> get tasks => List.unmodifiable(_tasks);
  int get doneCount => _tasks.where((t) => t.done).length;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _tasks
        ..clear()
        ..addAll(list.map((e) => Task.fromJson(e as Map<String, dynamic>)));
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_tasks.map((t) => t.toJson()).toList()));
  }

  void add(String title, {Priority priority = Priority.normal}) {
    final t = title.trim();
    if (t.isEmpty) return;
    _tasks.insert(
      0,
      Task(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: t,
        priority: priority,
      ),
    );
    _changed();
  }

  void toggle(Task task) {
    task.done = !task.done;
    _changed();
  }

  void update(Task task, String title, Priority priority) {
    task.title = title.trim();
    task.priority = priority;
    _changed();
  }

  void remove(Task task) {
    _tasks.remove(task);
    _changed();
  }

  void insertAt(int index, Task task) {
    _tasks.insert(index.clamp(0, _tasks.length), task);
    _changed();
  }

  void clearCompleted() {
    _tasks.removeWhere((t) => t.done);
    _changed();
  }

  void _changed() {
    notifyListeners();
    _save();
  }
}
