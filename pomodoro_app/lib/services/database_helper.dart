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

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

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

    return await openDatabase(
      path,
      version: 3,
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
        tickTickId TEXT
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
        currentSessionEnd TEXT
      )
    ''');
    // ポイント管理用テーブル
    await db.execute('''
    CREATE TABLE reward_points (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      earnedPoints INTEGER NOT NULL,
      usedPoints INTEGER NOT NULL,
      lastUpdated TEXT NOT NULL
    )
  ''');

    await db.execute('''
    CREATE TABLE app_usage_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      appId INTEGER NOT NULL,
      startTime TEXT NOT NULL,
      endTime TEXT NOT NULL,
      pointsSpent INTEGER NOT NULL,
      FOREIGN KEY (appId) REFERENCES restricted_apps (id) ON DELETE CASCADE
    )
  ''');

    // 新しく追加するテーブル - 日次目標
    await db.execute('''
      CREATE TABLE daily_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        targetPomodoros INTEGER NOT NULL,
        achievedPomodoros INTEGER NOT NULL,
        achieved INTEGER NOT NULL
      )
    ''');
    // インデックスの作成（検索パフォーマンス向上のため）
    await db.execute(
        'CREATE INDEX idx_pomodoro_sessions_taskId ON pomodoro_sessions(taskId)');
    await db.execute(
        'CREATE INDEX idx_pomodoro_sessions_startTime ON pomodoro_sessions(startTime)');
    await db.execute('CREATE INDEX idx_daily_goals_date ON daily_goals(date)');
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

  Future<List<Task>> getTasks() async {
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
      orderBy: 'startTime DESC',
    );
    return results.map((map) => PomodoroSession.fromMap(map)).toList();
  }

  Future<List<PomodoroSession>> getTaskPomodoroSessions(int taskId) async {
    final db = await database;
    final results = await db.query(
      'pomodoro_sessions',
      where: 'taskId = ?',
      whereArgs: [taskId],
      orderBy: 'startTime DESC',
    );
    return results.map((map) => PomodoroSession.fromMap(map)).toList();
  }

  // 統計関連のメソッド
  Future<List<Map<String, dynamic>>> getDailyStatistics() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        date(startTime) as date,
        COUNT(*) as count,
        SUM(durationMinutes) as totalMinutes
      FROM pomodoro_sessions
      WHERE completed = 1
      GROUP BY date(startTime)
      ORDER BY date(startTime) DESC
      LIMIT 7
    ''');

    return results.reversed.toList();
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
    final results = await db.query(
      'app_usage_sessions',
      orderBy: 'startTime DESC',
    );
    return results.map((map) => AppUsageSession.fromMap(map)).toList();
  }
}
