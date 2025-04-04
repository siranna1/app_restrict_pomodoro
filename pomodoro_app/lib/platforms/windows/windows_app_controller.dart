// windows_app_controller.dart - Windowsアプリ制御実装
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import '../../models/restricted_app.dart';
import '../../services/database_helper.dart';

class WindowsAppController {
  static final WindowsAppController _instance =
      WindowsAppController._internal();
  factory WindowsAppController() => _instance;

  WindowsAppController._internal();

  bool _isMonitoring = false;

  // 制限対象アプリのリスト
  List<RestrictedApp> _restrictedApps = [];

  // 今日のポモドーロ完了数
  int _completedPomodorosToday = 0;

  // 初期化
  Future<void> initialize() async {
    if (!Platform.isWindows) return;

    // DBから制限対象アプリを読み込む
    await _loadRestrictedApps();

    // 今日のポモドーロ完了数を取得
    await _loadCompletedPomodorosToday();
  }

  // DBから制限対象アプリを読み込む
  Future<void> _loadRestrictedApps() async {
    final db = await DatabaseHelper.instance.database;
    final results =
        await db.query('restricted_apps', where: 'isRestricted = 1');
    _restrictedApps = results.map((map) => RestrictedApp.fromMap(map)).toList();
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
    ''', [today]);
    if (results.isNotEmpty) {
      _completedPomodorosToday = results.first['count'] as int;
      print('今日のポモドーロ完了数を読み込み: $_completedPomodorosToday');
    }

    if (results.isNotEmpty) {
      _completedPomodorosToday = results.first['count'] as int;
    }
  }

  // 監視を開始
  void startMonitoring() {
    if (!Platform.isWindows || _isMonitoring) return;

    _isMonitoring = true;
    _monitorApps();
  }

  // 監視を停止
  void stopMonitoring() {
    _isMonitoring = false;
  }

  // アプリの監視処理
  Future<void> _monitorApps() async {
    if (!Platform.isWindows) return;
    while (_isMonitoring) {
      final runningApps = _getRunningApplications();

      for (final app in _restrictedApps) {
        // 制限が無効か、現在解除中の場合はスキップ
        if (!app.isRestricted || app.isCurrentlyUnlocked) continue;

        final isRunning = runningApps.any((process) =>
            process.executablePath.toLowerCase() ==
            app.executablePath.toLowerCase());

        if (isRunning) {
          // 制限中のアプリが実行されていれば終了
          _terminateApplication(app.executablePath);
          _showNotification(app);
        }
      }

      // 一定間隔で監視
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  // 実行中のアプリケーション一覧を取得
  List<ProcessInfo> _getRunningApplications() {
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

  // プロセスIDから実行パスを取得
  String _getProcessExecutablePath(int processId) {
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

  // アプリケーションを終了させる
  void _terminateApplication(String executablePath) {
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

  // 通知を表示
  void _showNotification(RestrictedApp app) {
    // トースト通知を表示（実際にはFlutterの通知機能を使用）
    // この例では簡略化のためにコンソール出力のみ
    // print('アプリ実行中: ${app.name}');
    // print('制限状態: ${app.isRestricted}');
    // print('完了ポモドーロ数: $_completedPomodorosToday');
    // print('必要ポモドーロ数: ${app.requiredPomodorosToUnlock}');
    print('アプリ「${app.name}」は制限されています。ポイントを使用して一時的に解除できます。');
  }

  // 完了ポモドーロ数を更新
  Future<void> updateCompletedPomodoros(int count) async {
    _completedPomodorosToday = count;
  }

  // 制限対象アプリを追加
  Future<void> addRestrictedApp(RestrictedApp app) async {
    try {
      print("WindowsAppController: アプリ追加開始");

      final db = await DatabaseHelper.instance.database;
      final Map<String, dynamic> appMap = app.toMap();

      // requiredPomodorosToUnlockフィールドに値が確実に設定されていることを確認
      if (appMap['requiredPomodorosToUnlock'] == null) {
        appMap['requiredPomodorosToUnlock'] = 0; // デフォルト値を設定
      }

      final id = await db.insert('restricted_apps', appMap);
      print("WindowsAppController: 追加されたアプリのID: $id");

      // 新しいアプリをIDを付けてメモリ内リストに追加
      final newApp = app.copyWith(id: id);
      _restrictedApps.add(newApp);
      print("WindowsAppController: メモリ内リスト更新完了");
    } catch (e) {
      print("WindowsAppController: アプリ追加中にエラー発生: $e");
      // エラーを再スロー
      rethrow;
    }
  }

  // 制限対象アプリを更新
  Future<void> updateRestrictedApp(RestrictedApp app) async {
    try {
      app.toMap();
      print("WindowsAppController: アプリ更新開始 ID=${app.id}");

      // IDが存在することを確認
      if (app.id == null) {
        print("WindowsAppController: エラー - IDがnullです");
        return;
      }

      final db = await DatabaseHelper.instance.database;

      final updateResult = await db.update(
        'restricted_apps',
        app.toMap(),
        where: 'id = ?',
        whereArgs: [app.id],
      );

      print("WindowsAppController: 更新された行数: $updateResult");

      if (updateResult == 0) {
        print("WindowsAppController: 警告 - 更新対象のレコードが見つかりません ID=${app.id}");
      }

      // メモリ内リストも更新
      final index = _restrictedApps.indexWhere((a) => a.id == app.id);
      if (index >= 0) {
        _restrictedApps[index] = app;
        print("WindowsAppController: メモリ内リスト更新完了");
      } else {
        print("WindowsAppController: 警告 - メモリ内リストに該当アプリがありません");
      }
    } catch (e) {
      print("WindowsAppController: アプリ更新中にエラー発生: $e");
      rethrow;
    }
  }

  // 制限対象アプリを削除
  Future<void> removeRestrictedApp(int id) async {
    _restrictedApps.removeWhere((app) => app.id == id);
  }

  // 手動カウント更新メソッド
  Future<void> manualUpdatePomodoroCount() async {
    print("WindowsAppController.manualUpdatePomodoroCount が呼ばれました");
    await _loadCompletedPomodorosToday();
    print("更新後のポモドーロカウント: $_completedPomodorosToday");
  }

  Future<List<String>> getInstalledAppPaths() {
    //windowsだと使われないっぽいから、空を返す
    return Future.value([]);
  }

  // 自動起動の設定
  Future<bool> setAutoStart(bool enabled) async {
    if (!Platform.isWindows) return false;

    try {
      final appPath = Platform.resolvedExecutable;

      final keyPath = 'Software\\Microsoft\\Windows\\CurrentVersion\\Run';
      final valueName = 'PomodoroApp';

      // レジストリキーを開く
      final hKey = calloc<HKEY>();
      final result = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        TEXT(keyPath),
        0,
        KEY_SET_VALUE | KEY_QUERY_VALUE,
        hKey,
      );

      if (result != ERROR_SUCCESS) {
        free(hKey);
        return false;
      }

      if (enabled) {
        // 自動起動設定を追加
        final pathPointer = TEXT('$appPath --start-minimized');
        final valueSize = pathPointer.length * 2;

        final regSetResult = RegSetValueEx(
          hKey.value,
          TEXT(valueName),
          0,
          REG_SZ,
          pathPointer.cast<Uint8>(),
          valueSize,
        );

        free(pathPointer);
        RegCloseKey(hKey.value);
        free(hKey);

        return regSetResult == ERROR_SUCCESS;
      } else {
        // 自動起動設定を削除
        final regDelResult = RegDeleteValue(
          hKey.value,
          TEXT(valueName),
        );

        RegCloseKey(hKey.value);
        free(hKey);

        return regDelResult == ERROR_SUCCESS;
      }
    } catch (e) {
      print('自動起動設定エラー: $e');
      return false;
    }
  }

// 自動起動設定の確認
  Future<bool> isAutoStartEnabled() async {
    if (!Platform.isWindows) return false;

    try {
      final keyPath = 'Software\\Microsoft\\Windows\\CurrentVersion\\Run';
      final valueName = 'PomodoroApp';

      // レジストリキーを開く
      final hKey = calloc<HKEY>();
      final result = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        TEXT(keyPath),
        0,
        KEY_QUERY_VALUE,
        hKey,
      );

      if (result != ERROR_SUCCESS) {
        free(hKey);
        return false;
      }

      // 値を確認
      final valueType = calloc<DWORD>();
      final dataSize = calloc<DWORD>();
      dataSize.value = 0;

      final queryResult = RegQueryValueEx(
        hKey.value,
        TEXT(valueName),
        nullptr,
        valueType,
        nullptr,
        dataSize,
      );

      RegCloseKey(hKey.value);
      free(hKey);
      free(valueType);
      free(dataSize);

      return queryResult == ERROR_SUCCESS;
    } catch (e) {
      print('自動起動設定確認エラー: $e');
      return false;
    }
  }
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
