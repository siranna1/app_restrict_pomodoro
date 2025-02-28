import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  // 静的インスタンスの管理方法を変更
  static NotificationService? _instance;

  // ファクトリーメソッドを使ってインスタンスを安全に取得
  factory NotificationService() {
    _instance ??= NotificationService._internal();
    return _instance!;
  }
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // 通知初期化
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const IOSInitializationSettings initializationSettingsIOS =
          IOSInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
      );

      _isInitialized = true;
      print('通知サービスが初期化されました');
    } catch (e) {
      print('通知サービスの初期化に失敗しました: $e');
    }
  }

  // 通知を表示 - エラーハンドリングを強化
  Future<void> showNotification(String title, String body) async {
    try {
      // 初期化されていない場合は初期化を試みる
      if (!_isInitialized) {
        print('通知サービスが初期化されていないため、初期化を試みます');
        await init();
      }

      // それでも初期化されていない場合はログだけ出して終了
      if (!_isInitialized) {
        print('通知サービスの初期化に失敗したため、通知を表示できません');
        return;
      }

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'pomodoro_channel',
        'ポモドーロ通知',
        channelDescription: 'ポモドーロタイマーの通知チャンネル',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );

      const IOSNotificationDetails iOSPlatformChannelSpecifics =
          IOSNotificationDetails(
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

      print('通知を表示しました: $title');
    } catch (e) {
      print('通知の表示中にエラーが発生しました: $e');
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

    const IOSNotificationDetails iOSPlatformChannelSpecifics =
        IOSNotificationDetails();

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
      androidAllowWhileIdle: true,
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
}
