// providers/app_restriction_provider.dart - アプリ制限管理のProvider
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:win32/win32.dart';
import '../models/restricted_app.dart';
import '../models/reward_point.dart';
import '../models/app_usage_session.dart';
import '../services/database_helper.dart';
import '../windows_app_controller.dart';
import '../android_app_controller.dart';
import '../utils/platform_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AppRestrictionProvider with ChangeNotifier {
  final _windowsAppController = WindowsAppController();
  final _androidAppController = AndroidAppController();
  // 権限ガイドが必要かを示すフラグ
  bool _needsPermissionGuide = false;
  // 権限ガイドが必要かどうかを取得
  bool get needsPermissionGuide => _needsPermissionGuide;
  bool isMonitoring = false;
  List<RestrictedApp> restrictedApps = [];
  Timer? _unlockExpirationTimer; //アプリ解除後の残り時間確認用タイマー
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

  @override
  void dispose() {
    _unlockExpirationTimer?.cancel();
    super.dispose();
  }

  AppRestrictionProvider() {
    _instance = this; // インスタンスを保存
    _initializeController();
    _loadRestrictedApps();
    _loadRewardPoints();
    _loadMonitoringState();
    _checkUnlockExpirations();
    //_startUnlockExpirationChecker();
  }

  void _startUnlockExpirationChecker() {
    // 既存のタイマーをキャンセル
    _unlockExpirationTimer?.cancel();

    // 60秒ごとに解除期限をチェック
    _unlockExpirationTimer = Timer.periodic(Duration(seconds: 60), (_) {
      _checkUnlockExpirations();
    });
  }

  // 静的メソッドを追加
  static Future<void> notifyPomodoroCompleted() async {
    if (_instance != null) {
      await _instance!.onPomodoroCompleted();
    }
  }

  static Future<bool> checkExpirations() async {
    if (_instance != null) {
      return await _instance!._checkAndUpdateExpirations();
    }
    return false;
  }

  Future<void> _initializeController() async {
    final platformUtils = PlatformUtils();
    if (platformUtils.isWindows) {
      await _windowsAppController.initialize();
    } else if (platformUtils.isAndroid) {
      await _androidAppController.initialize();

      // 権限チェック
      final hasPermission =
          await _androidAppController.hasUsageStatsPermission();
      if (!hasPermission) {
        _needsPermissionGuide = true;
        print("使用状況へのアクセス権限がありません。権限ガイドを表示します。");
      } else {
        print("使用状況へのアクセス権限があります。監視機能が利用可能です。");
      }
    } else {
      print("未サポートのプラットフォームです。");
    }
  }

  Future<void> _loadRestrictedApps() async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query('restricted_apps');

    // 現在時刻を取得
    final now = DateTime.now();

    // アプリごとに期限チェックしつつリストを作成
    List<RestrictedApp> apps = [];
    for (var map in results) {
      final app = RestrictedApp.fromMap(map);

      // 解除中だが期限切れの場合は制限状態に戻す
      if (app.isCurrentlyUnlocked &&
          app.currentSessionEnd != null &&
          now.isAfter(app.currentSessionEnd!)) {
        // 期限切れなので更新
        final updatedApp = app.copyWith(currentSessionEnd: null);
        await db.update(
          'restricted_apps',
          updatedApp.toMap(),
          where: 'id = ?',
          whereArgs: [app.id],
        );

        // 更新したアプリを追加
        apps.add(updatedApp);
        print("${app.name}の解除期限が切れていたため、制限状態に戻しました");
      } else {
        // 通常のアプリを追加
        apps.add(app);
      }
    }

    restrictedApps = apps;
    notifyListeners();

    // サービスに最新の状態を通知
    if (isMonitoring) {
      await _updateAndroidMonitoringServiceAppList();
    }
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
  void startMonitoring() async {
    final platformUtils = PlatformUtils();
    // 監視開始前に解除期限をチェック
    await _checkUnlockExpirations();

    if (platformUtils.isWindows) {
      _windowsAppController.startMonitoring();
      isMonitoring = true;
    } else if (platformUtils.isAndroid) {
      // 権限チェック
      final hasPermission =
          await _androidAppController.hasUsageStatsPermission();
      if (!hasPermission) {
        _needsPermissionGuide = true;
        notifyListeners();
        return;
      }

      // 制限対象アプリリストを更新
      //await _androidAppController.updateRestrictedApps(restrictedApps);
      _updateAndroidMonitoringServiceAppList();

      // サービスとして監視開始
      print("Androidサービスとして監視を開始します");
      final success = await _startAndroidMonitoringService();
      isMonitoring = success;
      print("Android監視の開始結果: $success");
    }

    if (isMonitoring) {
      _saveMonitoringState(true);
    }
    notifyListeners();
  }

  // 監視を停止
  void stopMonitoring() async {
    final platformUtils = PlatformUtils();

    if (platformUtils.isWindows) {
      _windowsAppController.stopMonitoring();
    } else if (platformUtils.isAndroid) {
      await _stopAndroidMonitoringService();
    }
    isMonitoring = false;
    _saveMonitoringState(false); // 状態を保存
    notifyListeners();
  }

  // Android版のサービス起動・停止メソッドを追加
  Future<bool> _startAndroidMonitoringService() async {
    try {
      print("AndroidサービスをアプリリストでStartします");
      final restrictedPackageNames = restrictedApps
          .where((app) => app.isRestricted && !app.isCurrentlyUnlocked)
          .map((app) => app.executablePath)
          .toList();
      print("監視対象パッケージ: $restrictedPackageNames");

      final result = await _androidAppController.startMonitoringService(
        restrictedPackageNames,
      );
      print("サービス開始結果: $result");
      return result;
    } catch (e) {
      print('Android監視サービス起動エラー: $e');
      return false;
    }
  }

  // Android版のサービス更新メソッドを追加
  Future<void> _updateAndroidMonitoringServiceAppList() async {
    if (!PlatformUtils().isAndroid) return;

    try {
      // 現在制限対象になっているアプリのリストを取得（解除状態のものを除く）
      //final restrictedPackageNames = restrictedApps
      //    .where((app) => app.isRestricted && !app.isCurrentlyUnlocked)
      //    .map((app) => app.executablePath)
      //    .toList();
//
      //print("サービスに更新する監視対象パッケージ: $restrictedPackageNames");

      // サービスに制限リスト更新を通知
      //await _androidAppController.updateRestrictedApps(restrictedPackageNames);
      await _androidAppController.updateRestrictedApps(restrictedApps);
    } catch (e) {
      print('Android監視対象アプリ更新エラー: $e');
    }
  }

  Future<void> _stopAndroidMonitoringService() async {
    try {
      await _androidAppController.stopMonitoringService();
    } catch (e) {
      print('Android監視サービス停止エラー: $e');
    }
  }

  // 制限対象アプリを追加
  Future<bool> addRestrictedApp(RestrictedApp app) async {
    try {
      print("アプリ追加開始: 名前=${app.name}");
      // プラットフォームを検出
      final platformUtils = PlatformUtils();

      // プラットフォームに応じて処理を分岐
      if (platformUtils.isWindows) {
        // Windows用の処理
        await _windowsAppController.addRestrictedApp(app);
      } else if (platformUtils.isAndroid) {
        // Android用の処理 - SQLiteに直接追加
        final db = await DatabaseHelper.instance.database;
        await db.insert('restricted_apps', app.toMap());
      }

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

      // プラットフォームを検出
      final platformUtils = PlatformUtils();

      // プラットフォームに応じて処理を分岐
      if (platformUtils.isWindows) {
        // Windows用の処理
        await _windowsAppController.updateRestrictedApp(app);
        // 更新成功後にリストを再読み込み
        await _loadRestrictedApps();
      } else if (platformUtils.isAndroid) {
        // Android用の処理 - SQLiteに直接更新
        final db = await DatabaseHelper.instance.database;
        await db.update(
          'restricted_apps',
          app.toMap(),
          where: 'id = ?',
          whereArgs: [app.id],
        );
        // 更新成功後にリストを再読み込み
        await _loadRestrictedApps();

        // 監視中なら制限リストを更新
        //if (isMonitoring) {
        await _updateAndroidMonitoringServiceAppList();
        //}
      }

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

      // プラットフォームを検出
      final platformUtils = PlatformUtils();

      // プラットフォームに応じて処理を分岐
      if (platformUtils.isAndroid) {
        await _androidAppController.registerAppUnlock(
          app.executablePath,
          unlockUntil.millisecondsSinceEpoch,
        );
        print("Android側に解除情報を通知: ${app.name}, 期限: $unlockUntil");
      }

      return true;
    } catch (e) {
      print('アプリ解除中にエラーが発生: $e');
      return false;
    }
  }

  Future<void> _checkUnlockExpirations() async {
    print("解除期限チェックを実行中...");
    bool needsUpdate = false;
    //RestrictedApp needUpdateApp = restrictedApps.first;
    final now = DateTime.now();
    final platformUtils = PlatformUtils();

    // 解除期限が切れたアプリを確認
    for (final app in restrictedApps) {
      if (app.isCurrentlyUnlocked && app.currentSessionEnd != null) {
        if (now.isAfter(app.currentSessionEnd!)) {
          print("${app.name}の解除期限が切れました。制限を再開します。");

          // アプリの解除状態をリセット
          final updatedApp = app.copyWith(currentSessionEnd: null);
          //needUpdateApp = updatedApp;
          await DatabaseHelper.instance.updateRestrictedApp(updatedApp);

          // 現在のインスタンスも更新
          final index = restrictedApps.indexWhere((a) => a.id == app.id);
          if (index >= 0) {
            restrictedApps[index] = updatedApp;
          }

          needsUpdate = true;
        }
      }
    }

    // 変更があった場合のみ監視サービスを更新
    if (needsUpdate) {
      // サービスに制限リスト更新を通知
      if (isMonitoring) {
        if (platformUtils.isAndroid) {
          // Android側のサービスに制限リスト更新を通知
          await _updateAndroidMonitoringServiceAppList();
        } else if (platformUtils.isWindows) {
          // Windows側の監視に制限リスト更新を通知
          await _windowsAppController.manualUpdatePomodoroCount();

          // Windows用の追加更新処理（更新されたアプリリストを反映）
          for (var app in restrictedApps) {
            if (app.id != null) {
              await _windowsAppController.updateRestrictedApp(app);
            }
          }
        }
      }
      notifyListeners();
    }
  }

  // アプリが実行中でなくても動作する期限切れチェック
  // アンドロイド用
  Future<bool> _checkAndUpdateExpirations() async {
    print("バックグラウンドで解除期限チェックを実行中...");
    bool needsUpdate = false;

    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();

      // DBから直接制限アプリを取得して期限をチェック
      final results = await db.query('restricted_apps');

      for (var row in results) {
        final app = RestrictedApp.fromMap(row);

        // 解除中だが期限切れの場合
        if (app.currentSessionEnd != null &&
            now.isAfter(app.currentSessionEnd!)) {
          print("${app.name}の解除期限が切れました。制限を再開します。");

          // 期限をnullに設定して更新
          final updatedData = app.copyWith(currentSessionEnd: null).toMap();
          await db.update(
            'restricted_apps',
            updatedData,
            where: 'id = ?',
            whereArgs: [app.id],
          );

          needsUpdate = true;
        }
      }

      // メモリ内のリストも更新
      if (needsUpdate) {
        await _loadRestrictedApps();

        // 監視サービスに通知
        if (isMonitoring) {
          final platformUtils = PlatformUtils();

          if (platformUtils.isAndroid) {
            await _updateAndroidMonitoringServiceAppList();
          } else if (platformUtils.isWindows) {
            await _windowsAppController.manualUpdatePomodoroCount();
          }
        }

        notifyListeners();
      }

      return needsUpdate;
    } catch (e) {
      print("バックグラウンド期限チェックエラー: $e");
      return false;
    }
  }

  // 権限ガイドを表示するメソッド（外部から呼び出し可能）
  void showPermissionGuideIfNeeded(BuildContext context) {
    if (!_needsPermissionGuide) return;

    // フラグをリセット
    _needsPermissionGuide = false;

    // ダイアログとして表示
    showDialog(
      context: context,
      barrierDismissible: false, // ユーザーがダイアログ外をタップしても閉じない
      builder: (dialogContext) => AlertDialog(
        title: const Text('権限が必要です'),
        content: const Text('アプリ制限機能を使用するには「使用状況へのアクセス」権限が必要です。\n\n'
            'この権限により、ポモドーロセッション中に制限対象アプリを検出して自動的に終了させることができます。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // ダイアログを閉じる
            },
            child: const Text('後で行う'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop(); // ダイアログを閉じる

              // 権限設定画面を開く
              await _androidAppController.openUsageStatsSettings();

              // 設定から戻ってきたら権限を再確認（少し遅延を入れる）
              Future.delayed(const Duration(seconds: 1), () async {
                final hasPermission =
                    await _androidAppController.hasUsageStatsPermission();
                if (hasPermission) {
                  // 権限を取得できた場合の処理
                  // 例: 監視を開始する
                  if (isMonitoring) {
                    startMonitoring();
                  }
                } else {
                  // まだ権限がない場合は再度フラグを立てる
                  _needsPermissionGuide = true;
                  notifyListeners();
                }
              });
            },
            child: const Text('権限を設定する'),
          ),
        ],
      ),
    );
  }

  /// 必要な権限を持っているかチェックするメソッド
  Future<bool> hasPermission() async {
    final platformUtils = PlatformUtils();

    if (platformUtils.isAndroid) {
      // Androidの場合はUsageStats権限をチェック
      return await _androidAppController.hasUsageStatsPermission();
    } else if (platformUtils.isWindows) {
      // Windowsの場合は常にtrueを返す（特別な権限は不要）
      return true;
    }

    // その他のプラットフォームではfalseを返す
    return false;
  }

  /// オーバーレイ権限があるかチェック (Android専用)
  Future<bool> hasOverlayPermission() async {
    final platformUtils = PlatformUtils();
    if (!platformUtils.isAndroid) return true;

    try {
      return await _androidAppController.hasOverlayPermission();
    } catch (e) {
      print('オーバーレイ権限チェックエラー: $e');
      return false;
    }
  }

  /// オーバーレイ権限リクエスト (Android専用)
  Future<void> requestOverlayPermission() async {
    final platformUtils = PlatformUtils();
    if (!platformUtils.isAndroid) return;

    try {
      await _androidAppController.requestOverlayPermission();
    } catch (e) {
      print('オーバーレイ権限リクエストエラー: $e');
    }
  }

  /// バッテリー最適化設定の確認と通知
  Future<void> checkAndRequestBatteryOptimization(BuildContext context) async {
    if (!PlatformUtils().isAndroid) return;

    // 現在のバッテリー最適化状態を確認
    final isIgnored =
        await _androidAppController.isBatteryOptimizationIgnored();

    if (!isIgnored && context.mounted) {
      // まだ確認していない場合は確認ダイアログを表示
      bool shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('バッテリー最適化の設定'),
              content: const Text(
                'アプリ制限機能を正常に動作させるには、バッテリー最適化を無効にすることをお勧めします。\n\n'
                'これにより、アプリがバックグラウンドでも正常に動作するようになります。',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('後で行う'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('設定を開く'),
                ),
              ],
            ),
          ) ??
          false;

      // ユーザーが「設定を開く」を選択した場合のみ設定画面に遷移
      if (shouldOpenSettings && context.mounted) {
        await _androidAppController.openBatteryOptimizationSettings();
      }
    }
  }
}
