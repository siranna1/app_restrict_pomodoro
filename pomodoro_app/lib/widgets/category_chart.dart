// widgets/category_chart.dart - カテゴリグラフウィジェット
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class CategoryChart extends StatelessWidget {
  final List<Map<String, dynamic>> categoryData;

  const CategoryChart({
    Key? key,
    required this.categoryData,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (categoryData.isEmpty) {
      return const Center(child: Text('データがありません'));
    }

    // 合計セッション数
    final totalSessions = categoryData.fold<int>(
        0, (sum, item) => sum + (item['sessionCount'] as int? ?? 0));

    // 円グラフのセクションデータを作成
    final sections = <PieChartSectionData>[];

    for (int i = 0; i < categoryData.length; i++) {
      final item = categoryData[i];
      final category = item['category'] as String? ?? 'その他';
      final sessionCount = item['sessionCount'] as int? ?? 0;
      final percentage = sessionCount / totalSessions * 100;

      sections.add(
        PieChartSectionData(
          color: _getCategoryColor(i),
          value: sessionCount.toDouble(),
          title: '$category\n${percentage.toStringAsFixed(1)}%',
          radius: 100,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 0,
              sectionsSpace: 2,
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        // const SizedBox(height: 16),
        // Wrap(
        //   spacing: 8,
        //   runSpacing: 8,
        //   children: categoryData.asMap().entries.map((entry) {
        //     final index = entry.key;
        //     final item = entry.value;
        //     final category = item['category'] as String? ?? 'その他';
        //     final sessionCount = item['sessionCount'] as int? ?? 0;
        //     final totalMinutes = item['totalMinutes'] as int? ?? 0;
        //     final hours = totalMinutes ~/ 60;
        //     final minutes = totalMinutes % 60;

        //     return Chip(
        //       avatar: CircleAvatar(
        //         backgroundColor: _getCategoryColor(index),
        //         radius: 8,
        //       ),
        //       label: Text(
        //         '$category: $sessionCount回 ($hours時間$minutes分)',
        //         style: const TextStyle(fontSize: 12),
        //       ),
        //       backgroundColor: Colors.grey[200],
        //     );
        //   }).toList(),
        // ),
      ],
    );
  }

  // カテゴリインデックスに基づく色を返す
  Color _getCategoryColor(int index) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
    ];

    return colors[index % colors.length];
  }
}
