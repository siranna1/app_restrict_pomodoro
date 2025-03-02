// services/settings_service.dart - 設定管理サービス
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリケーション全体の設定を管理するサービスクラス
///
/// すべての設定項目へのアクセスと永続化を一元管理します。
/// ChangeNotifierを継承しているため、設定変更時に依存UIを更新できます。
class SettingsService with ChangeNotifier {
  // シングルトンパターンの実装
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;

  // SharedPreferencesインスタンス
  SharedPreferences? _prefs;
  bool _initialized = false;

  // プライベートコンストラクタ
  SettingsService._internal();

  /// サービスを初期化し、保存された設定を読み込みます
  Future<void> init() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  /// サービスが初期化されているかどうかを確認し、必要に応じて初期化します
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  // ポモドーロタイマー設定 --------------------------------------------------

  /// 作業時間（分）を取得します
  Future<int> getWorkDuration() async {
    await _ensureInitialized();
    return _prefs?.getInt(_Keys.workDuration) ?? _Defaults.workDuration;
  }

  /// 作業時間（分）を設定します
  Future<void> setWorkDuration(int minutes) async {
    await _ensureInitialized();
    await _prefs?.setInt(_Keys.workDuration, minutes);
    notifyListeners();
  }

  /// 短い休憩時間（分）を取得します
  Future<int> getShortBreakDuration() async {
    await _ensureInitialized();
    return _prefs?.getInt(_Keys.shortBreakDuration) ??
        _Defaults.shortBreakDuration;
  }

  /// 短い休憩時間（分）を設定します
  Future<void> setShortBreakDuration(int minutes) async {
    await _ensureInitialized();
    await _prefs?.setInt(_Keys.shortBreakDuration, minutes);
    notifyListeners();
  }

  /// 長い休憩時間（分）を取得します
  Future<int> getLongBreakDuration() async {
    await _ensureInitialized();
    return _prefs?.getInt(_Keys.longBreakDuration) ??
        _Defaults.longBreakDuration;
  }

  /// 長い休憩時間（分）を設定します
  Future<void> setLongBreakDuration(int minutes) async {
    await _ensureInitialized();
    await _prefs?.setInt(_Keys.longBreakDuration, minutes);
    notifyListeners();
  }

  /// 長い休憩までのポモドーロ数を取得します
  Future<int> getLongBreakInterval() async {
    await _ensureInitialized();
    return _prefs?.getInt(_Keys.longBreakInterval) ??
        _Defaults.longBreakInterval;
  }

  /// 長い休憩までのポモドーロ数を設定します
  Future<void> setLongBreakInterval(int count) async {
    await _ensureInitialized();
    await _prefs?.setInt(_Keys.longBreakInterval, count);
    notifyListeners();
  }

  /// 1日の目標ポモドーロ数を取得します
  Future<int> getDailyTargetPomodoros() async {
    await _ensureInitialized();
    return _prefs?.getInt(_Keys.dailyTargetPomodoros) ??
        _Defaults.dailyTargetPomodoros;
  }

  /// 1日の目標ポモドーロ数を設定します
  Future<void> setDailyTargetPomodoros(int count) async {
    await _ensureInitialized();
    await _prefs?.setInt(_Keys.dailyTargetPomodoros, count);
    notifyListeners();
  }

  // 通知と音声設定 --------------------------------------------------

  /// 通知が有効かどうかを取得します
  Future<bool> getNotificationsEnabled() async {
    await _ensureInitialized();
    return _prefs?.getBool(_Keys.enableNotifications) ??
        _Defaults.enableNotifications;
  }

  /// 通知の有効/無効を設定します
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _ensureInitialized();
    await _prefs?.setBool(_Keys.enableNotifications, enabled);
    notifyListeners();
  }

  /// 効果音が有効かどうかを取得します
  Future<bool> getSoundsEnabled() async {
    await _ensureInitialized();
    return _prefs?.getBool(_Keys.enableSounds) ?? _Defaults.enableSounds;
  }

  /// 効果音の有効/無効を設定します
  Future<void> setSoundsEnabled(bool enabled) async {
    await _ensureInitialized();
    await _prefs?.setBool(_Keys.enableSounds, enabled);
    notifyListeners();
  }

  /// バイブレーションが有効かどうかを取得します
  Future<bool> getVibrationEnabled() async {
    await _ensureInitialized();
    return _prefs?.getBool(_Keys.enableVibration) ?? _Defaults.enableVibration;
  }

  /// バイブレーションの有効/無効を設定します
  Future<void> setVibrationEnabled(bool enabled) async {
    await _ensureInitialized();
    await _prefs?.setBool(_Keys.enableVibration, enabled);
    notifyListeners();
  }

  // 制限アプリ設定 --------------------------------------------------

  /// アプリ監視が有効かどうかを取得します
  Future<bool> getAppMonitoringEnabled() async {
    await _ensureInitialized();
    return _prefs?.getBool(_Keys.appMonitoringEnabled) ??
        _Defaults.appMonitoringEnabled;
  }

  /// アプリ監視の有効/無効を設定します
  Future<void> setAppMonitoringEnabled(bool enabled) async {
    await _ensureInitialized();
    await _prefs?.setBool(_Keys.appMonitoringEnabled, enabled);
    notifyListeners();
  }

  /// バックグラウンドサービスが有効かどうかを取得します
  Future<bool> getBackgroundServiceEnabled() async {
    await _ensureInitialized();
    return _prefs?.getBool(_Keys.autoStartBackgroundService) ??
        _Defaults.autoStartBackgroundService;
  }

  /// バックグラウンドサービスの有効/無効を設定します
  Future<void> setBackgroundServiceEnabled(bool enabled) async {
    await _ensureInitialized();
    await _prefs?.setBool(_Keys.autoStartBackgroundService, enabled);
    notifyListeners();
  }

  // 外観設定 --------------------------------------------------

  /// テーマモードを取得します
  Future<ThemeMode> getThemeMode() async {
    await _ensureInitialized();
    String themeModeString =
        _prefs?.getString(_Keys.themeMode) ?? _Defaults.themeMode;
    return _stringToThemeMode(themeModeString);
  }

  /// テーマモードを設定します
  Future<void> setThemeMode(ThemeMode mode) async {
    await _ensureInitialized();
    await _prefs?.setString(_Keys.themeMode, _themeModeToString(mode));
    notifyListeners();
  }

  /// テーマモード名をThemeModeに変換
  ThemeMode _stringToThemeMode(String themeModeString) {
    switch (themeModeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  /// ThemeModeを文字列に変換
  String _themeModeToString(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }

  /// 画面表示を継続するかどうかを取得します (Android専用)
  Future<bool> getKeepScreenOn() async {
    await _ensureInitialized();
    return _prefs?.getBool(_Keys.keepScreenOn) ?? _Defaults.keepScreenOn;
  }

  /// 画面表示を継続するかどうかを設定します (Android専用)
  Future<void> setKeepScreenOn(bool enabled) async {
    await _ensureInitialized();
    await _prefs?.setBool(_Keys.keepScreenOn, enabled);
    notifyListeners();
  }

  // その他の設定 --------------------------------------------------

  /// 起動時に自動起動するかどうかを取得します
  Future<bool> getAutoStartEnabled() async {
    await _ensureInitialized();
    return _prefs?.getBool(_Keys.autoStartEnabled) ??
        _Defaults.autoStartEnabled;
  }

  /// 起動時に自動起動するかどうかを設定します
  Future<void> setAutoStartEnabled(bool enabled) async {
    await _ensureInitialized();
    await _prefs?.setBool(_Keys.autoStartEnabled, enabled);
    notifyListeners();
  }

  /// TickTickとの連携が有効かどうかを取得します
  Future<bool> getTickTickIntegrationEnabled() async {
    await _ensureInitialized();
    return _prefs?.getBool(_Keys.tickTickIntegrationEnabled) ??
        _Defaults.tickTickIntegrationEnabled;
  }

  /// TickTickとの連携の有効/無効を設定します
  Future<void> setTickTickIntegrationEnabled(bool enabled) async {
    await _ensureInitialized();
    await _prefs?.setBool(_Keys.tickTickIntegrationEnabled, enabled);
    notifyListeners();
  }

  /// TickTickのアクセストークンを取得します
  Future<String?> getTickTickAccessToken() async {
    await _ensureInitialized();
    return _prefs?.getString(_Keys.tickTickAccessToken);
  }

  /// TickTickのアクセストークンを設定します
  Future<void> setTickTickAccessToken(String token) async {
    await _ensureInitialized();
    await _prefs?.setString(_Keys.tickTickAccessToken, token);
    // ここでは通知しない - 内部実装の詳細
  }

  /// TickTickのリフレッシュトークンを取得します
  Future<String?> getTickTickRefreshToken() async {
    await _ensureInitialized();
    return _prefs?.getString(_Keys.tickTickRefreshToken);
  }

  /// TickTickのリフレッシュトークンを設定します
  Future<void> setTickTickRefreshToken(String token) async {
    await _ensureInitialized();
    await _prefs?.setString(_Keys.tickTickRefreshToken, token);
    // ここでは通知しない - 内部実装の詳細
  }

  /// TickTickトークンの有効期限を取得します
  Future<DateTime?> getTickTickTokenExpiry() async {
    await _ensureInitialized();
    final expiryMs = _prefs?.getInt(_Keys.tickTickTokenExpiry);
    if (expiryMs != null) {
      return DateTime.fromMillisecondsSinceEpoch(expiryMs);
    }
    return null;
  }

  /// TickTickトークンの有効期限を設定します
  Future<void> setTickTickTokenExpiry(DateTime expiry) async {
    await _ensureInitialized();
    await _prefs?.setInt(
        _Keys.tickTickTokenExpiry, expiry.millisecondsSinceEpoch);
    // ここでは通知しない - 内部実装の詳細
  }

  /// すべての設定をデフォルト値にリセットします
  Future<void> resetAllSettings() async {
    await _ensureInitialized();

    // TickTickトークンは保持する
    final String? tickTickAccessToken = await getTickTickAccessToken();
    final String? tickTickRefreshToken = await getTickTickRefreshToken();
    final DateTime? tickTickTokenExpiry = await getTickTickTokenExpiry();

    // すべての設定をクリア
    await _prefs?.clear();

    // TickTickトークンを復元
    if (tickTickAccessToken != null) {
      await setTickTickAccessToken(tickTickAccessToken);
    }
    if (tickTickRefreshToken != null) {
      await setTickTickRefreshToken(tickTickRefreshToken);
    }
    if (tickTickTokenExpiry != null) {
      await setTickTickTokenExpiry(tickTickTokenExpiry);
    }

    notifyListeners();
  }
}

/// 設定キーの定義
class _Keys {
  // ポモドーロタイマー設定
  static const String workDuration = 'workDuration';
  static const String shortBreakDuration = 'shortBreakDuration';
  static const String longBreakDuration = 'longBreakDuration';
  static const String longBreakInterval = 'longBreakInterval';
  static const String dailyTargetPomodoros = 'dailyTargetPomodoros';

  // 通知と音声設定
  static const String enableNotifications = 'enableNotifications';
  static const String enableSounds = 'enableSounds';
  static const String enableVibration = 'enableVibration';

  // 制限アプリ設定
  static const String appMonitoringEnabled = 'app_monitoring_enabled';
  static const String autoStartBackgroundService = 'autoStartBackgroundService';

  // 外観設定
  static const String themeMode = 'themeMode';
  static const String keepScreenOn = 'keepScreenOn';

  // その他の設定
  static const String autoStartEnabled = 'autoStartEnabled';
  static const String tickTickIntegrationEnabled = 'tickTickIntegrationEnabled';

  // TickTick連携
  static const String tickTickAccessToken = 'ticktick_access_token';
  static const String tickTickRefreshToken = 'ticktick_refresh_token';
  static const String tickTickTokenExpiry = 'ticktick_token_expiry';
}

/// デフォルト設定値の定義
class _Defaults {
  // ポモドーロタイマー設定
  static const int workDuration = 25;
  static const int shortBreakDuration = 5;
  static const int longBreakDuration = 15;
  static const int longBreakInterval = 4;
  static const int dailyTargetPomodoros = 8;

  // 通知と音声設定
  static const bool enableNotifications = true;
  static const bool enableSounds = true;
  static const bool enableVibration = true;

  // 制限アプリ設定
  static const bool appMonitoringEnabled = false;
  static const bool autoStartBackgroundService = false;

  // 外観設定
  static const String themeMode = 'system';
  static const bool keepScreenOn = true;

  // その他の設定
  static const bool autoStartEnabled = false;
  static const bool tickTickIntegrationEnabled = false;
}
