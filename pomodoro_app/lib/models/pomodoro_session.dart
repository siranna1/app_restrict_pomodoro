// models/pomodoro_session.dart - ポモドーロセッションモデル
class PomodoroSession {
  final int? id;
  int taskId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final bool completed;
  final double focusScore;
  final String?
      timeOfDay; // 時間帯カテゴリ (morning, forenoon, afternoon, evening, night, midnight)
  final int interruptionCount; // 中断・邪魔が入った回数
  final String? mood; // セッション後の気分 (great, good, neutral, tired, frustrated)
  final bool isBreak; // 休憩セッションかどうか
  String? firebaseId;
  String? firebaseTaskId;

  PomodoroSession({
    this.id,
    required this.taskId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.completed = true,
    this.focusScore = 100.0,
    this.timeOfDay,
    this.interruptionCount = 0,
    this.mood,
    this.isBreak = false,
    this.firebaseId,
    this.firebaseTaskId,
  });

  // 時間帯を自動的に設定するファクトリコンストラクタ
  factory PomodoroSession.withTimeOfDay({
    int? id,
    required int taskId,
    required DateTime startTime,
    required DateTime endTime,
    required int durationMinutes,
    bool completed = true,
    double focusScore = 100.0,
    int interruptionCount = 0,
    String? mood,
    bool isBreak = false,
  }) {
    // 開始時間に基づいて時間帯を自動判定
    final hour = startTime.hour;
    String timeOfDay;

    if (hour >= 5 && hour < 8) {
      timeOfDay = 'morning'; // 早朝 (5-8時)
    } else if (hour >= 8 && hour < 12) {
      timeOfDay = 'forenoon'; // 午前 (8-12時)
    } else if (hour >= 12 && hour < 17) {
      timeOfDay = 'afternoon'; // 午後 (12-17時)
    } else if (hour >= 17 && hour < 20) {
      timeOfDay = 'evening'; // 夕方 (17-20時)
    } else if (hour >= 20 && hour < 24) {
      timeOfDay = 'night'; // 夜間 (20-24時)
    } else {
      timeOfDay = 'midnight'; // 深夜 (0-5時)
    }

    return PomodoroSession(
      id: id,
      taskId: taskId,
      startTime: startTime,
      endTime: endTime,
      durationMinutes: durationMinutes,
      completed: completed,
      focusScore: focusScore,
      timeOfDay: timeOfDay,
      interruptionCount: interruptionCount,
      mood: mood,
      isBreak: isBreak,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'completed': completed ? 1 : 0,
      'focusScore': focusScore,
      'timeOfDay': timeOfDay,
      'interruptionCount': interruptionCount,
      'mood': mood,
      'isBreak': isBreak ? 1 : 0,
      'firebaseId': firebaseId,
    };
  }

  factory PomodoroSession.fromMap(Map<String, dynamic> map) {
    return PomodoroSession(
      id: map['id'],
      taskId: map['taskId'],
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      durationMinutes: map['durationMinutes'],
      completed: map['completed'] == 1,
      focusScore: map['focusScore'],
      timeOfDay: map['timeOfDay'],
      interruptionCount: map['interruptionCount'] ?? 0,
      mood: map['mood'],
      isBreak: map['isBreak'] == 1,
      firebaseId: map['firebaseId'],
    );
  }
  // コピーメソッド
  PomodoroSession copyWith({
    int? id,
    int? taskId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    bool? completed,
    double? focusScore,
    String? timeOfDay,
    int? interruptionCount,
    String? mood,
    bool? isBreak,
    String? firebaseId,
  }) {
    return PomodoroSession(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      completed: completed ?? this.completed,
      focusScore: focusScore ?? this.focusScore,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      interruptionCount: interruptionCount ?? this.interruptionCount,
      mood: mood ?? this.mood,
      isBreak: isBreak ?? this.isBreak,
      firebaseId: firebaseId ?? this.firebaseId,
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'taskId': firebaseTaskId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'completed': completed,
      'focusScore': focusScore,
      'timeOfDay': timeOfDay,
      'interruptionCount': interruptionCount,
      'mood': mood,
      'isBreak': isBreak,
    };
  }

  factory PomodoroSession.fromFirebase(Map<String, dynamic> data) {
    return PomodoroSession(
      taskId: 0, // 仮の値。あとで正しいタスクIDに更新する
      startTime: DateTime.parse(data['startTime']),
      endTime: DateTime.parse(data['endTime']),
      durationMinutes: data['durationMinutes'],
      completed: data['completed'],
      focusScore: data['focusScore'].toDouble(),
      timeOfDay: data['timeOfDay'],
      interruptionCount: data['interruptionCount'],
      mood: data['mood'],
      isBreak: data['isBreak'],
      firebaseTaskId: data['firebaseTaskId'],
    );
  }
}
