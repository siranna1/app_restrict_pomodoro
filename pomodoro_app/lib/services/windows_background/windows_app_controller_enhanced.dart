// windows_app_controller_enhanced.dart
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'package:path/path.dart' as path;
import '../../models/restricted_app.dart';
import '../../services/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:typed_data';

class WindowsAppController {
  static final WindowsAppController _instance =
      WindowsAppController._internal();
  factory WindowsAppController() => _instance;

  WindowsAppController._internal();

  bool _isMonitoring = false;
  Isolate? _monitoringIsolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;
  Timer? _expirationCheckTimer;

  // ミューテックスハンドル (重複実行防止用)
  int? _mutexHandle;

  // 制限対象アプリのリスト
  List<RestrictedApp> _restrictedApps = [];

  // 今日のポモドーロ完了数
  int _completedPomodorosToday = 0;

  // ファイルベースのロック
  File? _lockFile;
  RandomAccessFile? _lockFileHandle;

  // 初期化
  Future<void> initialize() async {
    if (!Platform.isWindows) return;

    // 重複起動チェック
    if (!_checkSingleInstance()) {
      print('既に別のインスタンスが実行中です');
      return;
    }

    // DBから制限対象アプリを読み込む
    await _loadRestrictedApps();

    // 今日のポモドーロ完了数を取得
    await _loadCompletedPomodorosToday();

    // 以前の状態を復元
    await _restoreMonitoringState();
  }

  // 重複インスタンス実行チェック
  bool _checkSingleInstance() {
    try {
      // アプリケーションディレクトリ内にロックファイルを作成
      final appDir = path.dirname(Platform.resolvedExecutable);
      final lockFilePath = path.join(appDir, 'pomodoro_app.lock');
      _lockFile = File(lockFilePath);

      // 排他ロックを試行
      _lockFileHandle = _lockFile!.openSync(mode: FileMode.write);

      try {
        // 排他ロックを取得を試行
        _lockFileHandle!.lockSync(FileLock.exclusive);

        // ロックに成功
        return true;
      } catch (e) {
        // ロックに失敗（既に他のプロセスが実行中）
        _lockFileHandle!.closeSync();
        _lockFileHandle = null;
        return false;
      }
    } catch (e) {
      print('ロックファイル操作エラー: $e');
      return false;
    }
  }

  // DBから制限対象アプリを読み込む
  Future<void> _loadRestrictedApps() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query('restricted_apps');
    _restrictedApps = results.map((map) => RestrictedApp.fromMap(map)).toList();

    print('制限アプリ一覧を読み込みました（${_restrictedApps.length}件）');
  }

  // 今日のポモドーロ完了数を取得
  Future<void> _loadCompletedPomodorosToday() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();

    final results = await db.rawQuery('''
      SELECT 
        COUNT(*) as count
      FROM pomodoro_sessions
      WHERE date(startTime) = date(?)
        AND isBreak = 0
        AND completed = 1
    ''', [today]);

    if (results.isNotEmpty) {
      _completedPomodorosToday = results.first['count'] as int;
      print('今日のポモドーロ完了数: $_completedPomodorosToday');
    }
  }

  // 保存された監視状態を復元
  Future<void> _restoreMonitoringState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMonitoring = prefs.getBool('app_monitoring_enabled') ?? false;

      if (isMonitoring) {
        startMonitoring();
      }
    } catch (e) {
      print('監視状態復元エラー: $e');
    }
  }

  // 監視を開始
  void startMonitoring() async {
    if (!Platform.isWindows || _isMonitoring) return;

    _isMonitoring = true;

    // 最新の制限アプリリストを読み込む
    await _loadRestrictedApps();

    // 監視用のIsolateを起動
    _receivePort = ReceivePort();

    // Isolateに渡すパラメータ
    final params = {
      'sendPort': _receivePort!.sendPort,
      'restrictedApps': _restrictedApps.map((app) => app.toMap()).toList(),
      'completedPomodoros': _completedPomodorosToday,
    };

    // Isolateでモニタリングを開始
    _monitoringIsolate = await Isolate.spawn(
      _monitoringIsolateEntryPoint,
      params,
    );

    // メインIsolateでメッセージを受信
    _receivePort!.listen(_handleIsolateMessage);

    // SharedPreferencesに状態を保存
    _saveMonitoringState(true);

    print('アプリ監視を開始しました (Isolate)');
  }

  // 監視を停止
  void stopMonitoring() {
    if (!_isMonitoring) return;

    // Isolateを終了
    _monitoringIsolate?.kill(priority: Isolate.immediate);
    _monitoringIsolate = null;
    _receivePort?.close();
    _receivePort = null;
    _sendPort = null;

    _isMonitoring = false;

    // SharedPreferencesに状態を保存
    _saveMonitoringState(false);

    print('アプリ監視を停止しました');
  }

  // モニタリングIsolateのエントリーポイント
  static void _monitoringIsolateEntryPoint(Map<String, dynamic> params) {
    final sendPort = params['sendPort'] as SendPort;
    final restrictedApps = (params['restrictedApps'] as List)
        .map((map) => RestrictedApp.fromMap(map as Map<String, dynamic>))
        .toList();
    final completedPomodoros = params['completedPomodoros'] as int;

    // メインIsolateとの通信用ポート
    final receivePort = ReceivePort();
    sendPort.send({'type': 'port', 'port': receivePort.sendPort});

    // メインIsolateからのメッセージを受信
    receivePort.listen((message) {
      if (message is Map<String, dynamic>) {
        if (message['type'] == 'updateApps') {
          restrictedApps.clear();
          restrictedApps.addAll(
            (message['apps'] as List)
                .map(
                    (map) => RestrictedApp.fromMap(map as Map<String, dynamic>))
                .toList(),
          );
        } else if (message['type'] == 'updatePomodoros') {
          // ポモドーロ数を更新
        }
      }
    });

    // 定期的に制限アプリをチェック
    Timer.periodic(Duration(seconds: 5), (_) {
      try {
        final runningApps = _getRunningApplications();

        for (final app in restrictedApps) {
          // 制限が無効か、現在解除中の場合はスキップ
          if (!app.isRestricted || app.isCurrentlyUnlocked) continue;

          final isRunning = runningApps.any((process) =>
              process.executablePath.toLowerCase() ==
              app.executablePath.toLowerCase());

          if (isRunning) {
            // 制限中のアプリが実行されていれば終了
            _terminateApplication(app.executablePath);

            // メインIsolateに通知
            sendPort.send({
              'type': 'appRestricted',
              'appName': app.name,
              'executablePath': app.executablePath,
            });
          }
        }
      } catch (e) {
        sendPort.send({
          'type': 'error',
          'message': 'アプリ監視エラー: $e',
        });
      }
    });
  }

  // Isolateからのメッセージを処理
  void _handleIsolateMessage(dynamic message) {
    if (message is Map<String, dynamic>) {
      final type = message['type'] as String?;

      switch (type) {
        case 'port':
          _sendPort = message['port'] as SendPort;
          break;
        case 'appRestricted':
          final appName = message['appName'] as String;
          print('アプリ「$appName」を制限しました');
          _showNotification(appName);
          break;
        case 'error':
          print(message['message']);
          break;
      }
    }
  }

  // 実行中のアプリケーション一覧を取得（静的メソッド）
  static List<ProcessInfo> _getRunningApplications() {
    final processes = <ProcessInfo>[];

    // スナップショットを取得
    final hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);

    if (hSnapshot == INVALID_HANDLE_VALUE) {
      return processes;
    }

    try {
      // PROCESSENTRY32 構造体を初期化
      final pe32 = calloc<PROCESSENTRY32>();
      pe32.ref.dwSize = sizeOf<PROCESSENTRY32>();

      // 最初のプロセスを取得
      if (Process32First(hSnapshot, pe32) != 0) {
        do {
          final processId = pe32.ref.th32ProcessID;
          final executablePath = _getProcessExecutablePath(processId);

          if (executablePath.isNotEmpty) {
            processes.add(ProcessInfo(
              processId: processId,
              executablePath: executablePath,
            ));
          }
        } while (Process32Next(hSnapshot, pe32) != 0);
      }

      free(pe32);
    } finally {
      CloseHandle(hSnapshot);
    }

    return processes;
  }

  // プロセスIDから実行パスを取得（静的メソッド）
  static String _getProcessExecutablePath(int processId) {
    final hProcess = OpenProcess(
      PROCESS_QUERY_INFORMATION | PROCESS_VM_READ,
      FALSE,
      processId,
    );

    if (hProcess == 0) {
      return '';
    }

    try {
      final pathBuffer = calloc<Uint16>(MAX_PATH).cast<Utf16>();
      final len = GetModuleFileNameEx(
        hProcess,
        0,
        pathBuffer,
        MAX_PATH,
      );

      if (len == 0) {
        free(pathBuffer);
        return '';
      }

      final path = pathBuffer.toDartString();
      free(pathBuffer);
      return path;
    } finally {
      CloseHandle(hProcess);
    }
  }

  // アプリケーションを終了させる（静的メソッド）
  static void _terminateApplication(String executablePath) {
    final runningApps = _getRunningApplications();

    for (final process in runningApps) {
      if (process.executablePath.toLowerCase() ==
          executablePath.toLowerCase()) {
        final hProcess = OpenProcess(
          PROCESS_TERMINATE,
          FALSE,
          process.processId,
        );

        if (hProcess != 0) {
          TerminateProcess(hProcess, 0);
          CloseHandle(hProcess);
        }
      }
    }
  }

  // 監視状態をSharedPreferencesに保存
  Future<void> _saveMonitoringState(bool isMonitoring) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_monitoring_enabled', isMonitoring);
    } catch (e) {
      print('監視状態保存エラー: $e');
    }
  }

  // 通知を表示
  void _showNotification(String appName) {
    // Windows通知を表示（実際の実装では別の通知メカニズムを使用）
    print('アプリ「$appName」は制限されています。ポイントを使用して一時的に解除できます。');
  }

  // 完了ポモドーロ数を更新
  Future<void> updateCompletedPomodoros(int count) async {
    _completedPomodorosToday = count;

    // Isolateに通知
    _sendPort?.send({
      'type': 'updatePomodoros',
      'count': count,
    });
  }

  // 制限対象アプリを追加
  Future<void> addRestrictedApp(RestrictedApp app) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final id = await db.insert('restricted_apps', app.toMap());

      final newApp = app.copyWith(id: id);
      _restrictedApps.add(newApp);

      // Isolateに制限アプリリストの更新を通知
      _updateRestrictedAppsInIsolate();

      print('制限アプリを追加しました: ${newApp.name}');
    } catch (e) {
      print('制限アプリ追加エラー: $e');
      throw e;
    }
  }

  // 制限対象アプリを更新
  Future<void> updateRestrictedApp(RestrictedApp app) async {
    try {
      if (app.id == null) {
        throw ArgumentError('アプリIDが指定されていません');
      }

      final db = await DatabaseHelper.instance.database;
      await db.update(
        'restricted_apps',
        app.toMap(),
        where: 'id = ?',
        whereArgs: [app.id],
      );

      // メモリ内リストも更新
      final index = _restrictedApps.indexWhere((a) => a.id == app.id);
      if (index >= 0) {
        _restrictedApps[index] = app;
      }

      // Isolateに制限アプリリストの更新を通知
      _updateRestrictedAppsInIsolate();

      print('制限アプリを更新しました: ${app.name}');
    } catch (e) {
      print('制限アプリ更新エラー: $e');
      throw e;
    }
  }

  // 制限アプリリスト全体を更新
  Future<void> updateRestrictedApps(List<RestrictedApp> apps) async {
    try {
      _restrictedApps.clear();
      _restrictedApps.addAll(apps);

      // Isolateに制限アプリリストの更新を通知
      _updateRestrictedAppsInIsolate();

      // 解除期限のある最初のアプリを見つけて、チェックタイマーを設定
      _scheduleNextExpirationCheck(apps);

      print('制限アプリリストを更新しました（${apps.length}件）');
    } catch (e) {
      print('制限アプリリスト更新エラー: $e');
      throw e;
    }
  }

// 次回の解除期限チェックをスケジュール
  void _scheduleNextExpirationCheck(List<RestrictedApp> apps) {
    // 現在進行中のタイマーをキャンセル
    _expirationCheckTimer?.cancel();

    // 最も早い解除期限を持つアプリを見つける
    DateTime? nextCheckTime;
    for (final app in apps) {
      if (app.isCurrentlyUnlocked && app.currentSessionEnd != null) {
        final expireTime = app.currentSessionEnd!;
        if (nextCheckTime == null || expireTime.isBefore(nextCheckTime)) {
          nextCheckTime = expireTime;
        }
      }
    }

    // 期限がある場合は、その時間にチェックをスケジュール
    if (nextCheckTime != null) {
      final now = DateTime.now();
      final timeUntilExpiration = nextCheckTime.difference(now);

      // 有効な期間がある場合のみスケジュール（過去の日時ではない）
      if (timeUntilExpiration.isNegative) {
        // すでに期限切れなので即座にチェック
        _checkUnlockExpirations();
      } else {
        // 期限切れになる時間にタイマーをセット
        _expirationCheckTimer = Timer(timeUntilExpiration, () {
          _checkUnlockExpirations();
        });
        print('期限切れチェックタイマーを設定: ${nextCheckTime.toString()}');
      }
    }
  }

// 解除期限チェック
  Future<void> _checkUnlockExpirations() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      bool hasUpdated = false;

      // DBから直接取得して最新情報を得る
      final results = await db.query('restricted_apps');

      for (var map in results) {
        final app = RestrictedApp.fromMap(map);

        // 解除中だが期限切れの場合
        if (app.isCurrentlyUnlocked &&
            app.currentSessionEnd != null &&
            now.isAfter(app.currentSessionEnd!)) {
          // 期限をnullに設定して更新
          final updatedApp = app.copyWith(currentSessionEnd: null);
          await db.update(
            'restricted_apps',
            updatedApp.toMap(),
            where: 'id = ?',
            whereArgs: [app.id],
          );

          print("期限切れ: ${app.name}の解除を終了しました");
          hasUpdated = true;
        }
      }

      // 変更があった場合のみリスト再読み込み
      if (hasUpdated) {
        await _loadRestrictedApps();
      }

      // 次回のチェックをスケジュール
      _scheduleNextExpirationCheck(_restrictedApps);
    } catch (e) {
      print('解除期限チェックエラー: $e');
    }
  }

  // 制限対象アプリを削除
  Future<void> removeRestrictedApp(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'restricted_apps',
        where: 'id = ?',
        whereArgs: [id],
      );

      _restrictedApps.removeWhere((app) => app.id == id);

      // Isolateに制限アプリリストの更新を通知
      _updateRestrictedAppsInIsolate();

      print('制限アプリを削除しました: ID=$id');
    } catch (e) {
      print('制限アプリ削除エラー: $e');
      throw e;
    }
  }

  // Isolateに制限アプリリストを更新
  void _updateRestrictedAppsInIsolate() {
    if (_sendPort == null) return;

    _sendPort!.send({
      'type': 'updateApps',
      'apps': _restrictedApps.map((app) => app.toMap()).toList(),
    });
  }

  // 手動カウント更新メソッド
  Future<void> manualUpdatePomodoroCount() async {
    await _loadCompletedPomodorosToday();

    // Isolateに通知
    if (_sendPort != null) {
      _sendPort!.send({
        'type': 'updatePomodoros',
        'count': _completedPomodorosToday,
      });
    }

    print('ポモドーロ完了数を更新しました: $_completedPomodorosToday');
  }

  // リソース解放
  void dispose() {
    stopMonitoring();

    // ロックファイルの解放
    if (_lockFileHandle != null) {
      try {
        _lockFileHandle!.unlockSync();
        _lockFileHandle!.closeSync();
      } catch (e) {
        print('ロックファイル解放エラー: $e');
      }
      _lockFileHandle = null;
    }

    if (_mutexHandle != null) {
      CloseHandle(_mutexHandle!);
      _mutexHandle = null;
    }
  }

  // アプリが実行中かチェック（外部から呼び出し用）
  bool checkIfAppIsRunning(String executablePath) {
    final runningApps = _getRunningApplications();
    return runningApps.any((process) =>
        process.executablePath.toLowerCase() == executablePath.toLowerCase());
  }

  // アプリケーションを終了（外部から呼び出し用）
  void terminateApplication(String executablePath) {
    _terminateApplication(executablePath);
  }

  // 監視状態を取得
  bool get isMonitoring => _isMonitoring;
}

// ProcessInfo class - プロセス情報を保持するクラス
class ProcessInfo {
  final int processId;
  final String executablePath;

  ProcessInfo({
    required this.processId,
    required this.executablePath,
  });
}
