// lib/android_app_controller.dart
import 'package:flutter/services.dart';
import 'dart:async';
import './models/restricted_app.dart';

class AndroidAppController {
  static const MethodChannel _channel =
      MethodChannel('com.example.pomodoro_app/app_control');
  bool _isMonitoring = false;
  List<String> _restrictedPackages = [];

  // シングルトンパターンの実装
  static final AndroidAppController _instance =
      AndroidAppController._internal();
  factory AndroidAppController() => _instance;
  AndroidAppController._internal();

  /// 初期化処理
  Future<bool> initialize() async {
    try {
      return await _channel.invokeMethod('initialize') ?? false;
    } catch (e) {
      print('AndroidAppController初期化エラー: $e');
      return false;
    }
  }

  /// 使用統計権限があるか確認
  Future<bool> hasUsageStatsPermission() async {
    try {
      return await _channel.invokeMethod('hasUsageStatsPermission') ?? false;
    } catch (e) {
      print('権限確認エラー: $e');
      return false;
    }
  }

  /// 使用統計権限の設定画面を開く
  Future<void> openUsageStatsSettings() async {
    try {
      await _channel.invokeMethod('openUsageStatsSettings');
    } catch (e) {
      print('設定画面オープンエラー: $e');
    }
  }

  /// 監視を開始
  Future<bool> startMonitoring() async {
    if (_isMonitoring) return true;

    // 権限チェック
    final hasPermission = await hasUsageStatsPermission();
    if (!hasPermission) {
      await openUsageStatsSettings();
      return false;
    }

    try {
      final result = await _channel.invokeMethod('startMonitoring');
      _isMonitoring = result ?? false;
      return _isMonitoring;
    } catch (e) {
      print('監視開始エラー: $e');
      return false;
    }
  }

  /// 監視を停止
  Future<bool> stopMonitoring() async {
    if (!_isMonitoring) return true;

    try {
      final result = await _channel.invokeMethod('stopMonitoring');
      _isMonitoring = !(result ?? false);
      return !_isMonitoring;
    } catch (e) {
      print('監視停止エラー: $e');
      return false;
    }
  }

  /// 制限対象アプリのリストを更新
  Future<bool> updateRestrictedApps(List<RestrictedApp> apps) async {
    try {
      _restrictedPackages = apps
          .where((app) => app.isRestricted && !app.isCurrentlyUnlocked)
          .map((app) => app.executablePath)
          .toList();

      final result = await _channel.invokeMethod('updateRestrictedPackages', {
        'packages': _restrictedPackages,
      });

      return result ?? false;
    } catch (e) {
      print('制限アプリ更新エラー: $e');
      return false;
    }
  }

  /// 特定のアプリを強制終了
  Future<bool> killApp(String packageName) async {
    try {
      return await _channel.invokeMethod('killApp', {
            'packageName': packageName,
          }) ??
          false;
    } catch (e) {
      print('アプリ終了エラー: $e');
      return false;
    }
  }

  /// 現在フォアグラウンドで実行中のアプリを取得
  Future<String?> getCurrentForegroundApp() async {
    try {
      return await _channel.invokeMethod('getCurrentForegroundApp');
    } catch (e) {
      print('フォアグラウンドアプリ取得エラー: $e');
      return null;
    }
  }

  /// インストール済みアプリのリストを取得
  Future<List<Map<String, dynamic>>> getInstalledApps() async {
    try {
      final result = await _channel.invokeMethod('getInstalledApps');
      if (result is List) {
        return List<Map<String, dynamic>>.from(
          result.map((item) => Map<String, dynamic>.from(item)),
        );
      }
      return [];
    } catch (e) {
      print('インストール済みアプリ取得エラー: $e');
      return [];
    }
  }

  /// 監視状態を取得
  bool get isMonitoring => _isMonitoring;
}
