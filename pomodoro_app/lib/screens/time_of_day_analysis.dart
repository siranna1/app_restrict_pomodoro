import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_helper.dart';

class TimeOfDayAnalysisTab extends StatefulWidget {
  const TimeOfDayAnalysisTab({Key? key}) : super(key: key);

  @override
  _TimeOfDayAnalysisTabState createState() => _TimeOfDayAnalysisTabState();
}

class _TimeOfDayAnalysisTabState extends State<TimeOfDayAnalysisTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _timeOfDayStats = [];
  int _selectedDays = 30;

  // 時間帯の日本語ラベル
  final Map<String, String> _timeOfDayLabels = {
    'morning': '早朝 (5-8時)',
    'forenoon': '午前 (8-12時)',
    'afternoon': '午後 (12-17時)',
    'evening': '夕方 (17-20時)',
    'night': '夜間 (20-24時)',
    'midnight': '深夜 (0-5時)',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // データを読み込んでソート
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // データベースからデータを取得
      final stats = await DatabaseHelper.instance
          .getTimeOfDayStatisticsForUI(_selectedDays);

      // ポモドーロ数の多い順にソート
      stats.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      setState(() {
        _timeOfDayStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('時間帯データ読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_timeOfDayStats.isEmpty) {
      return const Center(child: Text('データがありません'));
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '時間帯別生産性分析',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // 棒グラフ
            Container(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _timeOfDayStats
                          .map((e) => e['count'] as int)
                          .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final item = _timeOfDayStats[groupIndex];
                        final timeOfDay = item['timeOfDay'] as String;
                        final label = _timeOfDayLabels[timeOfDay] ?? timeOfDay;

                        return BarTooltipItem(
                          '$label\n',
                          const TextStyle(color: Colors.white),
                          children: <TextSpan>[
                            TextSpan(
                              text: '${rod.toY.round()} ポモドーロ\n',
                              style: const TextStyle(
                                color: Colors.yellow,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text:
                                  '集中度: ${(item['avgFocusScore'] as double).toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Colors.white,
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
                          if (index >= 0 && index < _timeOfDayStats.length) {
                            final timeOfDay =
                                _timeOfDayStats[index]['timeOfDay'] as String;
                            final label =
                                _timeOfDayLabels[timeOfDay] ?? timeOfDay;

                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                label,
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
                  barGroups: _getBarGroups(),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 詳細データテーブル（すでにソート済みのデータを使用）
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '時間帯別詳細データ',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('時間帯')),
                          DataColumn(label: Text('ポモドーロ数')),
                          DataColumn(label: Text('集中度')),
                          DataColumn(label: Text('総学習時間')),
                          DataColumn(label: Text('平均中断回数')),
                        ],
                        rows: _timeOfDayStats.map((item) {
                          final timeOfDay = item['timeOfDay'] as String;
                          final label =
                              _timeOfDayLabels[timeOfDay] ?? timeOfDay;
                          final minutes = item['totalMinutes'] as int;
                          final hours = minutes ~/ 60;
                          final mins = minutes % 60;

                          return DataRow(
                            cells: [
                              DataCell(Text(label)),
                              DataCell(Text('${item['count']}回')),
                              DataCell(Text(
                                  '${(item['avgFocusScore'] as double).toStringAsFixed(1)}')),
                              DataCell(Text('${hours}時間${mins}分')),
                              DataCell(Text(
                                  '${(item['avgInterruptions'] as double).toStringAsFixed(1)}回')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ソート済みデータからバーグループを生成
  List<BarChartGroupData> _getBarGroups() {
    return _timeOfDayStats.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: item['count'].toDouble(),
            color: _getTimeOfDayColor(item['timeOfDay'] as String),
            width: 20,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }

  // 時間帯に応じた色を取得
  Color _getTimeOfDayColor(String timeOfDay) {
    switch (timeOfDay) {
      case 'morning':
        return Colors.orange[300]!;
      case 'forenoon':
        return Colors.blue[400]!;
      case 'afternoon':
        return Colors.green[400]!;
      case 'evening':
        return Colors.amber[600]!;
      case 'night':
        return Colors.indigo[400]!;
      case 'midnight':
        return Colors.purple[300]!;
      default:
        return Colors.grey;
    }
  }
}
