// screens/home_screen.dart - ホーム画面
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/pomodoro_provider.dart';
import '../widgets/pomodoro_timer.dart';
import '../widgets/task_selection.dart';
import '../widgets/daily_progress.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pomodoroProvider = Provider.of<PomodoroProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('ポモドーロ学習管理'), centerTitle: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ポモドーロタイマーウィジェット
              PomodoroTimer(
                isRunning: pomodoroProvider.isRunning,
                isPaused: pomodoroProvider.isPaused,
                isBreak: pomodoroProvider.isBreak,
                remainingSeconds: pomodoroProvider.remainingSeconds,
                totalSeconds: pomodoroProvider.totalSeconds,
                onStart: () {
                  if (pomodoroProvider.currentTask != null) {
                    pomodoroProvider.startTimer(pomodoroProvider.currentTask!);
                  } else {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('タスクを選択してください')));
                  }
                },
                onPause: pomodoroProvider.pauseTimer,
                onResume: pomodoroProvider.resumeTimer,
                onCancel: pomodoroProvider.cancelTimer,
              ),

              const SizedBox(height: 24),

              // 現在のタスク表示
              if (pomodoroProvider.isRunning)
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '現在のタスク:',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pomodoroProvider.currentTask?.name ?? '選択されていません',
                          style: Theme.of(context).textTheme.displayLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pomodoroProvider.currentTask?.completedPomodoros ?? 0} / ${pomodoroProvider.currentTask?.estimatedPomodoros ?? 0} ポモドーロ',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                )
              else
                // タスク選択ウィジェット
                TaskSelection(
                  tasks: taskProvider.tasks,
                  onTaskSelected: (task) {
                    pomodoroProvider.currentTask = task;
                  },
                ),

              const SizedBox(height: 24),

              // 今日の進捗サマリー
              const DailyProgress(),
            ],
          ),
        ),
      ),
    );
  }
}
