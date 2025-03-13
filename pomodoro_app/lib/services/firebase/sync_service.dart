// sync_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:pomodoro_app/services/database_helper.dart';
import 'package:pomodoro_app/services/settings_service.dart';
import 'package:pomodoro_app/models/task.dart';
import 'package:pomodoro_app/models/pomodoro_session.dart';
import 'package:pomodoro_app/models/reward_point.dart';
import 'package:pomodoro_app/models/app_usage_session.dart';
import 'package:pomodoro_app/models/restricted_app.dart';
import 'dart:math';

class SyncService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final DatabaseHelper _dbHelper;
  final SettingsService _settingsService;

  SyncService(this._dbHelper, this._settingsService);

  // タスク同期 - 改良版
  Future<void> syncTasks(String userId) async {
    try {
      print("同期開始");
      final tasksRef = _database.child('users/$userId/tasks');

      // 前回の同期タイムスタンプ取得
      final lastSyncTime = await _settingsService.getLastSyncTime('tasks');

      // ローカルタスクの取得
      //final localTasks = await _dbHelper.getTasksChangedSince(lastSyncTime);
      final localTasks = await _dbHelper.getTasks();

      // ローカルのタスク名をマップ化して高速検索できるようにする
      final localTaskNameMap = <String, Task>{};
      for (var task in localTasks) {
        localTaskNameMap[task.name] = task;
      }

      // Firebaseからタスクを取得
      final snapshot = await tasksRef.get();
      print("同期中");
      //final snapshot = event.snapshot;

      Map<String, dynamic> remoteTasks = {};

      if (snapshot.value != null) {
        // Firebase データを Map<String, dynamic> に変換
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            remoteTasks[key.toString()] = Map<String, dynamic>.from(value.map(
              (k, v) => MapEntry(k.toString(), v),
            ));
          }
        });
      }

      // リモートに存在しないローカルタスクをアップロード
      for (var task in localTasks) {
        if (task.firebaseId == null ||
            !remoteTasks.containsKey(task.firebaseId)) {
          final newRef = tasksRef.push();
          task.firebaseId = newRef.key;
          await newRef.set(task.toFirebase());
          await _dbHelper.updateTask(task);
          print('新しいタスクをアップロード: ${task.name}');
        } else {
          // 更新日時に基づいて同期
          final remoteTask = remoteTasks[task.firebaseId!];
          final remoteUpdated = DateTime.parse(remoteTask['updatedAt']);

          if (task.updatedAt.isAfter(remoteUpdated)) {
            // ローカルの方が新しい場合、アップロード
            await tasksRef.child(task.firebaseId!).set(task.toFirebase());
            print('既存タスクを更新: ${task.name}');
          } else if (remoteUpdated.isAfter(task.updatedAt)) {
            // リモートの方が新しい場合、ダウンロード
            final updatedTask = Task.fromFirebase(remoteTask);
            updatedTask.id = task.id;
            updatedTask.firebaseId = task.firebaseId;
            await _dbHelper.updateTask(updatedTask);
            print('リモートタスクをダウンロード: ${updatedTask.name}');
          }
        }
      }

      // ローカルに存在しないリモートタスクをダウンロード
      for (var entry in remoteTasks.entries) {
        final key = entry.key;
        final taskData = entry.value;
        print("リモートキー $key");
        // FirebaseIDでの存在チェック
        final existsByFirebaseId =
            localTasks.any((task) => task.firebaseId == key);

        if (!existsByFirebaseId) {
          final remoteTaskName = taskData['name'] as String;

          // 同じ名前のタスクがローカルに存在するかチェック
          final existingTask = await _dbHelper.getTaskByName(remoteTaskName);

          if (existingTask == null) {
            // 完全に新しいタスクなのでインポート
            final task = Task.fromFirebase(taskData);
            task.firebaseId = key;
            final id = await _dbHelper.insertTask(task);
            print('新しいリモートタスクを追加: ${task.name}, ID: $id');
          } else if (existingTask.firebaseId == null) {
            // 名前が同じだがFirebaseID未設定のタスクには、FirebaseIDを関連付け
            existingTask.firebaseId = key;
            await _dbHelper.updateTask(existingTask);
            print('既存タスクをリモートタスクと関連付け: ${existingTask.name}');
          } else {
            // 名前が同じで別のFirebaseIDを持つ場合は、命名競合とみなす
            // この場合、リモートタスク名に接尾辞を追加して区別
            final task = Task.fromFirebase(taskData);
            task.name = "${task.name} (同期)";
            task.firebaseId = key;
            final id = await _dbHelper.insertTask(task);
            print('命名競合タスクを修正して追加: ${task.name}, ID: $id');
          }
        }
      }

      // 同期タイムスタンプを更新
      await _settingsService.setLastSyncTime('tasks', DateTime.now());
    } catch (e) {
      print('タスク同期エラー: $e');
      rethrow;
    }
  }

  // ポモドーロセッション同期 - 改良版
  Future<void> syncPomodoroSessions(String userId) async {
    try {
      final sessionsRef = _database.child('users/$userId/pomodoro_sessions');

      // 前回の同期タイムスタンプ取得
      final lastSyncTime =
          await _settingsService.getLastSyncTime('pomodoro_sessions');

      // 1. ローカルセッションをすべて取得 (変更されたものだけではなく)
      final allLocalSessions = await _dbHelper.getPomodoroSessions();

      // 2. 前回の同期以降に変更されたセッションのみを取得（アップロード用）
      final changedLocalSessions =
          await _dbHelper.getSessionsChangedSince(lastSyncTime);

      // 3. ローカルセッションのFirebaseID一覧を作成（既存セッションチェック用）
      final localSessionFirebaseIds = <String?>{};
      for (var session in allLocalSessions) {
        if (session.firebaseId != null) {
          localSessionFirebaseIds.add(session.firebaseId);
        }
      }

      // 4. startTime + endTimeの複合キーをマップとして保存（重複検出用）
      final sessionTimeKeys = <String>{};
      for (var session in allLocalSessions) {
        final timeKey =
            '${session.startTime.toIso8601String()}_${session.endTime.toIso8601String()}';
        sessionTimeKeys.add(timeKey);
      }

      // タスクとFirebase IDのマッピングを取得
      final taskMappings = await _getTaskFirebaseIdMappings();

      // Firebaseからセッションを取得
      final event = await sessionsRef.once();
      final snapshot = event.snapshot;

      Map<String, dynamic> remoteSessions = {};

      if (snapshot.value != null) {
        // Firebase データを Map<String, dynamic> に変換
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            remoteSessions[key.toString()] =
                Map<String, dynamic>.from(value.map(
              (k, v) => MapEntry(k.toString(), v),
            ));
          }
        });
      }

      // リモートに存在しないローカルセッションをアップロード（変更されたもののみ）
      for (var session in changedLocalSessions) {
        // セッションに関連するタスクのFirebase IDを取得
        final taskId = session.taskId;
        String? firebaseTaskId = taskMappings[taskId];

        if (firebaseTaskId != null) {
          if (session.firebaseId == null ||
              !remoteSessions.containsKey(session.firebaseId)) {
            final newRef = sessionsRef.push();
            session.firebaseId = newRef.key;

            // セッションデータにタスクのFirebase IDを含める
            final sessionData = session.toFirebase();
            sessionData['firebaseTaskId'] = firebaseTaskId;

            await newRef.set(sessionData);

            // ローカルのセッションにもFirebaseタスクIDを保存
            session.firebaseTaskId = firebaseTaskId;
            await _dbHelper.updatePomodoroSession(session);
            print('新しいセッションをアップロード: ${session.id}');
          }
        } else {
          print('警告: セッションID ${session.id} に関連するタスクのFirebase IDが見つかりません');
        }
      }

      // ローカルに存在しないリモートセッションをダウンロード
      for (var entry in remoteSessions.entries) {
        final key = entry.key;
        final sessionData = entry.value;

        // 1. すでにfirebaseIdでマッピングされているセッションはスキップ
        if (localSessionFirebaseIds.contains(key)) {
          continue;
        }

        // 2. 時間による重複検出 - 開始時間と終了時間が一致するセッションはスキップ
        final startTime = DateTime.parse(sessionData['startTime']);
        final endTime = DateTime.parse(sessionData['endTime']);
        final timeKey =
            '${startTime.toIso8601String()}_${endTime.toIso8601String()}';

        //if (sessionTimeKeys.contains(timeKey)) {
        //  print('重複セッションをスキップ: $timeKey');
        //  continue;
        //}

        // 新しいセッションとしてインポート
        final session = PomodoroSession.fromFirebase(sessionData);
        session.firebaseId = key;

        // FirebaseタスクIDからローカルタスクIDをマッピング
        final firebaseTaskId = sessionData['firebaseTaskId'];
        if (firebaseTaskId != null) {
          final localTaskId =
              await _getLocalTaskIdFromFirebaseId(firebaseTaskId);
          if (localTaskId != null) {
            session.taskId = localTaskId;
            session.firebaseTaskId = firebaseTaskId;

            final id = await _dbHelper.insertPomodoroSession(session);
            print('新しいリモートセッションを追加: $id');

            // セッション追加後にセッション時間キーセットに追加（同じセッションが複数回ダウンロードされるのを防ぐ）
            sessionTimeKeys.add(timeKey);
          } else {
            print('警告: リモートセッションに関連するローカルタスクが見つかりません');
          }
        } else {
          print('警告: リモートセッションにfirebaseTaskIdが含まれていません');
        }
      }

      // 同期タイムスタンプを更新
      await _settingsService.setLastSyncTime(
          'pomodoro_sessions', DateTime.now());
    } catch (e) {
      print('ポモドーロセッション同期エラー: $e');
      rethrow;
    }
  }

  // タスクIDとそのFirebase IDをマッピングするヘルパーメソッド
  Future<Map<int, String>> _getTaskFirebaseIdMappings() async {
    final tasks = await _dbHelper.getTasks();
    final Map<int, String> mappings = {};

    for (var task in tasks) {
      if (task.id != null && task.firebaseId != null) {
        mappings[task.id!] = task.firebaseId!;
      }
    }

    return mappings;
  }

  // Firebase IDからローカルタスクIDを取得するヘルパーメソッド
  Future<int?> _getLocalTaskIdFromFirebaseId(String firebaseId) async {
    final task = await _dbHelper.getTaskByFirebaseId(firebaseId);
    return task?.id;
  }

  // アプリ名とパスから対応するローカルアプリIDを検索
  Future<int?> _findLocalAppIdByNameAndPath(String? name, String? path) async {
    if (name == null || path == null) return null;

    final apps = await _dbHelper.getRestrictedApps();

    // 名前とパスが完全一致するアプリを探す
    for (var app in apps) {
      if (app.name == name && app.executablePath == path && app.id != null) {
        return app.id;
      }
    }

    return null;
  }

// アプリ名だけで対応するローカルアプリIDを検索
  Future<int?> _findLocalAppIdByName(String name) async {
    final apps = await _dbHelper.getRestrictedApps();

    // 名前が一致するアプリを探す
    for (var app in apps) {
      if (app.name == name && app.id != null) {
        return app.id;
      }
    }

    return null;
  }

// 「未知のアプリ」カテゴリを取得または作成
  Future<int> _getOrCreateUnknownApp(String name, String? path) async {
    // まず「未知のアプリ」という名前のアプリを検索
    final apps = await _dbHelper.getRestrictedAppByName('未知のアプリ: $name');

    if (apps.isNotEmpty && apps.first.id != null) {
      return apps.first.id!;
    }

    // なければ新規作成
    final unknownApp = RestrictedApp(
      name: '未知のアプリ: $name',
      executablePath: path ?? 'unknown',
      allowedMinutesPerDay: 0,
      isRestricted: false, // 制限なし（別デバイス用）
      requiredPomodorosToUnlock: 0,
      minutesPerPoint: 30,
    );

    final id = await _dbHelper.insertRestrictedApp(unknownApp);
    return id;
  }

  // 制限アプリの同期
  Future<void> syncRestrictedApps(String userId) async {
    try {
      final appsRef = _database.child('users/$userId/restricted_apps');

      // ローカルの制限アプリを取得
      final localApps = await _dbHelper.getRestrictedApps();

      // Firebaseから制限アプリを取得
      final event = await appsRef.once();
      final snapshot = event.snapshot;

      Map<String, dynamic> remoteApps = {};

      if (snapshot.value != null) {
        // Firebase データを Map<String, dynamic> に変換
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            remoteApps[key.toString()] = Map<String, dynamic>.from(value.map(
              (k, v) => MapEntry(k.toString(), v),
            ));
          }
        });
      }

      // リモートに存在しないローカルアプリをアップロード
      for (var app in localApps) {
        if (app.firebaseId == null || !remoteApps.containsKey(app.firebaseId)) {
          final newRef = appsRef.push();

          // ローカルアプリにFirebase IDを設定して保存
          final updatedApp = app.copyWith(firebaseId: newRef.key);
          await _dbHelper.updateRestrictedApp(updatedApp);

          // Firebase にアップロード
          await newRef.set(app.toFirebase());
          print('新しい制限アプリをアップロード: ${app.name}');
        } else {
          // 既存のアプリは設定のみアップデート（セッション終了時間などの一時的な状態は除く）
          await appsRef.child(app.firebaseId!).update(app.toFirebase());
          print('既存の制限アプリを更新: ${app.name}');
        }
      }

      // ローカルに存在しないリモートアプリをダウンロード
      for (var entry in remoteApps.entries) {
        final key = entry.key;
        final appData = entry.value;

        // すでにインポート済みかどうか確認
        final exists = localApps.any((app) => app.firebaseId == key);

        if (!exists) {
          // アプリ名とパスでローカルに同じアプリがないか確認
          final appName = appData['name'];
          final appPath = appData['executablePath'];

          final existingApp =
              await _dbHelper.getRestrictedAppByNameAndPath(appName, appPath);

          if (existingApp == null) {
            // 新しいアプリとしてインポート
            final app = RestrictedApp.fromFirebase(appData);
            final updatedApp = app.copyWith(firebaseId: key);
            //await _dbHelper.insertRestrictedApp(updatedApp);
            print('新しいリモート制限アプリを追加: ${app.name}');
          } else if (existingApp.firebaseId == null) {
            // 既存のアプリにFirebase IDを関連付け
            final updatedApp = existingApp.copyWith(firebaseId: key);
            await _dbHelper.updateRestrictedApp(updatedApp);
            print('既存の制限アプリにFirebase IDを関連付け: ${existingApp.name}');
          }
        }
      }

      // 同期タイムスタンプを更新
      await _settingsService.setLastSyncTime('restricted_apps', DateTime.now());
    } catch (e) {
      print('制限アプリ同期エラー: $e');
      rethrow;
    }
  }

  // ポイント同期 - 改良版
  Future<void> syncRewardPoints(String userId) async {
    try {
      final pointsRef = _database.child('users/$userId/reward_points');

      // ローカルポイント取得
      final localPoints = await _dbHelper.getRewardPoints();
      print(
          '同期前のローカルポイント: 獲得=${localPoints.earnedPoints}, 使用=${localPoints.usedPoints}, 前回同期獲得=${localPoints.lastSyncEarnedPoints}, 前回同期使用=${localPoints.lastSyncUsedPoints}');

      // リモートポイント取得
      final event = await pointsRef.once();
      final snapshot = event.snapshot;

      if (snapshot.exists && snapshot.value != null) {
        final remoteData = snapshot.value as Map<dynamic, dynamic>;
        final remoteMap = Map<String, dynamic>.from(remoteData.map(
          (k, v) => MapEntry(k.toString(), v),
        ));

        final remotePoints = RewardPoint.fromFirebase(remoteMap);
        print(
            'リモートポイント: 獲得=${remotePoints.earnedPoints}, 使用=${remotePoints.usedPoints}, 前回同期獲得=${remotePoints.lastSyncEarnedPoints}, 前回同期使用=${remotePoints.lastSyncUsedPoints}');

        // 増分計算: 両方が変更されている場合の正しい処理
        final localEarnedDelta = localPoints.lastSyncEarnedPoints != null
            ? localPoints.earnedPoints - localPoints.lastSyncEarnedPoints!
            : 0;
        final localUsedDelta = localPoints.lastSyncUsedPoints != null
            ? localPoints.usedPoints - localPoints.lastSyncUsedPoints!
            : 0;

        final remoteEarnedDelta = remotePoints.lastSyncEarnedPoints != null
            ? remotePoints.earnedPoints - remotePoints.lastSyncEarnedPoints!
            : 0;
        final remoteUsedDelta = remotePoints.lastSyncUsedPoints != null
            ? remotePoints.usedPoints - remotePoints.lastSyncUsedPoints!
            : 0;

        print('ローカル変化量: 獲得=$localEarnedDelta, 使用=$localUsedDelta');
        print('リモート変化量: 獲得=$remoteEarnedDelta, 使用=$remoteUsedDelta');

        // 新しい合計を計算
        final baseEarnedPoints = max(localPoints.lastSyncEarnedPoints ?? 0,
            remotePoints.lastSyncEarnedPoints ?? 0);
        final baseUsedPoints = max(localPoints.lastSyncUsedPoints ?? 0,
            remotePoints.lastSyncUsedPoints ?? 0);

        // 新しいポイント合計 = 基準値 + ローカル増分 + リモート増分
        final newEarnedPoints =
            baseEarnedPoints + localEarnedDelta + remoteEarnedDelta;
        final newUsedPoints = baseUsedPoints + localUsedDelta + remoteUsedDelta;

        print('同期後のポイント: 獲得=$newEarnedPoints, 使用=$newUsedPoints');

        // 更新したポイントオブジェクトを作成
        final mergedPoints = RewardPoint(
          id: localPoints.id,
          earnedPoints: newEarnedPoints,
          usedPoints: newUsedPoints,
          lastUpdated: DateTime.now(),
          firebaseId: localPoints.firebaseId,
          lastSyncEarnedPoints: newEarnedPoints, // 同期完了時点の値を記録
          lastSyncUsedPoints: newUsedPoints, // 同期完了時点の値を記録
        );

        // ローカルとリモートの両方を更新
        await _dbHelper.updateRewardPoints(mergedPoints);
        await pointsRef.set(mergedPoints.toFirebase());

        print('ポイントデータを増分同期しました: 獲得=$newEarnedPoints, 使用=$newUsedPoints');
      } else {
        // リモートにデータがない場合、初期アップロード
        final initialPoints = localPoints.copyWith(
          lastSyncEarnedPoints: localPoints.earnedPoints,
          lastSyncUsedPoints: localPoints.usedPoints,
        );

        await pointsRef.set(initialPoints.toFirebase());
        await _dbHelper.updateRewardPoints(initialPoints);

        print(
            '初期ポイントデータをアップロード: 獲得=${initialPoints.earnedPoints}, 使用=${initialPoints.usedPoints}');
      }

      // 同期タイムスタンプを更新
      await _settingsService.setLastSyncTime('reward_points', DateTime.now());
    } catch (e) {
      print('ポイント同期エラー: $e');
      rethrow;
    }
  }

  Future<void> syncAppUsageSessions(String userId) async {
    try {
      final sessionsRef = _database.child('users/$userId/app_usage_sessions');

      // 前回の同期タイムスタンプ取得
      final lastSyncTime =
          await _settingsService.getLastSyncTime('app_usage_sessions');

      // ローカルセッション取得
      final localSessions =
          await _dbHelper.getAppUsageSessionsChangedSince(lastSyncTime);

      // ローカルのアプリ情報を取得
      final appInfoMap = await _getLocalRestrictedAppsInfo();

      // セッションにアプリ情報を追加
      for (var session in localSessions) {
        final appInfo = appInfoMap[session.appId];
        if (appInfo != null) {
          session.appName = appInfo['name'];
          session.appPath = appInfo['executablePath'];
        }
      }

      // Firebaseからデータ取得
      final event = await sessionsRef.once();
      final snapshot = event.snapshot;

      Map<String, dynamic> remoteSessions = {};

      if (snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            remoteSessions[key.toString()] =
                Map<String, dynamic>.from(value.map(
              (k, v) => MapEntry(k.toString(), v),
            ));
          }
        });
      }

      // ローカルセッションのアップロード
      for (var session in localSessions) {
        if (session.firebaseId == null ||
            !remoteSessions.containsKey(session.firebaseId)) {
          final newRef = sessionsRef.push();

          // セッションデータにアプリ情報を含める
          final sessionData = session.toFirebase();

          await newRef.set(sessionData);

          // ローカルのセッションにFirebase IDを保存
          session.firebaseId = newRef.key;
          await _dbHelper.updateAppUsageSession(session);
          print('新しいアプリ使用セッションをアップロード: ${session.appName}');
        }
      }

      // リモートセッションのダウンロード
      for (var entry in remoteSessions.entries) {
        final key = entry.key;
        final sessionData = entry.value;

        // 既に同じFirebase IDを持つセッションがあるかチェック
        final exists =
            localSessions.any((session) => session.firebaseId == key);

        if (!exists) {
          // セッションデータから必要な情報を抽出
          final appName = sessionData['appName'];
          final appPath = sessionData['appPath'];
          final remoteAppId = sessionData['remoteAppId'];

          // アプリ名・パスから対応するローカルの制限アプリを検索
          int? localAppId =
              await _findLocalAppIdByNameAndPath(appName, appPath);

          if (localAppId == null && appName != null) {
            // 名前だけで検索
            localAppId = await _findLocalAppIdByName(appName);
          }

          if (localAppId != null) {
            // 対応するアプリが見つかった場合は通常のインポート
            final session = AppUsageSession.fromFirebase(sessionData);
            session.firebaseId = key;
            session.appId = localAppId;
            await _dbHelper.insertAppUsageSession(session);
            print('リモートアプリ使用セッションをダウンロード: $appName');
          } else if (appName != null) {
            // 対応するアプリがない場合は「未知のアプリ」として記録
            // まず「未知のアプリ」カテゴリを作成または検索
            int unknownAppId = await _getOrCreateUnknownApp(appName, appPath);

            final session = AppUsageSession.fromFirebase(sessionData);
            session.firebaseId = key;
            session.appId = unknownAppId;
            session.remoteAppId = remoteAppId;
            await _dbHelper.insertAppUsageSession(session);
            print('未知のアプリセッションをダウンロード: $appName');
          }
        }
      }

      // 同期タイムスタンプを更新
      await _settingsService.setLastSyncTime(
          'app_usage_sessions', DateTime.now());
    } catch (e) {
      print('アプリ使用セッション同期エラー: $e');
      rethrow;
    }
  }

// ローカルの制限アプリ情報を取得するヘルパーメソッド
  Future<Map<int, Map<String, dynamic>>> _getLocalRestrictedAppsInfo() async {
    final apps = await _dbHelper.getRestrictedApps();
    final Map<int, Map<String, dynamic>> result = {};

    for (var app in apps) {
      if (app.id != null) {
        result[app.id!] = {
          'name': app.name,
          'executablePath': app.executablePath,
        };
      }
    }

    return result;
  }

  // 全データ同期
  Future<void> syncAll(String userId) async {
    try {
      // 1. まずタスクを同期（他のデータの参照元になるため）
      await syncTasks(userId);

      // 2. ポモドーロセッションを同期（タスク参照が必要）
      await syncPomodoroSessions(userId);

      // 3. 制限アプリを同期
      await syncRestrictedApps(userId);

      // 4. 補助データを同期
      await syncRewardPoints(userId);
      await syncAppUsageSessions(userId);
    } catch (e) {
      print('データ同期エラー: $e');
      rethrow;
    }
  }
}
