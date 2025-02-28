// providers/app_restriction_provider.dart - アプリ制限管理のProvider
import 'package:flutter/material.dart';
import '../models/restricted_app.dart';
import '../services/database_helper.dart';
import 'windows_app_controller.dart';

class AppRestrictionProvider with ChangeNotifier {
  final _windowsAppController = WindowsAppController();
  List<RestrictedApp> restrictedApps = [];
  bool isMonitoring = false;

  AppRestrictionProvider() {
    _initializeController();
    _loadRestrictedApps();
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

  // 監視を開始
  void startMonitoring() {
    _windowsAppController.startMonitoring();
    isMonitoring = true;
    notifyListeners();
  }

  // 監視を停止
  void stopMonitoring() {
    _windowsAppController.stopMonitoring();
    isMonitoring = false;
    notifyListeners();
  }

  // 制限対象アプリを追加
  Future<void> addRestrictedApp(RestrictedApp app) async {
    await _windowsAppController.addRestrictedApp(app);
    await _loadRestrictedApps();
  }

  // 制限対象アプリを更新
  Future<void> updateRestrictedApp(RestrictedApp app) async {
    await _windowsAppController.updateRestrictedApp(app);
    await _loadRestrictedApps();
  }

  // 制限対象アプリを削除
  Future<void> removeRestrictedApp(int id) async {
    await _windowsAppController.removeRestrictedApp(id);
    await _loadRestrictedApps();
  }

  // ポモドーロ完了時に呼び出し
  Future<void> onPomodoroCompleted() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();
    
    final results = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM pomodoro_sessions
      WHERE date(startTime) = date(?) AND completed = 1
    ''', [today]);
    
    if (results.isNotEmpty) {
      final count = results.first['count'] as int;
      await _windowsAppController.updateCompletedPomodoros(count);
    }
  }
}
