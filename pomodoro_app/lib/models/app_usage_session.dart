// models/app_usage_session.dart
class AppUsageSession {
  final int? id;
  final int appId;
  final DateTime startTime;
  final DateTime endTime;
  final int pointsSpent;

  AppUsageSession({
    this.id,
    required this.appId,
    required this.startTime,
    required this.endTime,
    required this.pointsSpent,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appId': appId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'pointsSpent': pointsSpent,
    };
  }

  factory AppUsageSession.fromMap(Map<String, dynamic> map) {
    return AppUsageSession(
      id: map['id'],
      appId: map['appId'],
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      pointsSpent: map['pointsSpent'],
    );
  }
}
