// providers/sync_provider.dart を修正
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pomodoro_app/services/firebase/auth_service.dart';
import 'package:pomodoro_app/services/firebase/sync_service.dart';
import 'package:pomodoro_app/services/settings_service.dart';
import 'package:pomodoro_app/services/network_connectivity.dart';
import 'package:pomodoro_app/services/background_sync_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pomodoro_app/providers/pomodoro_provider.dart';

class SyncProvider with ChangeNotifier {
  final AuthService _authService;
  final SyncService _syncService;
  final SettingsService _settingsService;
  final NetworkConnectivity _networkConnectivity;
  final BackgroundSyncService _backgroundSyncService;

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _error;
  Timer? _syncTimer;

  SyncProvider(
    this._authService,
    this._syncService,
    this._settingsService,
    this._networkConnectivity,
    this._backgroundSyncService,
  ) {
    // 初期化時に自動同期を設定
    _setupAutoSync();
    // 認証状態変更リスナーを追加
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      // 認証状態が変わったらリスナーに通知
      notifyListeners();
    });
  }

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get error => _error;
  bool get isAuthenticated => _authService.userId != null;
  String? get userEmail => FirebaseAuth.instance.currentUser?.email;

  // 同期処理
  Future<bool> sync() async {
    if (_isSyncing) return false;

    // 接続チェック
    final isConnected = await _networkConnectivity.isConnected();
    if (!isConnected) {
      _error = "ネットワーク接続がありません";
      notifyListeners();
      return false;
    }

    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      // 認証確認
      String? userId = _authService.userId;
      if (userId == null) {
        _error = "認証が必要です";
        _isSyncing = false;
        notifyListeners();
        return false;
      }

      // 全データ同期
      await _syncService.syncAll(userId);
      _lastSyncTime = DateTime.now();
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = "同期エラー: $e";
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  // 自動同期の設定
  void _setupAutoSync() {
    // 既存のタイマーをキャンセル
    _syncTimer?.cancel();

    // 自動同期が有効で、間隔が設定されている場合のみタイマーを開始
    if (_settingsService.autoSyncEnabled) {
      final syncInterval =
          Duration(minutes: _settingsService.autoSyncIntervalMinutes);
      _syncTimer = Timer.periodic(syncInterval, (_) {
        if (isAuthenticated) {
          sync();
        }
      });

      // バックグラウンドサービスの設定
      _backgroundSyncService
          .schedulePeriodicSync(_settingsService.autoSyncIntervalMinutes);
    } else {
      // 自動同期無効の場合はバックグラウンド同期をキャンセル
      _backgroundSyncService.cancelSync();
    }
  }

  // 同期間隔の変更
  void updateSyncInterval(int minutes) {
    _settingsService.setAutoSyncInterval(minutes);
    _setupAutoSync();
  }

  // 自動同期の有効/無効切り替え
  void toggleAutoSync(bool enabled) {
    _settingsService.setAutoSyncEnabled(enabled);
    _setupAutoSync();
    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
