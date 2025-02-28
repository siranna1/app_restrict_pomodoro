// utils/platform_utils.dart - プラットフォーム固有の機能を提供するユーティリティ
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:platform/platform.dart';
import '../services/app_platform_service.dart';

class PlatformUtils {
  static final PlatformUtils _instance = PlatformUtils._internal();
  factory PlatformUtils() => _instance;

  PlatformUtils._internal();

  // 現在のプラットフォームを取得
  final Platform platform = const LocalPlatform();

  // Windowsプラットフォームかどうか
  bool get isWindows => platform.isWindows;

  // Androidプラットフォームかどうか
  bool get isAndroid => platform.isAndroid;

  // iOSプラットフォームかどうか
  bool get isIOS => platform.isIOS;

  // モバイルプラットフォームかどうか
  bool get isMobile => isAndroid || isIOS;

  // デスクトッププラットフォームかどうか
  bool get isDesktop => isWindows || platform.isLinux || platform.isMacOS;

  // プラットフォーム固有のサービスを取得
  AppPlatformService getPlatformService() {
    if (isWindows) {
      return WindowsPlatformService();
    } else if (isAndroid) {
      return AndroidPlatformService();
    } else if (isIOS) {
      return IOSPlatformService();
    } else {
      return DefaultPlatformService();
    }
  }
}
