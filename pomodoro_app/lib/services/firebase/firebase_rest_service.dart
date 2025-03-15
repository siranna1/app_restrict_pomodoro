// lib/services/firebase/firebase_rest_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';
import '../../models/task.dart';
import '../../models/pomodoro_session.dart';
import '../../models/reward_point.dart';
import '../../models/app_usage_session.dart';
import '../../models/restricted_app.dart';
import '../firebase/auth_service.dart';
import '../../utils/platform_utils.dart';

/// Windowsプラットフォーム用のFirebase Realtime DatabaseへのREST API実装
class FirebaseRestService {
  final AuthService _authService;
  final String _databaseUrl;

  FirebaseRestService({
    required AuthService authService,
    required String databaseUrl,
  })  : _authService = authService,
        _databaseUrl = databaseUrl;

  /// REST API経由でデータを取得
  Future<Map<String, dynamic>?> getData(String path) async {
    try {
      // 認証トークンを取得
      final String? idToken = await _authService.getCurrentUserIdToken();
      if (idToken == null) {
        print('FirebaseRestService: User not authenticated');
        return null;
      }

      // REST APIエンドポイントを構築
      final url = '$_databaseUrl/$path.json?auth=$idToken';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (response.body == 'null') return null; // 空のデータの場合

        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        print(
            'FirebaseRestService: Failed to get data: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('FirebaseRestService: Error getting data: $e');
      return null;
    }
  }

  /// REST API経由でデータを保存 (PUT)
  Future<bool> saveData(String path, Map<String, dynamic> data) async {
    try {
      final String? idToken = await _authService.getCurrentUserIdToken();
      if (idToken == null) {
        print('FirebaseRestService: User not authenticated');
        return false;
      }

      final url = '$_databaseUrl/$path.json?auth=$idToken';

      final response = await http.put(
        Uri.parse(url),
        body: json.encode(data),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print(
            'FirebaseRestService: Failed to save data: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('FirebaseRestService: Error saving data: $e');
      return false;
    }
  }

  /// REST API経由でデータを更新 (PATCH)
  Future<bool> updateData(String path, Map<String, dynamic> data) async {
    try {
      final String? idToken = await _authService.getCurrentUserIdToken();
      if (idToken == null) {
        print('FirebaseRestService: User not authenticated');
        return false;
      }

      final url = '$_databaseUrl/$path.json?auth=$idToken';

      final response = await http.patch(
        Uri.parse(url),
        body: json.encode(data),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print(
            'FirebaseRestService: Failed to update data: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('FirebaseRestService: Error updating data: $e');
      return false;
    }
  }

  /// REST API経由でデータを削除
  Future<bool> deleteData(String path) async {
    try {
      final String? idToken = await _authService.getCurrentUserIdToken();
      if (idToken == null) {
        print('FirebaseRestService: User not authenticated');
        return false;
      }

      final url = '$_databaseUrl/$path.json?auth=$idToken';

      final response = await http.delete(Uri.parse(url));

      if (response.statusCode == 200) {
        return true;
      } else {
        print(
            'FirebaseRestService: Failed to delete data: ${response.statusCode}');
        print('Response body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('FirebaseRestService: Error deleting data: $e');
      return false;
    }
  }

  /// REST API経由でデータを保存 (POST - 一意のキーを生成)
  Future<String?> pushData(String path, Map<String, dynamic> data) async {
    try {
      final String? idToken = await _authService.getCurrentUserIdToken();
      if (idToken == null) {
        print('FirebaseRestService: User not authenticated');
        return null;
      }

      final url = '$_databaseUrl/$path.json?auth=$idToken';

      final response = await http.post(
        Uri.parse(url),
        body: json.encode(data),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['name'] as String; // Firebaseが生成した一意のキー
      } else {
        print(
            'FirebaseRestService: Failed to push data: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('FirebaseRestService: Error pushing data: $e');
      return null;
    }
  }

  /// 特定の日時以降のタスクを取得
  Future<Map<String, dynamic>?> getTasksChangedSince(
      String userId, DateTime? timestamp) async {
    try {
      //final timestampMs = timestamp.millisecondsSinceEpoch;
      // Firebase REST APIでは時間でのフィルタリングがやや複雑なため、
      // すべてのタスクを取得してクライアント側でフィルタリングする方が簡単
      return await getData('users/$userId/tasks');
    } catch (e) {
      print('FirebaseRestService: Error getting tasks: $e');
      return null;
    }
  }

  /// 特定の日時以降のセッションを取得
  Future<Map<String, dynamic>?> getSessionsChangedSince(
      String userId, DateTime? timestamp) async {
    try {
      //final timestampMs = timestamp.millisecondsSinceEpoch;
      // Firebase REST APIでは時間でのフィルタリングがやや複雑なため、
      // すべてのセッションを取得してクライアント側でフィルタリングする方が簡単
      return await getData('users/$userId/pomodoro_sessions');
    } catch (e) {
      print('FirebaseRestService: Error getting sessions: $e');
      return null;
    }
  }

  /// ポイント情報を取得
  Future<Map<String, dynamic>?> getRewardPoints(String userId) async {
    try {
      return await getData('users/$userId/reward_points');
    } catch (e) {
      print('FirebaseRestService: Error getting reward points: $e');
      return null;
    }
  }

  /// 制限アプリ情報を取得
  Future<Map<String, dynamic>?> getRestrictedApps(String userId) async {
    try {
      return await getData('users/$userId/restricted_apps');
    } catch (e) {
      print('FirebaseRestService: Error getting restricted apps: $e');
      return null;
    }
  }

  /// アプリ使用セッション情報を取得
  Future<Map<String, dynamic>?> getAppUsageSessions(
      String userId, DateTime? timestamp) async {
    try {
      //final timestampMs = timestamp.millisecondsSinceEpoch;
      // Firebase REST APIでは時間でのフィルタリングがやや複雑なため、
      // すべてのセッションを取得してクライアント側でフィルタリングする方が簡単
      return await getData('users/$userId/app_usage_sessions');
    } catch (e) {
      print('FirebaseRestService: Error getting app usage sessions: $e');
      return null;
    }
  }

  /// タスク同期（保存または更新）
  Future<String?> syncTask(String userId, Task task) async {
    try {
      // FirebaseIDがある場合は更新、ない場合は新規作成
      if (task.firebaseId != null && task.firebaseId!.isNotEmpty) {
        final updated = await updateData(
          'users/$userId/tasks/${task.firebaseId}',
          task.toFirebase(),
        );
        return updated ? task.firebaseId : null;
      } else {
        // 新規作成
        return await pushData('users/$userId/tasks', task.toFirebase());
      }
    } catch (e) {
      print('FirebaseRestService: Error syncing task: $e');
      return null;
    }
  }

  /// セッション同期（保存または更新）
  Future<String?> syncSession(String userId, PomodoroSession session) async {
    try {
      // FirebaseIDがある場合は更新、ない場合は新規作成
      if (session.firebaseId != null && session.firebaseId!.isNotEmpty) {
        final updated = await updateData(
          'users/$userId/pomodoro_sessions/${session.firebaseId}',
          session.toFirebase(),
        );
        return updated ? session.firebaseId : null;
      } else {
        // 新規作成
        return await pushData(
            'users/$userId/pomodoro_sessions', session.toFirebase());
      }
    } catch (e) {
      print('FirebaseRestService: Error syncing session: $e');
      return null;
    }
  }

  /// 制限アプリ同期
  Future<String?> syncRestrictedApp(String userId, RestrictedApp app) async {
    try {
      if (app.firebaseId != null && app.firebaseId!.isNotEmpty) {
        final updated = await updateData(
          'users/$userId/restricted_apps/${app.firebaseId}',
          app.toFirebase(),
        );
        return updated ? app.firebaseId : null;
      } else {
        // 新規作成
        return await pushData(
            'users/$userId/restricted_apps', app.toFirebase());
      }
    } catch (e) {
      print('FirebaseRestService: Error syncing restricted app: $e');
      return null;
    }
  }

  /// ポイント同期
  Future<String?> syncRewardPoint(String userId, RewardPoint point) async {
    try {
      if (point.firebaseId != null && point.firebaseId!.isNotEmpty) {
        final updated = await updateData(
          'users/$userId/reward_points/${point.firebaseId}',
          //'users/$userId/reward_points',
          point.toFirebase(),
        );
        return updated ? point.firebaseId : null;
      } else {
        // 新規作成
        return await pushData(
            'users/$userId/reward_points', point.toFirebase());
      }
    } catch (e) {
      print('FirebaseRestService: Error syncing reward point: $e');
      return null;
    }
  }

  /// アプリ使用セッション同期
  Future<String?> syncAppUsageSession(
      String userId, AppUsageSession session) async {
    try {
      if (session.firebaseId != null && session.firebaseId!.isNotEmpty) {
        final updated = await updateData(
          'users/$userId/app_usage_sessions/${session.firebaseId}',
          session.toFirebase(),
        );
        return updated ? session.firebaseId : null;
      } else {
        // 新規作成
        return await pushData(
            'users/$userId/app_usage_sessions', session.toFirebase());
      }
    } catch (e) {
      print('FirebaseRestService: Error syncing app usage session: $e');
      return null;
    }
  }
}
