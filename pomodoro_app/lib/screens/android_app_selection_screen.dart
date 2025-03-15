import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../platforms/android/android_app_controller.dart';
import '../models/restricted_app.dart';
import '../providers/app_restriction_provider.dart';
import '../widgets/app_icon.dart';
import '../models/app_info.dart';

class AndroidAppSelectionScreen extends StatefulWidget {
  const AndroidAppSelectionScreen({Key? key}) : super(key: key);

  @override
  State<AndroidAppSelectionScreen> createState() =>
      _AndroidAppSelectionScreenState();
}

class _AndroidAppSelectionScreenState extends State<AndroidAppSelectionScreen> {
  final _androidAppController = AndroidAppController();
  // アプリ情報を格納する変数を変更
  List<AppInfo> _installedApps = [];
  Map<String, int> _appPointSettings = {};
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  //final _minutesPerPointController = TextEditingController(text: '30');
  final int _defaultMinutesPerPoint = 30;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 権限チェック
      final hasPermission =
          await _androidAppController.hasUsageStatsPermission();
      if (!hasPermission) {
        // 権限がない場合は権限設定画面へ
        await _androidAppController.openUsageStatsSettings();

        // 少し待ってから権限を再確認
        await Future.delayed(const Duration(seconds: 2));
        final hasPermissionNow =
            await _androidAppController.hasUsageStatsPermission();
        if (!hasPermissionNow) {
          // まだ権限がない場合は警告を表示
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('使用状況へのアクセス権限がないと、アプリを制限できません'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      }

      // インストール済みアプリ一覧を取得
      final rawApps = await _androidAppController.getInstalledApps();
      // AppInfo型に変換
      final apps = rawApps.map((app) => AppInfo.fromMap(app)).toList();

      // 現在制限されているアプリのパッケージ名リストを取得
      final appRestrictionProvider =
          Provider.of<AppRestrictionProvider>(context, listen: false);
      final restrictedApps = appRestrictionProvider.restrictedApps;
      // 既存のアプリのポイント設定を保存
      Map<String, int> pointSettings = {};
      for (var app in restrictedApps) {
        pointSettings[app.executablePath] = app.minutesPerPoint;
      }

      if (mounted) {
        setState(() {
          _installedApps = apps;
          _appPointSettings = pointSettings;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('アプリ一覧取得エラー: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('アプリ一覧の取得に失敗しました: $e')),
        );
      }
    }
  }

  // 選択したアプリを保存
  Future<void> _saveSelectedApps() async {
    try {
      final appRestrictionProvider =
          Provider.of<AppRestrictionProvider>(context, listen: false);
      // 設定したアプリのみを処理
      RestrictedApp? existingApp;
      for (String packageName in _appPointSettings.keys) {
        // 既存のアプリを確認
        try {
          existingApp = appRestrictionProvider.restrictedApps.firstWhere(
            (app) => app.executablePath == packageName,
          );
        } catch (_) {
          existingApp = null;
        }

        final minutesPerPoint =
            _appPointSettings[packageName] ?? _defaultMinutesPerPoint;

        if (existingApp != null) {
          // 既存アプリの場合は更新
          if (existingApp.minutesPerPoint != minutesPerPoint) {
            await appRestrictionProvider.updateRestrictedApp(
              existingApp.copyWith(
                minutesPerPoint: minutesPerPoint,
                isRestricted: true,
              ),
            );
          }
        } else {
          // 新規アプリの場合は追加
          // アプリ名を取得
          final appInfo = _installedApps.firstWhere(
            (app) => app.packageName == packageName,
            orElse: () => AppInfo(
              name: 'Unknown App',
              packageName: packageName,
              isSystemApp: false,
              iconBase64: '',
            ),
          );

          final newApp = RestrictedApp(
            name: appInfo.name,
            executablePath: packageName,
            allowedMinutesPerDay: 0,
            isRestricted: true,
            minutesPerPoint: minutesPerPoint,
          );

          await appRestrictionProvider.addRestrictedApp(newApp);
        }
      }

      // 監視中なら制限アプリリストを更新
      if (appRestrictionProvider.isMonitoring) {
        await _androidAppController.updateRestrictedApps(
          appRestrictionProvider.restrictedApps,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('制限アプリを保存しました')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラーが発生しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 検索フィルター適用
    final filteredApps = _filterApps();

    return Scaffold(
      appBar: AppBar(
        title: const Text('アプリを選択'),
      ),
      body: Column(
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'アプリを検索',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // 選択情報
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${{_appPointSettings.length}}個のアプリを選択中',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.deselect),
                  label: const Text('選択解除'),
                  onPressed: () {
                    setState(() {
                      _appPointSettings = {};
                    });
                  },
                ),
              ],
            ),
          ),

          // アプリリスト
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredApps.isEmpty
                    ? const Center(child: Text('該当するアプリがありません'))
                    : ListView.builder(
                        itemCount: filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          final packageName = app.packageName;
                          final appName = app.name;
                          final isSelected =
                              _appPointSettings.containsKey(packageName);
                          final minutesPerPoint =
                              _appPointSettings[packageName] ??
                                  _defaultMinutesPerPoint;

                          return ListTile(
                            title: Text(appName),
                            subtitle: isSelected
                                ? Text(
                                    '$packageName (1ポイント = $minutesPerPoint分)')
                                : Text(packageName),
                            leading: AppIconWidget(iconBase64: app.iconBase64),
                            trailing: isSelected
                                ? IconButton(
                                    icon: const Icon(
                                        Icons.remove_circle_outline,
                                        color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _appPointSettings.remove(packageName);
                                      });
                                    },
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.add_circle_outline,
                                        color: Colors.green),
                                    onPressed: () async {
                                      await _showPointSettingDialog(
                                          packageName, appName);
                                    },
                                  ),
                            onTap: () async {
                              if (isSelected) {
                                // 既に選択済みの場合は設定を変更
                                await _showPointSettingDialog(
                                    packageName, appName);
                              } else {
                                // 未選択の場合は新規設定
                                await _showPointSettingDialog(
                                    packageName, appName);
                              }
                            },
                          );
                        },
                      ),
          ),

          // 下部のアクションボタン
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('キャンセル'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saveSelectedApps,
                    child: const Text('追加'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ポイント設定ダイアログを表示
  Future<void> _showPointSettingDialog(
      String packageName, String appName) async {
    // 現在のポイント設定を取得（存在しない場合はデフォルト値を使用）
    int currentValue =
        _appPointSettings[packageName] ?? _defaultMinutesPerPoint;
    TextEditingController controller =
        TextEditingController(text: currentValue.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$appNameのポイント設定'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: '1ポイントあたりの使用時間（分）',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final minutes =
                      int.tryParse(controller.text) ?? _defaultMinutesPerPoint;
                  final pointsPerHour = (60 / minutes).ceil();
                  return Text(
                    '1時間 = $pointsPerHour ポイント',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value != null && value > 0) {
                  Navigator.of(context).pop(value);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('有効な数値を入力してください')),
                  );
                }
              },
              child: const Text('設定'),
            ),
          ],
        );
      },
    );

    // 結果を保存
    if (result != null) {
      setState(() {
        _appPointSettings[packageName] = result;
      });
    }
  }

  // アプリをフィルタリングするメソッド（AppInfo型を対応）
  List<AppInfo> _filterApps() {
    if (_searchQuery.isEmpty) {
      return _installedApps;
    }

    final query = _searchQuery.toLowerCase();
    return _installedApps.where((app) {
      final appName = app.name.toLowerCase();
      final packageName = app.packageName.toLowerCase();
      return appName.contains(query) || packageName.contains(query);
    }).toList();
  }
}
