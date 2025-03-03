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
                  // タイトル設定
                  // ...
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
