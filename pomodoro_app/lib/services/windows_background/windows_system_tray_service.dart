// windows_system_tray_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';
import 'package:path/path.dart' as path;
//import '../../platforms/windows/windows_app_controller.dart';
import 'windows_app_controller_enhanced.dart';
import '../../services/database_helper.dart';
import '../../models/restricted_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class WindowsSystemTrayService {
  final SystemTray _systemTray = SystemTray();
  final AppWindow _appWindow = AppWindow();
  final WindowsAppController _windowsAppController = WindowsAppController();
  // システムクラスを初期化
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Timer? _monitorTimer;
  bool _isMonitoring = false;
  List<RestrictedApp> _restrictedApps = [];

  // シングルトンパターン
  static final WindowsSystemTrayService _instance =
      WindowsSystemTrayService._internal();
  factory WindowsSystemTrayService() => _instance;
  WindowsSystemTrayService._internal();

  // 初期化
  Future<void> initialize() async {
    // システムトレイアイコンを設定
    await _setupSystemTray();

    // 制限アプリリストを読み込み
    await _loadRestrictedApps();

    // 監視状態を復元（SharedPreferencesなどから）
    await _restoreMonitoringState();
  }

  // システムトレイの設定
  Future<void> _setupSystemTray() async {
    String iconPath = 'assets/app_icon.ico';

    // デバッグビルドで実行時にアセットパスを調整
    if (Directory.current.path.endsWith('build/windows/runner/Debug') ||
        Directory.current.path.endsWith('build/windows/runner/Release')) {
      iconPath = path.join(
          Directory.current.path, 'data/flutter_assets/assets/app_icon.ico');
    }

    // システムトレイのアイコンを設定
    await _systemTray.initSystemTray(
      toolTip: 'ポモドーロアプリ',
      iconPath: iconPath,
    );

    // メニューの作成
    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: '監視を開始',
        onClicked: (_) => startMonitoring(),
      ),
      MenuItemLabel(
        label: '監視を停止',
        onClicked: (_) => stopMonitoring(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'アプリを表示',
        onClicked: (_) => _appWindow.show(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '終了',
        onClicked: (_) => exit(0),
      ),
    ]);

    // システムトレイにメニューを設定
    await _systemTray.setContextMenu(menu);

    // トレイアイコンクリック時の動作
    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        _appWindow.show();
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });
  }

  // 制限アプリの読み込み
  Future<void> _loadRestrictedApps() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query('restricted_apps');
      _restrictedApps =
          results.map((map) => RestrictedApp.fromMap(map)).toList();
      print('制限アプリを${_restrictedApps.length}件読み込みました');
    } catch (e) {
      print('制限アプリ読み込みエラー: $e');
    }
  }

  // 監視状態の復元
  Future<void> _restoreMonitoringState() async {
    try {
      // SharedPreferencesから監視状態を読み込む
      final prefs = await SharedPreferences.getInstance();
      final isMonitoring = prefs.getBool('app_monitoring_enabled') ?? false;

      if (isMonitoring) {
        startMonitoring();
      }
    } catch (e) {
      print('監視状態復元エラー: $e');
    }
  }

  // 監視の開始
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _windowsAppController.initialize();

    // 5秒ごとに監視
    _monitorTimer = Timer.periodic(Duration(seconds: 5), (_) {
      _checkRestrictedApps();
    });

    // SharedPreferencesに状態を保存
    _saveMonitoringState(true);

    // トレイ通知
    _systemTray.setToolTip('ポモドーロアプリ（監視中）');
    _systemTray.setImage('assets/app_icon_active.ico');
  }

  // 監視の停止
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;

    // SharedPreferencesに状態を保存
    _saveMonitoringState(false);

    // トレイ通知を元に戻す
    _systemTray.setToolTip('ポモドーロアプリ');
    _systemTray.setImage('assets/app_icon.ico');
  }

  // 制限アプリの確認
  Future<void> _checkRestrictedApps() async {
    if (!_isMonitoring) return;

    try {
      // 最新の制限アプリリストを読み込む（解除期限も考慮）
      await _loadRestrictedApps();

      // 制限対象アプリのみ抽出
      final restrictedList = _restrictedApps
          .where((app) => app.isRestricted && !app.isCurrentlyUnlocked)
          .toList();

      // WindowsAppControllerに制限リストを渡して処理
      for (var app in restrictedList) {
        final isRunning =
            _windowsAppController.checkIfAppIsRunning(app.executablePath);
        if (isRunning) {
          _windowsAppController.terminateApplication(app.executablePath);
          _showNotification(app);
        }
      }
    } catch (e) {
      print('制限アプリ確認エラー: $e');
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

  // 通知の表示
  void _showNotification(RestrictedApp app) {
    // 通知設定
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'pomodoro_channel',
      'ポモドーロ通知',
      channelDescription: 'ポモドーロタイマーの通知チャンネル',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // 通知表示
    flutterLocalNotificationsPlugin.show(
      0,
      'アプリ制限',
      'アプリ「${app.name}」は制限されています。ポイントを使用して一時的に解除できます。',
      platformChannelSpecifics,
    );
  }

  // 監視状態を取得
  bool get isMonitoring => _isMonitoring;
}
