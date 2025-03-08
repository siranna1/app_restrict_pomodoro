// lib/screens/permission_guide_screen.dart
import 'package:flutter/material.dart';
import '../platforms/android/android_app_controller.dart';

class PermissionGuideScreen extends StatelessWidget {
  final VoidCallback onPermissionGranted;

  const PermissionGuideScreen({Key? key, required this.onPermissionGranted})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('権限が必要です'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.security,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'アプリ制限機能を使用するには「使用状況へのアクセス」権限が必要です',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'この権限により、ポモドーロセッション中に制限対象アプリを検出して自動的に終了させることができます。',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final controller = AndroidAppController();
                await controller.openUsageStatsSettings();

                // 権限画面から戻ってきたら権限を再確認
                Future.delayed(const Duration(seconds: 2), () async {
                  final hasPermission =
                      await controller.hasUsageStatsPermission();
                  if (hasPermission) {
                    onPermissionGranted();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('権限が許可されませんでした。アプリ制限機能を使用するには権限が必要です。'),
                      ),
                    );
                  }
                });
              },
              child: const Text('権限を設定する'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('後で行う'),
            ),
          ],
        ),
      ),
    );
  }
}
