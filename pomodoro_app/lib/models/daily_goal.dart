// models/daily_goal.dart - 日次目標モデル
class DailyGoal {
  final int? id;
  final DateTime date;
  final int targetPomodoros;
  final int achievedPomodoros;
  final bool achieved;

  DailyGoal({
    this.id,
    required this.date,
    required this.targetPomodoros,
    required this.achievedPomodoros,
    required this.achieved,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'targetPomodoros': targetPomodoros,
      'achievedPomodoros': achievedPomodoros,
      'achieved': achieved ? 1 : 0,
    };
  }

  factory DailyGoal.fromMap(Map<String, dynamic> map) {
    return DailyGoal(
      id: map['id'],
      date: DateTime.parse(map['date']),
      targetPomodoros: map['targetPomodoros'],
      achievedPomodoros: map['achievedPomodoros'],
      achieved: map['achieved'] == 1,
    );
  }

  DailyGoal copyWith({
    int? id,
    DateTime? date,
    int? targetPomodoros,
    int? achievedPomodoros,
    bool? achieved,
  }) {
    return DailyGoal(
      id: id ?? this.id,
      date: date ?? this.date,
      targetPomodoros: targetPomodoros ?? this.targetPomodoros,
      achievedPomodoros: achievedPomodoros ?? this.achievedPomodoros,
      achieved: achieved ?? this.achieved,
    );
  }
}
