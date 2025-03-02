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
import '../services/settings_service.dart';

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

  PomodoroProvider({
    required this.notificationService,
    this.taskProvider,
    required this.soundService,
  }) {
    _loadSettings();
  }
  Future<void> _loadSettings() async {
    // 設定の読み込み
    workDuration = await _settingService.getWorkDuration();
    shortBreakDuration = await _settingService.getShortBreakDuration();
    longBreakDuration = await _settingService.getLongBreakDuration();
    longBreakInterval = await _settingService.getLongBreakInterval();
    notifyListeners();
  }

  // タイマーを開始
  void startTimer(Task task) {
    currentTask = task;
    isRunning = true;
    isPaused = true;
    isBreak = false;

    totalSeconds = workDuration * 60;
    remainingSeconds = totalSeconds;
    sessionStartTime = DateTime.now();

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
          //isBreak = false;
          //isRunning = false;
          startTimer(currentTask!);
          notificationService.showNotification('休憩終了', '次のポモドーロセッションを始めましょう。');
          final context = GlobalContext.context;
          notificationService.showNotificationBasedOnState(
            context,
            '休憩終了',
            '次のポモドーロセッションを始めましょう。',
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
      notificationService.showNotification(
        title,
        message,
      );
      final context = GlobalContext.context;
      notificationService.showNotificationBasedOnState(
        context,
        title,
        message,
        onDismiss: () => soundService.stopAllSounds(), // ダイアログを閉じたら音を停止
      );
      // 休憩モードに移行
      startBreak();
    } catch (e) {
      print('ポモドーロ完了の処理中にエラーが発生しました: $e');
    }
  }

  // スキップ機能
  Future<void> skipTimer() async {
    if (!isRunning) return;

    _timer?.cancel();

    // 現在の経過時間を記録
    final elapsedSeconds = totalSeconds - remainingSeconds;
    final elapsedMinutes = (elapsedSeconds / 60).ceil();

    if (!isBreak && elapsedMinutes >= 1) {
      // 作業時間をスキップした場合、実際に作業した時間を記録
      await _completePomodoro(customDuration: elapsedMinutes);
    } else if (isBreak) {
      await soundService.playBreakCompleteSound();
      notificationService.showNotification('休憩終了', '次のポモドーロセッションを始めましょう。');
      final context = GlobalContext.context;
      notificationService.showNotificationBasedOnState(
        context,
        '休憩終了',
        '次のポモドーロセッションを始めましょう。',
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
      soundService.stopAllSounds(); // 音を停止
      notifyListeners();
    }
  }

  // タイマーを再開
  void resumeTimer() {
    if (isRunning && isPaused) {
      isPaused = false;
      _startCountdown();
      soundService.stopAllSounds(); // 音を停止
      notifyListeners();
    }
  }

  // タイマーをキャンセル
  void cancelTimer() {
    _timer?.cancel();
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
