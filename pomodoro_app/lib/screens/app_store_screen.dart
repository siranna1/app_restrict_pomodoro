// screens/app_store_screen.dart - 新しいアプリストア画面

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_restriction_provider.dart';
import '../models/restricted_app.dart';
import '../models/app_usage_session.dart';
import '../services/database_helper.dart';

class AppStoreScreen extends StatefulWidget {
  const AppStoreScreen({Key? key}) : super(key: key);

  @override
  _AppStoreScreenState createState() => _AppStoreScreenState();
}

class _AppStoreScreenState extends State<AppStoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appRestrictionProvider = Provider.of<AppRestrictionProvider>(context);
    final availablePoints = appRestrictionProvider.availablePoints;

    return Scaffold(
      appBar: AppBar(
        title: const Text('アプリストア'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'アプリストア'),
            Tab(text: '設定'),
            Tab(text: '履歴'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ポイント表示
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '利用可能ポイント',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.stars,
                            color: Colors.amber,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$availablePoints pt',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '獲得: ${appRestrictionProvider.earnedPoints} pt',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        '使用: ${appRestrictionProvider.usedPoints} pt',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // タブコンテンツ
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // アプリストアタブ
                AppStoreTab(),

                // 設定タブ
                SettingsTab(),

                // 履歴タブ
                HistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// アプリストアタブ
class AppStoreTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appRestrictionProvider = Provider.of<AppRestrictionProvider>(context);
    final restrictedApps = appRestrictionProvider.restrictedApps;

    if (restrictedApps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apps_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '制限アプリがありません',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('アプリを追加'),
              onPressed: () => _showAddAppDialog(context),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: restrictedApps.length,
      itemBuilder: (context, index) {
        final app = restrictedApps[index];
        final isUnlocked = app.isCurrentlyUnlocked;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isUnlocked ? Colors.green : Colors.red,
                      child: Icon(
                        isUnlocked ? Icons.lock_open : Icons.lock,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isUnlocked
                                ? '残り${app.remainingMinutes}分間使用可能'
                                : '制限中',
                            style: TextStyle(
                              color: isUnlocked ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: app.isRestricted,
                      onChanged: (value) {
                        appRestrictionProvider.updateRestrictedApp(
                          app.copyWith(isRestricted: value),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('1ポイント = ${app.minutesPerPoint}分'),
                          Text('1時間 = ${app.pointCostPerHour}ポイント'),
                        ],
                      ),
                    ),
                    if (!isUnlocked)
                      ElevatedButton.icon(
                        icon: Icon(Icons.shopping_cart),
                        label: Text('解除する'),
                        onPressed: () => _showUnlockDialog(context, app),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // アプリ追加ダイアログ
  void _showAddAppDialog(BuildContext context) {
    // 既存のダイアログを使用
  }

  // アプリ解除ダイアログ
  void _showUnlockDialog(BuildContext context, RestrictedApp app) {
    final appRestrictionProvider =
        Provider.of<AppRestrictionProvider>(context, listen: false);
    int selectedPoints = 1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final minutes = selectedPoints * app.minutesPerPoint;

            return AlertDialog(
              title: Text('${app.name}を解除'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ポイントを使用して一時的に制限を解除します。'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: selectedPoints > 1
                            ? () => setState(() => selectedPoints--)
                            : null,
                      ),
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$selectedPoints ポイント',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () => setState(() => selectedPoints++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('解除時間: $minutes 分間'),
                  const SizedBox(height: 8),
                  Text(
                    '利用可能ポイント: ${appRestrictionProvider.availablePoints}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('キャンセル'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: Text('解除する'),
                  onPressed:
                      appRestrictionProvider.availablePoints >= selectedPoints
                          ? () async {
                              final success =
                                  await appRestrictionProvider.unlockApp(
                                app,
                                selectedPoints,
                              );
                              Navigator.of(context).pop();

                              // 結果を表示
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? '${app.name}を$minutes分間解除しました'
                                        : 'アプリの解除に失敗しました',
                                  ),
                                  backgroundColor:
                                      success ? Colors.green : Colors.red,
                                ),
                              );
                            }
                          : null,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// 設定タブ
class SettingsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appRestrictionProvider = Provider.of<AppRestrictionProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'アプリ制限設定',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('アプリ制限を有効にする'),
            subtitle: const Text('ポイントを使ってアプリを一時的に解除できます'),
            value: appRestrictionProvider.isMonitoring,
            onChanged: (value) {
              if (value) {
                appRestrictionProvider.startMonitoring();
              } else {
                appRestrictionProvider.stopMonitoring();
              }
            },
          ),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            '登録済みアプリ',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: appRestrictionProvider.restrictedApps.length,
            itemBuilder: (context, index) {
              final app = appRestrictionProvider.restrictedApps[index];
              return ListTile(
                title: Text(app.name),
                subtitle: Text(app.executablePath),
                trailing: IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _showEditAppDialog(context, app),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text('アプリを追加'),
              onPressed: () => _showAddAppDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  // アプリ追加・編集ダイアログ（既存のコードを使用）
  void _showAddAppDialog(BuildContext context) {
    // 既存のダイアログを使用
  }

  void _showEditAppDialog(BuildContext context, RestrictedApp app) {
    // 既存のダイアログを使用
  }
}

// 履歴タブ
class HistoryTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppUsageSession>>(
      future: DatabaseHelper.instance.getAppUsageSessions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'まだ履歴がありません',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // セッションデータとアプリ情報をマッピング
        final sessions = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];

            // アプリ情報を取得
            final appProvider = Provider.of<AppRestrictionProvider>(context);
            final app = appProvider.restrictedApps.firstWhere(
              (app) => app.id == session.appId,
              orElse: () => RestrictedApp(
                name: '不明なアプリ',
                executablePath: '',
                allowedMinutesPerDay: 0,
                isRestricted: false,
              ),
            );

            // 使用時間を計算
            final duration = session.endTime.difference(session.startTime);
            final minutes = (duration.inSeconds / 60).ceil();

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.access_time, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_formatDateTime(session.startTime)} - ${_formatDateTime(session.endTime)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('使用ポイント: ${session.pointsSpent} pt'),
                        Text('使用時間: $minutes 分'),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 日時のフォーマット
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
