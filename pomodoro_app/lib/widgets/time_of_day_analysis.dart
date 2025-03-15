// widgets/time_of_day_analysis.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_helper.dart';

class TimeOfDayAnalysis extends StatefulWidget {
  final int days;

  const TimeOfDayAnalysis({Key? key, this.days = 30}) : super(key: key);

  @override
  _TimeOfDayAnalysisState createState() => _TimeOfDayAnalysisState();
}

class _TimeOfDayAnalysisState extends State<TimeOfDayAnalysis> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _timeOfDayStats = [];
  List<Map<String, dynamic>> _timeOfDayStatsUndetailed = [];

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
      final stats = await DatabaseHelper.instance
          .getTimeOfDayStatisticsForUI(widget.days);
      final statsUndetailed = await DatabaseHelper.instance
          .getTimeOfDayStatisticsForUI(widget.days, isDetailed: false);

      // 時間帯の表示順を定義
      final timeOrder = {
        'morning': 0, // 早朝 (5-8時)
        'forenoon': 1, // 午前 (8-12時)
        'afternoon': 2, // 午後 (12-17時)
        'evening': 3, // 夕方 (17-20時)
        'night': 4, // 夜間 (20-24時)
        'midnight': 5, // 深夜 (0-5時)
      };
      // 時間順にソート
      stats.sort((a, b) {
        return (timeOrder[a['timeOfDay']] ?? 999)
            .compareTo(timeOrder[b['timeOfDay']] ?? 999);
      });
      statsUndetailed.sort((a, b) {
        return (timeOrder[a['timeOfDay']] ?? 999)
            .compareTo(timeOrder[b['timeOfDay']] ?? 999);
      });

      setState(() {
        _timeOfDayStats = stats;
        _timeOfDayStatsUndetailed = statsUndetailed;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '時間帯別生産性分析',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),

        // 棒グラフ
        Container(
          height: 250,
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
                    return BarTooltipItem(
                      '${_timeOfDayStats[groupIndex]['label']}\n',
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
                              '集中度: ${(_timeOfDayStats[groupIndex]['avgFocusScore'] as double).toStringAsFixed(1)}',
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

                      if (index >= 0 &&
                          index < _timeOfDayStatsUndetailed.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _timeOfDayStatsUndetailed[index]['label'] as String,
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
                topTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              barGroups: _getBarGroups(),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // 生産性インサイト
        _buildProductivityInsight(),

        const SizedBox(height: 16),

        // 詳細データテーブル
        _buildDetailsTable(),
      ],
    );
  }

  // BarGroupデータを生成
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

  // 生産性インサイトのウィジェット
  Widget _buildProductivityInsight() {
    // 最も生産性の高い時間帯
    final mostProductiveTime = _timeOfDayStats
        .reduce((a, b) => (a['count'] as int) > (b['count'] as int) ? a : b);

    // 最も集中度が高い時間帯
    final mostFocusedTime = _timeOfDayStats.reduce((a, b) =>
        (a['avgFocusScore'] as double) > (b['avgFocusScore'] as double)
            ? a
            : b);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '生産性インサイト',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
                '最も生産的な時間帯: ${mostProductiveTime['label']} (${mostProductiveTime['count']}ポモドーロ)'),
            const SizedBox(height: 4),
            Text(
                '最も集中できる時間帯: ${mostFocusedTime['label']} (集中度: ${(mostFocusedTime['avgFocusScore'] as double).toStringAsFixed(1)})'),
          ],
        ),
      ),
    );
  }

  // 詳細データテーブル
  Widget _buildDetailsTable() {
    return SingleChildScrollView(
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
          final minutes = item['totalMinutes'] as int;
          final hours = minutes ~/ 60;
          final mins = minutes % 60;

          return DataRow(
            cells: [
              DataCell(Text(item['label'] as String)),
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
    );
  }
}
