// firebase_rest_test.dart
import 'package:flutter/material.dart';
import 'package:pomodoro_app/services/firebase/auth_service.dart';
import 'package:pomodoro_app/services/firebase/firebase_rest_service.dart';
import 'package:pomodoro_app/models/task.dart';

/// Firebase REST APIの動作を確認するためのシンプルなテストウィジェット
class FirebaseRestTest extends StatefulWidget {
  const FirebaseRestTest({Key? key}) : super(key: key);

  @override
  _FirebaseRestTestState createState() => _FirebaseRestTestState();
}

class _FirebaseRestTestState extends State<FirebaseRestTest> {
  final AuthService _authService = AuthService();
  late FirebaseRestService _restService;

  bool _isLoading = false;
  String _resultMessage = '';
  String _errorMessage = '';

  // Firebase Realtime DBのURL
  final String _databaseUrl =
      'https://pomodoroappsync-default-rtdb.asia-southeast1.firebasedatabase.app';

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    setState(() {
      _isLoading = true;
      _resultMessage = '初期化中...';
    });

    try {
      // AuthServiceの初期化
      await _authService.initialize();

      // REST Serviceの初期化
      _restService = FirebaseRestService(
        authService: _authService,
        databaseUrl: _databaseUrl,
      );

      setState(() {
        _resultMessage = '初期化完了';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '初期化エラー: $e';
        _isLoading = false;
      });
    }
  }

  // テストデータの読み込み
  Future<void> _testReadData() async {
    if (!_authService.isUserLoggedIn) {
      setState(() {
        _errorMessage = 'ユーザーがログインしていません';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _resultMessage = 'データ読み込み中...';
      _errorMessage = '';
    });

    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        setState(() {
          _errorMessage = 'ユーザーIDが取得できません';
          _isLoading = false;
        });
        return;
      }

      // タスクデータの取得をテスト
      final tasksData = await _restService.getData('users/$userId/tasks');

      setState(() {
        if (tasksData != null) {
          _resultMessage = '読み込み成功: ${tasksData.length} 件のタスクを取得';
        } else {
          _resultMessage = '読み込み成功: タスクデータなし';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'データ読み込みエラー: $e';
        _isLoading = false;
      });
    }
  }

  // テストデータの書き込み
  Future<void> _testWriteData() async {
    if (!_authService.isUserLoggedIn) {
      setState(() {
        _errorMessage = 'ユーザーがログインしていません';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _resultMessage = 'データ書き込み中...';
      _errorMessage = '';
    });

    try {
      final userId = _authService.getCurrentUserId();
      if (userId == null) {
        setState(() {
          _errorMessage = 'ユーザーIDが取得できません';
          _isLoading = false;
        });
        return;
      }

      // テスト用タスクの作成
      final testTask = Task(
        name: 'REST APIテストタスク',
        category: 'テスト',
        description: 'REST API経由で作成されたテストタスク',
        estimatedPomodoros: 1,
        completedPomodoros: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // タスクの書き込みをテスト
      final newTaskKey = await _restService.pushData(
        'users/$userId/tasks',
        testTask.toFirebase(),
      );

      setState(() {
        if (newTaskKey != null) {
          _resultMessage = '書き込み成功: 新しいタスクID=$newTaskKey';
        } else {
          _resultMessage = '書き込み失敗';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'データ書き込みエラー: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase REST APIテスト'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ユーザー情報
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'ログイン状態: ${_authService.isUserLoggedIn ? "ログイン中" : "未ログイン"}'),
                    if (_authService.isUserLoggedIn)
                      Text('ユーザーメール: ${_authService.userEmail ?? "不明"}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // アクションボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _testReadData,
                  child: const Text('読み込みテスト'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _testWriteData,
                  child: const Text('書き込みテスト'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 結果表示
            if (_isLoading) const Center(child: CircularProgressIndicator()),

            if (_resultMessage.isNotEmpty)
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('結果:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_resultMessage),
                    ],
                  ),
                ),
              ),

            if (_errorMessage.isNotEmpty)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('エラー:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(_errorMessage),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
