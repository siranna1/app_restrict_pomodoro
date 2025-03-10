// settings_screen/sections/sync_settings.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pomodoro_app/providers/sync_provider.dart';
import 'package:pomodoro_app/services/settings_service.dart';

class SyncSettingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final syncProvider = Provider.of<SyncProvider>(context);
    final settingsService =
        Provider.of<SettingsService>(context, listen: false);

    return Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('データ同期設定', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),

            // 同期状態表示
            Row(
              children: [
                Icon(Icons.sync, color: Theme.of(context).primaryColor),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('同期状態'),
                      Text(
                        syncProvider.lastSyncTime != null
                            ? '最終同期: ${DateFormat('yyyy/MM/dd HH:mm').format(syncProvider.lastSyncTime!)}'
                            : '未同期',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (syncProvider.isSyncing)
                  SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  ElevatedButton(
                    child: Text('今すぐ同期'),
                    onPressed: () => syncProvider.sync(),
                    style: ElevatedButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),

            Divider(height: 24),

            // 自動同期設定
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('自動同期'),
              subtitle: Text('定期的に自動でデータを同期します'),
              value: settingsService.autoSyncEnabled,
              onChanged: (value) => syncProvider.toggleAutoSync(value),
            ),

            // 自動同期間隔設定
            if (settingsService.autoSyncEnabled) ...[
              Text('同期間隔'),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildIntervalChip(
                      context, 1, '1分', syncProvider, settingsService),
                  _buildIntervalChip(
                      context, 5, '5分', syncProvider, settingsService),
                  _buildIntervalChip(
                      context, 15, '15分', syncProvider, settingsService),
                  _buildIntervalChip(
                      context, 30, '30分', syncProvider, settingsService),
                ],
              ),
            ],

            // エラー表示
            if (syncProvider.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          syncProvider.error!,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalChip(
    BuildContext context,
    int minutes,
    String label,
    SyncProvider syncProvider,
    SettingsService settingsService,
  ) {
    final isSelected = settingsService.autoSyncIntervalMinutes == minutes;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          syncProvider.updateSyncInterval(minutes);
        }
      },
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }
}
