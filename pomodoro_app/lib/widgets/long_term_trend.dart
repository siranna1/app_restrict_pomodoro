import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_helper.dart';

class LongTermTrendAnalysis extends StatefulWidget {
  final String timeFrame; // 'monthly', 'quarterly', 'yearly'

  const LongTermTrendAnalysis({Key? key, this.timeFrame = 'monthly'})
      : super(key: key);

  @override
  _LongTermTrendAnalysisState createState() => _LongTermTrendAnalysisState();
}

class _LongTermTrendAnalysisState extends State<LongTermTrendAnalysis> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _trendData = [];
  String _selectedTimeFrame = 'monthly';

  @override
  void initState() {
    super.initState();
    _selectedTimeFrame = widget.timeFrame;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await DatabaseHelper.instance
          .getLongTermTrendData(_selectedTimeFrame);
      setState(() {
        _trendData = data;
        _isLoading = false;
      });
    } catch (e) {
      print('長期トレンドデータ読み込みエラー: $e');
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

    if (_trendData.isEmpty) {
      return const Center(child: Text('十分なデータがありません'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '長期トレンド分析',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            // 期間選択
            DropdownButton<String>(
              value: _selectedTimeFrame,
              items: [
                DropdownMenuItem(value: 'monthly', child: Text('月次')),
                DropdownMenuItem(value: 'quarterly', child: Text('四半期')),
                DropdownMenuItem(value: 'yearly', child: Text('年次')),
              ],
              onChanged: (value) {
                if (value != null && value != _selectedTimeFrame) {
                  setState(() {
                    _selectedTimeFrame = value;
                  });
                  _loadData();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 折れ線グラフ
        Container(
          height: 250,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= _trendData.length) {
                        return const SizedBox.shrink();
                      }

                      // 現在のperiodを取得（例："2024-01"）
                      final period = _trendData[index]['period'] as String;
                      final parts = period.split('-');

                      // 月次データの場合
                      if (_selectedTimeFrame == 'monthly') {
                        if (parts.length != 2) return const SizedBox.shrink();

                        final year = parts[0];
                        final month = parts[1];

                        // 最初のデータポイントか月が変わるタイミングでのみ表示
                        final isMonthChange = index == 0 ||
                            (index > 0 &&
                                month !=
                                    _trendData[index - 1]['period']
                                        .toString()
                                        .split('-')[1]);

                        if (!isMonthChange) {
                          return const SizedBox.shrink(); // 月が変わらないときは何も表示しない
                        }

                        // 年が変わるタイミングでは年も表示
                        final isYearChange = index == 0 ||
                            (index > 0 &&
                                year !=
                                    _trendData[index - 1]['period']
                                        .toString()
                                        .split('-')[0]);

                        // 表示テキスト（例："2024年1月" または "1月"）
                        final displayText = isYearChange
                            ? "$year年${int.parse(month)}月"
                            : "${int.parse(month)}月";

                        return Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            displayText,
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      // 四半期データの場合
                      else if (_selectedTimeFrame == 'quarterly') {
                        if (parts.length != 2) return const SizedBox.shrink();

                        final year = parts[0];
                        final quarter = parts[1];

                        // 最初のデータポイントか四半期が変わるタイミングでのみ表示
                        final isQuarterChange = index == 0 ||
                            (index > 0 &&
                                quarter !=
                                    _trendData[index - 1]['period']
                                        .toString()
                                        .split('-')[1]);

                        if (!isQuarterChange) {
                          return const SizedBox.shrink(); // 四半期が変わらないときは何も表示しない
                        }

                        // 年が変わるタイミングでは年も表示
                        final isYearChange = index == 0 ||
                            (index > 0 &&
                                year !=
                                    _trendData[index - 1]['period']
                                        .toString()
                                        .split('-')[0]);

                        final displayText =
                            isYearChange ? "$year年Q$quarter" : "Q$quarter";

                        return Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            displayText,
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
                      // 年次データの場合 - すべてのポイントで年を表示
                      else {
                        return Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            "${period}年",
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      }
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
                // 上部と右側のタイトルを非表示に
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: [
                // ポモドーロ数の折れ線
                LineChartBarData(
                  spots: _getSpots('count'),
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(show: false),
                ),
                // 集中度スコアの折れ線
                LineChartBarData(
                  spots: _getSpots('avgFocusScore'),
                  isCurved: true,
                  color: Colors.red,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(show: false),
                ),
              ],
            ),
          ),
        ),

        // 凡例
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.blue, 'ポモドーロ数'),
              const SizedBox(width: 24),
              _buildLegendItem(Colors.red, '平均集中度'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 詳細データテーブル
        _buildDetailsTable(),
      ],
    );
  }

  // 凡例アイテム
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }

  // グラフのスポットデータを生成
  List<FlSpot> _getSpots(String dataKey) {
    return _trendData.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final item = entry.value;

      double value;
      if (dataKey == 'avgFocusScore') {
        value = (item[dataKey] as double?) ?? 0.0;
        // スケーリング: 0-100の集中度を0-[最大ポモドーロ数]に変換
        final maxCount = _trendData
            .map((e) => e['count'] as int)
            .reduce((a, b) => a > b ? a : b)
            .toDouble();
        value = (value / 100) * maxCount;
      } else {
        value = (item[dataKey] as int).toDouble();
      }

      return FlSpot(index, value);
    }).toList();
  }

  // 詳細データテーブル
  Widget _buildDetailsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(_getPeriodLabel())),
          const DataColumn(label: Text('ポモドーロ数')),
          const DataColumn(label: Text('学習時間')),
          const DataColumn(label: Text('集中度')),
          const DataColumn(label: Text('活動日数')),
        ],
        rows: _trendData.map((item) {
          final minutes = item['totalMinutes'] as int;
          final hours = minutes ~/ 60;
          final mins = minutes % 60;

          return DataRow(
            cells: [
              DataCell(Text(_formatPeriod(item['period'] as String))),
              DataCell(Text('${item['count']}回')),
              DataCell(Text('${hours}時間${mins}分')),
              DataCell(Text(
                  '${(item['avgFocusScore'] as double).toStringAsFixed(1)}')),
              DataCell(Text('${item['activeDays']}日')),
            ],
          );
        }).toList(),
      ),
    );
  }

  // 期間ラベルを取得
  String _getPeriodLabel() {
    switch (_selectedTimeFrame) {
      case 'monthly':
        return '月';
      case 'quarterly':
        return '四半期';
      case 'yearly':
        return '年';
      default:
        return '期間';
    }
  }

  // 期間表示のフォーマット
  String _formatPeriod(String period) {
    try {
      if (_selectedTimeFrame == 'monthly') {
        final parts = period.split('-');
        return '${parts[0]}年${parts[1]}月';
      } else if (_selectedTimeFrame == 'quarterly') {
        final parts = period.split('-');
        return '${parts[0]}年Q${parts[1]}';
      } else {
        return '${period}年';
      }
    } catch (e) {
      return period;
    }
  }
}
