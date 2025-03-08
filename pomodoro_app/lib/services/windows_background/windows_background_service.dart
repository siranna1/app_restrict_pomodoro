// windows_background_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'windows_system_tray_service.dart';
import 'windows_app_controller_enhanced.dart';
import 'windows_autostart_manager.dart';
import 'dart:async';
import '../../models/restricted_app.dart';

/// Windows専用のバックグラウンドサービス統合クラス
/// アプリケーションの起動時に適切なモードでサービスを初期化します
class WindowsBackgroundService {
  static final WindowsBackgroundService _instance =
      WindowsBackgroundService._internal();
  factory WindowsBackgroundService() => _instance;
  WindowsBackgroundService._internal();

  // 各サービスへの参照
  final _windowsSystemTray = WindowsSystemTrayService();
  final _windowsAppController = WindowsAppController();
  final _autoStartManager = WindowsAutoStartManager();

  // 初期化済みフラグ
  bool _initialized = false;

  /// 初期化メソッド - アプリの起動時に呼び出す
  Future<void> initialize({List<String> arguments = const []}) async {
    if (!Platform.isWindows || _initialized) return;

    try {
      // 起動引数を解析
      final bool startMinimized = arguments.contains('--minimized');
      final bool startOnBoot = arguments.contains('--autostart');

      // 設定を読み込み
      final prefs = await SharedPreferences.getInstance();
      final bool serviceEnabled =
          prefs.getBool('background_service_enabled') ?? false;

      if (serviceEnabled || startOnBoot) {
        // システムトレイサービスを初期化
        await _windowsSystemTray.initialize();

        // アプリコントローラを初期化
        await _windowsAppController.initialize();

        // 自動起動時は監視を開始
        if (startOnBoot ||
            (prefs.getBool('start_monitoring_on_boot') ?? false)) {
          _windowsAppController.startMonitoring();
        }

        // 最小化する
        if (startMinimized) {
          // ウィンドウを非表示にする（Flutterアプリウィンドウを使用）
          // この部分はglobalContextからアプリウィンドウを操作する必要があります
        }
      }

      _initialized = true;
    } catch (e) {
      print('Windows バックグラウンドサービス初期化エラー: $e');
    }
  }

  /// 設定の更新
  Future<void> updateSettings({
    bool? serviceEnabled,
    bool? startMonitoringOnBoot,
    bool? autoStartEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // バックグラウンドサービスの有効/無効
    if (serviceEnabled != null) {
      await prefs.setBool('background_service_enabled', serviceEnabled);

      if (serviceEnabled) {
        // サービスを有効化
        if (!_initialized) {
          await initialize();
        }
      } else {
        // サービスを無効化（監視も停止）
        _windowsAppController.stopMonitoring();
      }
    }

    // 起動時の監視開始設定
    if (startMonitoringOnBoot != null) {
      await prefs.setBool('start_monitoring_on_boot', startMonitoringOnBoot);
    }

    // 自動起動の設定
    if (autoStartEnabled != null) {
      if (autoStartEnabled) {
        await _autoStartManager.enableAutoStart(minimized: true);
      } else {
        await _autoStartManager.disableAutoStart();
      }
    }
  }

  /// バックグラウンドで実行するためのエントリーポイント
  /// Windows向けの独立したアプリケーションとして実行する場合に使用
  static Future<void> runAsBackgroundService(List<String> arguments) async {
    // 初期化
    final service = WindowsBackgroundService();
    await service.initialize(arguments: arguments);

    // 終了されるまで実行し続ける
    if (arguments.contains('--minimized')) {
      // バックグラウンド実行モードの場合はUIなしで実行
      // 永続的なプロセスとして実行し続ける必要がある
      final completer = Completer<void>();

      // Ctrl+Cなどのシグナルをキャッチして終了処理
      ProcessSignal.sigint.watch().listen((_) {
        // 終了処理
        completer.complete();
        exit(0);
      });

      // 終了されるまで待機
      await completer.future;
    }
  }

  /// 適切なモードでアプリケーションを起動
  static Future<bool> launchInAppropriateMode() async {
    if (!Platform.isWindows) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final backgroundServiceEnabled =
          prefs.getBool('background_service_enabled') ?? false;

      if (backgroundServiceEnabled) {
        // バックグラウンドサービスが有効な場合は、現在のインスタンスが
        // 通常起動モードかどうかを確認
        final args = Platform.executableArguments;
        if (!args.contains('--minimized') && !args.contains('--autostart')) {
          // すでにバックグラウンドで実行中の場合は通知
          return false;
        }
      }

      return true;
    } catch (e) {
      print('起動モード確認エラー: $e');
      return true; // エラー時は通常モードで起動
    }
  }

  // アプリの解除情報を更新するメソッド
  Future<void> updateAppUnlockInfo(List<RestrictedApp> apps) async {
    if (!Platform.isWindows) return;

    try {
      // 制限アプリ情報をWindowsAppControllerに渡す
      await _windowsAppController.updateRestrictedApps(apps);

      // 次回の解除期限チェックをスケジュール
      _scheduleNextUnlockCheck(apps);
    } catch (e) {
      print('Windows解除情報更新エラー: $e');
    }
  }

// 次回の解除期限チェックをスケジュール
  void _scheduleNextUnlockCheck(List<RestrictedApp> apps) {
    // 最も早い解除期限を見つける
    DateTime? nextCheckTime;

    for (final app in apps) {
      if (app.isCurrentlyUnlocked && app.currentSessionEnd != null) {
        if (nextCheckTime == null ||
            app.currentSessionEnd!.isBefore(nextCheckTime)) {
          nextCheckTime = app.currentSessionEnd;
        }
      }
    }

    // 解除期限がある場合は、その時間にチェックをスケジュール
    if (nextCheckTime != null) {
      // ここでアラームやタイマーを設定
      print('次回の解除期限チェック: $nextCheckTime');
    }
  }

  /// デバッグ用のステータス情報を返す
  Future<Map<String, dynamic>> getStatusInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final isAutoStartEnabled = await _autoStartManager.isAutoStartEnabled();

    return {
      'initialized': _initialized,
      'isMonitoring': _windowsAppController.isMonitoring,
      'serviceEnabled': prefs.getBool('background_service_enabled') ?? false,
      'startOnBoot': prefs.getBool('start_monitoring_on_boot') ?? false,
      'autoStartEnabled': isAutoStartEnabled,
      'executablePath': _autoStartManager.getExecutablePath(),
      'arguments': Platform.executableArguments,
    };
  }

  /// リソースの解放
  void dispose() {
    _windowsAppController.dispose();
  }
}
