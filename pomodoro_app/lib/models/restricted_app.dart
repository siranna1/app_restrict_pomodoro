// models/restricted_app.dart - 制限対象アプリモデル
class RestrictedApp {
  final int? id;
  final String name;
  final String executablePath;
  final int allowedMinutesPerDay;
  final bool isRestricted;
  final int requiredPomodorosToUnlock;

  RestrictedApp({
    this.id,
    required this.name,
    required this.executablePath,
    required this.allowedMinutesPerDay,
    required this.isRestricted,
    required this.requiredPomodorosToUnlock,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'executablePath': executablePath,
      'allowedMinutesPerDay': allowedMinutesPerDay,
      'isRestricted': isRestricted ? 1 : 0,
      'requiredPomodorosToUnlock': requiredPomodorosToUnlock,
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
    );
  }

  RestrictedApp copyWith({
    int? id,
    String? name,
    String? executablePath,
    int? allowedMinutesPerDay,
    bool? isRestricted,
    int? requiredPomodorosToUnlock,
  }) {
    return RestrictedApp(
      id: id ?? this.id,
      name: name ?? this.name,
      executablePath: executablePath ?? this.executablePath,
      allowedMinutesPerDay: allowedMinutesPerDay ?? this.allowedMinutesPerDay,
      isRestricted: isRestricted ?? this.isRestricted,
      requiredPomodorosToUnlock:
          requiredPomodorosToUnlock ?? this.requiredPomodorosToUnlock,
    );
  }
}
