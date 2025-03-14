// lib/android_app_controller.dart
import 'package:flutter/services.dart';
import 'dart:async';
import '../../models/restricted_app.dart';
import '../../providers/app_restriction_provider.dart';

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

  static void staticInitialize() {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  // メソッドコールハンドラー
  static Future<dynamic> _methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case 'checkUnlockExpirations':
        return await AppRestrictionProvider.checkExpirations();
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'Method ${call.method} not implemented',
        );
    }
  }

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

  // android_app_controller.dart に以下のメソッドを追加

  /// サービスとして監視を開始
  Future<bool> startMonitoringService(List<String> packages) async {
    print('startMonitoringService: $packages');
    try {
      return await _channel.invokeMethod('startMonitoringService', {
            'packages': packages,
          }) ??
          false;
    } catch (e) {
      print('サービス起動エラー: $e');
      return false;
    }
  }

  /// サービスを停止
  Future<bool> stopMonitoringService() async {
    try {
      return await _channel.invokeMethod('stopMonitoringService') ?? false;
    } catch (e) {
      print('サービス停止エラー: $e');
      return false;
    }
  }

  /// サービスが実行中かどうかを確認
  Future<bool> isServiceRunning() async {
    try {
      return await _channel.invokeMethod('isServiceRunning') ?? false;
    } catch (e) {
      print('サービス状態確認エラー: $e');
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

      print("制限対象のアプリ: $_restrictedPackages");

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

  Future<List<String>> getInstalledAppNames() async {
    try {
      final installedApps = await getInstalledApps();
      return installedApps.map((app) => app['packageName'] as String).toList();
    } catch (e) {
      print('インストール済みアプリ名取得エラー: $e');
      return [];
    }
  }

  /// オーバーレイ権限があるか確認
  Future<bool> hasOverlayPermission() async {
    try {
      return await _channel.invokeMethod('checkOverlayPermission') ?? false;
    } catch (e) {
      print('オーバーレイ権限確認エラー: $e');
      return false;
    }
  }

  /// オーバーレイ権限の設定画面を開く
  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      print('オーバーレイ権限リクエストエラー: $e');
    }
  }

  /// バッテリー最適化が無効になっているか確認
  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      return await _channel.invokeMethod('checkBatteryOptimization') ?? false;
    } catch (e) {
      print('バッテリー最適化状態確認エラー: $e');
      return false;
    }
  }

  /// バッテリー最適化設定画面を開く
  Future<void> openBatteryOptimizationSettings() async {
    try {
      await _channel.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      print('バッテリー最適化設定画面オープンエラー: $e');
    }
  }

  // アプリ解除情報を登録
  Future<bool> registerAppUnlock(
      String packageName, int expiryTimeMillis) async {
    try {
      return await _channel.invokeMethod('registerAppUnlock', {
            'packageName': packageName,
            'expiryTime': expiryTimeMillis,
          }) ??
          false;
    } catch (e) {
      print('アプリ解除登録エラー: $e');
      return false;
    }
  }

  /// 監視状態を取得
  bool get isMonitoring => _isMonitoring;
}
