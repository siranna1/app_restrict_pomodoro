/ services/app_platform_service.dart - プラットフォーム固有のサービス抽象クラス
import 'package:shared_preferences/shared_preferences.dart';

// プラットフォーム固有の機能を提供する抽象クラス
abstract class AppPlatformService {
  // アプリをバックグラウンドで実行できるかどうか
  bool get supportsBackgroundExecution;
  
  // アプリ制限機能をサポートしているかどうか
  bool get supportsAppRestriction;
  
  // 設定を初期化
  Future<void> initializeSettings();
  
  // 通知をサポートしているかどうか
  bool get supportsNotifications;

  // バイブレーションをサポートしているかどうか
  bool get supportsVibration;
  
  // バイブレーションを実行
  Future<void> vibrate();
  
  // スタートアップ時に自動実行するように設定
  Future<bool> setAutoStartEnabled(bool enabled);
  
  // スタートアップ時に自動実行が有効かどうか
  Future<bool> isAutoStartEnabled();
}

// Windowsプラットフォーム向けの実装
class WindowsPlatformService implements AppPlatformService {
  @override
  bool get supportsBackgroundExecution => true;
  
  @override
  bool get supportsAppRestriction => true;
  
  @override
  bool get supportsNotifications => true;
  
  @override
  bool get supportsVibration => false;
  
  @override
  Future<void> initializeSettings() async {
    // Windows固有の設定初期化
    final prefs = await SharedPreferences.getInstance();
    
    // デフォルト設定が存在しない場合は初期値を設定
    if (!prefs.containsKey('workDuration')) {
      await prefs.setInt('workDuration', 25);
    }
    if (!prefs.containsKey('shortBreakDuration')) {
      await prefs.setInt('shortBreakDuration', 5);
    }
    if (!prefs.containsKey('longBreakDuration')) {
      await prefs.setInt('longBreakDuration', 15);
    }
    if (!prefs.containsKey('longBreakInterval')) {
      await prefs.setInt('longBreakInterval', 4);
    }
    if (!prefs.containsKey('enableNotifications')) {
      await prefs.setBool('enableNotifications', true);
    }
    if (!prefs.containsKey('enableSounds')) {
      await prefs.setBool('enableSounds', true);
    }
    if (!prefs.containsKey('themeMode')) {
      await prefs.setString('themeMode', 'system');
    }
  }
  
  @override
  Future<void> vibrate() async {
    // Windowsではバイブレーション非対応
    return;
  }
  
  @override
  Future<bool> setAutoStartEnabled(bool enabled) async {
    // Windowsのレジストリに自動起動設定を書き込む
    // 実際の実装ではWin32 APIを使用してレジストリを操作
    try {
      // Windowsレジストリに設定を書き込むコード
      // 例: HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('autoStartEnabled', enabled);
      return true;
    } catch (e) {
      print('自動起動の設定に失敗しました: $e');
      return false;
    }
  }
  
  @override
  Future<bool> isAutoStartEnabled() async {
    // 自動起動が有効かどうかを確認
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('autoStartEnabled') ?? false;
    } catch (e) {
      print('自動起動設定の取得に失敗しました: $e');
      return false;
    }
  }
}

// Androidプラットフォーム向けの実装
class AndroidPlatformService implements AppPlatformService {
  @override
  bool get supportsBackgroundExecution => true;
  
  @override
  bool get supportsAppRestriction => false;
  
  @override
  bool get supportsNotifications => true;
  
  @override
  bool get supportsVibration => true;
  
  @override
  Future<void> initializeSettings() async {
    // Android固有の設定初期化
    final prefs = await SharedPreferences.getInstance();
    
    // デフォルト設定が存在しない場合は初期値を設定
    if (!prefs.containsKey('workDuration')) {
      await prefs.setInt('workDuration', 25);
    }
    if (!prefs.containsKey('shortBreakDuration')) {
      await prefs.setInt('shortBreakDuration', 5);
    }
    if (!prefs.containsKey('longBreakDuration')) {
      await prefs.setInt('longBreakDuration', 15);
    }
    if (!prefs.containsKey('longBreakInterval')) {
      await prefs.setInt('longBreakInterval', 4);
    }
    if (!prefs.containsKey('enableNotifications')) {
      await prefs.setBool('enableNotifications', true);
    }
    if (!prefs.containsKey('enableSounds')) {
      await prefs.setBool('enableSounds', true);
    }
    if (!prefs.containsKey('enableVibration')) {
      await prefs.setBool('enableVibration', true);
    }
    if (!prefs.containsKey('themeMode')) {
      await prefs.setString('themeMode', 'system');
    }
    if (!prefs.containsKey('keepScreenOn')) {
      await prefs.setBool('keepScreenOn', true);
    }
  }
  
  @override
  Future<void> vibrate() async {
    // バイブレーション実行
    // 実際の実装ではVibration pluginを使用
    try {
      // HapticFeedback.vibrate() などを使用
    } catch (e) {
      print('バイブレーション実行エラー: $e');
    }
  }
  
  @override
  Future<bool> setAutoStartEnabled(bool enabled) async {
    // Androidでは直接自動起動を設定できないため、
    // ユーザーに設定方法を案内する必要がある
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoStartEnabled', enabled);
    return true;
  }
  
  @override
  Future<bool> isAutoStartEnabled() async {
    // 自動起動設定の状態を確認
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('autoStartEnabled') ?? false;
  }
}

// iOSプラットフォーム向けの実装
class IOSPlatformService implements AppPlatformService {
  @override
  bool get supportsBackgroundExecution => false;
  
  @override
  bool get supportsAppRestriction => false;
  
  @override
  bool get supportsNotifications => true;
  
  @override
  bool get supportsVibration => true;
  
  @override
  Future<void> initializeSettings() async {
    // iOS固有の設定初期化
    final prefs = await SharedPreferences.getInstance();
    
    // デフォルト設定が存在しない場合は初期値を設定
    if (!prefs.containsKey('workDuration')) {
      await prefs.setInt('workDuration', 25);
    }
    if (!prefs.containsKey('shortBreakDuration')) {
      await prefs.setInt('shortBreakDuration', 5);
    }
    if (!prefs.containsKey('longBreakDuration')) {
      await prefs.setInt('longBreakDuration', 15);
    }
    if (!prefs.containsKey('longBreakInterval')) {
      await prefs.setInt('longBreakInterval', 4);
    }
    if (!prefs.containsKey('enableNotifications')) {
      await prefs.setBool('enableNotifications', true);
    }
    if (!prefs.containsKey('enableSounds')) {
      await prefs.setBool('enableSounds', true);
    }
    if (!prefs.containsKey('enableVibration')) {
      await prefs.setBool('enableVibration', true);
    }
    if (!prefs.containsKey('themeMode')) {
      await prefs.setString('themeMode', 'system');
    }
  }
  
  @override
  Future<void> vibrate() async {
    // バイブレーション実行
    try {
      // HapticFeedback.vibrate() などを使用
    } catch (e) {
      print('バイブレーション実行エラー: $e');
    }
  }
  
  @override
  Future<bool> setAutoStartEnabled(bool enabled) async {
    // iOSでは自動起動をサポートしていないため、何もしない
    return false;
  }
  
  @override
  Future<bool> isAutoStartEnabled() async {
    // iOSでは自動起動をサポートしていないため、常にfalse
    return false;
  }
}

// デフォルトのプラットフォームサービス（未対応プラットフォーム用）
class DefaultPlatformService implements AppPlatformService {
  @override
  bool get supportsBackgroundExecution => false;
  
  @override
  bool get supportsAppRestriction => false;
  
  @override
  bool get supportsNotifications => false;
  
  @override
  bool get supportsVibration => false;
  
  @override
  Future<void> initializeSettings() async {
    // 基本設定のみ初期化
    final prefs = await SharedPreferences.getInstance();
    
    if (!prefs.containsKey('workDuration')) {
      await prefs.setInt('workDuration', 25);
    }
    if (!prefs.containsKey('shortBreakDuration')) {
      await prefs.setInt('shortBreakDuration', 5);
    }
    if (!prefs.containsKey('longBreakDuration')) {
      await prefs.setInt('longBreakDuration', 15);
    }
    if (!prefs.containsKey('longBreakInterval')) {
      await prefs.setInt('longBreakInterval', 4);
    }
    if (!prefs.containsKey('themeMode')) {
      await prefs.setString('themeMode', 'system');
    }
  }
  
  @override
  Future<void> vibrate() async {
    // 何もしない
    return;
  }
  
  @override
  Future<bool> setAutoStartEnabled(bool enabled) async {
    // サポートされていないため、常にfalse
    return false;
  }
  
  @override
  Future<bool> isAutoStartEnabled() async {
    // サポートされていないため、常にfalse
    return false;
  }
}
