// models/pomodoro_session.dart - ポモドーロセッションモデル
class PomodoroSession {
  final int? id;
  final int taskId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final bool completed;
  final double focusScore;

  PomodoroSession({
    this.id,
    required this.taskId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.completed = true,
    this.focusScore = 100.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'durationMinutes': durationMinutes,
      'completed': completed ? 1 : 0,
      'focusScore': focusScore,
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
    );
  }
}
