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
import 'auth_service.dart';
import '../../utils/platform_utils.dart';
import 'firebase_rest_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../platforms/android/android_app_controller.dart';
import '../../platforms/windows/windows_app_controller.dart';
import 'dart:io';

class SyncService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final DatabaseHelper _dbHelper;
  final SettingsService _settingsService;
  final AuthService _authService;
  final PlatformUtils _platformUtils = PlatformUtils();
  // REST APIベースの実装用
  late FirebaseRestService _restService;

  // Firebase Realtime DBのURL
  final String _databaseUrl =
      'https://pomodoroappsync-default-rtdb.asia-southeast1.firebasedatabase.app';

  SyncService(this._dbHelper, this._settingsService, this._authService) {
    // REST APIサービスを初期化
    _restService = FirebaseRestService(
      authService: _authService,
      databaseUrl: _databaseUrl,
    );
  }

  // プラットフォームに応じたサービス選択
  bool get _useRestApi => _platformUtils.isWindows;

  // タスク同期 - 改良版
  Future<void> syncTasks(String userId) async {
    try {
      print("タスク同期開始 (${_useRestApi ? 'REST API' : 'SDK'})");

      // 前回の同期タイムスタンプ取得
      final lastSyncTime = await _settingsService.getLastSyncTime('tasks');

      // ローカルタスクの取得
      //final localTasks = await _dbHelper.getTasksChangedSince(lastSyncTime);
      final localTasks = await _dbHelper.getAllTasksIncludingDeleted();

      // ローカルのタスク名をマップ化して高速検索できるようにする
      final localTaskNameMap = <String, Task>{};
      for (var task in localTasks) {
        localTaskNameMap[task.name] = task;
      }
      Map<String, dynamic> remoteTasks = {};
      if (_useRestApi) {
        final remoteData =
            await _restService.getTasksChangedSince(userId, lastSyncTime);
        if (remoteData != null) {
          remoteTasks = remoteData;
        }
      } else {
        final tasksRef = _database.child('users/$userId/tasks');

        // Firebaseからタスクを取得
        final snapshot = await tasksRef.get();
        //final snapshot = event.snapshot;

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
      }

      // リモートに存在しないローカルタスクをアップロード
      for (var task in localTasks) {
        if (task.firebaseId == null ||
            !remoteTasks.containsKey(task.firebaseId)) {
          String? newFirebaseId;
          if (_useRestApi) {
            newFirebaseId = await _restService.syncTask(userId, task);
          } else {
            final tasksRef = _database.child('users/$userId/tasks');
            final newRef = tasksRef.push();
            task.firebaseId = newRef.key;
            await newRef.set(task.toFirebase());
            newFirebaseId = newRef.key;
          }
          if (newFirebaseId != null) {
            task.firebaseId = newFirebaseId;
            await _dbHelper.updateTask(task);
            print('新しいタスクをアップロード: ${task.name}');
          }
        } else {
          // 更新日時に基づいて同期
          final remoteTask = remoteTasks[task.firebaseId!];
          final remoteUpdated = DateTime.parse(remoteTask['updatedAt']);

          if (task.updatedAt.isAfter(remoteUpdated)) {
            if (_useRestApi) {
              await _restService.updateData(
                  'users/$userId/tasks/${task.firebaseId}', task.toFirebase());
            } else {
              // ローカルの方が新しい場合、アップロード
              final tasksRef = _database.child('users/$userId/tasks');
              await tasksRef.child(task.firebaseId!).set(task.toFirebase());
            }
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
      print("ポモドーロセッション同期開始 (${_useRestApi ? 'REST API' : 'SDK'})");

      // 前回の同期タイムスタンプ取得
      final lastSyncTime =
          await _settingsService.getLastSyncTime('pomodoro_sessions');

      // 1. ローカルセッションをすべて取得 (変更されたものだけではなく)
      final allLocalSessions =
          await _dbHelper.getAllPomodoroSessionsIncludingDeleted();

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
      Map<String, dynamic> remoteSessions = {};
      if (_useRestApi) {
        final remoteData =
            await _restService.getSessionsChangedSince(userId, lastSyncTime);
        if (remoteData != null) {
          remoteSessions = remoteData;
        }
      } else {
        final sessionsRef = _database.child('users/$userId/pomodoro_sessions');
        // Firebaseからセッションを取得
        final event = await sessionsRef.once();
        final snapshot = event.snapshot;

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
      }

      // リモートに存在しないローカルセッションをアップロード（変更されたもののみ）
      for (var session in changedLocalSessions) {
        // セッションに関連するタスクのFirebase IDを取得
        final taskId = session.taskId;
        print("taskId: $taskId");
        String? firebaseTaskId = taskMappings[taskId];

        if (firebaseTaskId != null) {
          if (session.firebaseId == null ||
              !remoteSessions.containsKey(session.firebaseId)) {
            String? newFirebaseId;
            session.firebaseTaskId = firebaseTaskId;
            if (_useRestApi) {
              newFirebaseId = await _restService.syncSession(userId, session);
            } else {
              final sessionsRef =
                  _database.child('users/$userId/pomodoro_sessions');
              final newRef = sessionsRef.push();

              // セッションデータにタスクのFirebase IDを含める
              final sessionData = session.toFirebase();
              sessionData['firebaseTaskId'] = firebaseTaskId;
              newFirebaseId = newRef.key;
              await newRef.set(sessionData);
            }
            if (newFirebaseId != null) {
              session.firebaseId = newFirebaseId;
              await _dbHelper.updatePomodoroSession(session);
              print('新しいセッションをアップロード: ${session.id}');
            }
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
          print("スキップ");
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
    if (name.startsWith("未知のアプリ: ")) {
      String cleanName = name.substring("未知のアプリ: ".length);
      for (var app in apps) {
        if (app.name == cleanName && app.id != null) {
          return app.id;
        }
      }
    }

    return null;
  }

// 「未知のアプリ」カテゴリを取得または作成
  Future<int> _getOrCreateUnknownApp(String name, String? path,
      {String? platformType, String? DeviceId}) async {
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
      isAvailableLocally: false,
      deviceId: DeviceId,
      platformType: platformType,
    );

    final id = await _dbHelper.insertRestrictedApp(unknownApp);
    return id;
  }

  // SyncService の syncRestrictedApps メソッドの改良版

  Future<void> syncRestrictedApps(String userId) async {
    try {
      print("制限アプリ同期開始 (${_useRestApi ? 'REST API' : 'SDK'})");

      // デバイス識別子とプラットフォームタイプを取得
      final String deviceId = await _getDeviceId();
      final String platformType =
          _platformUtils.isWindows ? "windows" : "android";

      // ローカルの制限アプリを取得（論理削除されたものも含む）
      final localApps = await _dbHelper.getAllRestrictedAppsIncludingDeleted();

      // 現在のデバイスにインストールされているアプリのリストを取得
      final installedApps = await _getInstalledApps();

      Map<String, dynamic> remoteApps = {};
      if (_useRestApi) {
        final remoteData = await _restService.getRestrictedApps(userId);
        if (remoteData != null) {
          remoteApps = remoteData;
        }
      } else {
        final appsRef = _database.child('users/$userId/restricted_apps');
        // Firebaseから制限アプリを取得
        final event = await appsRef.once();
        final snapshot = event.snapshot;

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
      }

      //ローカルのアプリの名前に「未知のアプリ」とあったら、未知のアプリの部分を消す
      for (var i = 0; i < localApps.length; i++) {
        var app = localApps[i];
        if (app.name.startsWith("未知のアプリ: ")) {
          String cleanName = app.name.substring("未知のアプリ: ".length);
          localApps[i] = app.copyWith(name: cleanName);
          print("アプリ名を修正: ${app.name} -> $cleanName");
        }
      }

      // リモートの制限アプリを処理
      List<RestrictedApp> uniqueRemoteApps = [];
      Map<String, RestrictedApp> pathToAppMap = {};

      // リモートアプリのリストから同じパスを持つアプリの重複を除去
      for (var entry in remoteApps.entries) {
        final key = entry.key;
        final appData = entry.value;

        final app = RestrictedApp.fromFirebase(appData, key);

        // アプリがローカルに存在するかチェック
        bool isAvailableLocally = _isAppAvailableLocally(app, installedApps);
        app.isAvailableLocally = isAvailableLocally;

        // 実行パスをキーにして最新のアプリデータだけを保持
        final path = app.executablePath;
        final updatedAt =
            DateTime.parse(appData['updatedAt'] ?? '2000-01-01T00:00:00Z');

        if (!pathToAppMap.containsKey(path) ||
            !pathToAppMap[path]!.updatedAt.isAfter(updatedAt)) {
          pathToAppMap[path] = app;
        }
      }

      // 重複のないリストを作成
      uniqueRemoteApps = pathToAppMap.values.toList();

      // ローカルアプリのマッピングを作成（パス → アプリ）
      final localAppByPath = <String, RestrictedApp>{};
      for (var app in localApps) {
        localAppByPath[app.executablePath] = app;
      }

      // ローカルのFirebaseID → アプリマッピングも作成
      final localAppByFirebaseId = <String, RestrictedApp>{};
      for (var app in localApps) {
        if (app.firebaseId != null) {
          localAppByFirebaseId[app.firebaseId!] = app;
        }
      }

      // リモートアプリをローカルDBに追加/更新
      for (var remoteApp in uniqueRemoteApps) {
        final path = remoteApp.executablePath;

        // 実行パスが同じアプリがローカルに存在するか確認
        if (localAppByPath.containsKey(path)) {
          final localApp = localAppByPath[path]!;

          // パスは同じだがFirebaseIDが異なる場合、同じアプリとみなして統合
          if (localApp.firebaseId != remoteApp.firebaseId) {
            print(
                '同じパスで異なるIDのアプリを統合: ${remoteApp.name}, パス=${remoteApp.executablePath}');

            // 更新用のアプリ情報を作成（ローカルIDを維持しつつ、リモートの最新情報とリモートのFirebaseIDを使用）
            final updatedApp = localApp.copyWith(
              name: remoteApp.name,
              allowedMinutesPerDay: remoteApp.allowedMinutesPerDay,
              isRestricted: remoteApp.isRestricted,
              requiredPomodorosToUnlock: remoteApp.requiredPomodorosToUnlock,
              minutesPerPoint: remoteApp.minutesPerPoint,
              deviceId: remoteApp.deviceId,
              platformType: remoteApp.platformType,
              isAvailableLocally: remoteApp.isAvailableLocally,
              isDeleted: remoteApp.isDeleted,
              firebaseId: remoteApp.firebaseId,
            );

            await _dbHelper.updateRestrictedApp(updatedApp);
          } else if (remoteApp.firebaseId == localApp.firebaseId) {
            // 同じFirebaseIDの場合は通常の更新処理
            final remoteTimestamp = DateTime.parse(
                remoteApps[remoteApp.firebaseId!]['updatedAt'] ??
                    '2000-01-01T00:00:00Z');

            // リモートの方が新しい場合はローカルを更新
            if (remoteTimestamp.isAfter(localApp.updatedAt)) {
              final updatedApp = localApp.copyWith(
                name: remoteApp.name,
                allowedMinutesPerDay: remoteApp.allowedMinutesPerDay,
                isRestricted: remoteApp.isRestricted,
                requiredPomodorosToUnlock: remoteApp.requiredPomodorosToUnlock,
                minutesPerPoint: remoteApp.minutesPerPoint,
                deviceId: remoteApp.deviceId,
                platformType: remoteApp.platformType,
                isAvailableLocally: remoteApp.isAvailableLocally,
                isDeleted: remoteApp.isDeleted,
              );

              await _dbHelper.updateRestrictedApp(updatedApp);
              print('リモートの最新情報でアプリを更新: ${remoteApp.name}');
            }
          }
        } else if (remoteApp.firebaseId != null &&
            localAppByFirebaseId.containsKey(remoteApp.firebaseId)) {
          // パスは異なるがFirebaseIDが一致する場合（稀なケース）
          final localApp = localAppByFirebaseId[remoteApp.firebaseId!]!;

          // リモートの更新日時を取得
          final remoteTimestamp = DateTime.parse(
              remoteApps[remoteApp.firebaseId!]['updatedAt'] ??
                  '2000-01-01T00:00:00Z');

          // リモートの方が新しい場合はローカルを更新
          if (remoteTimestamp.isAfter(localApp.updatedAt)) {
            final updatedApp = localApp.copyWith(
              name: remoteApp.name,
              executablePath: remoteApp.executablePath, // パスも更新
              allowedMinutesPerDay: remoteApp.allowedMinutesPerDay,
              isRestricted: remoteApp.isRestricted,
              requiredPomodorosToUnlock: remoteApp.requiredPomodorosToUnlock,
              minutesPerPoint: remoteApp.minutesPerPoint,
              deviceId: remoteApp.deviceId,
              platformType: remoteApp.platformType,
              isAvailableLocally: remoteApp.isAvailableLocally,
              isDeleted: remoteApp.isDeleted,
            );

            await _dbHelper.updateRestrictedApp(updatedApp);
            print('異なるパスでFirebaseIDが一致するアプリを更新: ${remoteApp.name}');
          }
        } else {
          // 完全に新しいアプリの場合
          // 自分のデバイスのアプリか、ローカルに存在するアプリのみを追加
          if (remoteApp.deviceId == deviceId || remoteApp.isAvailableLocally) {
            final newApp = remoteApp.copyWith(
              deviceId: remoteApp.deviceId ?? deviceId,
              platformType: remoteApp.platformType ?? platformType,
            );

            await _dbHelper.insertRestrictedApp(newApp);
            print('新しいリモートアプリを追加: ${remoteApp.name}');
          } else {
            print('他デバイスの利用できないアプリはスキップ: ${remoteApp.name}');
          }
        }
      }

      // ローカルアプリをFirebaseにアップロード（FirebaseIDがないものだけ）
      for (var localApp in localApps) {
        print(localApp.firebaseId);
        if (localApp.firebaseId == null) {
          // このデバイスで作成されたアプリにデバイス情報を設定
          final updatedApp = localApp.copyWith(
            deviceId: deviceId,
            platformType: platformType,
          );

          String? newFirebaseId;
          if (_useRestApi) {
            newFirebaseId =
                await _restService.syncRestrictedApp(userId, updatedApp);
          } else {
            final appsRef = _database.child('users/$userId/restricted_apps');
            final newRef = appsRef.push();
            newFirebaseId = newRef.key;
            await newRef.set(updatedApp.toFirebase());
          }

          if (newFirebaseId != null) {
            updatedApp.firebaseId = newFirebaseId;
            await _dbHelper.updateRestrictedApp(updatedApp);
            print('新しい制限アプリをアップロード: ${updatedApp.name}');
          }
        } else {
          // 既存のアプリでFirebaseIDがある場合、更新が必要か確認
          // 削除フラグの同期なども行う
          await _updateExistingRestrictedApp(userId, localApp, remoteApps);
        }
      }

      // 同期タイムスタンプを更新
      await _settingsService.setLastSyncTime('restricted_apps', DateTime.now());
    } catch (e) {
      print('制限アプリ同期エラー: $e');
      rethrow;
    }
  }

// 既存の制限アプリを更新するヘルパーメソッド
  Future<void> _updateExistingRestrictedApp(String userId,
      RestrictedApp localApp, Map<String, dynamic> remoteApps) async {
    try {
      if (localApp.firebaseId == null ||
          !remoteApps.containsKey(localApp.firebaseId)) {
        return; // FirebaseIDがないか、リモートに存在しない場合はスキップ
      }

      final remoteData = remoteApps[localApp.firebaseId!];
      final remoteTimestamp =
          DateTime.parse(remoteData['updatedAt'] ?? '2000-01-01T00:00:00Z');

      // 論理削除の同期（ローカルで削除された場合の処理）
      if (localApp.isDeleted &&
          !remoteData['isDeleted'] &&
          localApp.updatedAt.isAfter(remoteTimestamp)) {
        // ローカルで削除され、リモートではまだ削除されていない場合、リモートに削除を反映
        if (_useRestApi) {
          await _restService.updateData(
              'users/$userId/restricted_apps/${localApp.firebaseId}', {
            'isDeleted': true,
            'updatedAt': DateTime.now().toIso8601String()
          });
        } else {
          await _database
              .child('users/$userId/restricted_apps/${localApp.firebaseId}')
              .update({
            'isDeleted': true,
            'updatedAt': DateTime.now().toIso8601String()
          });
        }
        print('ローカルの削除状態をリモートに反映: ${localApp.name}');
      } else if (!localApp.isDeleted &&
          remoteData['isDeleted'] &&
          remoteTimestamp.isAfter(localApp.updatedAt)) {
        // リモートで削除され、ローカルではまだ削除されていない場合、ローカルに削除を反映
        final updatedApp = localApp.copyWith(isDeleted: true);
        await _dbHelper.updateRestrictedApp(updatedApp);
        print('リモートの削除状態をローカルに反映: ${localApp.name}');
      } else if (!localApp.isDeleted &&
          !remoteData['isDeleted'] &&
          localApp.updatedAt.isAfter(remoteTimestamp)) {
        // 通常の更新（ローカルの方が新しい場合）
        if (_useRestApi) {
          await _restService.updateData(
              'users/$userId/restricted_apps/${localApp.firebaseId}',
              localApp.toFirebase());
        } else {
          await _database
              .child('users/$userId/restricted_apps/${localApp.firebaseId}')
              .update(localApp.toFirebase());
        }
        print('ローカルの最新情報をリモートに反映: ${localApp.name}');
      }
    } catch (e) {
      print('制限アプリ更新エラー: $e');
    }
  }

// 現在のデバイスIDを取得
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      // デバイスIDがない場合は新規作成
      final uuid = Uuid();
      deviceId = uuid.v4();
      await prefs.setString('device_id', deviceId);
    }

    return deviceId;
  }

// 現在のデバイスにアプリが存在するか確認するヘルパーメソッド
  bool _isAppAvailableLocally(RestrictedApp app, List<String> installedApps) {
    if (_platformUtils.isWindows) {
      // Windowsの場合、実行ファイルパスが存在するか確認
      return File(app.executablePath).existsSync();
    } else {
      // Androidの場合、アプリ名がインストール済みアプリに含まれるか確認
      bool isInstalled = installedApps.contains(app.name) ||
          installedApps.contains(app.executablePath);
      if (!isInstalled && app.name.startsWith("未知のアプリ: ")) {
        String cleanName = app.name.substring("未知のアプリ: ".length);
        isInstalled = installedApps.contains(cleanName);
      }
      return isInstalled;
    }
  }

// インストール済みアプリのリストを取得
  Future<List<String>> _getInstalledApps() async {
    if (_platformUtils.isWindows) {
      // WindowsではWindowsAppControllerからインストール済みアプリを取得
      try {
        //空のリストを返す
        return await WindowsAppController().getInstalledAppPaths();
      } catch (e) {
        print('インストール済みアプリ取得エラー: $e');
        return [];
      }
    } else {
      // AndroidではAndroidAppControllerからインストール済みアプリを取得
      try {
        return await AndroidAppController().getInstalledAppNames();
      } catch (e) {
        print('インストール済みアプリ取得エラー: $e');
        return [];
      }
    }
  }

  // ポイント同期 - 改良版
  Future<void> syncRewardPoints(String userId) async {
    try {
      print("ポイント同期開始 (${_useRestApi ? 'REST API' : 'SDK'})");

      // ローカルポイント取得
      final localPoints = await _dbHelper.getRewardPoints();
      print(
          '同期前のローカルポイント: 獲得=${localPoints.earnedPoints}, 使用=${localPoints.usedPoints}, 前回同期獲得=${localPoints.lastSyncEarnedPoints}, 前回同期使用=${localPoints.lastSyncUsedPoints}');

      Map<String, dynamic>? remotePointsData;
      if (_useRestApi) {
        remotePointsData = await _restService.getRewardPoints(userId);
      } else {
        final pointsRef = _database.child('users/$userId/reward_points');
        final event = await pointsRef.once();
        final snapshot = event.snapshot;

        if (snapshot.exists && snapshot.value != null) {
          snapshot.key;
          final remoteData = snapshot.value as Map<dynamic, dynamic>;
          remotePointsData = Map<String, dynamic>.from(remoteData.map(
            (k, v) => MapEntry(k.toString(), v),
          ));
        }
      }

      if (remotePointsData != null && remotePointsData.isNotEmpty) {
        RewardPoint remotePoints;
        // 直接のデータ構造かネストされた構造かをチェック
        if (remotePointsData.containsKey("lastUpdated") ||
            remotePointsData.containsKey("earnedPoints")) {
          // 直接のデータ構造（SDK）
          remotePoints = RewardPoint.fromFirebase(remotePointsData);
        } else {
          // Firebase IDを含む余分な階層（REST API）
          String firebaseId = remotePointsData.keys.first;
          var pointsData =
              Map<String, dynamic>.from(remotePointsData[firebaseId]);
          // Firebase IDを保存
          //pointsData['firebaseId'] = firebaseId;
          remotePoints = RewardPoint.fromFirebase(pointsData);
          remotePoints.firebaseId = firebaseId;
          print('リモートポイントデータ: $firebaseId}');
        }
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
          firebaseId: remotePoints.firebaseId,
          lastSyncEarnedPoints: newEarnedPoints, // 同期完了時点の値を記録
          lastSyncUsedPoints: newUsedPoints, // 同期完了時点の値を記録
        );

        // ローカルとリモートの両方を更新
        await _dbHelper.updateRewardPoints(mergedPoints);
        if (_useRestApi) {
          // REST API実装
          if (mergedPoints.firebaseId != null) {
            await _restService.updateData(
                'users/$userId/reward_points/${mergedPoints.firebaseId}',
                mergedPoints.toFirebase());
          } else {
            final newFirebaseId =
                await _restService.syncRewardPoint(userId, mergedPoints);
            if (newFirebaseId != null) {
              mergedPoints.firebaseId = newFirebaseId;
              await _dbHelper.updateRewardPoints(mergedPoints);
            }
          }
        } else {
          final pointsRef = _database.child('users/$userId/reward_points');
          if (mergedPoints.firebaseId != null) {
            // 既存のFirebase IDを使用
            await pointsRef
                .child(mergedPoints.firebaseId!)
                .set(mergedPoints.toFirebase());
          } else {
            // 新しいFirebase IDを生成
            final newPointRef = pointsRef.push();
            final newFirebaseId = newPointRef.key;
            await newPointRef.set(mergedPoints.toFirebase());

            // 新しいFirebase IDでローカルを更新
            mergedPoints.firebaseId = newFirebaseId;
            await _dbHelper.updateRewardPoints(mergedPoints);
          }
          //await pointsRef.set(mergedPoints.toFirebase());
        }

        print('ポイントデータを増分同期しました: 獲得=$newEarnedPoints, 使用=$newUsedPoints');
      } else {
        // リモートにデータがない場合、初期アップロード
        final initialPoints = localPoints.copyWith(
          lastSyncEarnedPoints: localPoints.earnedPoints,
          lastSyncUsedPoints: localPoints.usedPoints,
        );
        if (_useRestApi) {
          final newFirebaseId =
              await _restService.syncRewardPoint(userId, initialPoints);
          if (newFirebaseId != null) {
            initialPoints.firebaseId = newFirebaseId;
            await _dbHelper.updateRewardPoints(initialPoints);
          }
        } else {
          final pointsRef = _database.child('users/$userId/reward_points');
          // Firebase SDKでは同じ構造で保存するために
          final newPointRef = pointsRef.push();
          final newFirebaseId = newPointRef.key;
          await newPointRef.set(initialPoints.toFirebase());

          // 新しいFirebase IDでローカルを更新
          initialPoints.firebaseId = newFirebaseId;
          await _dbHelper.updateRewardPoints(initialPoints);
        }

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
      print("アプリ使用セッション同期開始 (${_useRestApi ? 'REST API' : 'SDK'})");
      // 前回の同期タイムスタンプ取得
      final lastSyncTime =
          await _settingsService.getLastSyncTime('app_usage_sessions');

      // ローカルセッション取得
      final List<AppUsageSession> localSessions =
          await _dbHelper.getAppUsageSessions();
      //final localSessions = await _dbHelper.getAppUsageSessions();
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
      Map<String, dynamic> remoteSessions = {};
      if (_useRestApi) {
        final remoteData =
            await _restService.getAppUsageSessions(userId, lastSyncTime);
        if (remoteData != null) {
          remoteSessions = remoteData;
        }
      } else {
        final sessionsRef = _database.child('users/$userId/app_usage_sessions');
        // Firebaseからデータ取得
        final event = await sessionsRef.once();
        final snapshot = event.snapshot;

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
      }
      // ローカルセッションのアップロード
      for (var session in localSessions) {
        if (session.firebaseId == null ||
            !remoteSessions.containsKey(session.firebaseId)) {
          String? newFirebaseId;
          if (_useRestApi) {
            newFirebaseId =
                await _restService.syncAppUsageSession(userId, session);
          } else {
            final sessionsRef =
                _database.child('users/$userId/app_usage_sessions');
            final newRef = sessionsRef.push();
            newFirebaseId = newRef.key;
            // セッションデータにアプリ情報を含める
            final sessionData = session.toFirebase();
            await newRef.set(sessionData);
          }
          if (newFirebaseId != null) {
            // ローカルのセッションにFirebase IDを保存
            session.firebaseId = newFirebaseId;
            await _dbHelper.updateAppUsageSession(session);
            print('新しいアプリ使用セッションをアップロード: ${session.appName}');
          }
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
          final deviceId = sessionData['deviceId'];
          final platformType = sessionData['platformType'];

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
            int unknownAppId = await _getOrCreateUnknownApp(appName, appPath,
                platformType: platformType, DeviceId: deviceId);

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
