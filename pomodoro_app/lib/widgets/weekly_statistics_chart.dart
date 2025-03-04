// widgets/weekly_statistics_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

class WeeklyStatisticsChart extends StatefulWidget {
  const WeeklyStatisticsChart({Key? key}) : super(key: key);

  @override
  _WeeklyStatisticsChartState createState() => _WeeklyStatisticsChartState();
}

class _WeeklyStatisticsChartState extends State<WeeklyStatisticsChart> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getWeeklyStatistics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }

        final data = snapshot.data ?? [];

        if (data.isEmpty) {
          return const Center(child: Text('データがありません'));
        }

        // 週の表示名を作成
        final formattedData = data.map((item) {
          final week = item['week'] as String;
          final parts = week.split('-');
          final year = parts[0];
          final weekNum = parts[1];

          // 週の最初の日を計算
          final firstDay =
              _getFirstDayOfWeek(int.parse(year), int.parse(weekNum));
          final displayWeek = DateFormat('MM/dd').format(firstDay);

          return {
            ...item,
            'displayWeek': displayWeek,
          };
        }).toList();

        // グラフ用データ
        final barGroups = formattedData.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: item['count'].toDouble(),
                color: Colors.blue,
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList();

        // 総計と平均の計算
        final totalPomodoros = formattedData.fold<int>(
            0, (sum, item) => sum + (item['count'] as int));
        final totalMinutes = formattedData.fold<int>(
            0, (sum, item) => sum + (item['totalMinutes'] as int? ?? 0));
        final averagePomodoros =
            formattedData.isEmpty ? 0.0 : totalPomodoros / formattedData.length;

        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 週別ポモドーロ完了数グラフ
                Container(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: formattedData
                              .map((e) => e['count'] as int)
                              .reduce((a, b) => a > b ? a : b) *
                          1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: Colors.blueGrey,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${formattedData[groupIndex]['displayWeek']}週\n',
                              const TextStyle(color: Colors.white),
                              children: <TextSpan>[
                                TextSpan(
                                  text: '${rod.toY.round()} ポモドーロ',
                                  style: const TextStyle(
                                    color: Colors.yellow,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index >= 0 && index < formattedData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    formattedData[index]['displayWeek']
                                        as String,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) {
                                return const Text('0');
                              }
                              return Text(value.toInt().toString());
                            },
                          ),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                    ),
                  ),
                ),

                // サマリー情報
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      context,
                      '合計: $totalPomodoros回',
                      Icons.timer,
                    ),
                    _buildSummaryItem(
                      context,
                      '週平均: ${averagePomodoros.toStringAsFixed(1)}回',
                      Icons.trending_up,
                    ),
                    _buildSummaryItem(
                      context,
                      '${totalMinutes ~/ 60}時間${totalMinutes % 60}分',
                      Icons.access_time,
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

  // ISO週番号から週の最初の日（月曜日）の日付を計算
  DateTime _getFirstDayOfWeek(int year, int weekNumber) {
    // 1月4日は常に第1週に含まれる
    final jan4 = DateTime(year, 1, 4);
    // 1月4日の曜日（月曜日が1、日曜日が7）
    final jan4Weekday = jan4.weekday;
    // 第1週の最初の日（月曜日）
    final firstMonday = jan4.subtract(Duration(days: jan4Weekday - 1));
    // 求める週の最初の日
    return firstMonday.add(Duration(days: (weekNumber - 1) * 7));
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 18),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
