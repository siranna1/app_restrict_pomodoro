// services/database_helper.dart - データベース管理
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task.dart';
import '../models/pomodoro_session.dart';
import '../models/restricted_app.dart';
import '../models/reward_point.dart';
import '../models/app_usage_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import '../models/daily_goal.dart';
import 'dart:async';
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();
  // 新しいdefault constructor - シングルトンインスタンスを返す
  DatabaseHelper() {
    print(
        'Warning: Using default constructor. Consider using DatabaseHelper.instance instead.');
    // 何もしない - 既存のシングルトンインスタンスを使用する
  }
  // 初期化メソッド - 非同期の初期化処理をここに集約
  Future<void> initialize() async {
    // データベースファクトリの初期化
    await initDatabaseFactory();

    // データベースへの最初のアクセスを行い、初期化を完了
    await database;

    print('DatabaseHelper initialized successfully');
  }

  // 初期化
  Future<void> initDatabaseFactory() async {
    // Windows/Linux プラットフォームの場合、FFI を使用
    if (Platform.isWindows || Platform.isLinux) {
      // FFI の初期化
      sqfliteFfiInit();
      // データベースファクトリの設定
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;

    // データベース取得前にファクトリを初期化
    await initDatabaseFactory();

    _database = await _initDB('pomodoro_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    print(path);
    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
    CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      category TEXT NOT NULL,
      description TEXT,
      estimatedPomodoros INTEGER NOT NULL,
      completedPomodoros INTEGER NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL,
      tickTickId TEXT,
      firebaseId TEXT,
      isDeleted INTEGER DEFAULT 0
    )
  ''');

    await db.execute('''
    CREATE TABLE pomodoro_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      taskId INTEGER NOT NULL,
      startTime TEXT NOT NULL,
      endTime TEXT NOT NULL,
      durationMinutes INTEGER NOT NULL,
      completed INTEGER NOT NULL,
      focusScore REAL NOT NULL,
      timeOfDay TEXT,
      interruptionCount INTEGER DEFAULT 0,
      mood TEXT,
      isBreak INTEGER DEFAULT 0,
      firebaseId TEXT,
      isDeleted INTEGER DEFAULT 0,
      updatedAt TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (taskId) REFERENCES tasks (id) ON DELETE CASCADE
    )
  ''');

    await db.execute('''
    CREATE TABLE restricted_apps (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      executablePath TEXT NOT NULL,
      allowedMinutesPerDay INTEGER NOT NULL,
      isRestricted INTEGER NOT NULL,
      requiredPomodorosToUnlock INTEGER,
      pointCostPerHour INTEGER DEFAULT 2,
      minutesPerPoint INTEGER DEFAULT 30,
      currentSessionEnd TEXT,
      firebaseId TEXT,
      deviceId TEXT,
      platformType TEXT,
      isAvailableLocally INTEGER DEFAULT 1,
      isDeleted INTEGER DEFAULT 0,
      updatedAt TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

    // ポイント管理用テーブル
    await db.execute('''
    CREATE TABLE reward_points (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      earnedPoints INTEGER NOT NULL,
      usedPoints INTEGER NOT NULL,
      lastUpdated TEXT NOT NULL,
      firebaseId TEXT,
      lastSyncEarnedPoints INTEGER,
      lastSyncUsedPoints INTEGER
    )
  ''');

    await db.execute('''
    CREATE TABLE app_usage_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      appId INTEGER NOT NULL,
      startTime TEXT NOT NULL,
      endTime TEXT NOT NULL,
      pointsSpent INTEGER NOT NULL,
      firebaseId TEXT,
      appName TEXT,
      appPath TEXT,
      remoteAppId INTEGER,
      FOREIGN KEY (appId) REFERENCES restricted_apps (id) ON DELETE CASCADE
    )
  ''');

    // 日次目標テーブル
    await db.execute('''
    CREATE TABLE daily_goals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      targetPomodoros INTEGER NOT NULL,
      achievedPomodoros INTEGER NOT NULL,
      achieved INTEGER NOT NULL,
      firebaseId TEXT
    )
  ''');

    // インデックスの作成（検索パフォーマンス向上のため）
    await db.execute(
        'CREATE INDEX idx_pomodoro_sessions_taskId ON pomodoro_sessions(taskId)');
    await db.execute(
        'CREATE INDEX idx_pomodoro_sessions_startTime ON pomodoro_sessions(startTime)');
    await db.execute('CREATE INDEX idx_daily_goals_date ON daily_goals(date)');

    // Firebase ID用のインデックス作成
    await db.execute('CREATE INDEX idx_tasks_firebaseId ON tasks(firebaseId)');
    await db.execute(
        'CREATE INDEX idx_pomodoro_sessions_firebaseId ON pomodoro_sessions(firebaseId)');
    await db.execute(
        'CREATE INDEX idx_app_usage_sessions_firebaseId ON app_usage_sessions(firebaseId)');
    await db.execute(
        'CREATE INDEX idx_restricted_apps_firebaseId ON restricted_apps(firebaseId)');
    await db.execute(
        'CREATE INDEX idx_daily_goals_firebaseId ON daily_goals(firebaseId)');

    // 更新日時のインデックス作成（変更検出用）
    await db.execute('CREATE INDEX idx_tasks_updatedAt ON tasks(updatedAt)');
  }

  // データベースアップグレード処理
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // バージョン1から2へのアップグレード
      print('データベースをバージョン1から2にアップグレードします');

      // 新しいテーブルを作成
      await db.execute('''
      CREATE TABLE IF NOT EXISTS reward_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        earnedPoints INTEGER NOT NULL,
        usedPoints INTEGER NOT NULL,
        lastUpdated TEXT NOT NULL
      )
    ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS app_usage_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        appId INTEGER NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        pointsSpent INTEGER NOT NULL,
        FOREIGN KEY (appId) REFERENCES restricted_apps (id) ON DELETE CASCADE
      )
    ''');

      // restricted_apps テーブルに新しいカラムを追加
      try {
        await db.execute(
            'ALTER TABLE restricted_apps ADD COLUMN pointCostPerHour INTEGER');
        await db.execute(
            'ALTER TABLE restricted_apps ADD COLUMN minutesPerPoint INTEGER');
        await db.execute(
            'ALTER TABLE restricted_apps ADD COLUMN currentSessionEnd TEXT');
      } catch (e) {
        print('カラム追加エラー（既に存在する可能性があります）: $e');
      }

      // デフォルトのポイントレコードを追加
      try {
        await db.insert('reward_points', {
          'earnedPoints': 0,
          'usedPoints': 0,
          'lastUpdated': DateTime.now().toIso8601String(),
        });
        print('デフォルトポイントレコードを作成しました');
      } catch (e) {
        print('デフォルトポイント作成エラー: $e');
      }
    }
    if (oldVersion < 3) {
      print('データベースをバージョン2から3にアップグレードします');

      // pomodoro_sessionsテーブルに新しいカラムを追加
      try {
        // 既存のカラムを確認してから追加（重複エラーを回避）
        var tableInfo =
            await db.rawQuery("PRAGMA table_info(pomodoro_sessions)");
        List<String> existingColumns =
            tableInfo.map((col) => col['name'] as String).toList();

        if (!existingColumns.contains('timeOfDay')) {
          await db.execute(
              'ALTER TABLE pomodoro_sessions ADD COLUMN timeOfDay TEXT');
        }

        if (!existingColumns.contains('interruptionCount')) {
          await db.execute(
              'ALTER TABLE pomodoro_sessions ADD COLUMN interruptionCount INTEGER DEFAULT 0');
        }

        if (!existingColumns.contains('mood')) {
          await db
              .execute('ALTER TABLE pomodoro_sessions ADD COLUMN mood TEXT');
        }

        if (!existingColumns.contains('isBreak')) {
          await db.execute(
              'ALTER TABLE pomodoro_sessions ADD COLUMN isBreak INTEGER DEFAULT 0');
        }

        // 既存のセッションデータに時間帯情報を追加
        await db.execute('''
          UPDATE pomodoro_sessions
          SET timeOfDay = CASE
            WHEN strftime('%H', startTime) BETWEEN '05' AND '07' THEN 'morning'
            WHEN strftime('%H', startTime) BETWEEN '08' AND '11' THEN 'forenoon'
            WHEN strftime('%H', startTime) BETWEEN '12' AND '16' THEN 'afternoon'
            WHEN strftime('%H', startTime) BETWEEN '17' AND '19' THEN 'evening'
            WHEN strftime('%H', startTime) BETWEEN '20' AND '23' THEN 'night'
            ELSE 'midnight'
          END
          WHERE timeOfDay IS NULL
        ''');
      } catch (e) {
        print('pomodoro_sessionsテーブル更新エラー: $e');
      }
      // 日次目標テーブルを作成
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS daily_goals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            targetPomodoros INTEGER NOT NULL,
            achievedPomodoros INTEGER NOT NULL,
            achieved INTEGER NOT NULL
          )
        ''');

        // インデックス作成
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_pomodoro_sessions_taskId ON pomodoro_sessions(taskId)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_pomodoro_sessions_startTime ON pomodoro_sessions(startTime)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_daily_goals_date ON daily_goals(date)');

        print('daily_goalsテーブルを作成しました');
      } catch (e) {
        print('daily_goalsテーブル作成エラー: $e');
      }
    }
    if (oldVersion < 4) {
      // バージョン3から4へのアップグレード（同期フィールド追加）
      print('データベースをバージョン3から4にアップグレードします（同期フィールド追加）');

      try {
        // タスクテーブルに同期フィールドを追加
        await db.execute('ALTER TABLE tasks ADD COLUMN firebaseId TEXT');
        await db.execute(
            'ALTER TABLE tasks ADD COLUMN isDeleted INTEGER DEFAULT 0');

        // ポモドーロセッションテーブルに同期フィールドを追加
        await db.execute(
            'ALTER TABLE pomodoro_sessions ADD COLUMN firebaseId TEXT');

        // アプリ使用セッションテーブルに同期フィールドを追加
        await db.execute(
            'ALTER TABLE app_usage_sessions ADD COLUMN firebaseId TEXT');

        // ここに追加 ↓
        // reward_pointsテーブルに同期フィールドを追加
        await db
            .execute('ALTER TABLE reward_points ADD COLUMN firebaseId TEXT');

        // daily_goalsテーブルに同期フィールドを追加
        await db.execute('ALTER TABLE daily_goals ADD COLUMN firebaseId TEXT');

        print('同期フィールドを追加しました');
      } catch (e) {
        print('同期フィールド追加エラー: $e');
      }
    }
    if (oldVersion < 5) {
      // バージョン4から5へのアップグレード（同期フィールド拡張）
      print('データベースをバージョン4から5にアップグレードします（同期フィールド拡張）');

      try {
        // reward_pointsテーブルとdaily_goalsテーブルにfirebaseIdカラムがなければ追加
        var rewardPointsInfo =
            await db.rawQuery("PRAGMA table_info(reward_points)");
        List<String> rewardPointsColumns =
            rewardPointsInfo.map((col) => col['name'] as String).toList();

        var dailyGoalsInfo =
            await db.rawQuery("PRAGMA table_info(daily_goals)");
        List<String> dailyGoalsColumns =
            dailyGoalsInfo.map((col) => col['name'] as String).toList();

        // reward_pointsテーブルにfirebaseIdがなければ追加
        if (!rewardPointsColumns.contains('firebaseId')) {
          await db
              .execute('ALTER TABLE reward_points ADD COLUMN firebaseId TEXT');
          print('reward_pointsテーブルにfirebaseIdを追加しました');
        }

        // daily_goalsテーブルにfirebaseIdがなければ追加
        if (!dailyGoalsColumns.contains('firebaseId')) {
          await db
              .execute('ALTER TABLE daily_goals ADD COLUMN firebaseId TEXT');
          print('daily_goalsテーブルにfirebaseIdを追加しました');
        }

        // ポモドーロセッションテーブルにfirebaseTaskIdカラムを追加
        var pomodoroSessionsInfo =
            await db.rawQuery("PRAGMA table_info(pomodoro_sessions)");
        List<String> pomodoroColumns =
            pomodoroSessionsInfo.map((col) => col['name'] as String).toList();

        if (!pomodoroColumns.contains('firebaseTaskId')) {
          await db.execute(
              'ALTER TABLE pomodoro_sessions ADD COLUMN firebaseTaskId TEXT');
          print('pomodoro_sessionsテーブルにfirebaseTaskIdを追加しました');
        }

        print('同期フィールド拡張が完了しました');
      } catch (e) {
        print('同期フィールド拡張エラー: $e');
      }
    }

    if (oldVersion < 6) {
      // バージョン5から6へのアップグレード（ポイント同期フィールド追加）
      print('データベースをバージョン5から6にアップグレードします（ポイント同期フィールド追加）');

      try {
        // reward_pointsテーブルにLastSync関連カラムを追加
        var rewardPointsInfo =
            await db.rawQuery("PRAGMA table_info(reward_points)");
        List<String> rewardPointsColumns =
            rewardPointsInfo.map((col) => col['name'] as String).toList();

        if (!rewardPointsColumns.contains('lastSyncEarnedPoints')) {
          await db.execute(
              'ALTER TABLE reward_points ADD COLUMN lastSyncEarnedPoints INTEGER');
          print('reward_pointsテーブルにlastSyncEarnedPointsを追加しました');
        }

        if (!rewardPointsColumns.contains('lastSyncUsedPoints')) {
          await db.execute(
              'ALTER TABLE reward_points ADD COLUMN lastSyncUsedPoints INTEGER');
          print('reward_pointsテーブルにlastSyncUsedPointsを追加しました');
        }

        // 現在の値を同期値としても設定
        await db.execute('''
        UPDATE reward_points
        SET lastSyncEarnedPoints = earnedPoints,
            lastSyncUsedPoints = usedPoints
      ''');

        // app_usage_sessionsテーブルにアプリ情報カラムを追加
        var appUsageInfo =
            await db.rawQuery("PRAGMA table_info(app_usage_sessions)");
        List<String> appUsageColumns =
            appUsageInfo.map((col) => col['name'] as String).toList();

        if (!appUsageColumns.contains('appName')) {
          await db.execute(
              'ALTER TABLE app_usage_sessions ADD COLUMN appName TEXT');
        }

        if (!appUsageColumns.contains('appPath')) {
          await db.execute(
              'ALTER TABLE app_usage_sessions ADD COLUMN appPath TEXT');
        }

        if (!appUsageColumns.contains('remoteAppId')) {
          await db.execute(
              'ALTER TABLE app_usage_sessions ADD COLUMN remoteAppId INTEGER');
        }

        // 既存のセッションデータにアプリ情報を追加
        final sessions = await db.query('app_usage_sessions');
        for (var session in sessions) {
          final appId = session['appId'] as int;
          final appInfo = await db.query(
            'restricted_apps',
            columns: ['name', 'executablePath'],
            where: 'id = ?',
            whereArgs: [appId],
          );

          if (appInfo.isNotEmpty) {
            await db.update(
              'app_usage_sessions',
              {
                'appName': appInfo.first['name'],
                'appPath': appInfo.first['executablePath'],
              },
              where: 'id = ?',
              whereArgs: [session['id']],
            );
          }
        }

        print('ポイント同期とアプリセッション機能拡張が完了しました');
      } catch (e) {
        print('ポイント同期とアプリセッション機能拡張エラー: $e');
      }
    }
    if (oldVersion < 7) {
      await _upgradeDBToV7(db);
    }
    if (oldVersion < 8) {
      await _upgradeDBToV8(db);
    }
  }

  Future<void> _upgradeDBToV8(Database db) async {
    print('データベースをバージョン7から8にアップグレードします（論理削除フィールド拡張）');

    try {
      // セッションテーブルに論理削除と更新日時フィールドを追加
      await db.execute('''
      ALTER TABLE pomodoro_sessions ADD COLUMN isDeleted INTEGER DEFAULT 0;
      ALTER TABLE pomodoro_sessions ADD COLUMN updatedAt TEXT DEFAULT CURRENT_TIMESTAMP;
    ''');

      // 制限アプリテーブルにデバイス情報と論理削除フィールドを追加
      await db.execute('''
      ALTER TABLE restricted_apps ADD COLUMN deviceId TEXT;
      ALTER TABLE restricted_apps ADD COLUMN platformType TEXT;
      ALTER TABLE restricted_apps ADD COLUMN isAvailableLocally INTEGER DEFAULT 1;
      ALTER TABLE restricted_apps ADD COLUMN isDeleted INTEGER DEFAULT 0;
      ALTER TABLE restricted_apps ADD COLUMN updatedAt TEXT DEFAULT CURRENT_TIMESTAMP;
    ''');

      // アプリ使用セッションテーブルに論理削除フィールドを追加
      await db.execute('''
      ALTER TABLE app_usage_sessions ADD COLUMN isDeleted INTEGER DEFAULT 0;
    ''');

      // 既存のレコードの updatedAt フィールドを現在時刻で更新
      await db.execute('''
      UPDATE restricted_apps 
      SET updatedAt = CURRENT_TIMESTAMP 
      WHERE updatedAt IS NULL
    ''');

      print('論理削除フィールド拡張が完了しました');
    } catch (e) {
      print('論理削除フィールド拡張エラー: $e');
    }

    // 現在のデバイスIDを設定
    try {
      final deviceId = await _getDeviceId();
      final platformType = Platform.isWindows ? "windows" : "android";

      await db.update(
          'restricted_apps',
          {
            'deviceId': deviceId,
            'platformType': platformType,
          },
          where: 'deviceId IS NULL');

      print('既存アプリにデバイスIDを設定しました: $deviceId');
    } catch (e) {
      print('デバイスID設定エラー: $e');
    }
  }

  Future<void> _upgradeDBToV7(Database db) async {
    print('ポイント同期カラム追加中...');

    try {
      // reward_pointsテーブルに同期用カラムを追加
      var tableInfo = await db.rawQuery("PRAGMA table_info(reward_points)");
      List<String> existingColumns =
          tableInfo.map((col) => col['name'] as String).toList();

      if (!existingColumns.contains('lastSyncEarnedPoints')) {
        await db.execute(
            'ALTER TABLE reward_points ADD COLUMN lastSyncEarnedPoints INTEGER');
      }

      if (!existingColumns.contains('lastSyncUsedPoints')) {
        await db.execute(
            'ALTER TABLE reward_points ADD COLUMN lastSyncUsedPoints INTEGER');
      }

      // 現在の値を同期値としても設定
      await db.execute('''
      UPDATE reward_points
      SET lastSyncEarnedPoints = earnedPoints,
          lastSyncUsedPoints = usedPoints
    ''');

      print('ポイント同期カラム追加完了');
    } catch (e) {
      print('ポイント同期カラム追加エラー: $e');
    }
  }

  // 時間帯ごとのポモドーロ数を取得
  Future<List<Map<String, dynamic>>> getTimeOfDayStatistics(int days) async {
    final db = await database;
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));

    return await db.rawQuery('''
      SELECT 
        timeOfDay,
        COUNT(*) as count,
        AVG(focusScore) as avgFocusScore,
        SUM(durationMinutes) as totalMinutes,
        AVG(interruptionCount) as avgInterruptions
      FROM pomodoro_sessions
      WHERE startTime BETWEEN ? AND ?
        AND completed = 1
        AND isBreak = 0
      GROUP BY timeOfDay
      ORDER BY count DESC
    ''', [startDate.toIso8601String(), now.toIso8601String()]);
  }

  // 時間帯ごとのポモドーロ数をUI表示用に変換
  Future<List<Map<String, dynamic>>> getTimeOfDayStatisticsForUI(
      int days) async {
    final stats = await getTimeOfDayStatistics(days);

    // 時間帯名を日本語表示用に変換
    final Map<String, String> timeOfDayLabels = {
      'morning': '早朝 (5-8時)',
      'forenoon': '午前 (8-12時)',
      'afternoon': '午後 (12-17時)',
      'evening': '夕方 (17-20時)',
      'night': '夜間 (20-24時)',
      'midnight': '深夜 (0-5時)',
    };

    // すべての時間帯を網羅するための結果を作成
    final result = <Map<String, dynamic>>[];

    for (var entry in timeOfDayLabels.entries) {
      final timeOfDay = entry.key;
      final label = entry.value;

      // 該当する時間帯のデータを検索
      final statData = stats.firstWhere(
        (item) => item['timeOfDay'] == timeOfDay,
        orElse: () => {
          'timeOfDay': timeOfDay,
          'count': 0,
          'avgFocusScore': 0.0,
          'totalMinutes': 0,
          'avgInterruptions': 0.0,
        },
      );

      result.add({
        'timeOfDay': timeOfDay,
        'label': label,
        'count': statData['count'],
        'avgFocusScore': statData['avgFocusScore'] ?? 0.0,
        'totalMinutes': statData['totalMinutes'] ?? 0,
        'avgInterruptions': statData['avgInterruptions'] ?? 0.0,
      });
    }

    // カウント数でソート
    result.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return result;
  }

  // 長期トレンドデータを取得（月別・四半期別・年別）
  Future<List<Map<String, dynamic>>> getLongTermTrendData(
      String timeFrame) async {
    final db = await database;

    // 期間に基づいてグループ化方法を選択
    String groupFormat;
    switch (timeFrame) {
      case 'monthly':
        groupFormat = "'%Y-%m'";
        break;
      case 'quarterly':
        groupFormat = "'%Y-' || ((strftime('%m', startTime) - 1) / 3 + 1)";
        break;
      case 'yearly':
      default:
        groupFormat = "'%Y'";
        break;
    }

    return await db.rawQuery('''
      SELECT 
        strftime($groupFormat, startTime) as period,
        COUNT(*) as count,
        SUM(durationMinutes) as totalMinutes,
        AVG(focusScore) as avgFocusScore,
        SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) as completedCount,
        COUNT(DISTINCT date(startTime)) as activeDays
      FROM pomodoro_sessions
      WHERE isBreak = 0
      GROUP BY period
      ORDER BY period ASC
    ''');
  }

  // 習慣形成に関する統計を取得
  Future<Map<String, dynamic>> getHabitFormationStats() async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 今日のポモドーロ数
    final todayResults = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM pomodoro_sessions
      WHERE date(startTime) = date(?)
        AND isBreak = 0
        AND completed = 1
    ''', [today.toIso8601String()]);

    final todayCount = todayResults.first['count'] as int? ?? 0;

    // 最終セッション日を取得
    final lastSessionResults = await db.rawQuery('''
      SELECT MAX(date(startTime)) as lastSessionDate
      FROM pomodoro_sessions
      WHERE isBreak = 0
        AND completed = 1
    ''');

    final lastSessionDateStr =
        lastSessionResults.first['lastSessionDate'] as String?;
    final lastSessionDate =
        lastSessionDateStr != null ? DateTime.parse(lastSessionDateStr) : null;

    // 現在のストリーク（連続日数）を計算
    int currentStreak = 0;
    if (lastSessionDate != null) {
      // 今日のセッションがある、または最終セッションが昨日の場合
      if (todayCount > 0 ||
          lastSessionDate
              .isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
        currentStreak = 1; // まず今日または昨日をカウント

        var checkDate = todayCount > 0
            ? today.subtract(const Duration(days: 1))
            : today.subtract(const Duration(days: 2));

        while (true) {
          final dateStr = checkDate.toIso8601String();
          final result = await db.rawQuery('''
            SELECT COUNT(*) as count
            FROM pomodoro_sessions
            WHERE date(startTime) = date(?)
              AND isBreak = 0
              AND completed = 1
          ''', [dateStr]);

          final count = result.first['count'] as int? ?? 0;
          if (count > 0) {
            currentStreak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }
      }
    }

    // 最長ストリーク（連続日数）を計算
    final allDatesResults = await db.rawQuery('''
      SELECT DISTINCT date(startTime) as sessionDate
      FROM pomodoro_sessions
      WHERE isBreak = 0
        AND completed = 1
      ORDER BY sessionDate ASC
    ''');

    int longestStreak = 0;
    int tempStreak = 0;
    DateTime? previousDate;

    for (var row in allDatesResults) {
      final dateStr = row['sessionDate'] as String;
      final date = DateTime.parse(dateStr);

      if (previousDate == null) {
        tempStreak = 1;
      } else {
        final difference = date.difference(previousDate!).inDays;
        if (difference == 1) {
          tempStreak++;
        } else {
          if (tempStreak > longestStreak) {
            longestStreak = tempStreak;
          }
          tempStreak = 1;
        }
      }

      previousDate = date;
    }

    // 最後のシーケンスをチェック
    if (tempStreak > longestStreak) {
      longestStreak = tempStreak;
    }

    // 一貫性スコア（過去30日間で何日作業したか）
    final consistencyResults = await db.rawQuery('''
      SELECT COUNT(DISTINCT date(startTime)) as workDays
      FROM pomodoro_sessions
      WHERE startTime >= date('now', '-30 days')
        AND isBreak = 0
        AND completed = 1
    ''');

    final workDays = consistencyResults.first['workDays'] as int? ?? 0;
    final consistencyScore = (workDays / 30.0) * 100;
    // 過去7日間、過去30日間のデータ
    final last7DaysResults = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM pomodoro_sessions
      WHERE startTime >= date('now', '-7 days')
        AND isBreak = 0
        AND completed = 1
    ''');

    final last30DaysResults = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM pomodoro_sessions
      WHERE startTime >= date('now', '-30 days')
        AND isBreak = 0
        AND completed = 1
    ''');

    final last7DaysCount = last7DaysResults.first['count'] as int? ?? 0;
    final last30DaysCount = last30DaysResults.first['count'] as int? ?? 0;

    return {
      'todayPomodoros': todayCount,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'consistencyScore': consistencyScore,
      'workDaysLast30': workDays,
      'last7DaysCount': last7DaysCount,
      'last30DaysCount': last30DaysCount,
    };
  }

  // タスク効率分析データを取得
  Future<List<Map<String, dynamic>>> getTaskEfficiencyData() async {
    try {
      final db = await database;

      return await db.rawQuery('''
      SELECT 
        t.id,
        t.name,
        t.category,
        t.estimatedPomodoros,
        COUNT(ps.id) as completedPomodoros,
        AVG(ps.focusScore) as avgFocusScore,
        SUM(ps.durationMinutes) as totalMinutes,
        AVG(ps.interruptionCount) as avgInterruptions
      FROM tasks t
      JOIN pomodoro_sessions ps ON t.id = ps.taskId
      WHERE ps.completed = 1
        AND ps.isBreak = 0
      GROUP BY t.id
      HAVING completedPomodoros >= 3
      ORDER BY avgFocusScore DESC
    ''');
    } catch (e) {
      print('タスク効率データ取得エラー: $e');
      return [];
    }
  }

  // 曜日ごとの効率データを取得
  Future<List<Map<String, dynamic>>> getWeekdayEfficiencyData() async {
    final db = await database;

    return await db.rawQuery('''
      SELECT 
        strftime('%w', startTime) as weekday,
        COUNT(*) as count,
        AVG(focusScore) as avgFocusScore,
        SUM(durationMinutes) as totalMinutes,
        AVG(interruptionCount) as avgInterruptions
      FROM pomodoro_sessions
      WHERE completed = 1
        AND isBreak = 0
      GROUP BY weekday
      ORDER BY weekday ASC
    ''');
  }

  // エクスポート用の全セッションデータを取得
  Future<List<Map<String, dynamic>>> getAllSessionsForExport() async {
    final db = await database;

    return await db.rawQuery('''
      SELECT 
        ps.id,
        ps.taskId,
        t.name as taskName,
        t.category as taskCategory,
        ps.startTime,
        ps.endTime,
        ps.durationMinutes,
        ps.completed,
        ps.focusScore,
        ps.timeOfDay,
        ps.interruptionCount,
        ps.mood,
        ps.isBreak
      FROM pomodoro_sessions ps
      LEFT JOIN tasks t ON ps.taskId = t.id
      ORDER BY ps.startTime DESC
    ''');
  }

  // 日次目標の管理メソッド
  Future<int> insertDailyGoal(DailyGoal goal) async {
    final db = await database;
    return await db.insert('daily_goals', goal.toMap());
  }

  Future<void> updateDailyGoal(DailyGoal goal) async {
    final db = await database;
    await db.update(
      'daily_goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  Future<DailyGoal?> getDailyGoal(DateTime date) async {
    final db = await database;
    final dateStr = DateTime(date.year, date.month, date.day).toIso8601String();

    final results = await db.query(
      'daily_goals',
      where: 'date = ?',
      whereArgs: [dateStr],
    );

    if (results.isNotEmpty) {
      return DailyGoal.fromMap(results.first);
    }

    return null;
  }

  Future<List<DailyGoal>> getDailyGoals(
      DateTime startDate, DateTime endDate) async {
    final db = await database;
    final startDateStr =
        DateTime(startDate.year, startDate.month, startDate.day)
            .toIso8601String();
    final endDateStr =
        DateTime(endDate.year, endDate.month, endDate.day).toIso8601String();

    final results = await db.query(
      'daily_goals',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDateStr, endDateStr],
      orderBy: 'date ASC',
    );

    return results.map((map) => DailyGoal.fromMap(map)).toList();
  }

  // 今日の目標を取得または作成
  Future<DailyGoal> getOrCreateTodayGoal(int defaultTarget) async {
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);

    // 今日の目標を取得
    final existingGoal = await getDailyGoal(dateOnly);
    if (existingGoal != null) {
      return existingGoal;
    }

    // 今日のポモドーロ完了数を取得
    final todayResults = await database.then((db) => db.rawQuery('''
      SELECT COUNT(*) as count
      FROM pomodoro_sessions
      WHERE date(startTime) = date(?)
        AND isBreak = 0
        AND completed = 1
    ''', [dateOnly.toIso8601String()]));

    final todayCount = todayResults.first['count'] as int? ?? 0;

    // 新しい目標を作成
    final newGoal = DailyGoal(
      date: dateOnly,
      targetPomodoros: defaultTarget,
      achievedPomodoros: todayCount,
      achieved: todayCount >= defaultTarget,
    );

    final id = await insertDailyGoal(newGoal);
    return newGoal.copyWith(id: id);
  }

  // 目標達成状況を更新
  Future<void> updateDailyGoalAchievement(DailyGoal goal) async {
    final dateOnly = DateTime(goal.date.year, goal.date.month, goal.date.day);

    // その日のポモドーロ完了数を取得
    final results = await database.then((db) => db.rawQuery('''
      SELECT COUNT(*) as count
      FROM pomodoro_sessions
      WHERE date(startTime) = date(?)
        AND isBreak = 0
        AND completed = 1
    ''', [dateOnly.toIso8601String()]));

    final completedCount = results.first['count'] as int? ?? 0;

    // 目標達成状況を更新
    final updatedGoal = goal.copyWith(
      achievedPomodoros: completedCount,
      achieved: completedCount >= goal.targetPomodoros,
    );

    await updateDailyGoal(updatedGoal);
  }

  // PomodoroSessionテーブルにtimeOfDayフィールドを追加するマイグレーション
  Future<void> _upgradeDBToV3(Database db) async {
    // 既存のテーブルに新しいカラムを追加
    try {
      await db
          .execute('ALTER TABLE pomodoro_sessions ADD COLUMN timeOfDay TEXT');
      await db.execute(
          'ALTER TABLE pomodoro_sessions ADD COLUMN interruptionCount INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE pomodoro_sessions ADD COLUMN mood TEXT');

      // 既存のセッションデータに時間帯情報を追加
      await db.execute('''
        UPDATE pomodoro_sessions
        SET timeOfDay = CASE
          WHEN strftime('%H', startTime) BETWEEN '05' AND '07' THEN 'morning'
          WHEN strftime('%H', startTime) BETWEEN '08' AND '11' THEN 'forenoon'
          WHEN strftime('%H', startTime) BETWEEN '12' AND '16' THEN 'afternoon'
          WHEN strftime('%H', startTime) BETWEEN '17' AND '19' THEN 'evening'
          WHEN strftime('%H', startTime) BETWEEN '20' AND '23' THEN 'night'
          ELSE 'midnight'
        END
      ''');
    } catch (e) {
      print('マイグレーションエラー: $e');
    }
  }

  // タスク関連のメソッド
  Future<int> insertTask(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap());
  }

  // 論理削除されていないタスクのみを取得（上書き）
  Future<List<Task>> getTasks() async {
    final db = await database;
    final results = await db.query('tasks',
        where: 'isDeleted = 0', orderBy: 'updatedAt DESC');
    return results.map((map) => Task.fromMap(map)).toList();
  }

  // 論理削除されているタスクも含めて取得
  Future<List<Task>> getAllTasksIncludingDeleted() async {
    final db = await database;
    final results = await db.query('tasks', orderBy: 'updatedAt DESC');
    return results.map((map) => Task.fromMap(map)).toList();
  }

  Future<Task?> getTask(int id) async {
    final db = await database;
    final results = await db.query('tasks', where: 'id = ?', whereArgs: [id]);

    if (results.isNotEmpty) {
      return Task.fromMap(results.first);
    }
    return null;
  }

  Future<int> updateTask(Task task) async {
    final db = await database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ポモドーロセッション関連のメソッド
  Future<int> insertPomodoroSession(PomodoroSession session) async {
    final db = await database;
    return await db.insert('pomodoro_sessions', session.toMap());
  }

  Future<List<PomodoroSession>> getPomodoroSessions() async {
    final db = await database;
    final results = await db.query(
      'pomodoro_sessions',
      where: 'isDeleted = 0',
      orderBy: 'startTime DESC',
    );
    return results.map((map) => PomodoroSession.fromMap(map)).toList();
  }

  // すべてのポモドーロセッションを取得（同期用）
  Future<List<PomodoroSession>> getAllPomodoroSessionsIncludingDeleted() async {
    final db = await database;
    final results = await db.query(
      'pomodoro_sessions',
      orderBy: 'startTime DESC',
    );
    return results.map((map) => PomodoroSession.fromMap(map)).toList();
  }

  Future<List<PomodoroSession>> getTaskPomodoroSessions(int taskId) async {
    final db = await database;
    final results = await db.query(
      'pomodoro_sessions',
      where: 'taskId = ? AND isDeleted = 0',
      whereArgs: [taskId],
      orderBy: 'startTime DESC',
    );
    return results.map((map) => PomodoroSession.fromMap(map)).toList();
  }

  // 統計関連のメソッド
  Future<List<Map<String, dynamic>>> getDailyStatistics() async {
    final db = await database;
    final now = DateTime.now();

    // 過去5日間のデータを準備（今日も含む）
    final result = <Map<String, dynamic>>[];

    for (int i = 4; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day - i);
      final dateStr = date.toIso8601String().substring(0, 10);

      // その日のデータをクエリ
      final results = await db.rawQuery('''
      SELECT 
        COUNT(*) as count,
        SUM(durationMinutes) as totalMinutes
      FROM pomodoro_sessions
      WHERE date(startTime) = date(?)
        AND completed = 1
        AND isBreak = 0
    ''', [dateStr]);

      // データを結果リストに追加（セッションがなければ0として追加）
      result.add({
        'date': dateStr,
        'count': results.first['count'] as int? ?? 0,
        'totalMinutes': results.first['totalMinutes'] as int? ?? 0
      });
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> getWeeklyStatistics() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        strftime('%Y-%W', startTime) as week,
        COUNT(*) as count,
        SUM(durationMinutes) as totalMinutes
      FROM pomodoro_sessions
      WHERE completed = 1
      GROUP BY strftime('%Y-%W', startTime)
      ORDER BY week DESC
      LIMIT 8
    ''');

    return results.reversed.toList();
  }

  Future<List<Map<String, dynamic>>> getTaskStatistics() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        t.id,
        t.name,
        t.category,
        COUNT(ps.id) as sessionCount,
        SUM(ps.durationMinutes) as totalMinutes,
        AVG(ps.focusScore) as avgFocusScore
      FROM tasks t
      LEFT JOIN pomodoro_sessions ps ON t.id = ps.taskId AND ps.completed = 1
      GROUP BY t.id
      ORDER BY totalMinutes DESC
    ''');
  }

  Future<List<Map<String, dynamic>>> getCategoryStatistics() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT 
        t.category,
        COUNT(ps.id) as sessionCount,
        SUM(ps.durationMinutes) as totalMinutes
      FROM tasks t
      LEFT JOIN pomodoro_sessions ps ON t.id = ps.taskId AND ps.completed = 1
      GROUP BY t.category
      ORDER BY totalMinutes DESC
    ''');
  }

// 短期統計の要約を取得（過去30日間）
  Future<Map<String, dynamic>> getShortTermSummary() async {
    final db = await database;
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final results = await db.rawQuery('''
    SELECT 
      COUNT(*) as count,
      SUM(durationMinutes) as totalMinutes,
      COUNT(DISTINCT date(startTime)) as activeDays
    FROM pomodoro_sessions
    WHERE startTime BETWEEN ? AND ?
      AND completed = 1
      AND isBreak = 0
  ''', [thirtyDaysAgo.toIso8601String(), now.toIso8601String()]);

    final totalPomodoros = results.first['count'] as int? ?? 0;
    final totalMinutes = results.first['totalMinutes'] as int? ?? 0;
    final activeDays = results.first['activeDays'] as int? ?? 0;

    final avgDailyPomodoros =
        activeDays > 0 ? totalPomodoros / activeDays : 0.0;

    return {
      'totalPomodoros': totalPomodoros,
      'totalMinutes': totalMinutes,
      'activeDays': activeDays,
      'avgDailyPomodoros': avgDailyPomodoros,
    };
  }

// ポイント関連のCRUD操作
  Future<RewardPoint> getRewardPoints() async {
    try {
      final db = await database;
      final results = await db.query('reward_points');

      if (results.isEmpty) {
        // デフォルトのポイントレコードを作成
        final defaultPoints = RewardPoint(
          earnedPoints: 0,
          usedPoints: 0,
          lastUpdated: DateTime.now(),
        );
        try {
          final id = await db.insert('reward_points', defaultPoints.toMap());
          return defaultPoints.copyWith(id: id);
        } catch (e) {
          print('ポイントレコード作成エラー: $e');
          return defaultPoints; // テーブルが存在しない場合などは id なしで返す
        }
      }

      return RewardPoint.fromMap(results.first);
    } catch (e) {
      print('ポイント読み込みエラー: $e');
      return RewardPoint(
        earnedPoints: 0,
        usedPoints: 0,
        lastUpdated: DateTime.now(),
      );
    }
  }

  Future<void> updateRewardPoints(RewardPoint points) async {
    final db = await database;
    await db.update(
      'reward_points',
      points.toMap(),
      where: 'id = ?',
      whereArgs: [points.id],
    );
  }

  // ポイント増加
  Future<void> addEarnedPoints(int points) async {
    final currentPoints = await getRewardPoints();
    await updateRewardPoints(
      currentPoints.copyWith(
        earnedPoints: currentPoints.earnedPoints + points,
        lastUpdated: DateTime.now(),
      ),
    );
  }

  // ポイント使用
  Future<bool> usePoints(int points) async {
    final currentPoints = await getRewardPoints();
    if (currentPoints.availablePoints < points) {
      return false; // ポイント不足
    }

    await updateRewardPoints(
      currentPoints.copyWith(
        usedPoints: currentPoints.usedPoints + points,
        lastUpdated: DateTime.now(),
      ),
    );
    return true;
  }

  // アプリ使用セッション管理
  Future<int> insertAppUsageSession(AppUsageSession session) async {
    final db = await database;
    return await db.insert('app_usage_sessions', session.toMap());
  }

  Future<List<AppUsageSession>> getAppUsageSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'app_usage_sessions',
      orderBy: 'startTime DESC',
    );

    //return results.map((map) => AppUsageSession.fromMap(map)).toList();
    return List.generate(results.length, (i) {
      return AppUsageSession.fromMap(results[i]);
    });
  }

  // 制限アプリの追加にトランザクションを使用
  Future<int> insertRestrictedApp(RestrictedApp app) async {
    final db = await database;
    int id = 0;

    await db.transaction((txn) async {
      id = await txn.insert('restricted_apps', app.toMap());
    });

    return id;
  }

// 制限アプリの更新にトランザクションを使用
  Future<int> updateRestrictedApp(RestrictedApp app) async {
    final db = await database;
    int result = 0;

    await db.transaction((txn) async {
      result = await txn.update(
        'restricted_apps',
        app.toMap(),
        where: 'id = ?',
        whereArgs: [app.id],
      );
    });

    return result;
  }
  // DatabaseHelper クラスに追加するメソッド

  // 論理削除されていないの制限アプリを取得
  Future<List<RestrictedApp>> getRestrictedApps() async {
    final db = await database;
    final results = await db.query('restricted_apps');
    // パスごとにグループ化して最新のみを保持
    final Map<String, RestrictedApp> uniqueApps = {};

    for (var map in results) {
      final app = RestrictedApp.fromMap(map);
      final key = app.executablePath;

      // 既に同じパスのアプリが存在するか確認
      if (!uniqueApps.containsKey(key) || app.id! > uniqueApps[key]!.id!) {
        uniqueApps[key] = app;
      }
    }

    // 論理削除されていないアプリのみ返す
    return uniqueApps.values.where((app) => !app.isDeleted).toList();
  }

  Future<List<RestrictedApp>> getRestrictedAppsAvailableLocally() async {
    final db = await database;
    final results = await db.query('restricted_apps');
    // パスごとにグループ化して最新のみを保持
    final Map<String, RestrictedApp> uniqueApps = {};

    for (var map in results) {
      final app = RestrictedApp.fromMap(map);
      final key = app.executablePath;

      // 既に同じパスのアプリが存在するか確認
      if (!uniqueApps.containsKey(key) || app.id! > uniqueApps[key]!.id!) {
        uniqueApps[key] = app;
      }
    }

    // 論理削除されていないアプリのみ返す
    return uniqueApps.values
        .where((app) => !app.isDeleted && app.isAvailableLocally)
        .toList();
  }

// 名前で制限アプリを検索
  Future<List<RestrictedApp>> getRestrictedAppByName(String name) async {
    final db = await database;
    final results = await db.query(
      'restricted_apps',
      where: 'name = ?',
      whereArgs: [name],
    );
    return results.map((map) => RestrictedApp.fromMap(map)).toList();
  }

  // 削除されたものも含めて全ての制限アプリを取得（同期用）
  Future<List<RestrictedApp>> getAllRestrictedAppsIncludingDeleted() async {
    final db = await database;
    final results = await db.query('restricted_apps');

    // パスごとにグループ化して最新のみを保持
    final Map<String, RestrictedApp> uniqueApps = {};

    for (var map in results) {
      final app = RestrictedApp.fromMap(map);
      final key = app.executablePath;

      // 既に同じパスのアプリが存在するか確認
      if (!uniqueApps.containsKey(key) || app.id! > uniqueApps[key]!.id!) {
        uniqueApps[key] = app;
      }
    }

    return uniqueApps.values.toList();
  }

// 名前とパスで制限アプリを検索
  Future<RestrictedApp?> getRestrictedAppByNameAndPath(
      String name, String executablePath) async {
    final db = await database;
    final results = await db.query(
      'restricted_apps',
      where: 'name = ? AND executablePath = ?',
      whereArgs: [name, executablePath],
    );

    if (results.isNotEmpty) {
      return RestrictedApp.fromMap(results.first);
    }
    return null;
  }

// IDで制限アプリを取得
  Future<RestrictedApp?> getRestrictedApp(int id) async {
    final db = await database;
    final results = await db.query(
      'restricted_apps',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isNotEmpty) {
      return RestrictedApp.fromMap(results.first);
    }
    return null;
  }

// 制限アプリに関する統計情報を取得（使用時間、ポイント消費など）
  Future<Map<String, dynamic>> getAppUsageStatistics(int appId,
      {DateTime? startDate, DateTime? endDate}) async {
    final db = await database;

    final now = DateTime.now();
    final start = startDate ?? now.subtract(const Duration(days: 30));
    final end = endDate ?? now;

    // 指定された期間内のアプリ使用セッションを取得
    final results = await db.rawQuery('''
    SELECT 
      COUNT(*) as sessionCount,
      SUM((strftime('%s', endTime) - strftime('%s', startTime)) / 60) as totalMinutes,
      SUM(pointsSpent) as totalPointsSpent,
      MAX(endTime) as lastUsed
    FROM app_usage_sessions
    WHERE appId = ? 
      AND startTime BETWEEN ? AND ?
  ''', [appId, start.toIso8601String(), end.toIso8601String()]);

    if (results.isEmpty) {
      return {
        'sessionCount': 0,
        'totalMinutes': 0,
        'totalPointsSpent': 0,
        'lastUsed': null,
      };
    }

    final data = results.first;

    return {
      'sessionCount': data['sessionCount'] ?? 0,
      'totalMinutes': data['totalMinutes'] ?? 0,
      'totalPointsSpent': data['totalPointsSpent'] ?? 0,
      'lastUsed': data['lastUsed'] != null
          ? DateTime.parse(data['lastUsed'] as String)
          : null,
    };
  }

// 制限アプリの一覧を、最近使用したものから順に取得
  Future<List<Map<String, dynamic>>> getRestrictedAppsWithUsage() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      r.*,
      MAX(s.endTime) as lastUsed,
      COUNT(s.id) as usageCount
    FROM restricted_apps r
    LEFT JOIN app_usage_sessions s ON r.id = s.appId
    GROUP BY r.id
    ORDER BY lastUsed DESC NULLS LAST
  ''');
  }

// 特定の日のアプリ使用時間を取得
  Future<int> getAppUsageMinutesToday(int appId) async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();

    final results = await db.rawQuery('''
    SELECT 
      SUM((strftime('%s', endTime) - strftime('%s', startTime)) / 60) as minutesToday
    FROM app_usage_sessions
    WHERE appId = ? 
      AND date(startTime) = date(?)
  ''', [appId, today]);

    if (results.isEmpty || results.first['minutesToday'] == null) {
      return 0;
    }

    return (results.first['minutesToday'] as num).round();
  }

  // 特定の時間以降に変更されたタスクを取得
  Future<List<Task>> getTasksChangedSince(DateTime? timestamp) async {
    final db = await database;

    if (timestamp == null) {
      // タイムスタンプがnullの場合は全てのタスクを返す
      return getTasks();
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'updatedAt > ?',
      whereArgs: [timestamp.toIso8601String()],
    );

    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }

// 特定の時間以降に変更されたポモドーロセッションを取得
  Future<List<PomodoroSession>> getSessionsChangedSince(
      DateTime? timestamp) async {
    final db = await database;

    if (timestamp == null) {
      // タイムスタンプがnullの場合は全てのセッションを返す
      return getPomodoroSessions();
    }

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'pomodoro_sessions',
        where: 'endTime > ?',
        whereArgs: [timestamp.toIso8601String()],
      );

      final sessions = List.generate(maps.length, (i) {
        return PomodoroSession.fromMap(maps[i]);
      });

      print('変更されたセッション: ${sessions.length}件');
      return sessions;
    } catch (e) {
      print('セッション取得エラー: $e');
      return [];
    }
  }

// 特定の時間以降に変更されたアプリ使用セッションを取得
  Future<List<AppUsageSession>> getAppUsageSessionsChangedSince(
      DateTime? timestamp) async {
    final db = await database;

    if (timestamp == null) {
      // タイムスタンプがnullの場合は全てのセッションを返す
      return getAppUsageSessions();
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'app_usage_sessions',
      where: 'endTime > ?',
      whereArgs: [timestamp.toIso8601String()],
    );

    return List.generate(maps.length, (i) {
      return AppUsageSession.fromMap(maps[i]);
    });
  }

  // ポモドーロセッションの更新
  Future<void> updatePomodoroSession(PomodoroSession session) async {
    final db = await database;

    await db.update(
      'pomodoro_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

// アプリ使用セッションの更新
  Future<void> updateAppUsageSession(AppUsageSession session) async {
    final db = await database;

    await db.update(
      'app_usage_sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<Task?> getTaskByName(String name) async {
    final db = await database;
    final results = await db
        .query('tasks', where: 'name = ? AND isDeleted = 0', whereArgs: [name]);

    if (results.isNotEmpty) {
      return Task.fromMap(results.first);
    }
    return null;
  }

  // Firebase IDでタスクを検索
  Future<Task?> getTaskByFirebaseId(String firebaseId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'firebaseId = ?',
      whereArgs: [firebaseId],
    );

    if (maps.isEmpty) {
      return null;
    }

    return Task.fromMap(maps.first);
  }

// Firebase IDでポモドーロセッションを検索
  Future<PomodoroSession?> getSessionByFirebaseId(String firebaseId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'pomodoro_sessions',
      where: 'firebaseId = ?',
      whereArgs: [firebaseId],
    );

    if (maps.isEmpty) {
      return null;
    }

    return PomodoroSession.fromMap(maps.first);
  }

// Firebase IDでアプリ使用セッションを検索
  Future<AppUsageSession?> getAppUsageSessionByFirebaseId(
      String firebaseId) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'app_usage_sessions',
      where: 'firebaseId = ?',
      whereArgs: [firebaseId],
    );

    if (maps.isEmpty) {
      return null;
    }

    return AppUsageSession.fromMap(maps.first);
  }

  // タスクテーブルからすべてのカテゴリを取得
  Future<List<String>> getAllCategories() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
    SELECT DISTINCT category FROM tasks WHERE isDeleted = 0
  ''');

    return maps.map((map) => map['category'] as String).toList();
  }

// カテゴリ別にタスクを取得
  Future<List<Task>> getTasksByCategory(String category) async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'category = ? AND isDeleted = 0',
      whereArgs: [category],
      orderBy: 'updatedAt DESC',
    );

    return List.generate(maps.length, (i) {
      return Task.fromMap(maps[i]);
    });
  }

  // タスクを論理削除
  Future<int> softDeleteTask(int id) async {
    final db = await database;

    final task = await getTask(id);
    if (task == null) {
      return 0;
    }

    // 論理削除フラグを設定
    task.isDeleted = true;
    task.updatedAt = DateTime.now();

    return await updateTask(task);
  }

  // 制限アプリの論理削除
  Future<int> softDeleteRestrictedApp(int id) async {
    final db = await database;
    final app = await getRestrictedApp(id);

    if (app == null) {
      return 0;
    }

    final updatedApp = app.copyWith(
      isDeleted: true,
    );

    return await updateRestrictedApp(updatedApp);
  }

// ポモドーロセッションの論理削除
  Future<int> softDeletePomodoroSession(int id) async {
    final db = await database;

    try {
      // 対象のセッションを取得
      final results = await db.query(
        'pomodoro_sessions',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (results.isEmpty) {
        return 0;
      }

      final session = PomodoroSession.fromMap(results.first);

      // 論理削除状態に更新
      final updatedSession = session.copyWith(
        isDeleted: true,
        updatedAt: DateTime.now(),
      );

      // 更新を実行
      return await db.update(
        'pomodoro_sessions',
        updatedSession.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('ポモドーロセッション論理削除エラー: $e');
      return 0;
    }
  }

  Future<String> _getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');

      if (deviceId == null) {
        // デバイスIDがない場合は新規作成
        final uuid = Uuid();
        deviceId = uuid.v4();
        await prefs.setString('device_id', deviceId);
      }

      return deviceId;
    } catch (e) {
      print('デバイスID取得エラー: $e');
      // エラー時は一時的なIDを返す
      return 'temp_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  // 表示用の制限アプリリストを取得（未知のアプリをフィルタリング）
  Future<List<RestrictedApp>> getDisplayableRestrictedApps() async {
    final allApps = await getRestrictedApps();

    // 現在のデバイスに存在するアプリ、または現在のデバイスで作成されたアプリのみ表示
    final String deviceId = await _getDeviceId();

    return allApps
        .where((app) => app.isAvailableLocally == true
            //|| app.deviceId == deviceId
            )
        .toList();
  }

// セッション履歴表示用のクエリ（削除されたタスクの情報も含む）
  Future<List<Map<String, dynamic>>> getSessionHistoryWithTaskInfo() async {
    final db = await database;

    return await db.rawQuery('''
    SELECT 
      ps.id,
      ps.taskId,
      ps.startTime,
      ps.endTime,
      ps.durationMinutes,
      ps.completed,
      ps.focusScore,
      ps.timeOfDay,
      ps.interruptionCount,
      ps.mood,
      ps.isBreak,
      ps.isDeleted,
      t.name as taskName,
      t.category as taskCategory,
      t.isDeleted as taskIsDeleted
    FROM pomodoro_sessions ps
    LEFT JOIN tasks t ON ps.taskId = t.id
    WHERE ps.isDeleted = 0
    ORDER BY ps.startTime DESC
  ''');
  }

// 重複した制限アプリを整理するメソッド
  Future<void> removeDuplicateRestrictedApps() async {
    final db = await database;

    // 1. 重複を特定（同じ実行パスを持つアプリ）
    final duplicates = await db.rawQuery('''
    SELECT executable_path
    FROM restricted_apps
    WHERE is_deleted = 0
    GROUP BY executable_path
    HAVING COUNT(*) > 1
  ''');

    // 2. 各重複セットで、最新のものを残して他を論理削除
    for (var dup in duplicates) {
      final path = dup['executable_path'];
      final apps = await db.query('restricted_apps',
          where: 'executable_path = ? AND is_deleted = 0',
          whereArgs: [path],
          orderBy: 'id DESC');

      // 最新の1件を除いて他を論理削除
      for (int i = 1; i < apps.length; i++) {
        await db.update('restricted_apps', {'is_deleted': 1},
            where: 'id = ?', whereArgs: [apps[i]['id']]);
      }
    }
  }

// テスト用データを生成して追加する
  Future<void> addTestData(int count) async {
    final db = await database;
    final batch = db.batch();

    // 現在の日付から逆算して過去のデータを作成
    final now = DateTime.now();
    final random = Random();

    // テスト用のタスクを作成（存在しない場合）
    int taskId = -1;
    final testTasks = await db.query(
      'tasks',
      where: 'name = ?',
      whereArgs: ['テスト用タスク'],
    );

    if (testTasks.isEmpty) {
      taskId = await db.insert('tasks', {
        'name': 'テスト用タスク',
        'category': 'テスト',
        'description': 'テスト用に自動生成されたタスクです',
        'estimatedPomodoros': 20,
        'completedPomodoros': 0,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      });
    } else {
      taskId = testTasks.first['id'] as int;
    }

    // ポモドーロセッションを追加
    for (int i = 0; i < count; i++) {
      // 過去のランダムな日付を設定（最大90日前まで）
      final daysAgo = random.nextInt(90);
      final sessionDate = now.subtract(Duration(days: daysAgo));

      // 時間はランダム
      final hour = random.nextInt(24);
      final minute = random.nextInt(60);
      final startTime = DateTime(
        sessionDate.year,
        sessionDate.month,
        sessionDate.day,
        hour,
        minute,
      );

      // 25分後の終了時間
      final endTime = startTime.add(const Duration(minutes: 25));

      // 時間帯に応じたtimeOfDayを設定
      String timeOfDay;
      if (hour >= 5 && hour < 8) {
        timeOfDay = 'morning';
      } else if (hour >= 8 && hour < 12) {
        timeOfDay = 'forenoon';
      } else if (hour >= 12 && hour < 17) {
        timeOfDay = 'afternoon';
      } else if (hour >= 17 && hour < 20) {
        timeOfDay = 'evening';
      } else if (hour >= 20) {
        timeOfDay = 'night';
      } else {
        timeOfDay = 'midnight';
      }

      // 集中度はランダム（70〜100%）
      final focusScore = 70.0 + random.nextDouble() * 30.0;

      // 中断回数はランダム（0〜3回）
      final interruptionCount = random.nextInt(4);

      // 気分はランダム
      final moods = ['great', 'good', 'neutral', 'tired', 'frustrated'];
      final mood = moods[random.nextInt(moods.length)];

      // セッションデータを作成
      batch.insert('pomodoro_sessions', {
        'taskId': taskId,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'durationMinutes': 25,
        'completed': 1,
        'focusScore': focusScore,
        'timeOfDay': timeOfDay,
        'interruptionCount': interruptionCount,
        'mood': mood,
        'isBreak': 0,
      });
    }

    // バッチ処理を実行
    await batch.commit(noResult: true);

    // タスクの完了ポモドーロ数を更新
    final sessions = await db.query(
      'pomodoro_sessions',
      where: 'taskId = ?',
      whereArgs: [taskId],
    );

    await db.update(
      'tasks',
      {'completedPomodoros': sessions.length},
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

// テスト用データを削除する
  Future<int> deleteTestData() async {
    final db = await database;

    // テスト用タスクを検索
    final testTasks = await db.query(
      'tasks',
      where: 'name = ?',
      whereArgs: ['テスト用タスク'],
    );

    if (testTasks.isEmpty) {
      return 0; // テスト用タスクがなければ何もしない
    }

    final taskId = testTasks.first['id'] as int;

    // このタスクに関連するポモドーロセッションを削除
    final deletedSessions = await db.delete(
      'pomodoro_sessions',
      where: 'taskId = ?',
      whereArgs: [taskId],
    );

    // テスト用タスク自体も削除
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [taskId],
    );

    return deletedSessions; // 削除したセッション数を返す
  }

// デバッグ用に制限アプリテーブル内容を表示
  Future<void> debugPrintRestrictedApps() async {
    final db = await database;
    final results = await db.query('restricted_apps');

    print("=== 制限アプリテーブル内容 ===");
    print("件数: ${results.length}");

    for (var row in results) {
      print("------------------------------");
      print("ID: ${row['id']}");
      print("名前: ${row['name']}");
      print("パス: ${row['executablePath']}");
      print("制限状態: ${row['isRestricted']}");
      print("ポモドーロ: ${row['requiredPomodorosToUnlock']}");
      print("ポイント/時間: ${row['pointCostPerHour']}");
      print("分/ポイント: ${row['minutesPerPoint']}");
    }
    print("==============================");
  }

  // データベースの内容をデバッグ出力するメソッド
  Future<void> debugPrintDatabaseContent() async {
    final db = await database;

    // データベース内のすべてのテーブルを取得
    final tablesResult = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'");

    final tables =
        tablesResult.map((table) => table['name'] as String).toList();

    print("\n===== DATABASE DEBUG INFORMATION =====");
    print("Database path: ${db.path}");
    print("Tables found: ${tables.length}");

    // 各テーブルの内容を出力
    for (final tableName in tables) {
      try {
        // テーブルのスキーマを表示
        final tableInfoResult =
            await db.rawQuery("PRAGMA table_info($tableName)");
        final columns = tableInfoResult
            .map((col) => "${col['name']} (${col['type']})")
            .join(', ');

        print("\n----- TABLE: $tableName -----");
        print("COLUMNS: $columns");

        // テーブルの行数を取得
        final countResult =
            await db.rawQuery("SELECT COUNT(*) as count FROM $tableName");
        final rowCount = countResult.first['count'] as int;
        print("ROW COUNT: $rowCount");

        // データが存在する場合は先頭10行を表示
        if (rowCount > 0) {
          final rows = await db.query(tableName, limit: 10);
          print("\nSAMPLE DATA (up to 10 rows):");
          for (var i = 0; i < rows.length; i++) {
            print("Row $i: ${_formatRow(rows[i])}");
          }

          if (rowCount > 10) {
            print("... and ${rowCount - 10} more rows");
          }
        } else {
          print("\nNO DATA in this table");
        }
      } catch (e) {
        print("ERROR reading table $tableName: $e");
      }
    }

    print("\n===== END OF DATABASE DEBUG =====");
  }

// マップの内容を読みやすくフォーマットするヘルパーメソッド
  String _formatRow(Map<String, dynamic> row) {
    return row.entries.map((entry) {
      // 長い値は省略
      final value = entry.value?.toString() ?? 'null';
      final displayValue =
          value.length > 100 ? '${value.substring(0, 97)}...' : value;
      return '${entry.key}: $displayValue';
    }).join(', ');
  }
}
