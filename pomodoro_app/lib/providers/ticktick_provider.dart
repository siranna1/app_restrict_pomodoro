// providers/ticktick_provider.dart の修正

import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/ticktick_service.dart';
import '../services/database_helper.dart';

class TickTickProvider with ChangeNotifier {
  final _tickTickService = TickTickService();
  bool isAuthenticated = false;
  bool isSyncing = false;
  DateTime? lastSyncTime;
  // プロジェクト一覧
  List<Map<String, dynamic>> _projects = [];

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
    // TickTickServiceの認証メソッドを呼び出し
    final success = await _tickTickService.authenticate(authCode);
    isAuthenticated = success;
    notifyListeners();
    return success;
  }

  // TickTickからタスクをインポート
  Future<List<Task>> importTasks() async {
    if (!isAuthenticated) {
      print('TickTickに認証されていないため、インポートできません');
      return [];
    }

    isSyncing = true;
    notifyListeners();

    try {
      // TickTickServiceからタスクをインポート
      final tasks = await _tickTickService.importTasksFromTickTick();

      print('TickTickからインポートしたタスク数: ${tasks.length}');

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
    } catch (e) {
      print('タスクインポートエラー: $e');
      return [];
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  // 連携解除（ログアウト）
  Future<bool> logout() async {
    final success = await _tickTickService.logout();
    if (success) {
      isAuthenticated = false;
      _projects.clear();
      lastSyncTime = null;
      notifyListeners();
    }
    return success;
  }

  // ポモドーロセッション完了をTickTickに記録
  Future<bool> recordPomodoroSession(Task task, int durationMinutes) async {
    if (!isAuthenticated || task.tickTickId == null) {
      return false;
    }

    // TickTickServiceのメソッドを呼び出す
    // 実際のTickTick APIには該当機能がないようなので、
    // 独自に実装するか、コメントをつけるなどする必要があります
    // ここでは簡略化のため、常にtrueを返すようにしています

    notifyListeners();
    return true;
  }

  // タスク完了をTickTickに報告
  Future<bool> completeTask(Task task) async {
    if (!isAuthenticated || task.tickTickId == null) {
      return false;
    }

    // TickTickServiceのタスク完了メソッドを呼び出し
    final success = await _tickTickService.completeTask(task.tickTickId!);

    if (success) {
      notifyListeners();
    }

    return success;
  }

// プロジェクト一覧を取得
  Future<List<Map<String, dynamic>>> getProjects() async {
    if (!isAuthenticated) {
      return [];
    }

    try {
      _projects = await _tickTickService.getProjects();
      return _projects;
    } catch (e) {
      print('プロジェクト一覧取得エラー: $e');
      return [];
    }
  }

// 特定のプロジェクトからタスクをインポート
  Future<List<Task>> importTasksFromProject(
      String projectId, String projectName) async {
    if (!isAuthenticated) {
      return [];
    }

    isSyncing = true;
    notifyListeners();

    try {
      final tasks =
          await _tickTickService.fetchTasksFromProject(projectId, projectName);

      print('プロジェクト「$projectName」からインポートしたタスク数: ${tasks.length}');

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
    } catch (e) {
      print('プロジェクトからのタスクインポートエラー: $e');
      return [];
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }
}
