// services/database_helper.dart - データベース管理
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task.dart';
import '../models/pomodoro_session.dart';
import '../models/restricted_app.dart';
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
      version: 1,
      onCreate: _createDB,
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
}
