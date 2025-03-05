import 'package:flutter/material.dart';

class ProjectSelectionDialog extends StatelessWidget {
  final List<Map<String, dynamic>> projects;

  const ProjectSelectionDialog({
    Key? key,
    required this.projects,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('プロジェクトを選択'),
      content: Container(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: projects.length + 1, // すべてのプロジェクトのオプションを追加
          itemBuilder: (context, index) {
            // インデックス0は「すべてのプロジェクト」オプション
            if (index == 0) {
              return ListTile(
                title: const Text('すべてのプロジェクト'),
                leading: const Icon(Icons.apps),
                onTap: () {
                  Navigator.of(context).pop(null); // nullを返してすべてのプロジェクトを選択
                },
              );
            }

            // 実際のプロジェクト
            final project = projects[index - 1];
            return ListTile(
              title: Text(project['name']),
              subtitle: Text('タスク種別: ${project['kind']}'),
              leading: Icon(
                Icons.folder,
                color: _getColorFromHex(project['color']),
              ),
              onTap: () {
                Navigator.of(context).pop(project);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          child: const Text('キャンセル'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  // Hex色コードからColorオブジェクトを取得
  Color _getColorFromHex(String? hexColor) {
    if (hexColor == null || !hexColor.startsWith('#')) {
      return Colors.grey;
    }

    try {
      hexColor = hexColor.toUpperCase().replaceAll('#', '');
      if (hexColor.length == 6) {
        hexColor = 'FF' + hexColor;
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }
}
