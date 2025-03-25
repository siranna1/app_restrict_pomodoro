// providers/pomodoro_provider.dart - ポモドーロタイマー管理
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/pomodoro_session.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../providers/task_provider.dart';
import 'app_restriction_provider.dart';
import '../services/sound_service.dart';
import '../utils/global_context.dart';
import '../utils/platform_utils.dart';
import '../services/settings_service.dart';
import 'package:flutter/services.dart';

class PomodoroProvider with ChangeNotifier {
  // タイマー設定
  int workDuration = 25; // 作業時間（分）
  int shortBreakDuration = 5; // 短い休憩時間（分）
  int longBreakDuration = 15; // 長い休憩時間（分）
  int longBreakInterval = 4; // 長い休憩までのポモドーロ数

  // タイマー状態
  bool isRunning = false;
  bool isPaused = false;
  bool isBreak = false;
  int remainingSeconds = 0;
  int completedPomodoros = 0;
  int totalSeconds = 0;
  Timer? _timer;

  // 現在のタスク
  Task? currentTask;

  // セッション記録
  DateTime? sessionStartTime;

  final SettingsService _settingService = SettingsService();
  final NotificationService notificationService;
  final TaskProvider? taskProvider;
  final SoundService soundService;

  // MethodChannelを追加
  static const MethodChannel _channel =
      MethodChannel('com.example.pomodoro_app/pomodoro_timer');
  bool _hasNativeTimerService = false;

  PomodoroProvider({
    required this.notificationService,
    this.taskProvider,
    required this.soundService,
  }) {
    _loadSettings();
    _initializeMethodChannel();
    _checkTimerStatus();
  }
  Future<void> _loadSettings() async {
    // 設定の読み込み
    workDuration = await _settingService.getWorkDuration();
    shortBreakDuration = await _settingService.getShortBreakDuration();
    longBreakDuration = await _settingService.getLongBreakDuration();
    longBreakInterval = await _settingService.getLongBreakInterval();
    notifyListeners();
  }

  // MethodChannelの初期化
  Future<void> _initializeMethodChannel() async {
    _channel.setMethodCallHandler(_handleMethodCall);
    PlatformUtils platform = PlatformUtils();
    // プラットフォームがAndroidかチェック
    try {
      _hasNativeTimerService = platform.isAndroid;

      print('MethodChannelハンドラ設定完了');
    } catch (e) {
      _hasNativeTimerService = false;
    }
  }

  // タイマー状態を確認するメソッド
  Future<void> _checkTimerStatus() async {
    if (_hasNativeTimerService) {
      try {
        final result = await _channel.invokeMethod('getTimerStatus');
        if (result != null && result is Map) {
          final isTimerRunning = result['isRunning'] ?? false;

          if (isTimerRunning) {
            print('タイマーが実行中です。タスク情報を復元します。');
            isRunning = result['isRunning'] ?? false;
            isPaused = result['isPaused'] ?? false;
            isBreak = result['isBreak'] ?? false;
            remainingSeconds = result['remainingSeconds'] ?? 0;
            totalSeconds = result['totalSeconds'] ?? 0;

            // タスク情報を復元
            await _loadCurrentTaskInfo();

            notifyListeners();
          }
        }
      } catch (e) {
        print('タイマー状態確認エラー: $e');
      }
    }
  }

  void readyForPomodoro(Task task) async {
    if (task.id != null) {
      final freshTask = await DatabaseHelper.instance.getTask(task.id!);
      if (freshTask != null) {
        currentTask = freshTask;
        print('ポモドーロ開始: 最新のタスク情報を取得 - firebaseId: ${freshTask.firebaseId}');
      } else {
        currentTask = task;
      }
    } else {
      currentTask = task;
    }
    isRunning = false;
    isPaused = false;
    isBreak = false;

    totalSeconds = workDuration * 60;
    remainingSeconds = totalSeconds;
    sessionStartTime = DateTime.now();
    // タスク情報を保存
    _saveCurrentTaskInfo();

    notifyListeners();
  }

  // タイマーを開始
  void startTimer(Task task) async {
    if (isBreak) {
      startBreak();
      return;
    }
    if (task.id != null) {
      final freshTask = await DatabaseHelper.instance.getTask(task.id!);
      if (freshTask != null) {
        currentTask = freshTask;
        print('ポモドーロ開始: 最新のタスク情報を取得 - firebaseId: ${freshTask.firebaseId}');
      } else {
        currentTask = task;
      }
    } else {
      currentTask = task;
    }
    isRunning = true;
    isPaused = true;
    isBreak = false;

    totalSeconds = workDuration * 60;
    remainingSeconds = totalSeconds;
    sessionStartTime = DateTime.now();

    if (_hasNativeTimerService) {
      // ネイティブのバックグラウンドサービスを使用
      try {
        await _channel.invokeMethod('startPomodoro', {
          'minutes': workDuration,
          'taskId': currentTask?.id ?? -1,
          'taskName': currentTask?.name ?? "タスクなし",
        });
      } catch (e) {
        print('ネイティブタイマー開始エラー: $e');
        _startCountdown(); // フォールバック: Dartでタイマーを実行
      }
    } else {
      // 通常のDartタイマーを使用
      _startCountdown();
    }
    // タスク情報を保存
    _saveCurrentTaskInfo();
    //_startCountdown();
    notifyListeners();
  }

  // 休憩タイマーを開始
  void startBreak() {
    isRunning = true;
    isPaused = true;
    isBreak = true;

    // 長い休憩か短い休憩かを決定
    final isLongBreak = (completedPomodoros % longBreakInterval == 0);
    final breakDuration = isLongBreak ? longBreakDuration : shortBreakDuration;

    totalSeconds = breakDuration * 60;
    remainingSeconds = totalSeconds;

    if (_hasNativeTimerService) {
      // ネイティブのバックグラウンドサービスを使用
      try {
        _channel.invokeMethod('startBreak', {
          'minutes': breakDuration,
          'isLongBreak': isLongBreak,
        });
      } catch (e) {
        print('ネイティブ休憩タイマー開始エラー: $e');
        _startCountdown(); // フォールバック: Dartでタイマーを実行
      }
    } else {
      // 通常のDartタイマーを使用
      _startCountdown();
    }

    //_startCountdown();
    notifyListeners();
  }

  // カウントダウンを開始
  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        notifyListeners();
      } else {
        _timer?.cancel();

        if (!isBreak) {
          // ポモドーロが完了
          _completePomodoro();
        } else {
          soundService.playBreakCompleteSound();
          // 休憩が完了
          isBreak = false;
          isRunning = false;
          startTimer(currentTask!);
          //notificationService.showNotification('休憩終了', '次のポモドーロセッションを始めましょう。');
          final context = GlobalContext.context;
          notificationService.showNotificationBasedOnState(
            context,
            '休憩終了',
            '次のポモドーロセッションを始めましょう。',
            channel: 'break_channel',
            payload: 'break_completed',
            onDismiss: () => soundService.stopAllSounds(), // ダイアログを閉じたら音を停止
          );
        }

        notifyListeners();
      }
    });
  }

  // ポモドーロを完了としてマーク
  Future<void> _completePomodoro({int? customDuration}) async {
    if (currentTask == null || sessionStartTime == null) return;

    try {
      // セッションを保存
      final duration = customDuration ?? workDuration;
      await _saveSession(duration);

      await soundService.playPomodoroCompleteSound();

      final message = customDuration != null
          ? 'ポモドーロをスキップしました。$customDuration分間の作業を記録しました。'
          : '休憩時間です。次のセッションを始める準備をしましょう。';
      final title = customDuration != null ? 'ポモドーロスキップ' : 'ポモドーロ完了';
      final context = GlobalContext.context;
      notificationService.showNotificationBasedOnState(
        context,
        title,
        message,
        onDismiss: () => soundService.stopAllSounds(), // ダイアログを閉じたら音を停止
        payload: 'pomodoro_complete', // 通知タップ時のペイロード
        channel: 'pomodoro_channel', // 通知チャンネル
      );
      // 休憩モードに移行
      startBreak();
      // タスク情報を保存
      _saveCurrentTaskInfo();
    } catch (e) {
      print('ポモドーロ完了の処理中にエラーが発生しました: $e');
    }
  }

  // スキップ機能
  Future<void> skipTimer() async {
    if (!isRunning) return;

    _timer?.cancel();
    if (_hasNativeTimerService) {
      try {
        await _channel.invokeMethod('skipTimer');
        return; // ネイティブ側で処理するので以降は実行しない
      } catch (e) {
        print('ネイティブタイマースキップエラー: $e');
        // エラーの場合は従来のロジックでフォールバック
      }
    }

    // 現在の経過時間を記録
    final elapsedSeconds = totalSeconds - remainingSeconds;
    final elapsedMinutes = (elapsedSeconds / 60).ceil();

    if (!isBreak && elapsedMinutes >= 1) {
      // 作業時間をスキップした場合、実際に作業した時間を記録
      await _completePomodoro(customDuration: elapsedMinutes);
    } else if (isBreak) {
      await soundService.playBreakCompleteSound();
      //notificationService.showNotification('休憩終了', '次のポモドーロセッションを始めましょう。');
      final context = GlobalContext.context;
      notificationService.showNotificationBasedOnState(
        context,
        '休憩終了',
        '次のポモドーロセッションを始めましょう。',
        channel: 'break_channel',
        payload: 'break_completed',
        onDismiss: () => soundService.stopAllSounds(), // ダイアログを閉じたら音を停止
      );
      startTimer(currentTask!);
      notifyListeners();
    }
  }

  // セッションを保存するヘルパーメソッド（コードの重複を避けるため）
  Future<void> _saveSession(int durationMinutes) async {
    if (currentTask == null || sessionStartTime == null) return;

    completedPomodoros++;

    try {
      // セッションを記録
      final session = PomodoroSession.withTimeOfDay(
        taskId: currentTask!.id ?? -1,
        startTime: sessionStartTime!,
        endTime: DateTime.now(),
        durationMinutes: durationMinutes,
        completed: true,
        focusScore: _calculateFocusScore(),
        interruptionCount: _interruptionCount,
        mood: _sessionMood,
        isBreak: isBreak,
      );

      // タスク ID が有効な場合のみデータベースに保存
      if (currentTask!.id != null) {
        await DatabaseHelper.instance.insertPomodoroSession(session);
        String? id = currentTask!.firebaseId;
        print("ファイアベースid $id");
        // タスクの完了ポモドーロ数を更新
        currentTask = currentTask!.copyWith(
          completedPomodoros: currentTask!.completedPomodoros + 1,
          updatedAt: DateTime.now(),
        );
        await DatabaseHelper.instance.updateTask(currentTask!);

        // 日次目標の達成状況を更新
        final today = DateTime.now();
        final dailyGoal = await DatabaseHelper.instance.getDailyGoal(today);
        if (dailyGoal != null) {
          await DatabaseHelper.instance.updateDailyGoalAchievement(dailyGoal);
        }

        // タスクプロバイダーに通知
        if (taskProvider != null && currentTask!.id != null) {
          await taskProvider!.refreshTask(currentTask!.id!);
        }

        // 中断カウントをリセット
        resetInterruptionCount();
        // 気分評価をリセット
        _sessionMood = null;

        notifyListeners();

        try {
          // AppRestrictionProvider に通知
          await AppRestrictionProvider.notifyPomodoroCompleted();
          print("ポモドーロ完了を AppRestrictionProvider に通知しました");
        } catch (e) {
          print("AppRestrictionProvider 通知エラー: $e");
        }
      }
    } catch (e) {
      // エラーをキャッチして無視（UIに影響させない）
    }
  }

  // 休憩セッションを保存（休憩記録機能を追加）
  Future<void> _saveBreakSession(int durationMinutes) async {
    try {
      // 休憩セッションを記録
      final session = PomodoroSession(
        taskId: currentTask?.id ?? -1,
        startTime: sessionStartTime!,
        endTime: DateTime.now(),
        durationMinutes: durationMinutes,
        completed: true,
        focusScore: 100.0, // 休憩は常に100%とみなす
        timeOfDay: null, // 自動設定されるのでnullでOK
        interruptionCount: 0,
        mood: null,
        isBreak: true,
      );

      // データベースに保存（タスクIDが無効でも保存）
      await DatabaseHelper.instance.insertPomodoroSession(session);
    } catch (e) {
      print("休憩セッション保存エラー: $e");
    }
  }

  // 集中度スコアを計算（デモとして単純な実装）
  double _calculateFocusScore() {
    // 基本スコア（100点満点）
    double baseScore = 100.0;

    // 中断ごとにスコアを減点（中断1回につき10点減点、最大50点まで）
    double interruptionPenalty = _interruptionCount * 10.0;
    interruptionPenalty =
        interruptionPenalty > 50.0 ? 50.0 : interruptionPenalty;

    // 一時停止回数によるペナルティ（pauseTimerが呼ばれた回数に応じて）
    // この実装では省略（実際には一時停止回数を追跡する必要があります）

    // 最終スコアを計算
    double finalScore = baseScore - interruptionPenalty;

    // 0〜100の範囲に収める
    return finalScore.clamp(0.0, 100.0);
  }

  // タイマーを一時停止
  void pauseTimer() {
    if (isRunning && !isPaused) {
      isPaused = true;
      _timer?.cancel();
      if (_hasNativeTimerService) {
        try {
          _channel.invokeMethod('pausePomodoro');
        } catch (e) {
          print('ネイティブタイマー一時停止エラー: $e');
        }
      }
      soundService.stopAllSounds(); // 音を停止
      countInterruption(); // 中断カウントを追加
      notifyListeners();
    }
  }

  // タイマーを再開
  void resumeTimer() {
    if (isRunning && isPaused) {
      if (_hasNativeTimerService) {
        try {
          _channel.invokeMethod('resumePomodoro');
        } catch (e) {
          print('ネイティブタイマー再開エラー: $e');
          _startCountdown(); // フォールバック: Dartでタイマーを実行
        }
      } else {
        _startCountdown();
      }
      soundService.stopAllSounds(); // 音を停止
      notifyListeners();
    }
  }

  // タイマーをキャンセル
  void cancelTimer() {
    _timer?.cancel();
    if (_hasNativeTimerService) {
      try {
        _channel.invokeMethod('stopPomodoro');
      } catch (e) {
        print('ネイティブタイマー停止エラー: $e');
      }
    }
    isRunning = false;
    isPaused = false;
    soundService.stopAllSounds(); // 音を停止
    notifyListeners();
  }

  // 中断カウントを追加
  int _interruptionCount = 0;

  // 中断をカウントするメソッド
  void countInterruption() {
    _interruptionCount++;
    notifyListeners();
  }

  // 中断カウントをリセット
  void resetInterruptionCount() {
    _interruptionCount = 0;
    notifyListeners();
  }

  // 気分評価を保存するためのプロパティ
  String? _sessionMood;

  // 気分評価を設定
  void setSessionMood(String mood) {
    _sessionMood = mood;
    notifyListeners();
  }

  // 通知表示を試みる（エラーハンドリング付き）
  // void notificationService.showNotification(String title, String body) {
  //   try {
  //     notificationService.showNotification(title, body).catchError((e) {
  //       print('通知表示エラー: $e');
  //     });
  //   } catch (e) {
  //     print('通知表示中に例外が発生しました: $e');
  //   }
  // }

  // ネイティブからのコールを処理
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    print("なにか来たよ${call.method}");
    switch (call.method) {
      case "timerUpdate":
        // ネイティブからタイマー状態の更新
        final Map<dynamic, dynamic> args = call.arguments;
        print('受信したタイマー更新: $args');

        // データ型を明示的に変換
        isRunning = args['isRunning'] == true;
        isPaused = args['isPaused'] == true;
        isBreak = args['isBreak'] == true;

        // int型への明示的な変換
        if (args['remainingSeconds'] != null) {
          try {
            remainingSeconds = int.parse(args['remainingSeconds'].toString());
          } catch (e) {
            print('remainingSeconds変換エラー: $e');
          }
        }

        if (args['totalSeconds'] != null) {
          try {
            totalSeconds = int.parse(args['totalSeconds'].toString());
          } catch (e) {
            print('totalSeconds変換エラー: $e');
          }
        }

        // タスク情報がない場合は復元を試みる
        if (isRunning && currentTask == null) {
          _loadCurrentTaskInfo().then((_) {
            notifyListeners();
          });
        }
        notifyListeners();
        break;

      case 'pomodoroComplete':
        // ポモドーロ完了通知
        final Map<dynamic, dynamic> data = call.arguments;
        print("ポモドーロ完了通知: $data");
        if (currentTask != null &&
            currentTask!.id == int.parse(data['taskId'].toString())) {
          // セッション時間を記録
          await _saveSession(int.parse(data['durationMinutes'].toString()));

          // 通知処理
          await soundService.playPomodoroCompleteSound();
          final context = GlobalContext.context;
          notificationService.showNotificationBasedOnState(
            context,
            'ポモドーロ完了',
            '休憩時間です。開始ボタンを押して休憩を始めましょう。',
            onDismiss: () => soundService.stopAllSounds(),
            payload: 'pomodoro_complete',
            channel: 'pomodoro_channel',
          );

          isRunning = false;
          isPaused = false;
          isBreak = true;
          // 長い休憩か短い休憩かを決定
          final isLongBreak = (completedPomodoros % longBreakInterval == 0);
          final breakDuration =
              isLongBreak ? longBreakDuration : shortBreakDuration;

          totalSeconds = breakDuration * 60;
          remainingSeconds = totalSeconds;
          notifyListeners();
        }
        break;

      case 'pomodoroSkipped':
        // ポモドーロスキップ通知
        final Map<dynamic, dynamic> data = call.arguments;
        print("ポモドーロスキップ通知: $data");
        if (currentTask != null &&
            currentTask!.id == int.parse(data['taskId'].toString())) {
          // 実際に作業した時間を記録
          await _saveSession(int.parse(data['durationMinutes'].toString()));

          await soundService.playPomodoroCompleteSound();
          final context = GlobalContext.context;
          notificationService.showNotificationBasedOnState(
            context,
            'ポモドーロスキップ',
            '${int.parse(data['durationMinutes'].toString())}分間の作業を記録しました。',
            onDismiss: () => soundService.stopAllSounds(),
            payload: 'pomodoro_skipped',
            channel: 'pomodoro_channel',
          );

          isRunning = false;
          isPaused = false;
          isBreak = true;
          // 長い休憩か短い休憩かを決定
          final isLongBreak = (completedPomodoros % longBreakInterval == 0);
          final breakDuration =
              isLongBreak ? longBreakDuration : shortBreakDuration;

          totalSeconds = breakDuration * 60;
          remainingSeconds = totalSeconds;
          notifyListeners();
        }
        break;

      case 'breakComplete':
        // 休憩完了通知
        await soundService.playBreakCompleteSound();
        final context = GlobalContext.context;
        notificationService.showNotificationBasedOnState(
          context,
          '休憩終了',
          '次のポモドーロセッションを始めましょう。',
          channel: 'break_channel',
          payload: 'break_completed',
          onDismiss: () => soundService.stopAllSounds(),
        );

        readyForPomodoro(currentTask!);

        notifyListeners();
        break;

      default:
        print('Unknown method call: ${call.method}');
    }
    return null;
  }

  // 設定を保存
  Future<void> saveSettings({
    int? workDuration,
    int? shortBreakDuration,
    int? longBreakDuration,
    int? longBreakInterval,
  }) async {
    if (workDuration != null) {
      this.workDuration = workDuration;
      await _settingService.setWorkDuration(workDuration);
    }

    if (shortBreakDuration != null) {
      this.shortBreakDuration = shortBreakDuration;
      await _settingService.setShortBreakDuration(shortBreakDuration);
    }

    if (longBreakDuration != null) {
      this.longBreakDuration = longBreakDuration;
      await _settingService.setLongBreakDuration(longBreakDuration);
    }

    if (longBreakInterval != null) {
      this.longBreakInterval = longBreakInterval;
      await _settingService.setLongBreakInterval(longBreakInterval);
    }

    notifyListeners();
  }

  // タスク情報を保存
  Future<void> _saveCurrentTaskInfo() async {
    if (currentTask?.id != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_task_id', currentTask!.id!);
      await prefs.setBool('is_timer_running', isRunning);
      await prefs.setBool('is_break', isBreak);
      await prefs.setInt('complete_pomodoros', completedPomodoros);
      await prefs.setInt('longBreakInterval', longBreakInterval);
      print('現在のタスク情報を保存: ${currentTask!.id}');
    }
  }

  // タスク情報を読み込む
  Future<void> _loadCurrentTaskInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final taskId = prefs.getInt('current_task_id');

      if (taskId != null) {
        print('保存されたタスクID: $taskId');
        final task = await DatabaseHelper.instance.getTask(taskId);

        if (task != null) {
          currentTask = task;
          print('タスク情報を復元: ${task.name}');
          isRunning = prefs.getBool('is_timer_running') ?? false;
          isBreak = prefs.getBool('is_break') ?? false;
          completedPomodoros = prefs.getInt('complete_pomodoros') ?? 0;
          longBreakInterval = prefs.getInt('longBreakInterval') ?? 4;
        }
      }
    } catch (e) {
      print('タスク情報の読み込みエラー: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
