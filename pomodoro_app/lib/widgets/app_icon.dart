import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/app_info.dart';

class AppIconWidget extends StatelessWidget {
  final String iconBase64;
  final double size;

  const AppIconWidget({
    Key? key,
    required this.iconBase64,
    this.size = 40.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (iconBase64.isEmpty) {
      return Icon(Icons.android, size: size);
    }

    try {
      final bytes = base64Decode(iconBase64);
      return Image.memory(
        bytes,
        width: size,
        height: size,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.android, size: size);
        },
      );
    } catch (e) {
      return Icon(Icons.android, size: size);
    }
  }

  // 静的メソッドでアプリ情報からアイコンウィジェットを作成
  static Widget fromAppInfo(AppInfo appInfo, {double size = 40.0}) {
    return AppIconWidget(
      iconBase64: appInfo.iconBase64,
      size: size,
    );
  }
}
