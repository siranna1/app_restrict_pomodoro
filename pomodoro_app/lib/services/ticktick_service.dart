// ticktick_service.dart の修正

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class TickTickService {
  static final TickTickService _instance = TickTickService._internal();
  factory TickTickService() => _instance;

  TickTickService._internal();

  // TickTick API エンドポイント
  static const String _baseUrl = 'https://api.ticktick.com/open/v1';
  static const String _authUrl = 'https://ticktick.com/oauth/token';

  // アクセストークン
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  // プロジェクト情報のキャッシュ
  Map<String, String> _projectIdToNameMap = {};

  // APIキー情報を環境変数や設定から読み込む
  static String _clientId = "qd8SNKwQ9Z7eY6rBg6";
  static String _clientSecret = "ugZ9Rh*tiitPi9YZk_g++X@K&s769(86)";

  // 初期化
  Future<void> initialize() async {
    await _loadTokens();
  }

  // 保存されたトークンを読み込み
  Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('ticktick_access_token');
    _refreshToken = prefs.getString('ticktick_refresh_token');

    final expiryMs = prefs.getInt('ticktick_token_expiry');
    if (expiryMs != null) {
      _tokenExpiry = DateTime.fromMillisecondsSinceEpoch(expiryMs);
    }
  }

  // トークンを保存
  Future<void> _saveTokens() async {
    final prefs = await SharedPreferences.getInstance();

    if (_accessToken != null) {
      await prefs.setString('ticktick_access_token', _accessToken!);
    }

    if (_refreshToken != null) {
      await prefs.setString('ticktick_refresh_token', _refreshToken!);
    }

    if (_tokenExpiry != null) {
      await prefs.setInt(
        'ticktick_token_expiry',
        _tokenExpiry!.millisecondsSinceEpoch,
      );
    }
  }

  // 認証状態をチェック
  bool get isAuthenticated {
    if (_accessToken == null || _tokenExpiry == null) {
      return false;
    }

    // トークンの有効期限をチェック
    final now = DateTime.now();
    return now.isBefore(_tokenExpiry!);
  }

  // OAuth2認証フロー（認証コードフロー）
  Future<bool> authenticate(String authCode) async {
    try {
      print('TickTick認証開始: コード=$authCode');
      final response = await http.post(
        Uri.parse(_authUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': authCode,
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'redirect_uri':
              'https://script.google.com/macros/s/AKfycbxkOp3zrER5DR5nwVIzvc4TPkr0MfIRHQAimKMsVv2IdlPz_cSsBJ1hMLI_-H5P3LGF7A/exec',
        },
      );

      print('認証レスポンス: ${response.statusCode}');
      print('レスポンス本文: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];

        // トークンの有効期限を設定（通常は1時間）
        final expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        await _saveTokens();
        print('認証成功: トークン=${_accessToken?.substring(0, 10)}...');
        return true;
      }

      print('認証失敗: ステータスコード=${response.statusCode}');
      return false;
    } catch (e) {
      print('TickTick認証エラー: $e');
      return false;
    }
  }

  // アクセストークンをリフレッシュ
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) {
      print('リフレッシュトークンがありません');
      return false;
    }

    try {
      print('アクセストークンをリフレッシュ中...');
      final response = await http.post(
        Uri.parse(_authUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': _refreshToken,
          'client_id': _clientId,
          'client_secret': _clientSecret,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];

        // トークンの有効期限を更新
        final expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        await _saveTokens();
        print('トークンリフレッシュ成功');
        return true;
      }

      print('トークンリフレッシュ失敗: ${response.statusCode}');
      return false;
    } catch (e) {
      print('TickTickトークンリフレッシュエラー: $e');
      return false;
    }
  }

  // APIリクエストの共通処理
  Future<http.Response?> _apiRequest(String method, String endpoint,
      {Map<String, dynamic>? body}) async {
    if (!isAuthenticated) {
      print('認証が必要です');
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        print('トークンのリフレッシュに失敗しました');
        return null;
      }
    }

    final url = Uri.parse('$_baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

    print('APIリクエスト: $method $url');

    http.Response response;

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      print('APIレスポンス: ${response.statusCode}');

      // トークンの有効期限切れの場合は再認証
      if (response.statusCode == 401) {
        print('認証エラー (401) - トークンをリフレッシュします');
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          return _apiRequest(method, endpoint, body: body);
        }
        return null;
      }

      return response;
    } catch (e) {
      print('TickTick APIリクエストエラー: $e');
      return null;
    }
  }

  // タスクリストを取得
  Future<List<Task>> fetchTasks() async {
    try {
      // プロジェクト一覧を取得
      print('TickTickプロジェクト一覧を取得中...');
      final projectsResponse = await _apiRequest('GET', '/project');

      if (projectsResponse == null || projectsResponse.statusCode != 200) {
        print('TickTick プロジェクト取得エラー: ${projectsResponse?.statusCode}');
        if (projectsResponse != null) {
          print('レスポンス本文: ${projectsResponse.body}');
        }
        return [];
      }

      final projectsData = jsonDecode(projectsResponse.body);
      print('TickTick プロジェクト数: ${projectsData.length}');

      // プロジェクト情報をキャッシュ
      _projectIdToNameMap.clear();
      if (projectsData is List) {
        for (var project in projectsData) {
          final projectId = project['id'];
          final projectName = project['name'];
          _projectIdToNameMap[projectId] = projectName;
        }
      }

      List<Task> allTasks = [];

      // 各プロジェクトからタスクを取得
      if (projectsData is List) {
        for (var project in projectsData) {
          final projectId = project['id'];
          final projectName = project['name'];

          print('プロジェクト「$projectName」のタスクを取得中...');

          // プロジェクトごとのデータを取得（タスクを含む）
          final projectDataResponse =
              await _apiRequest('GET', '/project/$projectId/data');

          if (projectDataResponse != null &&
              projectDataResponse.statusCode == 200) {
            final projectData = jsonDecode(projectDataResponse.body);

            if (projectData.containsKey('tasks') &&
                projectData['tasks'] is List) {
              final tasksList = projectData['tasks'] as List;
              print('プロジェクト「$projectName」のタスク数: ${tasksList.length}');

              for (var taskData in tasksList) {
                // ステータスを確認（完了していないタスクのみ取得）
                final status = taskData['status'] as int? ?? 0;
                if (status != 2) {
                  // 2は完了済みタスク
                  // プロジェクト名とIDを使用してタスクを作成
                  allTasks.add(
                      _mapTickTickTaskToTask(taskData, projectName, projectId));
                }
              }
            }
          } else {
            print(
                'プロジェクト「$projectName」のデータ取得エラー: ${projectDataResponse?.statusCode}');
            if (projectDataResponse != null) {
              print('レスポンス本文: ${projectDataResponse.body}');
            }
          }
        }
      }

      print('取得したタスク総数: ${allTasks.length}');
      return allTasks;
    } catch (e) {
      print('TickTick タスク取得エラー: $e');
      return [];
    }
  }

  // TickTickのタスクをアプリのタスクモデルに変換
  Task _mapTickTickTaskToTask(
      Map<String, dynamic> tickTickTask, String projectName, String projectId) {
    // タスクのタイトルと説明を取得
    final title = tickTickTask['title'] ?? '';
    final description = tickTickTask['content'] ?? '';
    final tickTickTaskId = tickTickTask['id'] as String?;

    // カテゴリとしてプロジェクト名を使用
    final category = projectName;

    // ポモドーロ数の見積もり（優先度から判断など）
    final priority = tickTickTask['priority'] as int? ?? 0;
    int estimatedPomodoros = 1; // デフォルト

    // 優先度に基づいてポモドーロ数を推定
    // 0:なし、1:低、3:中、5:高
    if (priority == 5) {
      estimatedPomodoros = 4; // 高優先度
    } else if (priority == 3) {
      estimatedPomodoros = 2; // 中優先度
    }

    return Task(
      name: title,
      category: category,
      description: description,
      estimatedPomodoros: estimatedPomodoros,
      completedPomodoros: 0, // 初期値
      tickTickId: tickTickTaskId,
    );
  }

  // タスク完了をTickTickに報告
  Future<bool> completeTask(String tickTickId) async {
    if (!isAuthenticated) {
      print('認証されていないため、タスク完了を記録できません');
      return false;
    }

    try {
      // プロジェクト一覧を取得
      final projectsResponse = await _apiRequest('GET', '/project');
      if (projectsResponse == null || projectsResponse.statusCode != 200) {
        print('プロジェクト取得エラー: タスク完了を記録できません');
        return false;
      }

      final projectsData = jsonDecode(projectsResponse.body);

      // 各プロジェクトを調べてタスクを検索
      if (projectsData is List) {
        for (var project in projectsData) {
          final projectId = project['id'];

          // プロジェクト内のタスクを取得
          final projectDataResponse =
              await _apiRequest('GET', '/project/$projectId/data');

          if (projectDataResponse != null &&
              projectDataResponse.statusCode == 200) {
            final projectData = jsonDecode(projectDataResponse.body);

            if (projectData.containsKey('tasks') &&
                projectData['tasks'] is List) {
              final tasksList = projectData['tasks'] as List;

              // タスクIDが一致するタスクを探す
              for (var taskData in tasksList) {
                if (taskData['id'] == tickTickId) {
                  // タスクを完了としてマーク
                  print('タスク $tickTickId を完了としてマーク...');
                  final response = await _apiRequest(
                    'POST',
                    '/project/$projectId/task/$tickTickId/complete',
                  );

                  if (response != null && response.statusCode == 200) {
                    print('タスク完了が正常に記録されました');
                    return true;
                  } else {
                    print('タスク完了の記録に失敗: ${response?.statusCode}');
                    return false;
                  }
                }
              }
            }
          }
        }
      }

      print('指定されたID $tickTickId のタスクが見つかりませんでした');
      return false;
    } catch (e) {
      print('TickTick タスク完了エラー: $e');
      return false;
    }
  }

// プロジェクト一覧を取得
  Future<List<Map<String, dynamic>>> getProjects() async {
    try {
      print('TickTickプロジェクト一覧を取得中...');
      final projectsResponse = await _apiRequest('GET', '/project');

      if (projectsResponse == null || projectsResponse.statusCode != 200) {
        print('TickTick プロジェクト取得エラー: ${projectsResponse?.statusCode}');
        return [];
      }

      final projectsData = jsonDecode(projectsResponse.body);

      // プロジェクト情報をキャッシュ
      _projectIdToNameMap.clear();
      if (projectsData is List) {
        for (var project in projectsData) {
          final projectId = project['id'];
          final projectName = project['name'];
          _projectIdToNameMap[projectId] = projectName;
        }

        return List<Map<String, dynamic>>.from(projectsData);
      }

      return [];
    } catch (e) {
      print('TickTick プロジェクト取得エラー: $e');
      return [];
    }
  }

// 特定のプロジェクトからタスクを取得
  Future<List<Task>> fetchTasksFromProject(
      String projectId, String projectName) async {
    try {
      print('プロジェクト「$projectName」のタスクを取得中...');

      // プロジェクトごとのデータを取得（タスクを含む）
      final projectDataResponse =
          await _apiRequest('GET', '/project/$projectId/data');

      if (projectDataResponse == null ||
          projectDataResponse.statusCode != 200) {
        print(
            'プロジェクト「$projectName」のデータ取得エラー: ${projectDataResponse?.statusCode}');
        return [];
      }

      final projectData = jsonDecode(projectDataResponse.body);
      List<Task> tasks = [];

      if (projectData.containsKey('tasks') && projectData['tasks'] is List) {
        final tasksList = projectData['tasks'] as List;
        print('プロジェクト「$projectName」のタスク数: ${tasksList.length}');

        for (var taskData in tasksList) {
          // ステータスを確認（完了していないタスクのみ取得）
          final status = taskData['status'] as int? ?? 0;
          if (status != 2) {
            // 2は完了済みタスク
            // プロジェクト名とIDを使用してタスクを作成
            tasks.add(_mapTickTickTaskToTask(taskData, projectName, projectId));
          }
        }
      }

      return tasks;
    } catch (e) {
      print('TickTick プロジェクトタスク取得エラー: $e');
      return [];
    }
  }

  // TickTickからタスクをインポート
  Future<List<Task>> importTasksFromTickTick() async {
    return await fetchTasks();
  }
}
