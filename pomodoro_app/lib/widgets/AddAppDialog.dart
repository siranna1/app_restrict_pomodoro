import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

// カスタムダイアログウィジェット
class AddAppDialog extends StatefulWidget {
  const AddAppDialog({Key? key}) : super(key: key);

  @override
  _AddAppDialogState createState() => _AddAppDialogState();
}

class _AddAppDialogState extends State<AddAppDialog> {
  final formKey = GlobalKey<FormState>();
  late TextEditingController nameController;
  late TextEditingController pathController;
  late TextEditingController minutesController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController();
    pathController = TextEditingController();
    minutesController = TextEditingController(text: '30');
  }

  @override
  void dispose() {
    nameController.dispose();
    pathController.dispose();
    minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('制限対象アプリを追加'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'アプリ名',
                  hintText: '例: ゲーム、SNSアプリなど',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'アプリ名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: pathController,
                      decoration: const InputDecoration(
                        labelText: '実行ファイルパス',
                        hintText: 'C:\\Program Files\\App\\app.exe',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '実行ファイルパスを入力してください';
                        }
                        return null;
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['exe'],
                      );

                      if (result != null && result.files.isNotEmpty) {
                        setState(() {
                          pathController.text = result.files.first.path!;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: minutesController,
                decoration: const InputDecoration(
                  labelText: '1ポイントあたりの使用時間（分）',
                  hintText: '例: 30',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '使用時間を入力してください';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return '正の整数を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final minutes = int.tryParse(minutesController.text) ?? 30;
                  final pointsPerHour = (60 / minutes).ceil();
                  return Text(
                    '1時間 = $pointsPerHour ポイント',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('キャンセル'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        ElevatedButton(
          child: const Text('追加'),
          onPressed: () {
            if (formKey.currentState!.validate()) {
              // 有効なデータをMapとして返す
              Navigator.of(context).pop({
                'name': nameController.text,
                'path': pathController.text,
                'minutesPerPoint': int.tryParse(minutesController.text) ?? 30
              });
            }
          },
        ),
      ],
    );
  }
}
