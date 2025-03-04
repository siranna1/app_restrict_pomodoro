// tabs/detailed_analysis_tab.dart
import 'package:flutter/material.dart';
import '../../widgets/time_of_day_analysis.dart';
import '../../widgets/category_chart.dart';
import '../../widgets/task_efficiency_chart.dart';
import '../../services/database_helper.dart';

class DetailedAnalysisTab extends StatelessWidget {
  const DetailedAnalysisTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 時間帯別分析
            Text(
              '時間帯別分析',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const TimeOfDayAnalysis(),

            const SizedBox(height: 20),

            // タスク効率分析
            Text(
              'タスク効率分析',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const TaskEfficiencyChart(),

            const SizedBox(height: 20),

            // カテゴリー別分析
            Text(
              'カテゴリ別分析',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper.instance.getCategoryStatistics(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final categoryData = snapshot.data ?? [];

                if (categoryData.isEmpty) {
                  return const Center(child: Text('カテゴリデータがありません'));
                }

                return SizedBox(
                  height: 300,
                  child: CategoryChart(categoryData: categoryData),
                );
              },
            ),

            const SizedBox(height: 20),

            // 曜日別効率
            Text(
              '曜日別効率',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            // 曜日別効率のデータ取得と表示を修正
            FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper.instance.getWeekdayEfficiencyData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final weekdayData = snapshot.data ?? [];

                // すべての曜日のデータを準備
                final weekdayNames = ['日', '月', '火', '水', '木', '金', '土'];
                final fullWeekdayData = List.generate(7, (index) {
                  // 該当する曜日のデータを検索
                  final existingData = weekdayData
                      .where(
                          (day) => int.parse(day['weekday'] as String) == index)
                      .toList();

                  // 既存データがあれば使用、なければ0のデータを作成
                  if (existingData.isNotEmpty) {
                    return existingData.first;
                  } else {
                    return {
                      'weekday': '$index',
                      'count': 0,
                      'avgFocusScore': 0.0,
                      'totalMinutes': 0,
                      'avgInterruptions': 0.0,
                    };
                  }
                });

                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '曜日別効率',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: fullWeekdayData.length,
                            itemBuilder: (context, index) {
                              final day = fullWeekdayData[index];
                              final weekdayName = weekdayNames[index];
                              final count = day['count'] as int;
                              final avgFocus =
                                  day['avgFocusScore'] as double? ?? 0.0;

                              return Container(
                                width: 100,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  children: [
                                    Text(
                                      weekdayName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: Container(
                                        width: 60,
                                        decoration: BoxDecoration(
                                          // 集中度に基づいた色（セッションがない場合はグレー）
                                          color: count > 0
                                              ? _getFocusColor(avgFocus)
                                              : Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '$count',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                            const Text(
                                              '回', // シンプルに「回」とする
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      count > 0
                                          ? '集中度: ${avgFocus.toStringAsFixed(1)}'
                                          : 'データなし',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            },
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

  Color _getFocusColor(double focusScore) {
    if (focusScore >= 90) return Colors.green[700]!;
    if (focusScore >= 80) return Colors.green[500]!;
    if (focusScore >= 70) return Colors.lightGreen;
    if (focusScore >= 60) return Colors.amber;
    if (focusScore >= 50) return Colors.orange;
    return Colors.red;
  }
}
