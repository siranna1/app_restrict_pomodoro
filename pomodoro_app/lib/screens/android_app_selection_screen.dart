import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../android_app_controller.dart';
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
  List<String> _selectedPackages = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _minutesPerPointController = TextEditingController(text: '30');
  int _minutesPerPoint = 30;

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
      final restrictedPackages = restrictedApps
          .where((app) => app.isRestricted)
          .map((app) => app.executablePath)
          .toList();

      // デフォルトの分あたりポイント数を取得（既存のアプリから）
      if (restrictedApps.isNotEmpty) {
        _minutesPerPoint = restrictedApps.first.minutesPerPoint;
        _minutesPerPointController.text = _minutesPerPoint.toString();
      }

      if (mounted) {
        setState(() {
          _installedApps = apps;
          _selectedPackages = List.from(restrictedPackages);
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
      // 分あたりポイント数を解析
      final minutesPerPoint =
          int.tryParse(_minutesPerPointController.text) ?? 30;
      if (minutesPerPoint <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('1ポイントあたりの分数は1以上にしてください')),
        );
        return;
      }

      _minutesPerPoint = minutesPerPoint;

      final appRestrictionProvider =
          Provider.of<AppRestrictionProvider>(context, listen: false);

      // 現在の制限アプリリスト
      final existingApps = appRestrictionProvider.restrictedApps;

      // 既存の制限アプリを更新
      for (final app in existingApps) {
        // パッケージ名をexecutablePathとして扱う
        final isSelected = _selectedPackages.contains(app.executablePath);
        if (app.isRestricted != isSelected ||
            app.minutesPerPoint != _minutesPerPoint) {
          await appRestrictionProvider.updateRestrictedApp(
            app.copyWith(
              isRestricted: isSelected,
              minutesPerPoint: _minutesPerPoint,
            ),
          );
        }
      }

      // 新しく選択されたアプリを追加
      for (final packageName in _selectedPackages) {
        // 既存のアプリリストにないパッケージのみ追加
        if (!existingApps.any((app) => app.executablePath == packageName)) {
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

          final appName = appInfo.name;

          // 新しいRestrictedAppを作成
          final newApp = RestrictedApp(
            name: appName,
            executablePath: packageName,
            allowedMinutesPerDay: 0,
            isRestricted: true,
            minutesPerPoint: _minutesPerPoint,
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
                  '${_selectedPackages.length}個のアプリを選択中',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.select_all),
                  label: const Text('すべて選択'),
                  onPressed: () {
                    setState(() {
                      _selectedPackages =
                          _installedApps.map((app) => app.packageName).toList();
                    });
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.deselect),
                  label: const Text('選択解除'),
                  onPressed: () {
                    setState(() {
                      _selectedPackages = [];
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
                              _selectedPackages.contains(packageName);

                          return CheckboxListTile(
                            title: Text(appName),
                            subtitle: Text(packageName),
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedPackages.add(packageName);
                                } else {
                                  _selectedPackages.remove(packageName);
                                }
                              });
                            },
                            secondary:
                                AppIconWidget(iconBase64: app.iconBase64),
                          );
                        },
                      ),
          ),
          // 制限時間設定
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ポイント設定',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minutesPerPointController,
                            decoration: const InputDecoration(
                              labelText: '1ポイントあたりの使用時間（分）',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Builder(
                          builder: (context) {
                            final minutes =
                                int.tryParse(_minutesPerPointController.text) ??
                                    30;
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
                  ],
                ),
              ),
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
                  child: ElevatedButton(
                    onPressed: _saveSelectedApps,
                    child: const Text('追加'),
                    style: ElevatedButton.styleFrom(
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
