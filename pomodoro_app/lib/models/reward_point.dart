// models/reward_point.dart
class RewardPoint {
  final int? id;
  final int earnedPoints;
  final int usedPoints;
  final DateTime lastUpdated;
  String? firebaseId;

  RewardPoint({
    this.id,
    required this.earnedPoints,
    required this.usedPoints,
    required this.lastUpdated,
    this.firebaseId,
  });

  int get availablePoints => earnedPoints - usedPoints;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'earnedPoints': earnedPoints,
      'usedPoints': usedPoints,
      'lastUpdated': lastUpdated.toIso8601String(),
      'firebaseId': firebaseId,
    };
  }

  factory RewardPoint.fromMap(Map<String, dynamic> map) {
    return RewardPoint(
      id: map['id'],
      earnedPoints: map['earnedPoints'],
      usedPoints: map['usedPoints'],
      lastUpdated: DateTime.parse(map['lastUpdated']),
      firebaseId: map['firebaseId'],
    );
  }

  // Firebase用のメソッド（エラー修正）
  Map<String, dynamic> toFirebase() {
    return {
      'earnedPoints': earnedPoints,
      'usedPoints': usedPoints,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory RewardPoint.fromFirebase(Map<String, dynamic> data) {
    return RewardPoint(
      earnedPoints: data['earnedPoints'] ?? 0,
      usedPoints: data['usedPoints'] ?? 0,
      lastUpdated: DateTime.parse(data['lastUpdated']),
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
