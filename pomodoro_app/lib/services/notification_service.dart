import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';

class NotificationService {
  // 静的フィールドとプライベートコンストラクタを削除し、通常のクラスにする
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // 一般的なコンストラクタを使用
  NotificationService();

  // 通知初期化
  Future<bool> init() async {
    if (_isInitialized) return true;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      final bool? result = await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
      );

      _isInitialized = result ?? false;
      return _isInitialized;
    } catch (e) {
      _isInitialized = false;
      return false;
    }
  }

  // 通知を表示 - エラーハンドリングを強化
  Future<bool> showNotification(String title, String body) async {
    // 初期化されていない場合は初期化を試みる
    if (!_isInitialized) {
      final initialized = await init();
      if (!initialized) return false;
    }

    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'pomodoro_channel',
        'ポモドーロ通知',
        channelDescription: 'ポモドーロタイマーの通知チャンネル',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.show(
        0,
        title,
        body,
        platformChannelSpecifics,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // 予定通知を設定
  Future<void> scheduleNotification(
    int id,
    String title,
    String body,
    DateTime scheduledTime,
  ) async {
    tz.initializeTimeZones();
    final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(
      scheduledTime,
      tz.local,
    );
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'pomodoro_scheduled_channel',
      '予定ポモドーロ通知',
      channelDescription: 'ポモドーロタイマーの予定通知チャンネル',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      platformChannelSpecifics,
//      androidAllowWhileIdle: true,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // 通知をキャンセル
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  // すべての通知をキャンセル
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // アプリ内通知を表示（SnackBar形式）
  void showInAppSnackBar(BuildContext context, String title, String message,
      {VoidCallback? onDismiss}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        action: SnackBarAction(
          label: '閉じる',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            if (onDismiss != null) onDismiss();
          },
        ),
      ),
    );
  }

  // アプリ内通知をダイアログ形式で表示
  void showInAppDialog(BuildContext context, String title, String message,
      {VoidCallback? onDismiss}) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (onDismiss != null) onDismiss();
              },
            ),
          ],
        );
      },
    );
  }

  // アプリの状態に応じて適切な通知を表示
  void showNotificationBasedOnState(
    BuildContext? context,
    String title,
    String message, {
    VoidCallback? onDismiss,
    bool useDialog = false, // デフォルトはダイアログなし
  }) {
    // システム通知は常に表示
    showNotification(title, message);

    // コンテキストがあれば、アプリ内通知も表示
    if (context != null) {
      if (useDialog) {
        // ダイアログで表示
        showInAppDialog(context, title, message, onDismiss: onDismiss);
      } else {
        // SnackBarで表示
        showInAppSnackBar(context, title, message, onDismiss: onDismiss);
      }
    }
  }
}
