// models/restricted_app.dart - 制限対象アプリモデル
class RestrictedApp {
  final int? id;
  final String name;
  final String executablePath;
  final int allowedMinutesPerDay;
  final bool isRestricted;
  final int? requiredPomodorosToUnlock;
  final int minutesPerPoint;
  final DateTime? currentSessionEnd;
  String? firebaseId; // Firebase同期用のID
  final String? deviceId; // デバイス識別子
  final String? platformType; // "windows" または "android"
  bool isAvailableLocally; // 現在のデバイスに存在するかどうか
  final bool isDeleted; // 論理削除フラグ
  DateTime updatedAt;
  RestrictedApp(
      {this.id,
      required this.name,
      required this.executablePath,
      required this.allowedMinutesPerDay,
      required this.isRestricted,
      this.requiredPomodorosToUnlock, // 省略可能
      this.minutesPerPoint = 30, // デフォルト値
      this.currentSessionEnd,
      this.firebaseId, // Firebase同期用のID
      this.deviceId,
      this.platformType,
      this.isAvailableLocally = true,
      this.isDeleted = false,
      DateTime? updatedAt})
      : this.updatedAt = updatedAt ?? DateTime.now(); // デフォルト値は現在時刻

  // 1時間あたりのポイントコストをminutesPerPointから計算
  int get pointCostPerHour => (60 / minutesPerPoint).ceil();

  bool get isCurrentlyUnlocked {
    if (currentSessionEnd == null) return false;
    return DateTime.now().isBefore(currentSessionEnd!);
  }

  int get remainingMinutes {
    if (currentSessionEnd == null) return 0;
    if (!isCurrentlyUnlocked) return 0;

    final diff = currentSessionEnd!.difference(DateTime.now());
    return (diff.inSeconds / 60).ceil();
  }

  // 表示用の名前を取得（削除済みの場合はマーク付き）
  String get displayName => isDeleted ? "$name (削除済み)" : name;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'executablePath': executablePath,
      'allowedMinutesPerDay': allowedMinutesPerDay,
      'isRestricted': isRestricted ? 1 : 0,
      'requiredPomodorosToUnlock': requiredPomodorosToUnlock ?? 0,
      'pointCostPerHour': pointCostPerHour,
      'minutesPerPoint': minutesPerPoint,
      'currentSessionEnd': currentSessionEnd?.toIso8601String(),
      'firebaseId': firebaseId, // Firebase同期用のID
      'deviceId': deviceId,
      'platformType': platformType,
      'isAvailableLocally': isAvailableLocally ? 1 : 0,
      'isDeleted': isDeleted ? 1 : 0,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RestrictedApp.fromMap(Map<String, dynamic> map) {
    return RestrictedApp(
      id: map['id'],
      name: map['name'],
      executablePath: map['executablePath'],
      allowedMinutesPerDay: map['allowedMinutesPerDay'],
      isRestricted: map['isRestricted'] == 1,
      requiredPomodorosToUnlock: map['requiredPomodorosToUnlock'],
      minutesPerPoint: map['minutesPerPoint'] ?? 30,
      currentSessionEnd: map['currentSessionEnd'] != null
          ? DateTime.parse(map['currentSessionEnd'])
          : null,
      firebaseId: map['firebaseId'], // Firebase同期用のID
      deviceId: map['deviceId'],
      platformType: map['platformType'],
      isAvailableLocally: map['isAvailableLocally'] == 1,
      isDeleted: map['isDeleted'] == 1,
      updatedAt:
          map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  // Firebase用のマップデータを返すメソッド
  Map<String, dynamic> toFirebase() {
    return {
      'name': name,
      'executablePath': executablePath,
      'allowedMinutesPerDay': allowedMinutesPerDay,
      'isRestricted': isRestricted,
      'requiredPomodorosToUnlock': requiredPomodorosToUnlock,
      'minutesPerPoint': minutesPerPoint,
      'deviceId': deviceId,
      'platformType': platformType,
      'isDeleted': isDeleted,
      'updatedAt': updatedAt.toIso8601String(),
      // currentSessionEndはデバイス固有の情報なのでアップロードしない
      // 'currentSessionEnd': currentSessionEnd?.toIso8601String(),
    };
  }

  // Firebaseからのデータを元にインスタンスを作成
  factory RestrictedApp.fromFirebase(
      Map<String, dynamic> data, String firebaseId) {
    return RestrictedApp(
      name: data['name'],
      executablePath: data['executablePath'],
      allowedMinutesPerDay: data['allowedMinutesPerDay'],
      isRestricted: data['isRestricted'],
      requiredPomodorosToUnlock: data['requiredPomodorosToUnlock'],
      minutesPerPoint: data['minutesPerPoint'] ?? 30,
      deviceId: data['deviceId'],
      platformType: data['platformType'],
      firebaseId: firebaseId,
      isDeleted: data['isDeleted'] ?? false,
      isAvailableLocally: false, // デフォルトは false、後で確認
      updatedAt: data['updatedAt'] != null
          ? DateTime.parse(data['updatedAt'])
          : DateTime.now(),
      // currentSessionEndはアップロードされていないのでnull
    );
  }

  RestrictedApp copyWith({
    int? id,
    String? name,
    String? executablePath,
    int? allowedMinutesPerDay,
    bool? isRestricted,
    int? requiredPomodorosToUnlock,
    int? minutesPerPoint,
    DateTime? currentSessionEnd,
    String? firebaseId, // Firebase同期用のID
    String? deviceId,
    String? platformType,
    bool? isAvailableLocally,
    bool? isDeleted,
    DateTime? updatedAt,
  }) {
    return RestrictedApp(
      id: id ?? this.id,
      name: name ?? this.name,
      executablePath: executablePath ?? this.executablePath,
      allowedMinutesPerDay: allowedMinutesPerDay ?? this.allowedMinutesPerDay,
      isRestricted: isRestricted ?? this.isRestricted,
      requiredPomodorosToUnlock:
          requiredPomodorosToUnlock ?? this.requiredPomodorosToUnlock,
      minutesPerPoint: minutesPerPoint ?? this.minutesPerPoint,
      currentSessionEnd: currentSessionEnd ?? this.currentSessionEnd,
      firebaseId: firebaseId ?? this.firebaseId, // Firebase同期用のID
      deviceId: deviceId ?? this.deviceId,
      platformType: platformType ?? this.platformType,
      isAvailableLocally: isAvailableLocally ?? this.isAvailableLocally,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
