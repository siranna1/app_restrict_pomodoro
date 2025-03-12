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
  final String? firebaseId; // Firebase同期用のID

  RestrictedApp({
    this.id,
    required this.name,
    required this.executablePath,
    required this.allowedMinutesPerDay,
    required this.isRestricted,
    this.requiredPomodorosToUnlock, // 省略可能
    this.minutesPerPoint = 30, // デフォルト値
    this.currentSessionEnd,
    this.firebaseId, // Firebase同期用のID
  });

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
      // currentSessionEndはデバイス固有の情報なのでアップロードしない
      // 'currentSessionEnd': currentSessionEnd?.toIso8601String(),
    };
  }

  // Firebaseからのデータを元にインスタンスを作成
  factory RestrictedApp.fromFirebase(Map<String, dynamic> data) {
    return RestrictedApp(
      name: data['name'],
      executablePath: data['executablePath'],
      allowedMinutesPerDay: data['allowedMinutesPerDay'],
      isRestricted: data['isRestricted'],
      requiredPomodorosToUnlock: data['requiredPomodorosToUnlock'],
      minutesPerPoint: data['minutesPerPoint'] ?? 30,
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
    );
  }
}
