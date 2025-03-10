// sync_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:pomodoro_app/services/database_helper.dart';
import 'package:pomodoro_app/services/settings_service.dart';
import 'package:pomodoro_app/models/task.dart';
import 'package:pomodoro_app/models/pomodoro_session.dart';
import 'package:pomodoro_app/models/reward_point.dart';
import 'package:pomodoro_app/models/app_usage_session.dart';

class SyncService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final DatabaseHelper _dbHelper;
  final SettingsService _settingsService;

  SyncService(this._dbHelper, this._settingsService);

  // タスク同期
  Future<void> syncTasks(String userId) async {
    final tasksRef = _database.child('users/$userId/tasks');

    // 前回の同期タイムスタンプ取得
    final lastSyncTime = await _settingsService.getLastSyncTime('tasks');

    // ローカルタスクの取得
    final localTasks = await _dbHelper.getTasksChangedSince(lastSyncTime);

    // Firebaseからタスクを取得
    final event = await tasksRef.once();
    final snapshot = event.snapshot;
    final remoteTasks = snapshot.value as Map<dynamic, dynamic>? ?? {};

    // リモートに存在しないローカルタスクをアップロード
    for (var task in localTasks) {
      if (task.firebaseId == null ||
          !remoteTasks.containsKey(task.firebaseId)) {
        final newRef = tasksRef.push();
        task.firebaseId = newRef.key;
        await newRef.set(task.toFirebase());
        await _dbHelper.updateTask(task);
      } else {
        // 更新日時に基づいて同期
        final remoteTask = remoteTasks[task.firebaseId!];
        final remoteUpdated = DateTime.parse(remoteTask['updatedAt']);

        if (task.updatedAt.isAfter(remoteUpdated)) {
          // ローカルの方が新しい場合、アップロード
          await tasksRef.child(task.firebaseId!).set(task.toFirebase());
        } else if (remoteUpdated.isAfter(task.updatedAt)) {
          // リモートの方が新しい場合、ダウンロード
          final updatedTask = Task.fromFirebase(remoteTask);
          updatedTask.copyWith(id: task.id);
          updatedTask.firebaseId = task.firebaseId;
          await _dbHelper.updateTask(updatedTask);
        }
      }
    }

    // ローカルに存在しないリモートタスクをダウンロード
    remoteTasks.forEach((key, value) async {
      final taskData = value as Map<dynamic, dynamic>;
      final exists = localTasks.any((task) => task.firebaseId == key);

      if (!exists) {
        final task = Task.fromFirebase(Map<String, dynamic>.from(taskData));
        task.firebaseId = key;
        await _dbHelper.insertTask(task);
      }
    });

    // 同期タイムスタンプを更新
    await _settingsService.setLastSyncTime('tasks', DateTime.now());
  }

  // ポモドーロセッション同期
  Future<void> syncPomodoroSessions(String userId) async {
    final sessionsRef = _database.child('users/$userId/pomodoro_sessions');

    // 前回の同期タイムスタンプ取得
    final lastSyncTime =
        await _settingsService.getLastSyncTime('pomodoro_sessions');

    // ローカルセッションの取得
    final localSessions = await _dbHelper.getSessionsChangedSince(lastSyncTime);

    // Firebaseからセッションを取得
    final event = await sessionsRef.once();
    final snapshot = event.snapshot;
    final remoteSessions = snapshot.value as Map<dynamic, dynamic>? ?? {};

    // リモートに存在しないローカルセッションをアップロード
    for (var session in localSessions) {
      if (session.firebaseId == null ||
          !remoteSessions.containsKey(session.firebaseId)) {
        final newRef = sessionsRef.push();
        session.firebaseId = newRef.key;
        await newRef.set(session.toFirebase());
        await _dbHelper.updatePomodoroSession(session);
      }
      // ポモドーロセッションは編集されないため、競合解決は不要
    }

    // ローカルに存在しないリモートセッションをダウンロード
    remoteSessions.forEach((key, value) async {
      final sessionData = value as Map<dynamic, dynamic>;
      final exists = localSessions.any((session) => session.firebaseId == key);

      if (!exists) {
        final session = PomodoroSession.fromFirebase(
            Map<String, dynamic>.from(sessionData));
        session.firebaseId = key;
        await _dbHelper.insertPomodoroSession(session);
      }
    });

    // 同期タイムスタンプを更新
    await _settingsService.setLastSyncTime('pomodoro_sessions', DateTime.now());
  }

  // アプリ制限コイン数の同期
  Future<void> syncRewardPoints(String userId) async {
    final pointsRef = _database.child('users/$userId/reward_points');

    // ローカルポイント取得
    final localPoints = await _dbHelper.getRewardPoints();

    // リモートポイント取得
    final event = await pointsRef.once();
    final snapshot = event.snapshot;

    if (snapshot.exists) {
      final remotePoints = snapshot.value as Map<dynamic, dynamic>;
      final remoteLastUpdated = DateTime.parse(remotePoints['lastUpdated']);

      if (localPoints.lastUpdated.isAfter(remoteLastUpdated)) {
        // ローカルの方が新しい、アップロード
        await pointsRef.set(localPoints.toFirebase());
      } else {
        // リモートの方が新しい、ダウンロード
        final points =
            RewardPoint.fromFirebase(Map<String, dynamic>.from(remotePoints));
        points.copyWith(id: localPoints.id);
        await _dbHelper.updateRewardPoints(points);
      }
    } else {
      // リモートにデータがない場合、アップロード
      await pointsRef.set(localPoints.toFirebase());
    }

    // 同期タイムスタンプを更新
    await _settingsService.setLastSyncTime('reward_points', DateTime.now());
  }

  // アプリ制限履歴の同期
  Future<void> syncAppUsageSessions(String userId) async {
    final sessionsRef = _database.child('users/$userId/app_usage_sessions');

    // 前回の同期タイムスタンプ取得
    final lastSyncTime =
        await _settingsService.getLastSyncTime('app_usage_sessions');

    // ローカルセッションの取得
    final localSessions =
        await _dbHelper.getAppUsageSessionsChangedSince(lastSyncTime);

    // Firebaseからセッションを取得
    final event = await sessionsRef.once();
    final snapshot = event.snapshot;
    final remoteSessions = snapshot.value as Map<dynamic, dynamic>? ?? {};

    // リモートに存在しないローカルセッションをアップロード
    for (var session in localSessions) {
      if (session.firebaseId == null ||
          !remoteSessions.containsKey(session.firebaseId)) {
        final newRef = sessionsRef.push();
        session.firebaseId = newRef.key;
        await newRef.set(session.toFirebase());
        await _dbHelper.updateAppUsageSession(session);
      }
      // アプリ使用セッションは編集されないため、競合解決は不要
    }

    // ローカルに存在しないリモートセッションをダウンロード
    remoteSessions.forEach((key, value) async {
      final sessionData = value as Map<dynamic, dynamic>;
      final exists = localSessions.any((session) => session.firebaseId == key);

      if (!exists) {
        final session = AppUsageSession.fromFirebase(
            Map<String, dynamic>.from(sessionData));
        session.firebaseId = key;
        await _dbHelper.insertAppUsageSession(session);
      }
    });

    // 同期タイムスタンプを更新
    await _settingsService.setLastSyncTime(
        'app_usage_sessions', DateTime.now());
  }

  // 全データ同期
  Future<void> syncAll(String userId) async {
    await syncTasks(userId);
    await syncPomodoroSessions(userId);
    await syncRewardPoints(userId);
    await syncAppUsageSessions(userId);
  }
}
