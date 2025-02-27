// widgets/pomodoro_timer.dart - ポモドーロタイマーウィジェット
import 'package:flutter/material.dart';

class PomodoroTimer extends StatelessWidget {
  final bool isRunning;
  final bool isPaused;
  final bool isBreak;
  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const PomodoroTimer({
    Key? key,
    required this.isRunning,
    required this.isPaused,
    required this.isBreak,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final minutes = (remainingSeconds / 60).floor();
    final seconds = remainingSeconds % 60;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              isBreak ? '休憩時間' : '作業時間',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isBreak ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value:
                        totalSeconds > 0 ? remainingSeconds / totalSeconds : 0,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isBreak ? Colors.green : Colors.red,
                    ),
                  ),
                ),
                Text(
                  '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isRunning)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('開始'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: onStart,
                  )
                else if (isPaused)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('再開'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: onResume,
                  )
                else
                  ElevatedButton.icon(
                    icon: const Icon(Icons.pause),
                    label: const Text('一時停止'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: onPause,
                  ),
                const SizedBox(width: 16),
                if (isRunning)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('中止'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    onPressed: onCancel,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
