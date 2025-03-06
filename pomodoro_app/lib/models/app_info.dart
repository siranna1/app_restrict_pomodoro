import 'dart:convert';
import 'dart:typed_data';

class AppInfo {
  final String name;
  final String packageName;
  final bool isSystemApp;
  final String iconBase64;

  AppInfo({
    required this.name,
    required this.packageName,
    required this.isSystemApp,
    required this.iconBase64,
  });

  factory AppInfo.fromMap(Map<String, dynamic> map) {
    return AppInfo(
      name: map['name'] as String,
      packageName: map['packageName'] as String,
      isSystemApp: map['isSystemApp'] as bool,
      iconBase64: map['iconBase64'] as String? ?? '',
    );
  }

  Uint8List? get iconBytes {
    if (iconBase64.isEmpty) return null;
    try {
      return base64Decode(iconBase64);
    } catch (e) {
      print('Icon decoding error: $e');
      return null;
    }
  }

  // 同値比較のためのメソッド
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppInfo &&
          runtimeType == other.runtimeType &&
          packageName == other.packageName;

  @override
  int get hashCode => packageName.hashCode;
}
