// screens/settings_screen.dart - 設定画面
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pomodoro_provider.dart';
import '../providers/app_restriction_provider.dart';
import 'ticktick_sync_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';
<<<<<<< HEAD
import '../providers/sync_provider.dart';
import 'package:intl/intl.dart';
import 'sync/sync_setting_screen.dart';
=======
import '../services/notification_service.dart';
>>>>>>> main

class SettingsScreen extends StatefulWidget {
  final String? initialTab;
  const SettingsScreen({Key? key, this.initialTab}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  // 設定の一時保存用
  late int _workDuration;
  late int _shortBreakDuration;
  late int _longBreakDuration;
  late int _longBreakInterval;
  bool _enableNotifications = true;
  bool _enableSounds = true;
  String _selectedTheme = 'system';
  SettingsService? _settingsService;
  late TabController _tabController;

  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // 初期タブが指定されている場合は切り替え
    if (widget.initialTab == 'sync') {
      _tabController.animateTo(3); // 同期タブのインデックス
    }
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settingsService == null) {
      _settingsService = Provider.of<SettingsService>(context);
      if (!_isLoading) {
        _loadSettings();
      }
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    final pomodoroProvider =
        Provider.of<PomodoroProvider>(context, listen: false);
    final settingsService =
        Provider.of<SettingsService>(context, listen: false);

    _workDuration = pomodoroProvider.workDuration;
    _shortBreakDuration = pomodoroProvider.shortBreakDuration;
    _longBreakDuration = pomodoroProvider.longBreakDuration;
    _longBreakInterval = pomodoroProvider.longBreakInterval;

    _enableNotifications = await settingsService.getNotificationsEnabled();
    _enableSounds = await settingsService.getSoundsEnabled();

    final themeMode = await settingsService.getThemeMode();
    _selectedTheme = _themeModeToString(themeMode);

    setState(() {
      _isLoading = false;
    });
  }

  // ThemeModeを文字列に変換
  String _themeModeToString(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }

  // 文字列をThemeModeに変換
  ThemeMode _stringToThemeMode(String themeModeString) {
    switch (themeModeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pomodoroProvider = Provider.of<PomodoroProvider>(context);
    final syncProvider = Provider.of<SyncProvider>(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('設定'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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

          // 通知と音設定
          _buildSectionHeader(context, '通知と音'),

          SwitchListTile(
            title: const Text('通知'),
            subtitle: const Text('ポモドーロ完了時に通知を表示します'),
            value: _enableNotifications,
            onChanged: (value) async {
              setState(() {
                _enableNotifications = value;
              });

              await _settingsService!.setNotificationsEnabled(value);
            },
          ),

          SwitchListTile(
            title: const Text('効果音'),
            subtitle: const Text('タイマー開始・終了時に音を鳴らします'),
            value: _enableSounds,
            onChanged: (value) async {
              setState(() {
                _enableSounds = value;
              });
              await _settingsService!.setSoundsEnabled(value);

              // 音声サービスに設定を反映
              final pomodoroProvider =
                  Provider.of<PomodoroProvider>(context, listen: false);
              await pomodoroProvider.soundService.setEnableSounds(value);
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
              onChanged: (value) async {
                if (value != null) {
                  setState(() {
                    _selectedTheme = value;
                  });
                  await _settingsService!
                      .setThemeMode(_stringToThemeMode(value));
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

          // 通知と音設定
          _buildSectionHeader(context, '権限'),
          if (Platform.isAndroid)
            ListTile(
              title: const Text('バッテリー最適化の設定'),
              subtitle: const Text('制限機能のバックグラウンド動作を改善します'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Provider.of<AppRestrictionProvider>(context, listen: false)
                    .checkAndRequestBatteryOptimization(context);
              },
            ),

          const Divider(),

          // 連携設定
          _buildSectionHeader(context, '連携'),

          SyncSettingScreen(),
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

          const Divider(),

          // 設定リセット
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('すべての設定をリセット'),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('設定リセット'),
                    content: const Text('すべての設定をデフォルト値に戻しますか？この操作は元に戻せません。'),
                    actions: [
                      TextButton(
                        child: const Text('キャンセル'),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      TextButton(
                        child: const Text('リセット'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await _settingsService!.resetAllSettings();
                  await _loadSettings();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('設定をリセットしました')),
                  );
                }
              },
            ),
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
