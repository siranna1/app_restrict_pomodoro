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
      version: 2,
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
        requiredPomodorosToUnlock INTEGER NOT NULL
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
    // RestrictedApps テーブルに新しいカラムを追加
    await db.execute('''
    ALTER TABLE restricted_apps ADD COLUMN pointCostPerHour INTEGER DEFAULT 2;
    ALTER TABLE restricted_apps ADD COLUMN minutesPerPoint INTEGER DEFAULT 30;
    ALTER TABLE restricted_apps ADD COLUMN currentSessionEnd TEXT;
  ''');
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
