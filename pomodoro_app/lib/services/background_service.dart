// services/background_service.dart - バックグラウンド実行サービス
import 'dart:isolate';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/platform_utils.dart';

// バックグラウンド実行を管理するサービス
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;

  BackgroundService._internal();

  static const String _isolateName = 'pomodoro_isolate';
  final ReceivePort _receivePort = ReceivePort();

  bool _isRunning = false;
  Isolate? _isolate;

  // バックグラウンドサービスの状態
  bool get isRunning => _isRunning;

  // バックグラウンドサービスの初期化
  Future<void> initialize() async {
    // プラットフォームがバックグラウンド実行をサポートしているか確認
    final platformUtils = PlatformUtils();
    final platformService = platformUtils.getPlatformService();

    if (!platformService.supportsBackgroundExecution) {
      print('このプラットフォームはバックグラウンド実行をサポートしていません');
      return;
    }

    // Isolateの登録
    final success = IsolateNameServer.registerPortWithName(
      _receivePort.sendPort,
      _isolateName,
    );

    if (!success) {
      // すでに登録されている場合は削除して再登録
      IsolateNameServer.removePortNameMapping(_isolateName);
      IsolateNameServer.registerPortWithName(
        _receivePort.sendPort,
        _isolateName,
      );
    }

    // メッセージリスナーを設定
    _receivePort.listen(_handleMessage);

    // 設定から自動起動が有効かどうかを確認
    final prefs = await SharedPreferences.getInstance();
    final autoStart = prefs.getBool('autoStartBackgroundService') ?? false;

    if (autoStart) {
      await startService();
    }
  }

  // バックグラウンドサービスを開始
  Future<bool> startService() async {
    if (_isRunning) {
      return true;
    }

    try {
      // Isolateでバックグラウンド処理を開始
      _isolate = await Isolate.spawn(
        _backgroundIsolateEntryPoint,
        IsolateNameServer.lookupPortByName(_isolateName)!,
      );

      _isRunning = true;
      return true;
    } catch (e) {
      print('バックグラウンドサービスの開始に失敗しました: $e');
      _isRunning = false;
      return false;
    }
  }

  // バックグラウンドサービスを停止
  Future<bool> stopService() async {
    if (!_isRunning) {
      return true;
    }

    try {
      // Isolateを終了
      _isolate?.kill(priority: Isolate.immediate);
      _isolate = null;

      _isRunning = false;
      return true;
    } catch (e) {
      print('バックグラウンドサービスの停止に失敗しました: $e');
      return false;
    }
  }

  // バックグラウンドIsolateからのメッセージを処理
  void _handleMessage(dynamic message) {
    if (message is Map<String, dynamic>) {
      final type = message['type'] as String?;

      switch (type) {
        case 'log':
          print('バックグラウンド: ${message['message']}');
          break;
        case 'timer_completed':
          // タイマー完了のメッセージを処理
          break;
        case 'error':
          print('バックグラウンドエラー: ${message['message']}');
          break;
      }
    }
  }
}

// バックグラウンドIsolateのエントリーポイント
void _backgroundIsolateEntryPoint(SendPort sendPort) {
  // バックグラウンド処理のロジック
  final receivePort = ReceivePort();
  sendPort.send({
    'type': 'log',
    'message': 'バックグラウンドサービスが開始されました',
  });

  // メッセージ受信の設定
  receivePort.listen((message) {
    if (message is Map<String, dynamic>) {
      final type = message['type'] as String?;

      switch (type) {
        case 'stop':
          Isolate.exit();
          break;
      }
    }
  });

  // バックグラウンド処理を実行
  _runBackgroundTasks(sendPort);
}

// バックグラウンドタスクの実行
void _runBackgroundTasks(SendPort sendPort) async {
  try {
    // ここでバックグラウンドでの定期処理を実装
    // 例: 定期的なデータ同期、通知のスケジュール管理など
  } catch (e) {
    sendPort.send({
      'type': 'error',
      'message': 'バックグラウンドタスクでエラーが発生しました: $e',
    });
  }
}
