// background_sync_service.dart
import 'dart:io';

import 'package:pomodoro_app/widgets/auth_dialog.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/database_helper.dart';
import '../services/settings_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/sync_service.dart';
import '../utils/platform_utils.dart';

@pragma('vm:entry-point') // Dartコンパイラに必要なアノテーション
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Firebase初期化
      await Firebase.initializeApp();

      // ユーザーIDをInputDataから取得する方法に変更
      final userId = inputData?['userId'] as String?;
      if (userId == null) {
        print('UserID not provided for background sync');
        return false;
      }

      // サービスの初期化（AuthServiceは使わない）
      final databaseHelper = DatabaseHelper();
      await databaseHelper.initialize();

      final settingsService = SettingsService();
      await settingsService.init();

      final AuthService authService = AuthService();
      await authService.initialize();
      final syncService =
          SyncService(databaseHelper, settingsService, authService);

      // 同期処理（事前に取得したユーザーIDを使用）
      await syncService.syncAll(userId);

      return true;
    } catch (e) {
      print('Background sync error: $e');
      return false;
    }
  });
}

class BackgroundSyncService {
  static const String syncTaskName = 'jp.example.pomodoroapp.sync';

  // 初期化
  Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  // 定期同期のスケジュール
  Future<void> schedulePeriodicSync(int intervalMinutes) async {
    PlatformUtils platformUtils = PlatformUtils();
    if (platformUtils.isWindows) return;

    // ここでUIスレッドからユーザーIDを取得
    final authService = AuthService();
    final userId = authService.userId;

    if (userId != null) {
      await Workmanager().registerPeriodicTask(
        syncTaskName,
        syncTaskName,
        frequency: Duration(minutes: intervalMinutes),
        inputData: {'userId': userId}, // ユーザーIDを渡す
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    }
  }

  // 同期のキャンセル
  Future<void> cancelSync() async {
    PlatformUtils platformUtils = PlatformUtils();
    if (platformUtils.isWindows) return;
    await Workmanager().cancelByUniqueName(syncTaskName);
  }
}
