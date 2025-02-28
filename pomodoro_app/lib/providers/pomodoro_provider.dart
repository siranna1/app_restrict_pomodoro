// providers/pomodoro_provider.dart - ポモドーロタイマー管理
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../models/pomodoro_session.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

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

  final SharedPreferences prefs;
  final notificationService = NotificationService();
  final bool notificationInitialized;

  PomodoroProvider(this.prefs, {this.notificationInitialized = false}) {
    // 設定の読み込み
    workDuration = prefs.getInt('workDuration') ?? 25;
    shortBreakDuration = prefs.getInt('shortBreakDuration') ?? 5;
    longBreakDuration = prefs.getInt('longBreakDuration') ?? 15;
    longBreakInterval = prefs.getInt('longBreakInterval') ?? 4;

    // 通知サービスがまだ初期化されていなければ初期化
    if (!notificationInitialized) {
      notificationService.init().catchError((e) {
        print('PomodoroProviderでの通知サービス初期化エラー: $e');
      });
    }
  }

  // タイマーを開始
  void startTimer(Task task) {
    currentTask = task;
    isRunning = true;
    isPaused = false;
    isBreak = false;

    totalSeconds = workDuration * 60;
    remainingSeconds = totalSeconds;
    sessionStartTime = DateTime.now();

    _startCountdown();
    notifyListeners();
  }

  // 休憩タイマーを開始
  void startBreak() {
    isRunning = true;
    isPaused = false;
    isBreak = true;

    // 長い休憩か短い休憩かを決定
    final isLongBreak = (completedPomodoros % longBreakInterval == 0);
    final breakDuration = isLongBreak ? longBreakDuration : shortBreakDuration;

    totalSeconds = breakDuration * 60;
    remainingSeconds = totalSeconds;

    _startCountdown();
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
          _tryShowNotification(
            'ポモドーロ完了',
            '休憩時間です。次のセッションを始める準備をしましょう。',
          );
        } else {
          // 休憩が完了
          isBreak = false;
          isRunning = false;
          _tryShowNotification('休憩終了', '次のポモドーロセッションを始めましょう。');
        }

        notifyListeners();
      }
    });
  }

  // ポモドーロを完了としてマーク
  Future<void> _completePomodoro() async {
    if (currentTask == null || sessionStartTime == null) return;

    completedPomodoros++;

    try {
      // セッションを記録
      final session = PomodoroSession(
        taskId: currentTask!.id ?? -1, // ID が null の場合の対策
        startTime: sessionStartTime!,
        endTime: DateTime.now(),
        durationMinutes: workDuration,
        completed: true,
        focusScore: _calculateFocusScore(),
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
      }
    } catch (e) {
      print('ポモドーロ完了の記録中にエラーが発生しました: $e');
    }
  }

  // 通知を表示
  void _showNotification(String title, String body) {
    try {
      _tryShowNotification(title, body);
    } catch (e) {
      print('通知表示中にエラーが発生しました: $e');
    }
  }

  // 集中度スコアを計算（デモとして単純な実装）
  double _calculateFocusScore() {
    // ここで集中度を計算するロジックを実装
    // 実際のアプリでは、一時停止回数や中断時間などから計算
    return 100.0;
  }

  // タイマーを一時停止
  void pauseTimer() {
    if (isRunning && !isPaused) {
      isPaused = true;
      _timer?.cancel();
      notifyListeners();
    }
  }

  // タイマーを再開
  void resumeTimer() {
    if (isRunning && isPaused) {
      isPaused = false;
      _startCountdown();
      notifyListeners();
    }
  }

  // タイマーをキャンセル
  void cancelTimer() {
    _timer?.cancel();
    isRunning = false;
    isPaused = false;
    notifyListeners();
  }

  // 通知表示を試みる（エラーハンドリング付き）
  void _tryShowNotification(String title, String body) {
    try {
      notificationService.showNotification(title, body).catchError((e) {
        print('通知表示エラー: $e');
      });
    } catch (e) {
      print('通知表示中に例外が発生しました: $e');
    }
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
      await prefs.setInt('workDuration', workDuration);
    }

    if (shortBreakDuration != null) {
      this.shortBreakDuration = shortBreakDuration;
      await prefs.setInt('shortBreakDuration', shortBreakDuration);
    }

    if (longBreakDuration != null) {
      this.longBreakDuration = longBreakDuration;
      await prefs.setInt('longBreakDuration', longBreakDuration);
    }

    if (longBreakInterval != null) {
      this.longBreakInterval = longBreakInterval;
      await prefs.setInt('longBreakInterval', longBreakInterval);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
