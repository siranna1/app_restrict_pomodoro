// screens/statistics_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/export_service.dart';
import 'statistics_tab/short_term_analysis_tab.dart';
import 'statistics_tab/trend_analysis_tab.dart';
import 'statistics_tab/detailed_analysis_tab.dart';
import 'statistics_tab/session_history_tab.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

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

  // テストデータを追加
  Future<void> _addTestData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await DatabaseHelper.instance.addTestData(10);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('10件のテストデータを追加しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // テストデータを削除
  Future<void> _deleteTestData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final deletedCount = await DatabaseHelper.instance.deleteTestData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${deletedCount}件のテストデータを削除しました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // データエクスポートダイアログ
  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('データをエクスポート'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('CSVとしてエクスポート'),
                subtitle: const Text('スプレッドシートで開くことができます'),
                onTap: () async {
                  Navigator.of(context).pop();

                  // プログレスインジケータを表示
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  );

                  try {
                    final exportService = ExportService();
                    final file = await exportService.exportSessionsToCSV();

                    // プログレスインジケータを閉じる
                    if (context.mounted) Navigator.of(context).pop();

                    if (file != null) {
                      // 共有ダイアログを表示
                      await exportService.shareCSVFile(file);
                    } else {
                      _showErrorSnackBar(context, 'エクスポートに失敗しました');
                    }
                  } catch (e) {
                    // プログレスインジケータを閉じる
                    if (context.mounted) Navigator.of(context).pop();
                    _showErrorSnackBar(context, 'エラーが発生しました: $e');
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学習統計'),
        actions: [
          // テストデータ追加ボタン
          IconButton(
            icon: const Icon(Icons.add_chart),
            tooltip: 'テストデータを追加',
            onPressed: _isLoading ? null : _addTestData,
          ),
          // エクスポートボタン
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'データをエクスポート',
            onPressed: () => _showExportDialog(context),
          ),
          // オプションメニュー
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'add_10',
                child: Text('テストデータ10件追加'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text('テストデータを削除'),
              ),
            ],
            onSelected: (value) async {
              if (value == 'delete') {
                await _deleteTestData();
              } else if (value == 'add_10') {
                await DatabaseHelper.instance.addTestData(10);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('10件のテストデータを追加しました')),
                );
              }
              setState(() {}); // 画面を更新
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '短期分析'),
            Tab(text: 'トレンド'),
            Tab(text: '詳細分析'),
            Tab(text: '履歴'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ShortTermAnalysisTab(),
          TrendAnalysisTab(),
          DetailedAnalysisTab(),
          SessionHistoryTab(),
        ],
      ),
    );
  }
}
