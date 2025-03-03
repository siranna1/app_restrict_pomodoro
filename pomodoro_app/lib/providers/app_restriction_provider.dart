// providers/app_restriction_provider.dart - アプリ制限管理のProvider
import 'package:flutter/material.dart';
import '../models/restricted_app.dart';
import '../models/reward_point.dart';
import '../models/app_usage_session.dart';
import '../services/database_helper.dart';
import '../windows_app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppRestrictionProvider with ChangeNotifier {
  final _windowsAppController = WindowsAppController();
  List<RestrictedApp> restrictedApps = [];
  bool isMonitoring = false;
  // late を削除し、初期値を設定
  RewardPoint rewardPoints = RewardPoint(
    earnedPoints: 0,
    usedPoints: 0,
    lastUpdated: DateTime.now(),
  );

  // 利用可能なポイント数を取得
  int get availablePoints => rewardPoints.availablePoints;

  // 獲得ポイント数を取得
  int get earnedPoints => rewardPoints.earnedPoints;

  // 使用ポイント数を取得
  int get usedPoints => rewardPoints.usedPoints;

  static AppRestrictionProvider? _instance;

  AppRestrictionProvider() {
    _instance = this; // インスタンスを保存
    _initializeController();
    _loadRestrictedApps();
    _loadRewardPoints();
    _loadMonitoringState();
  }

  // 静的メソッドを追加
  static Future<void> notifyPomodoroCompleted() async {
    if (_instance != null) {
      await _instance!.onPomodoroCompleted();
    }
  }

  Future<void> _initializeController() async {
    await _windowsAppController.initialize();
  }

  Future<void> _loadRestrictedApps() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query('restricted_apps');
    restrictedApps = results.map((map) => RestrictedApp.fromMap(map)).toList();
    notifyListeners();
  }

  Future<void> _loadRewardPoints() async {
    try {
      final loadedPoints = await DatabaseHelper.instance.getRewardPoints();
      rewardPoints = loadedPoints;
      notifyListeners();
    } catch (e) {
      print('ポイント読み込みエラー: $e');
      // デフォルト値はすでにコンストラクタで設定されているため、
      // エラー時にも最低限の機能は維持される
    }
  }

  // 監視状態を SharedPreferences から読み込む
  Future<void> _loadMonitoringState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedState = prefs.getBool('app_monitoring_enabled') ?? false;

      // 保存されていた状態が true の場合のみ監視を開始
      if (savedState) {
        _windowsAppController.startMonitoring();
        isMonitoring = true;
        notifyListeners();
      }
    } catch (e) {
      print('監視状態の読み込みエラー: $e');
    }
  }

  // 監視状態を SharedPreferences に保存
  Future<void> _saveMonitoringState(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_monitoring_enabled', enabled);
    } catch (e) {
      print('監視状態の保存エラー: $e');
    }
  }

  // 監視を開始
  void startMonitoring() {
    _windowsAppController.startMonitoring();
    isMonitoring = true;
    _saveMonitoringState(true); // 状態を保存
    notifyListeners();
  }

  // 監視を停止
  void stopMonitoring() {
    _windowsAppController.stopMonitoring();
    isMonitoring = false;
    _saveMonitoringState(false); // 状態を保存
    notifyListeners();
  }

  // 制限対象アプリを追加
  Future<bool> addRestrictedApp(RestrictedApp app) async {
    try {
      print("アプリ追加開始: 名前=${app.name}");

      // データベース追加
      await _windowsAppController.addRestrictedApp(app);

      // 追加成功後にリストを再読み込み
      await _loadRestrictedApps();

      print("アプリ追加完了: ${app.name}");
      return true;
    } catch (e) {
      print("アプリ追加中にエラーが発生しました: $e");
      return false;
    }
  }

  // 制限対象アプリを更新
  Future<void> updateRestrictedApp(RestrictedApp app) async {
    try {
      print("アプリ更新開始: ID=${app.id}, 名前=${app.name}");

      // IDが存在することを確認
      if (app.id == null) {
        print("エラー: アプリIDがnullです");
        return;
      }

      // データベース更新
      await _windowsAppController.updateRestrictedApp(app);

      // 更新成功後にリストを再読み込み
      await _loadRestrictedApps();

      print("アプリ更新完了: ${app.name}");
    } catch (e) {
      print("アプリ更新中にエラーが発生しました: $e");
      // エラーを再スロー（UIでキャッチできるように）
      rethrow;
    }
  }

  // 制限対象アプリを削除
  Future<void> removeRestrictedApp(int id) async {
    await _windowsAppController.removeRestrictedApp(id);
    await _loadRestrictedApps();
  }

  // ポモドーロ完了時に呼び出し - ポイント獲得
  Future<void> onPomodoroCompleted() async {
    try {
      // 1ポイント加算
      await DatabaseHelper.instance.addEarnedPoints(1);
      await _windowsAppController.manualUpdatePomodoroCount();
      await _loadRewardPoints();

      print("ポモドーロ完了でポイント追加: +1ポイント");
    } catch (e) {
      print('ポイント追加中にエラーが発生: $e');
    }
  }

  // アプリの解除にポイントを使用
  Future<bool> unlockApp(RestrictedApp app, int points) async {
    // ポイント不足の場合
    if (rewardPoints.availablePoints < points) {
      return false;
    }

    try {
      // ポイントを使用
      final success = await DatabaseHelper.instance.usePoints(points);
      if (!success) return false;

      // 使用時間を計算（ポイント数 × 1ポイント当たりの分数）
      final minutes = points * app.minutesPerPoint;
      final unlockUntil = DateTime.now().add(Duration(minutes: minutes));

      // アプリのセッション終了時間を更新
      final updatedApp = app.copyWith(currentSessionEnd: unlockUntil);
      await updateRestrictedApp(updatedApp);

      // 使用セッションを記録
      final session = AppUsageSession(
        appId: app.id!,
        startTime: DateTime.now(),
        endTime: unlockUntil,
        pointsSpent: points,
      );
      await DatabaseHelper.instance.insertAppUsageSession(session);

      // ポイント更新
      await _loadRewardPoints();

      return true;
    } catch (e) {
      print('アプリ解除中にエラーが発生: $e');
      return false;
    }
  }
}
