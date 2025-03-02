import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/task_provider.dart';
import 'providers/pomodoro_provider.dart';
import 'providers/app_restriction_provider.dart';
import 'providers/ticktick_provider.dart';
import 'providers/theme_provider.dart';
import 'services/database_helper.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';
import 'utils/platform_utils.dart';
import 'screens/app_store_screen.dart';
import 'services/sound_service.dart';
import 'utils/global_context.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // データベースファクトリの初期化
  await DatabaseHelper.instance.initDatabaseFactory();
  await DatabaseHelper.instance.database;

  // 通知サービスをインスタンス化して初期化
  final notificationService = NotificationService();
  await notificationService.init();
  // 音声サービスをインスタンス化
  final soundService = SoundService();

  // プラットフォーム固有の設定初期化
  final platformService = PlatformUtils().getPlatformService();
  await platformService.initializeSettings();

  //タスクプロバイダーを作成
  final taskProvider = TaskProvider();

  // バックグラウンドサービスの初期化
  if (platformService.supportsBackgroundExecution) {
    await BackgroundService().initialize();
  }

  // アプリ設定の読み込み
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        //ChangeNotifierProvider(create: (_) => TaskProvider()),
        //ChangeNotifierProvider(create: (_) => PomodoroProvider(prefs)),
        ChangeNotifierProvider(create: (_) => AppRestrictionProvider()),
        ChangeNotifierProvider(create: (_) => TickTickProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        // 通知サービスのインスタンスを注入
        ChangeNotifierProvider(
          create: (_) => PomodoroProvider(
            prefs: prefs,
            notificationService: notificationService,
            taskProvider: taskProvider,
            soundService: soundService,
          ),
        ),
        ChangeNotifierProvider<TaskProvider>.value(
          value: taskProvider,
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'ポモドーロ学習管理',
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
      navigatorKey: GlobalContext.navigatorKey,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const TasksScreen(),
    const StatisticsScreen(),
    const AppStoreScreen(),
    const SettingsScreen(),
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // アプリのライフサイクル状態が変わったときに呼ばれる
    // これにより、WidgetsBinding.instance.lifecycleState が更新される
  }

  @override
  Widget build(BuildContext context) {
    // プラットフォームに応じてUIを調整
    final isDesktop = PlatformUtils().isDesktop;

    return Scaffold(
      body: Row(
        children: [
          // デスクトップの場合は左側にナビゲーションレールを表示
          if (isDesktop)
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.selected,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: Text('ホーム'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.task_outlined),
                  selectedIcon: Icon(Icons.task),
                  label: Text('タスク'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text('統計'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.shopping_bag_outlined),
                  selectedIcon: Icon(Icons.shopping_bag),
                  label: Text('アプリストア'), // 追加
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('設定'),
                ),
              ],
            ),

          // メインコンテンツ
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
      // モバイルの場合は下部にナビゲーションバーを表示
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'ホーム',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.task_outlined),
                  activeIcon: Icon(Icons.task),
                  label: 'タスク',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_outlined),
                  activeIcon: Icon(Icons.bar_chart),
                  label: '統計',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.shopping_bag_outlined),
                  activeIcon: Icon(Icons.shopping_bag),
                  label: 'アプリストア', // 追加
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: '設定',
                ),
              ],
            ),
    );
  }
}
