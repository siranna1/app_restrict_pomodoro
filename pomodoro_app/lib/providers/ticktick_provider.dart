// providers/ticktick_provider.dart - TickTick連携のProvider
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/ticktick_service.dart';
import '../services/database_helper.dart';

class TickTickProvider with ChangeNotifier {
  final _tickTickService = TickTickService();
  bool isAuthenticated = false;
  bool isSyncing = false;
  DateTime? lastSyncTime;

  TickTickProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    await _tickTickService.initialize();
    isAuthenticated = _tickTickService.isAuthenticated;
    notifyListeners();
  }

  // 認証状態を確認
  Future<void> checkAuthentication() async {
    isAuthenticated = _tickTickService.isAuthenticated;
    notifyListeners();
  }

  // 認証コードを使って認証
  Future<bool> authenticate(String authCode) async {
    final success = await _tickTickService.authenticate(authCode);
    isAuthenticated = success;
    notifyListeners();
    return success;
  }

  // TickTickからタスクをインポート
  Future<List<Task>> importTasks() async {
    if (!isAuthenticated) {
      return [];
    }

    isSyncing = true;
    notifyListeners();

    try {
      final tasks = await _tickTickService.importTasksFromTickTick();

      // データベースに保存
      final db = DatabaseHelper.instance;
      for (final task in tasks) {
        // 既存のタスクがあるか確認
        final existingTasks = await db.getTasks();
        final exists =
            existingTasks.any((t) => t.tickTickId == task.tickTickId);

        if (!exists) {
          await db.insertTask(task);
        }
      }

      lastSyncTime = DateTime.now();
      return tasks;
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  // ポモドーロセッション完了をTickTickに記録
  Future<bool> recordPomodoroSession(Task task, int durationMinutes) async {
    if (!isAuthenticated || task.tickTickId == null) {
      return false;
    }

    final success = await _tickTickService.recordPomodoroSession(
      task,
      durationMinutes,
    );

    if (success) {
      notifyListeners();
    }

    return success;
  }

  // タスク完了をTickTickに報告
  Future<bool> completeTask(Task task) async {
    if (!isAuthenticated || task.tickTickId == null) {
      return false;
    }

    final success = await _tickTickService.completeTask(task.tickTickId!);

    if (success) {
      notifyListeners();
    }

    return success;
  }
}
