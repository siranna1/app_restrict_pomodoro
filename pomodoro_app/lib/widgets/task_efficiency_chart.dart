// widgets/task_efficiency_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_helper.dart';

class TaskEfficiencyChart extends StatefulWidget {
  const TaskEfficiencyChart({Key? key}) : super(key: key);

  @override
  _TaskEfficiencyChartState createState() => _TaskEfficiencyChartState();
}

class _TaskEfficiencyChartState extends State<TaskEfficiencyChart> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _taskData = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await DatabaseHelper.instance.getTaskEfficiencyData();
      // 集中度スコアでソート
      data.sort((a, b) => (b['avgFocusScore'] as double)
          .compareTo(a['avgFocusScore'] as double));

      setState(() {
        _taskData = data;
        _isLoading = false;
      });
    } catch (e) {
      print('タスク効率データ読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_taskData.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('十分なタスクデータがありません')),
      );
    }

    // 表示するタスク数を制限（最大10個）
    final displayData = _taskData.take(10).toList();

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100, // 集中度は0-100
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: Colors.blueGrey,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final task = displayData[groupIndex];
                final name = task['name'] as String? ?? '';
                final avgFocus = task['avgFocusScore'] as double? ?? 0.0;
                final completedPomodoros =
                    task['completedPomodoros'] as int? ?? 0;

                return BarTooltipItem(
                  '$name\n',
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  children: <TextSpan>[
                    TextSpan(
                      text: '集中度: ${avgFocus.toStringAsFixed(1)}%\n',
                      style: const TextStyle(color: Colors.yellow),
                    ),
                    TextSpan(
                      text: 'ポモドーロ: $completedPomodoros回',
                      style: const TextStyle(color: Colors.white),
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
                  if (index >= 0 && index < displayData.length) {
                    final name = displayData[index]['name'] as String? ?? '';
                    // 長い名前は短く表示
                    final shortName =
                        name.length > 10 ? '${name.substring(0, 8)}...' : name;

                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        shortName,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return const Text('');
                },
                reservedSize: 40,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value % 20 == 0) {
                    return Text(value.toInt().toString());
                  }
                  return const Text('');
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
          barGroups: displayData.asMap().entries.map((entry) {
            final index = entry.key;
            final task = entry.value;
            final avgFocus = task['avgFocusScore'] as double? ?? 0.0;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: avgFocus,
                  color: _getFocusColor(avgFocus),
                  width: 20,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
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
