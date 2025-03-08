// windows_autostart_manager.dart
import 'dart:io';
import 'dart:ffi';
import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

/// Windowsの自動起動を管理するクラス
/// レジストリを使用して、アプリケーションの自動起動を設定または解除します
class WindowsAutoStartManager {
  static final WindowsAutoStartManager _instance =
      WindowsAutoStartManager._internal();
  factory WindowsAutoStartManager() => _instance;
  WindowsAutoStartManager._internal();

  // アプリ名（レジストリのキー名として使用）
  final String _appName = 'PomodoroAppMonitor';

  /// 自動起動を有効にする
  ///
  /// [executablePath] 実行ファイルのパス。指定しない場合は現在の実行ファイルを使用
  /// [minimized] 最小化状態で起動するかどうか
  Future<bool> enableAutoStart(
      {String? executablePath, bool minimized = true}) async {
    if (!Platform.isWindows) return false;

    try {
      final exePath = executablePath ?? getExecutablePath();
      if (exePath == null) {
        print('実行ファイルのパスを取得できませんでした');
        return false;
      }

      final command = minimized ? '$exePath --minimized' : exePath;

      return _setRegistryValue(_appName, command);
    } catch (e) {
      print('自動起動設定エラー: $e');
      return false;
    }
  }

  /// 自動起動を無効にする
  Future<bool> disableAutoStart() async {
    if (!Platform.isWindows) return false;

    try {
      return _deleteRegistryValue(_appName);
    } catch (e) {
      print('自動起動解除エラー: $e');
      return false;
    }
  }

  /// 自動起動が有効かどうかを確認
  Future<bool> isAutoStartEnabled() async {
    if (!Platform.isWindows) return false;

    try {
      return _getRegistryValue(_appName) != null;
    } catch (e) {
      print('自動起動確認エラー: $e');
      return false;
    }
  }

  /// レジストリに値を設定
  bool _setRegistryValue(String valueName, String value) {
    // レジストリキーをオープン
    final keyPath = r'SOFTWARE\Microsoft\Windows\CurrentVersion\Run';
    final keyPathUtf16 = keyPath.toNativeUtf16();
    final hKey = calloc<HANDLE>();

    final result = RegOpenKeyEx(
      HKEY_CURRENT_USER,
      keyPathUtf16,
      0,
      KEY_WRITE,
      hKey,
    );

    if (result != ERROR_SUCCESS) {
      calloc.free(hKey);
      print('レジストリキーを開けませんでした: $result');
      return false;
    }

    try {
      // UTF-16文字列に変換
      final valueNameUtf16 = valueName.toNativeUtf16();
      final valueUtf16 = value.toNativeUtf16();

      // 値の型とサイズを設定
      final valueSize = value.length * 2 + 2; // null終端文字を含む

      // レジストリに値を書き込み
      final setResult = RegSetValueEx(
        hKey.value,
        valueNameUtf16,
        0,
        REG_SZ,
        valueUtf16.cast<Uint8>(),
        valueSize,
      );

      // メモリ解放
      calloc.free(valueNameUtf16);
      calloc.free(valueUtf16);

      return setResult == ERROR_SUCCESS;
    } finally {
      // レジストリキーを閉じる
      RegCloseKey(hKey.value);
      calloc.free(hKey);
    }
  }

  /// レジストリから値を削除
  bool _deleteRegistryValue(String valueName) {
    // レジストリキーをオープン
    final keyPath = r'SOFTWARE\Microsoft\Windows\CurrentVersion\Run';
    final keyPathUtf16 = keyPath.toNativeUtf16();
    final hKey = calloc<HANDLE>();

    final result = RegOpenKeyEx(
      HKEY_CURRENT_USER,
      keyPathUtf16,
      0,
      KEY_WRITE,
      hKey,
    );

    if (result != ERROR_SUCCESS) {
      calloc.free(hKey);
      return false;
    }

    try {
      // UTF-16文字列に変換
      final valueNameUtf16 = valueName.toNativeUtf16();

      // レジストリから値を削除
      final deleteResult = RegDeleteValue(
        hKey.value,
        valueNameUtf16,
      );

      // メモリ解放
      calloc.free(valueNameUtf16);

      return deleteResult == ERROR_SUCCESS;
    } finally {
      // レジストリキーを閉じる
      RegCloseKey(hKey.value);
      calloc.free(hKey);
    }
  }

  /// レジストリから値を取得
  String? _getRegistryValue(String valueName) {
    // レジストリキーをオープン
    final keyPath = r'SOFTWARE\Microsoft\Windows\CurrentVersion\Run';
    final keyPathUtf16 = keyPath.toNativeUtf16();
    final hKey = calloc<HANDLE>();

    final result = RegOpenKeyEx(
      HKEY_CURRENT_USER,
      keyPathUtf16,
      0,
      KEY_READ,
      hKey,
    );

    if (result != ERROR_SUCCESS) {
      calloc.free(hKey);
      return null;
    }

    try {
      // UTF-16文字列に変換
      final valueNameUtf16 = valueName.toNativeUtf16();

      // 値のサイズを取得
      final sizePtr = calloc<DWORD>();
      final typePtr = calloc<DWORD>();

      var queryResult = RegQueryValueEx(
        hKey.value,
        valueNameUtf16,
        nullptr,
        typePtr,
        nullptr,
        sizePtr,
      );

      if (queryResult != ERROR_SUCCESS) {
        calloc.free(valueNameUtf16);
        calloc.free(sizePtr);
        calloc.free(typePtr);
        return null;
      }

      // 値を取得するためのバッファを確保
      final bufferSize = sizePtr.value;
      final buffer = calloc<Uint8>(bufferSize);

      queryResult = RegQueryValueEx(
        hKey.value,
        valueNameUtf16,
        nullptr,
        typePtr,
        buffer,
        sizePtr,
      );

      // メモリ解放
      calloc.free(valueNameUtf16);
      calloc.free(sizePtr);
      calloc.free(typePtr);

      if (queryResult != ERROR_SUCCESS) {
        calloc.free(buffer);
        return null;
      }

      // バッファをUTF-16文字列として変換
      final value = buffer.cast<Utf16>().toDartString();
      calloc.free(buffer);

      return value;
    } finally {
      // レジストリキーを閉じる
      RegCloseKey(hKey.value);
      calloc.free(hKey);
    }
  }

  /// 現在の実行ファイルのパスを取得
  String? getExecutablePath() {
    if (!Platform.isWindows) return null;

    try {
      // 現在の実行ファイルのパスを取得
      // Platform.resolvedExecutableを使用
      final exePath = Platform.resolvedExecutable;

      // パスが有効かどうかをチェック
      if (exePath.isEmpty || !File(exePath).existsSync()) {
        return null;
      }

      return exePath;
    } catch (e) {
      print('実行ファイルパス取得エラー: $e');
      return null;
    }
  }
}
