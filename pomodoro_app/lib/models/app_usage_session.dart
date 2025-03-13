// models/app_usage_session.dart
class AppUsageSession {
  final int? id;
  int appId;
  final DateTime startTime;
  final DateTime endTime;
  final int pointsSpent;
  String? firebaseId;
  String? appName; // アプリ名を追加
  String? appPath; // 実行ファイルパスを追加
  int? remoteAppId; // リモートの制限アプリID（別デバイスとの整合用）
  AppUsageSession({
    this.id,
    required this.appId,
    required this.startTime,
    required this.endTime,
    required this.pointsSpent,
    this.firebaseId,
    this.appName,
    this.appPath,
    this.remoteAppId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appId': appId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'pointsSpent': pointsSpent,
      'firebaseId': firebaseId,
      'appName': appName,
      'appPath': appPath,
      'remoteAppId': remoteAppId,
    };
  }

  factory AppUsageSession.fromMap(Map<String, dynamic> map) {
    return AppUsageSession(
      id: map['id'],
      appId: map['appId'],
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      pointsSpent: map['pointsSpent'],
      firebaseId: map['firebaseId'],
      appName: map['appName'],
      appPath: map['appPath'],
      remoteAppId: map['remoteAppId'],
    );
  }
  Map<String, dynamic> toFirebase() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'pointsSpent': pointsSpent,
      'appName': appName, // アプリ名を含める
      'appPath': appPath, // パスも含める
      'remoteAppId': appId, // 現在のデバイスでのIDをリモートIDとして保存
    };
  }

  factory AppUsageSession.fromFirebase(Map<String, dynamic> data) {
    return AppUsageSession(
      appId: 0, // 初期値（後で適切なIDに更新する）
      startTime: DateTime.parse(data['startTime']),
      endTime: DateTime.parse(data['endTime']),
      pointsSpent: data['pointsSpent'],
      appName: data['appName'],
      appPath: data['appPath'],
      remoteAppId: data['remoteAppId'],
    );
  }
  AppUsageSession copyWith({
    int? id,
    int? appId,
    DateTime? startTime,
    DateTime? endTime,
    int? pointsSpent,
    String? firebaseId,
    String? appName,
    String? appPath,
    int? remoteAppId,
  }) {
    return AppUsageSession(
      id: id ?? this.id,
      appId: appId ?? this.appId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      pointsSpent: pointsSpent ?? this.pointsSpent,
      firebaseId: firebaseId ?? this.firebaseId,
      appName: appName ?? this.appName,
      appPath: appPath ?? this.appPath,
      remoteAppId: remoteAppId ?? this.remoteAppId,
    );
  }
}
