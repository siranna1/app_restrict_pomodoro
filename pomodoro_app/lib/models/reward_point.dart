// models/reward_point.dart
class RewardPoint {
  int? id;
  final int earnedPoints;
  final int usedPoints;
  final DateTime lastUpdated;
  String? firebaseId;
  final int? lastSyncEarnedPoints; // 前回同期時の獲得ポイント
  final int? lastSyncUsedPoints; // 前回同期時の使用ポイント

  RewardPoint({
    this.id,
    required this.earnedPoints,
    required this.usedPoints,
    required this.lastUpdated,
    this.firebaseId,
    this.lastSyncEarnedPoints,
    this.lastSyncUsedPoints,
  });

  // 利用可能なポイント数を計算
  int get availablePoints => earnedPoints - usedPoints;

  // 前回の同期以降に獲得したポイント
  int get earnedSinceLastSync => lastSyncEarnedPoints != null
      ? earnedPoints - lastSyncEarnedPoints!
      : earnedPoints;

  // 前回の同期以降に使用したポイント
  int get usedSinceLastSync => lastSyncUsedPoints != null
      ? usedPoints - lastSyncUsedPoints!
      : usedPoints;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'earnedPoints': earnedPoints,
      'usedPoints': usedPoints,
      'lastUpdated': lastUpdated.toIso8601String(),
      'firebaseId': firebaseId,
      'lastSyncEarnedPoints': lastSyncEarnedPoints,
      'lastSyncUsedPoints': lastSyncUsedPoints,
    };
  }

  factory RewardPoint.fromMap(Map<String, dynamic> map) {
    return RewardPoint(
      id: map['id'],
      earnedPoints: map['earnedPoints'],
      usedPoints: map['usedPoints'],
      lastUpdated: DateTime.parse(map['lastUpdated']),
      firebaseId: map['firebaseId'],
      lastSyncEarnedPoints: map['lastSyncEarnedPoints'],
      lastSyncUsedPoints: map['lastSyncUsedPoints'],
    );
  }

  Map<String, dynamic> toFirebase() {
    return {
      'earnedPoints': earnedPoints,
      'usedPoints': usedPoints,
      'lastUpdated': lastUpdated.toIso8601String(),
      'lastSyncEarnedPoints': earnedPoints, // 同期時点の値を保存
      'lastSyncUsedPoints': usedPoints, // 同期時点の値を保存
    };
  }

  factory RewardPoint.fromFirebase(Map<String, dynamic> data) {
    return RewardPoint(
      earnedPoints: data['earnedPoints'] ?? 0,
      usedPoints: data['usedPoints'] ?? 0,
      lastUpdated: DateTime.parse(data['lastUpdated']),
      lastSyncEarnedPoints: data['lastSyncEarnedPoints'] ?? 0,
      lastSyncUsedPoints: data['lastSyncUsedPoints'] ?? 0,
    );
  }

  RewardPoint copyWith({
    int? id,
    int? earnedPoints,
    int? usedPoints,
    DateTime? lastUpdated,
    String? firebaseId,
    int? lastSyncEarnedPoints,
    int? lastSyncUsedPoints,
  }) {
    return RewardPoint(
      id: id ?? this.id,
      earnedPoints: earnedPoints ?? this.earnedPoints,
      usedPoints: usedPoints ?? this.usedPoints,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      firebaseId: firebaseId ?? this.firebaseId,
      lastSyncEarnedPoints: lastSyncEarnedPoints ?? this.lastSyncEarnedPoints,
      lastSyncUsedPoints: lastSyncUsedPoints ?? this.lastSyncUsedPoints,
    );
  }

  // 増分に基づく同期ロジック用メソッド
  RewardPoint mergeWithRemote(RewardPoint remote) {
    // リモートの前回同期からの増分を計算
    final remoteEarnedDelta = remote.earnedSinceLastSync;
    final remoteUsedDelta = remote.usedSinceLastSync;

    // ローカルの前回同期からの増分を計算
    final localEarnedDelta = this.earnedSinceLastSync;
    final localUsedDelta = this.usedSinceLastSync;

    // 両方の増分を合算して新しい合計を計算
    final newEarnedPoints = (remote.lastSyncEarnedPoints ?? 0) +
        remoteEarnedDelta +
        localEarnedDelta;
    final newUsedPoints =
        (remote.lastSyncUsedPoints ?? 0) + remoteUsedDelta + localUsedDelta;

    // 新しい状態を返す
    return RewardPoint(
      id: this.id,
      earnedPoints: newEarnedPoints,
      usedPoints: newUsedPoints,
      lastUpdated: DateTime.now(),
      firebaseId: this.firebaseId,
      lastSyncEarnedPoints: remote.lastSyncEarnedPoints,
      lastSyncUsedPoints: remote.lastSyncUsedPoints,
    );
  }
}
