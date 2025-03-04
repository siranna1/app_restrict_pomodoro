// widgets/heat_map_calendar.dart - ヒートマップカレンダーウィジェット
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ColorMode {
  COLOR,
  OPACITY,
}

class HeatMapCalendar extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Map<DateTime, int> dailyCounts;
  final ColorMode colorMode;
  final List<String> monthLabels;
  final List<String> weekLabels;

  const HeatMapCalendar({
    Key? key,
    required this.startDate,
    required this.endDate,
    required this.dailyCounts,
    this.colorMode = ColorMode.OPACITY,
    this.monthLabels = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ],
    this.weekLabels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  }) : super(key: key);

  // widgets/heat_map_calendar.dart の build メソッドを修正

  @override
  Widget build(BuildContext context) {
    // 最大セッション数を取得
    // final maxCount = dailyCounts.isEmpty
    //     ? 1
    //     : dailyCounts.values.reduce((max, value) => max > value ? max : value);
    final maxCount = 10;
    // 表示する月のリストを生成
    final monthList = _generateMonthList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 凡例 - スクロールエリアの外に配置
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 40.0),
          child: Row(
            children: [
              const Text('少'),
              const SizedBox(width: 4),
              for (int i = 0; i < 5; i++)
                Container(
                  width: 15,
                  height: 15,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: _getColor(i * (maxCount / 4).ceil(), maxCount),
                ),
              const SizedBox(width: 4),
              const Text('多'),
            ],
          ),
        ),

        // 曜日ラベル - これもスクロールエリアの外に配置
        Padding(
          padding: const EdgeInsets.only(left: 40.0),
          child: Row(
            children: [
              const SizedBox(width: 2),
              ...List.generate(7, (index) {
                return SizedBox(
                  width: 15,
                  child: Text(
                    weekLabels[index],
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // カレンダーのスクロール可能な部分
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 各月のヒートマップ
                for (final month in monthList)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 月ラベル
                      SizedBox(
                        width: 40,
                        child: Text(
                          monthLabels[month.month - 1],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),

                      // 該当月のカレンダーグリッド
                      _buildMonthGrid(month, maxCount),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 表示する月のリストを生成
  List<DateTime> _generateMonthList() {
    final result = <DateTime>[];

    // 表示開始月
    DateTime currentMonth = DateTime(startDate.year, startDate.month, 1);

    // 表示終了月
    final lastMonth = DateTime(endDate.year, endDate.month, 1);

    while (!currentMonth.isAfter(lastMonth)) {
      result.add(currentMonth);
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }

    return result;
  }

  // 月のグリッドを構築
  Widget _buildMonthGrid(DateTime month, int maxCount) {
    // 月の初日
    final firstDayOfMonth = DateTime(month.year, month.month, 1);

    // 月の最終日
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);

    // 初日の曜日（0: 月曜, 6: 日曜）
    final firstWeekday = firstDayOfMonth.weekday - 1;

    // カレンダーに表示する日数（前月の残りも含む）
    final daysInGrid = lastDayOfMonth.day + firstWeekday;

    // 週数
    final weeksCount = (daysInGrid / 7).ceil();

    return Column(
      children: List.generate(weeksCount, (weekIndex) {
        return Row(
          children: List.generate(7, (dayIndex) {
            final dayOffset = weekIndex * 7 + dayIndex - firstWeekday;

            if (dayOffset < 0 || dayOffset >= lastDayOfMonth.day) {
              // 前月または翌月のセル
              return const SizedBox(width: 15, height: 15);
            }

            // カレンダーの日付
            final date = DateTime(month.year, month.month, dayOffset + 1);

            // 当日のセッション数
            final count = dailyCounts[date] ?? 0;

            // 色を取得
            final color = _getColor(count, maxCount);

            return Container(
              width: 15,
              height: 15,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Tooltip(
                message:
                    '${DateFormat('yyyy/MM/dd').format(date)}: $count ポモドーロ',
                child: const SizedBox(),
              ),
            );
          }),
        );
      }),
    );
  }

  // 値に応じた色を取得
  Color _getColor(int count, int maxCount) {
    if (count == 0) {
      return Colors.grey[300]!;
    }

    if (colorMode == ColorMode.OPACITY) {
      // 透明度モード（緑色の濃淡）
      final opacity = count / maxCount > 1 ? 1 : count / maxCount;
      return Colors.purple.withValues(alpha: 0.2 + opacity * 0.8);
    } else {
      // カラーモード（青→緑→黄→赤）
      if (count <= maxCount * 0.25) {
        return Colors.blue[300]!;
      } else if (count <= maxCount * 0.5) {
        return Colors.green[400]!;
      } else if (count <= maxCount * 0.75) {
        return Colors.amber[500]!;
      } else {
        return Colors.red[400]!;
      }
    }
  }
}
