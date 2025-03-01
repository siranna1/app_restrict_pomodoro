// screens/settings_screen.dart - 設定画面
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/app_restriction_provider.dart';
import 'app_restriction_screen.dart';
import 'ticktick_sync_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 設定の一時保存用
  late int _workDuration;
  late int _shortBreakDuration;
  late int _longBreakDuration;
  late int _longBreakInterval;
  bool _enableNotifications = true;
  bool _enableSounds = true;
  String _selectedTheme = 'system';

  @override
  void initState() {
    super.initState();

    // 現在の設定を読み込み
    final pomodoroProvider =
        Provider.of<PomodoroProvider>(context, listen: false);
    _workDuration = pomodoroProvider.workDuration;
    _shortBreakDuration = pomodoroProvider.shortBreakDuration;
    _longBreakDuration = pomodoroProvider.longBreakDuration;
    _longBreakInterval = pomodoroProvider.longBreakInterval;
  }

  @override
  Widget build(BuildContext context) {
    final pomodoroProvider = Provider.of<PomodoroProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          // タイマー設定セクション
          _buildSectionHeader(context, 'タイマー設定'),

          ListTile(
            title: const Text('作業時間'),
            subtitle: Text('$_workDuration 分'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _workDuration > 1
                      ? () => setState(() => _workDuration--)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => _workDuration++),
                ),
              ],
            ),
          ),

          ListTile(
            title: const Text('短い休憩時間'),
            subtitle: Text('$_shortBreakDuration 分'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _shortBreakDuration > 1
                      ? () => setState(() => _shortBreakDuration--)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => _shortBreakDuration++),
                ),
              ],
            ),
          ),

          ListTile(
            title: const Text('長い休憩時間'),
            subtitle: Text('$_longBreakDuration 分'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _longBreakDuration > 1
                      ? () => setState(() => _longBreakDuration--)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => _longBreakDuration++),
                ),
              ],
            ),
          ),

          ListTile(
            title: const Text('長い休憩までのポモドーロ数'),
            subtitle: Text('$_longBreakInterval 回'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _longBreakInterval > 1
                      ? () => setState(() => _longBreakInterval--)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => _longBreakInterval++),
                ),
              ],
            ),
          ),

          // ListTile(
          //   title: const Text('1日の目標ポモドーロ数'),
          //   subtitle: Text('$_dailyTargetPomodoros 回'),
          //   trailing: Row(
          //     mainAxisSize: MainAxisSize.min,
          //     children: [
          //       IconButton(
          //         icon: const Icon(Icons.remove),
          //         onPressed: _dailyTargetPomodoros > 1
          //             ? () => setState(() => _dailyTargetPomodoros--)
          //             : null,
          //       ),
          //       IconButton(
          //         icon: const Icon(Icons.add),
          //         onPressed: () => setState(() => _dailyTargetPomodoros++),
          //       ),
          //     ],
          //   ),
          // ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              child: const Text('タイマー設定を保存'),
              onPressed: () {
                pomodoroProvider.saveSettings(
                  workDuration: _workDuration,
                  shortBreakDuration: _shortBreakDuration,
                  longBreakDuration: _longBreakDuration,
                  longBreakInterval: _longBreakInterval,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('設定を保存しました')),
                );
              },
            ),
          ),
          const Divider(),
          _buildSectionHeader(context, "アプリ制限"),

          const Divider(),

          // 通知と音設定
          _buildSectionHeader(context, '通知と音'),

          SwitchListTile(
            title: const Text('通知'),
            subtitle: const Text('ポモドーロ完了時に通知を表示します'),
            value: _enableNotifications,
            onChanged: (value) {
              setState(() {
                _enableNotifications = value;
              });
              // 通知設定を保存する実装
            },
          ),

          SwitchListTile(
            title: const Text('効果音'),
            subtitle: const Text('タイマー開始・終了時に音を鳴らします'),
            value: _enableSounds,
            onChanged: (value) {
              setState(() {
                _enableSounds = value;
              });
              // 音設定を保存する実装
            },
          ),

          const Divider(),

          // 外観設定
          _buildSectionHeader(context, '外観'),

          ListTile(
            title: const Text('テーマ'),
            subtitle: Text(_getThemeName(_selectedTheme)),
            trailing: DropdownButton<String>(
              value: _selectedTheme,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedTheme = value;
                  });
                  // テーマ設定を保存する実装
                }
              },
              items: const [
                DropdownMenuItem(
                  value: 'system',
                  child: Text('システム設定に合わせる'),
                ),
                DropdownMenuItem(
                  value: 'light',
                  child: Text('ライトテーマ'),
                ),
                DropdownMenuItem(
                  value: 'dark',
                  child: Text('ダークテーマ'),
                ),
              ],
            ),
          ),

          const Divider(),

          // 連携設定
          _buildSectionHeader(context, '連携'),

          ListTile(
            title: const Text('TickTick連携'),
            subtitle: const Text('TickTickとタスクやポモドーロ記録を同期します'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => const TickTickSyncScreen(),
              ));
            },
          ),

          const Divider(),

          // アプリについて
          _buildSectionHeader(context, 'アプリについて'),

          ListTile(
            title: const Text('バージョン'),
            subtitle: const Text('1.0.0'),
          ),

          ListTile(
            title: const Text('プライバシーポリシー'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // プライバシーポリシーを表示する実装
            },
          ),

          ListTile(
            title: const Text('利用規約'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // 利用規約を表示する実装
            },
          ),
        ],
      ),
    );
  }

  // セクションヘッダーウィジェット
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  // テーマ名を取得
  String _getThemeName(String themeKey) {
    switch (themeKey) {
      case 'system':
        return 'システム設定に合わせる';
      case 'light':
        return 'ライトテーマ';
      case 'dark':
        return 'ダークテーマ';
      default:
        return 'システム設定に合わせる';
    }
  }
}
