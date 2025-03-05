// services/ticktick_service.dart - TickTick API連携サービス
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class TickTickService {
  static final TickTickService _instance = TickTickService._internal();
  factory TickTickService() => _instance;

  TickTickService._internal();

  // TickTick API エンドポイント
  static const String _baseUrl = 'https://api.ticktick.com/api/v2';
  static const String _authUrl = 'https://ticktick.com/oauth/token';

  // アクセストークン
  String? _accessToken;
  String? _refreshToken;
  DateTime? _tokenExpiry;

  // APIキー情報（本来は環境変数などで管理）
  // 注: 実際のアプリ開発では、クライアントIDとシークレットは安全に管理してください
// APIキー情報を環境変数や設定から読み込む
  //static String get _clientId =>
  //    const String.fromEnvironment('TICKTICK_CLIENT_ID', defaultValue: '');
  static String _clientId = "qd8SNKwQ9Z7eY6rBg6";
  //static String get _clientSecret =>
  //    const String.fromEnvironment('TICKTICK_CLIENT_SECRET', defaultValue: '');
  static String _clientSecret = "ugZ9Rh*tiitPi9YZk_g++X@K&s769(86";

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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];

        // トークンの有効期限を設定（通常は1時間）
        final expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        await _saveTokens();
        return true;
      }

      return false;
    } catch (e) {
      print('TickTick認証エラー: $e');
      return false;
    }
  }

  // アクセストークンをリフレッシュ
  Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) {
      return false;
    }

    try {
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
        return true;
      }

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
      final refreshed = await _refreshAccessToken();
      if (!refreshed) {
        return null;
      }
    }

    final url = Uri.parse('$_baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

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

      // トークンの有効期限切れの場合は再認証
      if (response.statusCode == 401) {
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
  Future<List<Task>?> fetchTasks() async {
    try {
      final response = await _apiRequest('GET', '/task');

      if (response == null || response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);

      if (data is List) {
        return data.map((item) => _mapTickTickTaskToTask(item)).toList();
      }

      return [];
    } catch (e) {
      print('TickTick タスク取得エラー: $e');
      return null;
    }
  }

  // TickTickのタスクをアプリのタスクモデルに変換
  Task _mapTickTickTaskToTask(Map<String, dynamic> tickTickTask) {
    return Task(
      name: tickTickTask['title'] ?? '',
      category: _extractCategoryFromTags(tickTickTask['tags']),
      description: tickTickTask['content'] ?? '',
      estimatedPomodoros: _extractEstimatedPomodorosFromTask(tickTickTask),
      completedPomodoros: 0, // TickTickにはこの情報がないため初期値を設定
      tickTickId: tickTickTask['id'],
    );
  }

  // タグからカテゴリを抽出（例: 最初のタグをカテゴリとして使用）
  String _extractCategoryFromTags(List<dynamic>? tags) {
    if (tags == null || tags.isEmpty) {
      return 'その他';
    }
    return tags[0].toString();
  }

  // タスクから予定ポモドーロ数を抽出（例: タイトルから「[P3]」のような形式で抽出）
  int _extractEstimatedPomodorosFromTask(Map<String, dynamic> task) {
    final title = task['title'] ?? '';
    final match = RegExp(r'\[P(\d+)\]').firstMatch(title);

    if (match != null && match.groupCount >= 1) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }

    // デフォルト値
    return 1;
  }

  // ポモドーロセッション完了をTickTickに記録
  Future<bool> recordPomodoroSession(Task task, int durationMinutes) async {
    if (task.tickTickId == null) {
      return false;
    }

    try {
      // TickTickのタスク詳細を取得
      final taskResponse = await _apiRequest(
        'GET',
        '/task/${task.tickTickId}',
      );

      if (taskResponse == null || taskResponse.statusCode != 200) {
        return false;
      }

      final taskData = jsonDecode(taskResponse.body);

      // ポモドーロ記録を追加
      final pomodoros = taskData['pomodoros'] ?? [];
      pomodoros.add({
        'duration': durationMinutes,
        'startTime': DateTime.now().toIso8601String(),
      });

      // タスクを更新
      final updateResponse = await _apiRequest(
        'PUT',
        '/task/${task.tickTickId}',
        body: {
          ...taskData,
          'pomodoros': pomodoros,
        },
      );

      return updateResponse != null && updateResponse.statusCode == 200;
    } catch (e) {
      print('TickTick ポモドーロ記録エラー: $e');
      return false;
    }
  }

  // タスク完了をTickTickに報告
  Future<bool> completeTask(String tickTickId) async {
    try {
      final response = await _apiRequest(
        'POST',
        '/task/$tickTickId/complete',
      );

      return response != null && response.statusCode == 200;
    } catch (e) {
      print('TickTick タスク完了エラー: $e');
      return false;
    }
  }

  // TickTickからタスクをインポート
  Future<List<Task>> importTasksFromTickTick() async {
    final tasks = await fetchTasks();
    return tasks ?? [];
  }
}
