// windows_app_controller.dart - Windowsアプリ制御実装
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import '../models/restricted_app.dart';
import '../services/database_helper.dart';

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
      SELECT COUNT(*) as count
      FROM pomodoro_sessions
      WHERE date(startTime) = date(?) AND completed = 1
    ''', [today]);

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
        final isRunning = runningApps.any((process) =>
            process.executablePath.toLowerCase() ==
            app.executablePath.toLowerCase());

        if (isRunning) {
          // アプリが実行中で、制限条件に合致する場合は終了させる
          if (_completedPomodorosToday < app.requiredPomodorosToUnlock) {
            _terminateApplication(app.executablePath);
            _showNotification(app);
          }
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

  // 通知を表示
  void _showNotification(RestrictedApp app) {
    // トースト通知を表示（実際にはFlutterの通知機能を使用）
    // この例では簡略化のためにコンソール出力のみ
    print('アプリ「${app.name}」はポモドーロ ${app.requiredPomodorosToUnlock} 回の完了が必要です');
  }

  // 完了ポモドーロ数を更新
  Future<void> updateCompletedPomodoros(int count) async {
    _completedPomodorosToday = count;
  }

  // 制限対象アプリを追加
  Future<void> addRestrictedApp(RestrictedApp app) async {
    final db = await DatabaseHelper.instance.database;
    final id = await db.insert('restricted_apps', app.toMap());

    final newApp = app.copyWith(id: id);
    _restrictedApps.add(newApp);
  }

  // 制限対象アプリを更新
  Future<void> updateRestrictedApp(RestrictedApp app) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'restricted_apps',
      app.toMap(),
      where: 'id = ?',
      whereArgs: [app.id],
    );

    final index = _restrictedApps.indexWhere((a) => a.id == app.id);
    if (index >= 0) {
      _restrictedApps[index] = app;
    }
  }

  // 制限対象アプリを削除
  Future<void> removeRestrictedApp(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'restricted_apps',
      where: 'id = ?',
      whereArgs: [id],
    );

    _restrictedApps.removeWhere((app) => app.id == id);
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
