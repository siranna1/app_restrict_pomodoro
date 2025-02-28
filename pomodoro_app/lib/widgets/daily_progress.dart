// widgets/daily_progress.dart - 日別進捗ウィジェット
import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class DailyProgress extends StatelessWidget {
  const DailyProgress({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getDailyStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data ??
            {
              'totalPomodoros': 0,
              'totalMinutes': 0,
              'targetPomodoros': 8,
            };

        final totalPomodoros = stats['totalPomodoros'] as int;
        final totalMinutes = stats['totalMinutes'] as int;
        final targetPomodoros = stats['targetPomodoros'] as int;
        final progress = totalPomodoros / targetPomodoros;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '今日の進捗',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '$totalPomodoros / $targetPomodoros',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      context,
                      Icons.timer,
                      '$totalPomodoros回',
                      'ポモドーロ',
                    ),
                    _buildStatItem(
                      context,
                      Icons.access_time,
                      '$totalMinutes分',
                      '学習時間',
                    ),
                    _buildStatItem(
                      context,
                      Icons.trending_up,
                      '${(progress * 100).toStringAsFixed(0)}%',
                      '目標達成',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getDailyStats() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();

    final results = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        SUM(durationMinutes) as totalMinutes
      FROM pomodoro_sessions
      WHERE date(startTime) = date(?)
    ''', [today]);

    int totalPomodoros = 0;
    int totalMinutes = 0;

    if (results.isNotEmpty) {
      totalPomodoros = results.first['count'] as int? ?? 0;
      totalMinutes = results.first['totalMinutes'] as int? ?? 0;
    }

    return {
      'totalPomodoros': totalPomodoros,
      'totalMinutes': totalMinutes,
      'targetPomodoros': 8, // 目標ポモドーロ数（設定から取得するよう改善可能）
    };
  }
}
