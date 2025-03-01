// models/reward_point.dart
class RewardPoint {
  final int? id;
  final int earnedPoints;
  final int usedPoints;
  final DateTime lastUpdated;

  RewardPoint({
    this.id,
    required this.earnedPoints,
    required this.usedPoints,
    required this.lastUpdated,
  });

  int get availablePoints => earnedPoints - usedPoints;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'earnedPoints': earnedPoints,
      'usedPoints': usedPoints,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory RewardPoint.fromMap(Map<String, dynamic> map) {
    return RewardPoint(
      id: map['id'],
      earnedPoints: map['earnedPoints'],
      usedPoints: map['usedPoints'],
      lastUpdated: DateTime.parse(map['lastUpdated']),
    );
  }

  RewardPoint copyWith({
    int? id,
    int? earnedPoints,
    int? usedPoints,
    DateTime? lastUpdated,
  }) {
    return RewardPoint(
      id: id ?? this.id,
      earnedPoints: earnedPoints ?? this.earnedPoints,
      usedPoints: usedPoints ?? this.usedPoints,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
