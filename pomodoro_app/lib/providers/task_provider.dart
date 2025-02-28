// providers/task_provider.dart - タスク管理のProvider
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_helper.dart';

class TaskProvider with ChangeNotifier {
  List<Task> _tasks = [];

  List<Task> get tasks => _tasks;

  TaskProvider() {
    loadTasks();
  }

  Future<void> loadTasks() async {
    _tasks = await DatabaseHelper.instance.getTasks();
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    final id = await DatabaseHelper.instance.insertTask(task);
    final newTask = task.copyWith(id: id);
    _tasks.add(newTask);
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    await DatabaseHelper.instance.updateTask(task);

    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      _tasks[index] = task;
      notifyListeners();
    }
  }

  Future<void> deleteTask(int id) async {
    await DatabaseHelper.instance.deleteTask(id);
    _tasks.removeWhere((task) => task.id == id);
    notifyListeners();
  }

  Future<void> incrementTaskPomodoro(int taskId) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);

    if (index >= 0) {
      final task = _tasks[index];
      final updatedTask = task.copyWith(
        completedPomodoros: task.completedPomodoros + 1,
        updatedAt: DateTime.now(),
      );

      await DatabaseHelper.instance.updateTask(updatedTask);
      _tasks[index] = updatedTask;
      notifyListeners();
    }
  }
}
