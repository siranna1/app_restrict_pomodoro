// screens/statistics_screen.dart - 統計画面の実装
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../services/database_helper.dart';
import '../models/pomodoro_session.dart';
import '../widgets/heat_map_calendar.dart';
import '../widgets/category_chart.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学習統計'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '日別'),
            Tab(text: '週別'),
            Tab(text: 'タスク別'),
            Tab(text: 'カレンダー'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DailyStatisticsTab(),
          WeeklyStatisticsTab(),
          TaskStatisticsTab(),
          CalendarStatisticsTab(),
        ],
      ),
    );
  }
}

// 日別統計タブ
class DailyStatisticsTab extends StatelessWidget {
  const DailyStatisticsTab({Key? key}) : super(key: key);

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
        final averagePomodoros =
            data.isEmpty ? 0.0 : totalPomodoros / data.length;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // サマリーカード
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        context,
                        '$totalPomodoros',
                        '合計ポモドーロ',
                        Icons.timer,
                      ),
                      _buildStatColumn(
                        context,
                        '${totalMinutes ~/ 60}時間${totalMinutes % 60}分',
                        '合計時間',
                        Icons.access_time,
                      ),
                      _buildStatColumn(
                        context,
                        averagePomodoros.toStringAsFixed(1),
                        '1日平均',
                        Icons.trending_up,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 日別グラフ
              Expanded(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '日別ポモドーロ完了数',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
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
                                  getTooltipItem:
                                      (group, groupIndex, rod, rodIndex) {
                                    final dateStr =
                                        data[groupIndex]['date'] as String;
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
                                        final date =
                                            data[index]['date'] as String;
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8.0),
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
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 詳細データテーブル
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '詳細データ',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('日付')),
                            DataColumn(label: Text('ポモドーロ数')),
                            DataColumn(label: Text('学習時間')),
                          ],
                          rows: data.map((item) {
                            final minutes = item['totalMinutes'] as int? ?? 0;
                            final hours = minutes ~/ 60;
                            final mins = minutes % 60;

                            return DataRow(
                              cells: [
                                DataCell(Text(item['date'] as String)),
                                DataCell(Text('${item['count']} 回')),
                                DataCell(Text('$hours時間$mins分')),
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
        );
      },
    );
  }

  Widget _buildStatColumn(
      BuildContext context, String value, String label, IconData icon) {
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

// 週別統計タブ
class WeeklyStatisticsTab extends StatelessWidget {
  const WeeklyStatisticsTab({Key? key}) : super(key: key);

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

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // サマリーカード
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn(
                        context,
                        '$totalPomodoros',
                        '週間合計',
                        Icons.timer,
                      ),
                      _buildStatColumn(
                        context,
                        '${totalMinutes ~/ 60}時間',
                        '合計時間',
                        Icons.access_time,
                      ),
                      _buildStatColumn(
                        context,
                        averagePomodoros.toStringAsFixed(1),
                        '週平均',
                        Icons.trending_up,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 週別グラフ
              Expanded(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '週別ポモドーロ完了数',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Expanded(
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
                                  getTooltipItem:
                                      (group, groupIndex, rod, rodIndex) {
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
                                      if (index >= 0 &&
                                          index < formattedData.length) {
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8.0),
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
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 詳細データテーブル
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '詳細データ',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('週')),
                            DataColumn(label: Text('ポモドーロ数')),
                            DataColumn(label: Text('学習時間')),
                          ],
                          rows: formattedData.map((item) {
                            final minutes = item['totalMinutes'] as int? ?? 0;
                            final hours = minutes ~/ 60;
                            final mins = minutes % 60;

                            return DataRow(
                              cells: [
                                DataCell(Text('${item['displayWeek']}週')),
                                DataCell(Text('${item['count']} 回')),
                                DataCell(Text('$hours時間$mins分')),
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

  Widget _buildStatColumn(
      BuildContext context, String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue),
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

// タスク別統計タブ
class TaskStatisticsTab extends StatelessWidget {
  const TaskStatisticsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getTaskStatistics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }

        final taskData = snapshot.data ?? [];

        if (taskData.isEmpty) {
          return const Center(child: Text('データがありません'));
        }

        // カテゴリ別データを取得
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: DatabaseHelper.instance.getCategoryStatistics(),
          builder: (context, categorySnapshot) {
            if (categorySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final categoryData = categorySnapshot.data ?? [];

            // カテゴリ円グラフ用データ
            final pieData = categoryData.map((item) {
              final category = item['category'] as String? ?? 'その他';
              final sessionCount = item['sessionCount'] as int? ?? 0;

              return PieChartSectionData(
                value: sessionCount.toDouble(),
                title: '$category\n$sessionCount',
                radius: 100,
                titleStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                color: _getCategoryColor(category),
              );
            }).toList();

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // カテゴリ別円グラフ
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'カテゴリ別学習時間',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 220,
                            child: categoryData.isEmpty
                                ? const Center(child: Text('データがありません'))
                                : PieChart(
                                    PieChartData(
                                      sections: pieData,
                                      centerSpaceRadius: 0,
                                      sectionsSpace: 2,
                                      borderData: FlBorderData(show: false),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // タスク別詳細
                  Expanded(
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'タスク別詳細',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: taskData.isEmpty
                                  ? const Center(child: Text('データがありません'))
                                  : ListView.builder(
                                      itemCount: taskData.length,
                                      itemBuilder: (context, index) {
                                        final task = taskData[index];
                                        final name =
                                            task['name'] as String? ?? '';
                                        final category =
                                            task['category'] as String? ?? '';
                                        final sessionCount =
                                            task['sessionCount'] as int? ?? 0;
                                        final totalMinutes =
                                            task['totalMinutes'] as int? ?? 0;
                                        final hours = totalMinutes ~/ 60;
                                        final minutes = totalMinutes % 60;

                                        return ListTile(
                                          title: Text(name),
                                          subtitle: Text(category),
                                          trailing: Text(
                                            '$sessionCount回 ($hours時間$minutes分)',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          leading: CircleAvatar(
                                            backgroundColor:
                                                _getCategoryColor(category),
                                            child: Text(
                                              name.isNotEmpty ? name[0] : '?',
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // カテゴリ名に応じた色を返す
  Color _getCategoryColor(String category) {
    // カテゴリ名のハッシュ値に基づいて色を生成
    final hashCode = category.hashCode;

    // 定義済みの色リスト
    const colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.amber,
      Colors.cyan,
    ];

    return colors[hashCode % colors.length];
  }
}

// カレンダー統計タブ
class CalendarStatisticsTab extends StatelessWidget {
  const CalendarStatisticsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 6か月分のデータを取得
    final now = DateTime.now();
    final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);

    return FutureBuilder<List<PomodoroSession>>(
      future: DatabaseHelper.instance.getPomodoroSessions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }

        final sessions = snapshot.data ?? [];

        // 日付ごとのセッション数を集計
        final Map<DateTime, int> dailyCounts = {};
        for (final session in sessions) {
          final date = DateTime(
            session.startTime.year,
            session.startTime.month,
            session.startTime.day,
          );

          dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヒートマップカレンダー
              Text(
                'ポモドーロ達成カレンダー',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: HeatMapCalendar(
                      startDate: sixMonthsAgo,
                      endDate: now,
                      dailyCounts: dailyCounts,
                      colorMode: ColorMode.COLOR,
                      monthLabels: const [
                        '1月',
                        '2月',
                        '3月',
                        '4月',
                        '5月',
                        '6月',
                        '7月',
                        '8月',
                        '9月',
                        '10月',
                        '11月',
                        '12月'
                      ],
                      weekLabels: const ['月', '火', '水', '木', '金', '土', '日'],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 最近の連続記録
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '達成記録',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildStreakSummary(context, dailyCounts),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 連続記録サマリーを構築
  Widget _buildStreakSummary(
      BuildContext context, Map<DateTime, int> dailyCounts) {
    // 記録のある日の一覧を取得
    final recordDays = dailyCounts.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // 日付の降順にソート

    if (recordDays.isEmpty) {
      return const Text('まだ記録がありません');
    }

    // 最新の記録日
    final lastRecordDate = recordDays.first;

    // 今日の日付
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    // 最新の記録が今日かどうか
    final isToday = lastRecordDate.isAtSameMomentAs(today);

    // 現在の連続日数を計算
    int currentStreak = 0;

    if (isToday) {
      // 今日から遡って連続日数をカウント
      currentStreak = 1;
      var checkDate = today.subtract(const Duration(days: 1));

      while (dailyCounts.containsKey(checkDate)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
    } else {
      // 最新の記録から連続日数をカウント
      DateTime? checkDate;
      for (int i = 0; i < recordDays.length - 1; i++) {
        if (i == 0) {
          checkDate = recordDays[i];
          currentStreak = 1;
        } else {
          final nextDate = recordDays[i];
          final diff = checkDate!.difference(nextDate).inDays;

          if (diff == 1) {
            currentStreak++;
            checkDate = nextDate;
          } else {
            break;
          }
        }
      }
    }

    // 最長の連続記録を計算
    int longestStreak = 0;
    int currentLongestStreak = 0;
    DateTime? prevDate;

    for (final date in recordDays) {
      if (prevDate == null) {
        currentLongestStreak = 1;
      } else {
        final diff = prevDate.difference(date).inDays;

        if (diff == 1) {
          currentLongestStreak++;
        } else {
          currentLongestStreak = 1;
        }
      }

      if (currentLongestStreak > longestStreak) {
        longestStreak = currentLongestStreak;
      }

      prevDate = date;
    }

    // 総学習日数
    final totalDays = recordDays.length;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStreakItem(
              context,
              '$currentStreak日',
              '現在の連続記録',
              Icons.local_fire_department,
              Colors.orange,
            ),
            _buildStreakItem(
              context,
              '$longestStreak日',
              '最長連続記録',
              Icons.emoji_events,
              Colors.amber,
            ),
            _buildStreakItem(
              context,
              '$totalDays日',
              '合計学習日数',
              Icons.calendar_today,
              Colors.blue,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isToday) ...[
          const LinearProgressIndicator(
            value: 1.0,
            minHeight: 10,
            backgroundColor: Colors.grey,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          const SizedBox(height: 8),
          Text(
            '今日も学習を完了しました！明日も続けましょう。',
            style: TextStyle(
              color: Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          const LinearProgressIndicator(
            value: 0.0,
            minHeight: 10,
            backgroundColor: Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            '今日はまだポモドーロを完了していません。今すぐ始めましょう！',
            style: TextStyle(
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildStreakItem(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
