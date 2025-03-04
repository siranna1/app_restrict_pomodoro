// tabs/trend_analysis_tab.dart
import 'package:flutter/material.dart';
import '../../widgets/heat_map_calendar.dart';
import '../../widgets/long_term_trend.dart';
import '../../services/database_helper.dart';
import '../../models/pomodoro_session.dart';

class TrendAnalysisTab extends StatefulWidget {
  const TrendAnalysisTab({Key? key}) : super(key: key);

  @override
  _TrendAnalysisTabState createState() => _TrendAnalysisTabState();
}

class _TrendAnalysisTabState extends State<TrendAnalysisTab> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 長期トレンド分析
            Text(
              '長期トレンド',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const LongTermTrendAnalysis(),

            const SizedBox(height: 20),

            // カレンダーヒートマップ
            Text(
              'ポモドーロカレンダー',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<PomodoroSession>>(
              future: DatabaseHelper.instance.getPomodoroSessions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sessions = snapshot.data ?? [];
                final now = DateTime.now();
                final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

                // 日付ごとのセッション数をマッピング
                final Map<DateTime, int> dailyCounts = {};
                for (final session in sessions) {
                  final date = DateTime(
                    session.startTime.year,
                    session.startTime.month,
                    session.startTime.day,
                  );

                  dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
                }

                return SizedBox(
                  height: 300,
                  child: HeatMapCalendar(
                    startDate: sixMonthsAgo,
                    endDate: now,
                    dailyCounts: dailyCounts,
                    colorMode: ColorMode.COLOR,
                    monthLabels: const [
                      '1月',
                      '2月',
                      '3月',
                      '4月',
                      '5月',
                      '6月',
                      '7月',
                      '8月',
                      '9月',
                      '10月',
                      '11月',
                      '12月'
                    ],
                    weekLabels: const ['月', '火', '水', '木', '金', '土', '日'],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // 習慣形成分析
            FutureBuilder<Map<String, dynamic>>(
              future: DatabaseHelper.instance.getHabitFormationStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final stats = snapshot.data ?? {};
                final currentStreak = stats['currentStreak'] as int? ?? 0;
                final longestStreak = stats['longestStreak'] as int? ?? 0;
                final consistencyScore =
                    stats['consistencyScore'] as double? ?? 0.0;
                final workDaysLast30 = stats['workDaysLast30'] as int? ?? 0;

                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '習慣形成分析',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStreakItem(
                              context,
                              '$currentStreak日',
                              '現在の連続記録',
                              Icons.local_fire_department,
                              Colors.orange,
                            ),
                            _buildStreakItem(
                              context,
                              '$longestStreak日',
                              '最長連続記録',
                              Icons.emoji_events,
                              Colors.amber,
                            ),
                            _buildStreakItem(
                              context,
                              '${consistencyScore.toStringAsFixed(0)}%',
                              '一貫性スコア',
                              Icons.insights,
                              Colors.blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: workDaysLast30 / 30,
                          minHeight: 8,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getConsistencyColor(workDaysLast30 / 30),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '過去30日間: $workDaysLast30日間学習 (${(workDaysLast30 / 30 * 100).toStringAsFixed(0)}%)',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _getConsistencyColor(workDaysLast30 / 30),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakItem(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
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

  Color _getConsistencyColor(double ratio) {
    if (ratio >= 0.8) return Colors.green;
    if (ratio >= 0.6) return Colors.lightGreen;
    if (ratio >= 0.4) return Colors.amber;
    if (ratio >= 0.2) return Colors.orange;
    return Colors.red;
  }
}
