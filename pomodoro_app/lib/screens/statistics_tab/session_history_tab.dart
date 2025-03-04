// tabs/session_history_tab.dart
import 'package:flutter/material.dart';
import '../../services/database_helper.dart';

class SessionHistoryTab extends StatefulWidget {
  const SessionHistoryTab({Key? key}) : super(key: key);

  @override
  _SessionHistoryTabState createState() => _SessionHistoryTabState();
}

class _SessionHistoryTabState extends State<SessionHistoryTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _sessionData = [];
  String _filter = 'all'; // 'all', 'work', 'break'

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
      // 日付降順でセッションデータを取得
      final sessions = await DatabaseHelper.instance.getAllSessionsForExport();
      setState(() {
        _sessionData = sessions;
        _isLoading = false;
      });
    } catch (e) {
      print('セッション履歴データ読み込みエラー: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredSessions() {
    if (_filter == 'all') {
      return _sessionData;
    } else if (_filter == 'work') {
      return _sessionData.where((session) => session['isBreak'] != 1).toList();
    } else {
      // break
      return _sessionData.where((session) => session['isBreak'] == 1).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sessionData.isEmpty) {
      return const Center(child: Text('ポモドーロセッションの記録がありません'));
    }

    // フィルタリングしたセッションデータ
    final filteredSessions = _getFilteredSessions();

    // 日付でグループ化
    final groupedSessions = _groupSessionsByDate(filteredSessions);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // フィルター切り替え
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: [
                const Text('表示フィルター:'),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('すべて'),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('作業セッション'),
                  selected: _filter == 'work',
                  onSelected: (_) => setState(() => _filter = 'work'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('休憩'),
                  selected: _filter == 'break',
                  onSelected: (_) => setState(() => _filter = 'break'),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Text(
              'ポモドーロセッション履歴 (${filteredSessions.length}件)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),

          if (filteredSessions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('表示するデータがありません'),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: groupedSessions.length,
                itemBuilder: (context, index) {
                  final dateStr = groupedSessions.keys.elementAt(index);
                  final sessions = groupedSessions[dateStr]!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 日付ヘッダー
                      Container(
                        color: Colors.grey[200],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            Text(
                              _formatDateHeader(dateStr),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${sessions.length}セッション)',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // その日のセッションリスト
                      ...sessions.map((session) => _buildSessionCard(session)),

                      // 日付間の区切り線（最後の項目以外）
                      if (index < groupedSessions.length - 1)
                        const Divider(height: 1, thickness: 1),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // セッションカードの構築
  Widget _buildSessionCard(Map<String, dynamic> session) {
    final isBreak = session['isBreak'] == 1;
    final completed = session['completed'] == 1;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 上部: タスク名とセッションタイプ
            Row(
              children: [
                Expanded(
                  child: Text(
                    isBreak ? '休憩時間' : (session['taskName'] ?? '名称なし'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isBreak ? Colors.green : Colors.black,
                    ),
                  ),
                ),
                // セッションタイプ表示
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: isBreak
                        ? Colors.green[100]
                        : (completed == 1 ? Colors.blue[100] : Colors.red[100]),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isBreak ? '休憩' : (completed == 1 ? '完了' : '中断'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isBreak
                          ? Colors.green[800]
                          : (completed == 1
                              ? Colors.blue[800]
                              : Colors.red[800]),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 時間情報
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${_formatTime(session['startTime'])} - ${_formatTime(session['endTime'])}',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(width: 16),
                Text(
                  '${session['durationMinutes']}分',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // タスクカテゴリ（休憩以外）
            if (!isBreak && session['taskCategory'] != null)
              Chip(
                label: Text(
                  session['taskCategory'],
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.grey[200],
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),

            // 集中度スコアなどの詳細情報（休憩以外）
            if (!isBreak) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (session['focusScore'] != null) ...[
                    _buildInfoItem(
                      '集中度',
                      '${(session['focusScore'] as double).toStringAsFixed(1)}%',
                      icon: Icons.psychology,
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (session['interruptionCount'] != null) ...[
                    _buildInfoItem(
                      '中断',
                      '${session['interruptionCount']}回',
                      icon: Icons.notifications_active,
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (session['timeOfDay'] != null)
                    _buildInfoItem(
                      '時間帯',
                      _getTimeOfDayLabel(session['timeOfDay']),
                      icon: Icons.wb_sunny,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 情報項目ウィジェット
  Widget _buildInfoItem(String label, String value, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
        ],
        Text(
          '$label: $value',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  // セッションを日付ごとにグループ化
  Map<String, List<Map<String, dynamic>>> _groupSessionsByDate(
      List<Map<String, dynamic>> sessions) {
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final session in sessions) {
      final startTime = DateTime.parse(session['startTime']);
      final dateStr =
          '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';

      if (!grouped.containsKey(dateStr)) {
        grouped[dateStr] = [];
      }

      grouped[dateStr]!.add(session);
    }

    // 日付の降順でソート（最新の日付が最初）
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final result = <String, List<Map<String, dynamic>>>{};

    for (final key in sortedKeys) {
      result[key] = grouped[key]!;
    }

    return result;
  }

  // 日付ヘッダーのフォーマット
  String _formatDateHeader(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '今日 (${date.month}/${date.day})';
    } else if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return '昨日 (${date.month}/${date.day})';
    } else {
      return '${date.year}/${date.month}/${date.day}';
    }
  }

  // 時刻のフォーマット
  String _formatTime(String isoTimeStr) {
    final dateTime = DateTime.parse(isoTimeStr);
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 時間帯の表示名
  String _getTimeOfDayLabel(String timeOfDay) {
    switch (timeOfDay) {
      case 'morning':
        return '早朝';
      case 'forenoon':
        return '午前';
      case 'afternoon':
        return '午後';
      case 'evening':
        return '夕方';
      case 'night':
        return '夜間';
      case 'midnight':
        return '深夜';
      default:
        return timeOfDay;
    }
  }
}
