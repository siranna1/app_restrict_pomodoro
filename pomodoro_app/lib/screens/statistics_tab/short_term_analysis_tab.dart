// tabs/short_term_analysis_tab.dart
import 'package:flutter/material.dart';
import '../../widgets/habit_score_card.dart';
import '../../widgets/daily_statistics_chart.dart';
import '../../widgets/weekly_statistics_chart.dart';
import '../../services/database_helper.dart';

class ShortTermAnalysisTab extends StatelessWidget {
  const ShortTermAnalysisTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 習慣スコアカード
            const HabitScoreCard(),

            const SizedBox(height: 20),

            // 日別統計
            Text(
              '日別データ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const DailyStatisticsChart(),

            const SizedBox(height: 20),

            // 週別統計
            Text(
              '週別データ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const WeeklyStatisticsChart(),

            const SizedBox(height: 20),

            // 総合サマリー
            FutureBuilder<Map<String, dynamic>>(
              future: DatabaseHelper.instance.getShortTermSummary(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data ?? {};
                final totalPomodoros = data['totalPomodoros'] ?? 0;
                final totalMinutes = data['totalMinutes'] ?? 0;
                final avgDailyPomodoros = data['avgDailyPomodoros'] ?? 0.0;

                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '過去30日の統計',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildSummaryItem(
                              context,
                              '$totalPomodoros',
                              'ポモドーロ数',
                              Icons.timer,
                            ),
                            _buildSummaryItem(
                              context,
                              '${(totalMinutes / 60).toStringAsFixed(1)}',
                              '合計時間(時間)',
                              Icons.access_time,
                            ),
                            _buildSummaryItem(
                              context,
                              '${avgDailyPomodoros.toStringAsFixed(1)}',
                              '1日平均',
                              Icons.trending_up,
                            ),
                          ],
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

  Widget _buildSummaryItem(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
