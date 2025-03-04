// widgets/daily_statistics_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_helper.dart';

class DailyStatisticsChart extends StatefulWidget {
  const DailyStatisticsChart({Key? key}) : super(key: key);

  @override
  _DailyStatisticsChartState createState() => _DailyStatisticsChartState();
}

class _DailyStatisticsChartState extends State<DailyStatisticsChart> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getDailyStatistics(),
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

        // グラフ用のデータ
        final barGroups = data.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: item['count'].toDouble(),
                color: Theme.of(context).primaryColor,
                width: 15,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList();

        // 総計の計算
        final totalPomodoros =
            data.fold<int>(0, (sum, item) => sum + (item['count'] as int));
        final totalMinutes = data.fold<int>(
            0, (sum, item) => sum + (item['totalMinutes'] as int? ?? 0));

        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 日別ポモドーロ完了数グラフ
                Container(
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: data
                              .map((e) => e['count'] as int)
                              .reduce((a, b) => a > b ? a : b) *
                          1.2,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: Colors.blueGrey,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final dateStr = data[groupIndex]['date'] as String;
                            return BarTooltipItem(
                              '$dateStr\n',
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
                              if (index >= 0 && index < data.length) {
                                final date = data[index]['date'] as String;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    date.substring(5), // 月/日のみ表示
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

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 18),
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
