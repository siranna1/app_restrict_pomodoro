// screens/ticktick_sync_screen.dart - TickTick同期設定画面
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/ticktick_provider.dart';
import '../providers/task_provider.dart';

class TickTickSyncScreen extends StatefulWidget {
  const TickTickSyncScreen({Key? key}) : super(key: key);

  @override
  _TickTickSyncScreenState createState() => _TickTickSyncScreenState();
}

class _TickTickSyncScreenState extends State<TickTickSyncScreen> {
  final _authCodeController = TextEditingController();
  bool _isImporting = false;
  int _importedTaskCount = 0;

  @override
  void dispose() {
    _authCodeController.dispose();
    super.dispose();
  }

  // TickTickの認証ページを開く
  Future<void> _openTickTickAuth() async {
    // 注: 実際のアプリ開発では、クライアントIDを安全に管理してください
    const clientId = 'YOUR_TICKTICK_CLIENT_ID';
    const redirectUri = 'com.yourapp.pomodoro://oauth/callback';

    // TickTickのOAuth2認証ページURL
    final authUrl = Uri.parse(
      'https://ticktick.com/oauth/authorize'
      '?client_id=$clientId'
      '&redirect_uri=$redirectUri'
      '&response_type=code'
      '&scope=tasks:read tasks:write',
    );

    if (await canLaunchUrl(authUrl)) {
      await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ブラウザを開けませんでした')),
      );
    }
  }

  // TickTickからタスクをインポート
  Future<void> _importTasks() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final tickTickProvider =
          Provider.of<TickTickProvider>(context, listen: false);
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);

      final importedTasks = await tickTickProvider.importTasks();
      _importedTaskCount = importedTasks.length;

      // タスクリストを更新
      await taskProvider.loadTasks();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$_importedTaskCount 件のタスクをインポートしました')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('タスクのインポート中にエラーが発生しました: $e')),
      );
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tickTickProvider = Provider.of<TickTickProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TickTick同期設定'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TickTick連携状態',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          tickTickProvider.isAuthenticated
                              ? Icons.check_circle
                              : Icons.error,
                          color: tickTickProvider.isAuthenticated
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tickTickProvider.isAuthenticated ? '連携中' : '未連携',
                          style: TextStyle(
                            color: tickTickProvider.isAuthenticated
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (tickTickProvider.lastSyncTime != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '最終同期: ${_formatDateTime(tickTickProvider.lastSyncTime!)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!tickTickProvider.isAuthenticated) ...[
              Text(
                'TickTickと連携する',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.link),
                label: const Text('TickTickと連携する'),
                onPressed: _openTickTickAuth,
              ),
              const SizedBox(height: 16),
              const Text('認証後に表示される認証コードを入力:'),
              const SizedBox(height: 8),
              TextField(
                controller: _authCodeController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '認証コードを入力',
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                child: const Text('認証コードを送信'),
                onPressed: () async {
                  final code = _authCodeController.text.trim();
                  if (code.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('認証コードを入力してください')),
                    );
                    return;
                  }

                  final success = await tickTickProvider.authenticate(code);

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('TickTickとの連携に成功しました')),
                    );
                    _authCodeController.clear();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('認証に失敗しました。コードを確認してください')),
                    );
                  }
                },
              ),
            ] else ...[
              Text(
                'TickTickからタスクをインポート',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: Text(_isImporting ? 'インポート中...' : 'タスクをインポート'),
                onPressed: _isImporting ? null : _importTasks,
              ),
              if (_importedTaskCount > 0) ...[
                const SizedBox(height: 8),
                Text('$_importedTaskCount 件のタスクをインポートしました'),
              ],
              const SizedBox(height: 24),
              Text(
                '同期設定',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('ポモドーロ完了時に自動同期'),
                subtitle: const Text('ポモドーロセッションの完了をTickTickに記録します'),
                value: true, // 設定値として保存・取得する実装が必要
                onChanged: (value) {
                  // 設定を保存する実装
                },
              ),
              SwitchListTile(
                title: const Text('タスク完了時に自動同期'),
                subtitle: const Text('タスクの完了状態をTickTickと同期します'),
                value: true, // 設定値として保存・取得する実装が必要
                onChanged: (value) {
                  // 設定を保存する実装
                },
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('連携を解除'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                onPressed: () {
                  // 連携解除の実装
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('連携解除の確認'),
                      content: const Text('TickTickとの連携を解除しますか？'),
                      actions: [
                        TextButton(
                          child: const Text('キャンセル'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: const Text('解除する'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          onPressed: () {
                            // 連携解除処理
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 日時のフォーマット
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
