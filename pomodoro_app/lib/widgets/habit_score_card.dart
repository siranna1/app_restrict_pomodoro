import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class HabitScoreCard extends StatefulWidget {
  const HabitScoreCard({Key? key}) : super(key: key);

  @override
  _HabitScoreCardState createState() => _HabitScoreCardState();
}

class _HabitScoreCardState extends State<HabitScoreCard> {
  bool _isLoading = true;
  Map<String, dynamic> _habitStats = {};

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
      final habitStats = await DatabaseHelper.instance.getHabitFormationStats();
      setState(() {
        _habitStats = habitStats;
        _isLoading = false;
      });
    } catch (e) {
      print('習慣データ読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final currentStreak = _habitStats['currentStreak'] as int? ?? 0;
    final longestStreak = _habitStats['longestStreak'] as int? ?? 0;
    final consistencyScore = _habitStats['consistencyScore'] as double? ?? 0.0;
    final workDaysLast30 = _habitStats['workDaysLast30'] as int? ?? 0;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '学習習慣スコア',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScoreItem(
                  context,
                  Icons.local_fire_department,
                  '$currentStreak日',
                  '現在の連続学習',
                  Colors.orange,
                ),
                _buildScoreItem(
                  context,
                  Icons.emoji_events,
                  '$longestStreak日',
                  '最長連続記録',
                  Colors.amber,
                ),
                _buildScoreItem(
                  context,
                  Icons.insights,
                  '${consistencyScore.toStringAsFixed(0)}%',
                  '一貫性スコア',
                  Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: workDaysLast30 / 30,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                _getConsistencyColor(workDaysLast30 / 30),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '過去30日間: $workDaysLast30日間学習 (${(workDaysLast30 / 30 * 100).toStringAsFixed(0)}%)',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _getConsistencyColor(workDaysLast30 / 30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
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

  Color _getConsistencyColor(double ratio) {
    if (ratio >= 0.8) return Colors.green;
    if (ratio >= 0.6) return Colors.lightGreen;
    if (ratio >= 0.4) return Colors.amber;
    if (ratio >= 0.2) return Colors.orange;
    return Colors.red;
  }
}
