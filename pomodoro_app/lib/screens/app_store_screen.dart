// screens/app_store_screen.dart - 新しいアプリストア画面

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_restriction_provider.dart';
import '../models/restricted_app.dart';
import '../models/app_usage_session.dart';
import '../services/database_helper.dart';
import 'android_app_selection_screen.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/AddAppDialog.dart';

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
    // 初期化後、権限ガイドの確認を行う
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionGuide();
    });
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

  void _checkPermissionGuide() {
    final appRestrictionProvider =
        Provider.of<AppRestrictionProvider>(context, listen: false);
    if (appRestrictionProvider.needsPermissionGuide) {
      appRestrictionProvider.showPermissionGuideIfNeeded(context);
    }
  }
}

// アプリストアタブ
class AppStoreTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppRestrictionProvider>(
        builder: (context, appRestrictionProvider, child) {
      final appRestrictionProvider =
          Provider.of<AppRestrictionProvider>(context);
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
                onPressed: () {
                  // Androidかどうかをチェック
                  if (Theme.of(context).platform == TargetPlatform.android) {
                    // Android用のアプリ選択画面に遷移
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AndroidAppSelectionScreen(),
                      ),
                    );
                  } else {
                    // 既存のダイアログを表示（Windows用）
                    _showAddAppDialog(context);
                  }
                },
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
                            //Text('1時間 = ${app.pointCostPerHour}ポイント'),
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
    });
  }

  // アプリ追加ダイアログ
  Future<void> _showAddAppDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final pathController = TextEditingController();
    final minutesController = TextEditingController(text: '30'); // デフォルト値

    try {
      return await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('制限対象アプリを追加'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'アプリ名',
                        hintText: '例: ゲーム、SNSアプリなど',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'アプリ名を入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: pathController,
                            decoration: const InputDecoration(
                              labelText: '実行ファイルパス',
                              hintText: 'C:\\Program Files\\App\\app.exe',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '実行ファイルパスを入力してください';
                              }
                              return null;
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['exe'],
                            );

                            if (result != null && result.files.isNotEmpty) {
                              pathController.text = result.files.first.path!;
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: minutesController,
                      decoration: const InputDecoration(
                        labelText: '1ポイントあたりの使用時間（分）',
                        hintText: '例: 30',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '使用時間を入力してください';
                        }
                        final number = int.tryParse(value);
                        if (number == null || number <= 0) {
                          return '正の整数を入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    // 計算された値を表示（オプション）
                    Builder(
                      builder: (context) {
                        final minutes =
                            int.tryParse(minutesController.text) ?? 30;
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
              ),
            ),
            actions: [
              TextButton(
                child: const Text('キャンセル'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              ElevatedButton(
                child: const Text('追加'),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final provider = Provider.of<AppRestrictionProvider>(
                        context,
                        listen: false);

                    provider.addRestrictedApp(RestrictedApp(
                      name: nameController.text,
                      executablePath: pathController.text,
                      allowedMinutesPerDay: 0,
                      isRestricted: true,
                      minutesPerPoint: int.parse(minutesController.text),
                    ));

                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        },
      );
    } finally {
      // コントローラーの破棄
      nameController.dispose();
      pathController.dispose();
      minutesController.dispose();
    }
  }

  // アプリ解除ダイアログ
  void _showUnlockDialog(BuildContext context, RestrictedApp app) {
    final appRestrictionProvider =
        Provider.of<AppRestrictionProvider>(context, listen: false);
    int selectedPoints = 1;
    final minutesController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // ポイント数に基づいて解除時間を計算
            final points = selectedPoints;
            final minutes = points * app.minutesPerPoint;
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
                  const SizedBox(height: 4),
                  // 情報追加：時間あたりのポイント消費率を表示（オプション）
                  Text(
                    '(1ポイント = ${app.minutesPerPoint}分 / 1時間 = ${app.pointCostPerHour}ポイント)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
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
                _toggleMonitoring(context);
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
              onPressed: () {
                // Androidかどうかをチェック
                if (Theme.of(context).platform == TargetPlatform.android) {
                  // Android用のアプリ選択画面に遷移
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AndroidAppSelectionScreen(),
                    ),
                  );
                } else {
                  // 既存のダイアログを表示（Windows用）
                  _showAddAppDialog(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // アプリ追加ダイアログ - カスタムウィジェット使用版
  Future<void> _showAddAppDialog(BuildContext context) async {
    // ダイアログを表示してデータを取得
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddAppDialog(),
    );

    // キャンセルされた場合
    if (result == null) return;

    try {
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

      final provider =
          Provider.of<AppRestrictionProvider>(context, listen: false);

      // アプリを追加
      final success = await provider.addRestrictedApp(RestrictedApp(
        name: result['name'],
        executablePath: result['path'],
        allowedMinutesPerDay: 0,
        isRestricted: true,
        minutesPerPoint: result['minutesPerPoint'],
        requiredPomodorosToUnlock: 0,
      ));

      // プログレスインジケータを閉じる
      if (context.mounted) Navigator.of(context).pop();

      // 結果メッセージ
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'アプリを追加しました' : 'アプリの追加に失敗しました'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      // プログレスインジケータを閉じる
      if (context.mounted) Navigator.of(context).pop();

      // エラーメッセージ
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // アプリ編集ダイアログ - コントローラー適切管理版
  Future<void> _showEditAppDialog(
      BuildContext context, RestrictedApp app) async {
    final formKey = GlobalKey<FormState>();

    // ダイアログ内で使用するローカル変数
    String? updatedName;
    String? updatedPath;
    int? updatedMinutesPerPoint;
    bool? formValid;

    // ダイアログを表示
    await showDialog(
      context: context,
      builder: (dialogContext) {
        // このスコープ内でコントローラーを作成
        final nameController = TextEditingController(text: app.name);
        final pathController = TextEditingController(text: app.executablePath);
        final minutesController =
            TextEditingController(text: app.minutesPerPoint.toString());

        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('制限対象アプリを編集'),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'アプリ名',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'アプリ名を入力してください';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        updatedName = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: pathController,
                            decoration: const InputDecoration(
                              labelText: '実行ファイルパス',
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '実行ファイルパスを入力してください';
                              }
                              return null;
                            },
                            onSaved: (value) {
                              updatedPath = value;
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.folder_open),
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['exe'],
                            );

                            if (result != null && result.files.isNotEmpty) {
                              pathController.text = result.files.first.path!;
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: minutesController,
                      decoration: const InputDecoration(
                        labelText: '1ポイントあたりの使用時間（分）',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '使用時間を入力してください';
                        }
                        final number = int.tryParse(value);
                        if (number == null || number <= 0) {
                          return '正の整数を入力してください';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        updatedMinutesPerPoint = int.tryParse(value ?? '');
                      },
                    ),
                    const SizedBox(height: 8),
                    // 計算された値を表示（オプション）
                    Builder(
                      builder: (context) {
                        final minutes =
                            int.tryParse(minutesController.text) ?? 30;
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
              ),
            ),
            actions: [
              TextButton(
                child: const Text('キャンセル'),
                onPressed: () {
                  // コントローラーを破棄してからダイアログを閉じる
                  nameController.dispose();
                  pathController.dispose();
                  minutesController.dispose();
                  Navigator.of(dialogContext).pop();
                },
              ),
              TextButton(
                child: const Text('削除'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                onPressed: () async {
                  // コントローラーを破棄
                  nameController.dispose();
                  pathController.dispose();
                  minutesController.dispose();

                  final provider = Provider.of<AppRestrictionProvider>(context,
                      listen: false);

                  // ダイアログを閉じる
                  Navigator.of(dialogContext).pop();

                  try {
                    // アプリを削除
                    await provider.removeRestrictedApp(app.id!);

                    // 成功メッセージ
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${app.name}を削除しました')),
                    );
                  } catch (e) {
                    // エラーメッセージ
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('削除中にエラーが発生しました: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
              ElevatedButton(
                child: const Text('保存'),
                onPressed: () {
                  // フォームの検証と保存
                  formValid = formKey.currentState?.validate() ?? false;
                  bool formValidcpy = formValid ?? false;
                  if (formValidcpy) {
                    formKey.currentState?.save();

                    // コントローラーを破棄
                    //nameController.dispose();
                    //pathController.dispose();
                    //minutesController.dispose();

                    // ダイアログを閉じる
                    Navigator.of(dialogContext).pop();
                  }
                },
              ),
            ],
          ),
        );
      },
    );

    // ダイアログが閉じられた後、有効なフォームデータがあれば更新処理を実行
    if (formValid == true &&
        updatedName != null &&
        updatedPath != null &&
        updatedMinutesPerPoint != null) {
      try {
        final provider =
            Provider.of<AppRestrictionProvider>(context, listen: false);

        // アプリを更新
        await provider.updateRestrictedApp(app.copyWith(
          name: updatedName,
          executablePath: updatedPath,
          minutesPerPoint: updatedMinutesPerPoint,
        ));

        // 成功メッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アプリ設定を更新しました')),
        );
      } catch (e) {
        // エラーメッセージ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新中にエラーが発生しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // また、監視を開始するボタンがあるなら、そのonPressedでも確認
  void _toggleMonitoring(BuildContext context) {
    final appRestrictionProvider =
        Provider.of<AppRestrictionProvider>(context, listen: false);

    if (appRestrictionProvider.isMonitoring) {
      appRestrictionProvider.stopMonitoring();
    } else {
      appRestrictionProvider.startMonitoring();
      // 権限が必要なら自動的にダイアログが表示される
      if (appRestrictionProvider.needsPermissionGuide) {
        appRestrictionProvider.showPermissionGuideIfNeeded(context);
      }
    }
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
