// models/restricted_app.dart - 制限対象アプリモデル
class RestrictedApp {
  final int? id;
  final String name;
  final String executablePath;
  final int allowedMinutesPerDay;
  final bool isRestricted;
  final int? requiredPomodorosToUnlock;
  final int? _pointCostPerHour;
  final int? _minutesPerPoint;
  final DateTime? currentSessionEnd;
  RestrictedApp({
    this.id,
    required this.name,
    required this.executablePath,
    required this.allowedMinutesPerDay,
    required this.isRestricted,
    this.requiredPomodorosToUnlock, // 省略可能
    int? pointCostPerHour = 2, // デフォルト値
    int? minutesPerPoint = 30, // デフォルト値
    this.currentSessionEnd,
  })  : this._pointCostPerHour = pointCostPerHour,
        this._minutesPerPoint = minutesPerPoint;

  // ゲッターでデフォルト値を提供
  int get pointCostPerHour => _pointCostPerHour ?? 2;
  int get minutesPerPoint => _minutesPerPoint ?? 30;

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
      pointCostPerHour: map['pointCostPerHour'] ?? 2,
      minutesPerPoint: map['minutesPerPoint'] ?? 30,
      currentSessionEnd: map['currentSessionEnd'] != null
          ? DateTime.parse(map['currentSessionEnd'])
          : null,
    );
  }

  RestrictedApp copyWith({
    int? id,
    String? name,
    String? executablePath,
    int? allowedMinutesPerDay,
    bool? isRestricted,
    int? requiredPomodorosToUnlock,
    int? pointCostPerHour,
    int? minutesPerPoint,
    DateTime? currentSessionEnd,
  }) {
    return RestrictedApp(
      id: id ?? this.id,
      name: name ?? this.name,
      executablePath: executablePath ?? this.executablePath,
      allowedMinutesPerDay: allowedMinutesPerDay ?? this.allowedMinutesPerDay,
      isRestricted: isRestricted ?? this.isRestricted,
      requiredPomodorosToUnlock:
          requiredPomodorosToUnlock ?? this.requiredPomodorosToUnlock,
      pointCostPerHour: pointCostPerHour ?? this.pointCostPerHour,
      minutesPerPoint: minutesPerPoint ?? this.minutesPerPoint,
      currentSessionEnd: currentSessionEnd ?? this.currentSessionEnd,
    );
  }
}
