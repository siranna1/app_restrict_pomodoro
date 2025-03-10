// background_sync_service.dart
import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/database_helper.dart';
import '../services/settings_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/sync_service.dart';

@pragma('vm:entry-point') // Dartコンパイラに必要なアノテーション
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Firebase初期化
      await Firebase.initializeApp();

      // サービスの初期化
      final databaseHelper = DatabaseHelper();
      await databaseHelper.initialize();

      final settingsService = SettingsService();
      await settingsService.init();

      final authService = AuthService();
      final syncService = SyncService(databaseHelper, settingsService);

      // 同期処理
      final userId = authService.userId;
      if (userId != null) {
        await syncService.syncAll(userId);
      }

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
    await Workmanager().registerPeriodicTask(
      syncTaskName,
      syncTaskName,
      frequency: Duration(minutes: intervalMinutes),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  // 同期のキャンセル
  Future<void> cancelSync() async {
    await Workmanager().cancelByUniqueName(syncTaskName);
  }
}
