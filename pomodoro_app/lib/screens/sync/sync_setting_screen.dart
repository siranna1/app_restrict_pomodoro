// screens/sync/sync_setting_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/auth_dialog.dart';
import '../../services/firebase/auth_service.dart';
import '../../services/settings_service.dart';
import '../../utils/platform_utils.dart';

class SyncSettingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final syncProvider = Provider.of<SyncProvider>(context);
    final platformUtils = PlatformUtils();
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'データ同期',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _buildSyncButton(context, syncProvider),
              ],
            ),
            SizedBox(height: 8),

            // 認証状態に応じた表示
            if (syncProvider.isAuthenticated)
              _buildAuthenticatedView(context, syncProvider)
            else
              _buildUnauthenticatedView(context),

            // 最終同期時間の表示
            if (syncProvider.lastSyncTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '最終同期: ${DateFormat('yyyy/MM/dd HH:mm').format(syncProvider.lastSyncTime!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

            // エラーメッセージの表示
            if (syncProvider.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  syncProvider.error!,
                  style: TextStyle(color: Colors.red),
                ),
              ),

            Divider(height: 24),

            // 自動同期設定
            //if (!platformUtils.isWindows)
            SwitchListTile(
              title: Text('自動同期'),
              subtitle: Text('定期的にデータを同期します'),
              value: Provider.of<SettingsService>(context).autoSyncEnabled,
              onChanged: syncProvider.isAuthenticated
                  ? (value) => syncProvider.toggleAutoSync(value)
                  : null,
            ),
            //if (!platformUtils.isWindows)
            if (Provider.of<SettingsService>(context).autoSyncEnabled &&
                syncProvider.isAuthenticated)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text('同期間隔: '),
                    Expanded(
                      child: Slider(
                        min: 1,
                        max: 60,
                        divisions: 12,
                        value: Provider.of<SettingsService>(context)
                            .autoSyncIntervalMinutes
                            .toDouble(),
                        label:
                            '${Provider.of<SettingsService>(context).autoSyncIntervalMinutes}分',
                        onChanged: (value) {
                          syncProvider.updateSyncInterval(value.round());
                        },
                      ),
                    ),
                    Text(
                        '${Provider.of<SettingsService>(context).autoSyncIntervalMinutes}分'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 同期ボタン
  Widget _buildSyncButton(BuildContext context, SyncProvider syncProvider) {
    return ElevatedButton.icon(
      icon: Icon(Icons.sync),
      label: Text('同期'),
      onPressed: syncProvider.isSyncing
          ? null
          : () async {
              if (syncProvider.isAuthenticated) {
                // 認証済みの場合は同期を実行
                final success = await syncProvider.sync();
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('同期が完了しました')),
                  );
                }
              } else {
                // 未認証の場合は認証ダイアログを表示
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) => AuthDialog(),
                );

                if (result == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('認証に成功しました。データを同期します。')),
                  );
                  // 認証成功したら同期を実行
                  await syncProvider.sync();
                }
              }
            },
    );
  }

  // 認証済みの場合の表示
  Widget _buildAuthenticatedView(
      BuildContext context, SyncProvider syncProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ログイン中: ${syncProvider.userEmail ?? '不明'}'),
        SizedBox(height: 8),
        TextButton.icon(
          icon: Icon(Icons.logout),
          label: Text('ログアウト'),
          onPressed: () async {
            final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('ログアウト確認'),
                    content: Text('ログアウトすると、データ同期ができなくなります。よろしいですか？'),
                    actions: [
                      TextButton(
                        child: Text('キャンセル'),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                      TextButton(
                        child: Text('ログアウト'),
                        onPressed: () => Navigator.of(context).pop(true),
                      ),
                    ],
                  ),
                ) ??
                false;

            if (confirm) {
              await Provider.of<AuthService>(context, listen: false).signOut();
              syncProvider.notifyListeners();
            }
          },
        ),
      ],
    );
  }

  // 未認証の場合の表示
  Widget _buildUnauthenticatedView(BuildContext context) {
    return Text(
      'データを同期するには、認証が必要です。「同期」ボタンを押してログインまたはアカウント登録してください。',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
