// // screens/app_restriction_screen.dart - アプリ制限設定画面
// import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:provider/provider.dart';
// import '../providers/app_restriction_provider.dart';
// import '../models/restricted_app.dart';

// class AppRestrictionScreen extends StatefulWidget {
//   const AppRestrictionScreen({Key? key}) : super(key: key);

//   @override
//   _AppRestrictionScreenState createState() => _AppRestrictionScreenState();
// }

// class _AppRestrictionScreenState extends State<AppRestrictionScreen> {
//   @override
//   Widget build(BuildContext context) {
//     final appRestrictionProvider = Provider.of<AppRestrictionProvider>(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('アプリ制限設定'),
//       ),
//       body: Column(
//         children: [
//           // 監視オン/オフスイッチ
//           SwitchListTile(
//             title: const Text('アプリ制限を有効にする'),
//             subtitle: const Text('ポモドーロ目標達成まで指定アプリの使用を制限します'),
//             value: appRestrictionProvider.isMonitoring,
//             onChanged: (value) {
//               if (value) {
//                 appRestrictionProvider.startMonitoring();
//               } else {
//                 appRestrictionProvider.stopMonitoring();
//               }
//             },
//           ),

//           const Divider(),

//           // 制限対象アプリのリスト
//           Expanded(
//             child: ListView.builder(
//               itemCount: appRestrictionProvider.restrictedApps.length,
//               itemBuilder: (context, index) {
//                 final app = appRestrictionProvider.restrictedApps[index];
//                 return ListTile(
//                   leading: const Icon(Icons.apps),
//                   title: Text(app.name),
//                   subtitle:
//                       Text('ポイントコスト: 1時間あたり${app.pointCostPerHour ?? 2}ポイント'),
//                   trailing: Switch(
//                     value: app.isRestricted,
//                     onChanged: (value) {
//                       appRestrictionProvider.updateRestrictedApp(
//                         app.copyWith(isRestricted: value),
//                       );
//                     },
//                   ),
//                   onTap: () => _showEditAppDialog(context, app),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton(
//         child: const Icon(Icons.add),
//         onPressed: () => _showAddAppDialog(context),
//       ),
//     );
//   }

//   // アプリ追加ダイアログ
//   Future<void> _showAddAppDialog(BuildContext context) async {
//     final formKey = GlobalKey<FormState>();
//     String appName = '';
//     String executablePath = '';
//     int pointCostPerHour = 2;
//     int minutesPerPoint = 30;

//     return showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('制限対象アプリを追加'),
//           content: Form(
//             key: formKey,
//             child: SingleChildScrollView(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextFormField(
//                     decoration: const InputDecoration(
//                       labelText: 'アプリ名',
//                       hintText: '例: ゲーム、SNSアプリなど',
//                     ),
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return 'アプリ名を入力してください';
//                       }
//                       return null;
//                     },
//                     onSaved: (value) {
//                       appName = value!;
//                     },
//                   ),
//                   const SizedBox(height: 16),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: TextFormField(
//                           decoration: const InputDecoration(
//                             labelText: '実行ファイルパス',
//                             hintText: 'C:\\Program Files\\App\\app.exe',
//                           ),
//                           validator: (value) {
//                             if (value == null || value.isEmpty) {
//                               return '実行ファイルパスを入力してください';
//                             }
//                             return null;
//                           },
//                           onSaved: (value) {
//                             executablePath = value!;
//                           },
//                         ),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.folder_open),
//                         onPressed: () async {
//                           final result = await FilePicker.platform.pickFiles(
//                             type: FileType.custom,
//                             allowedExtensions: ['exe'],
//                           );

//                           if (result != null && result.files.isNotEmpty) {
//                             executablePath = result.files.first.path!;
//                             // フォームフィールドを更新するには、コントローラーを使用する必要があります
//                           }
//                         },
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     decoration: const InputDecoration(
//                       labelText: '1時間あたりのポイントコスト',
//                       hintText: '例: 2',
//                     ),
//                     keyboardType: TextInputType.number,
//                     initialValue: '2',
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return 'ポイントコストを入力してください';
//                       }
//                       final number = int.tryParse(value);
//                       if (number == null || number <= 0) {
//                         return '正の整数を入力してください';
//                       }
//                       return null;
//                     },
//                     onSaved: (value) {
//                       pointCostPerHour = int.parse(value!);
//                     },
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     decoration: const InputDecoration(
//                       labelText: '1ポイントあたりの分数',
//                       hintText: '例: 30',
//                     ),
//                     keyboardType: TextInputType.number,
//                     initialValue: '30',
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return '分数を入力してください';
//                       }
//                       final number = int.tryParse(value);
//                       if (number == null || number <= 0) {
//                         return '正の整数を入力してください';
//                       }
//                       return null;
//                     },
//                     onSaved: (value) {
//                       minutesPerPoint = int.parse(value!);
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               child: const Text('キャンセル'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: const Text('追加'),
//               onPressed: () {
//                 if (formKey.currentState!.validate()) {
//                   formKey.currentState!.save();

//                   final provider = Provider.of<AppRestrictionProvider>(context,
//                       listen: false);

//                   provider.addRestrictedApp(RestrictedApp(
//                     name: appName,
//                     executablePath: executablePath,
//                     allowedMinutesPerDay: 0,
//                     isRestricted: true,
//                     pointCostPerHour: pointCostPerHour,
//                     minutesPerPoint: minutesPerPoint,
//                   ));

//                   Navigator.of(context).pop();
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // アプリ編集ダイアログ
//   Future<void> _showEditAppDialog(
//       BuildContext context, RestrictedApp app) async {
//     final formKey = GlobalKey<FormState>();
//     String appName = app.name;
//     String executablePath = app.executablePath;
//     int pointCostPerHour = app.pointCostPerHour ?? 2;
//     int minutesPerPoint = app.minutesPerPoint ?? 30;

//     return showDialog(
//       context: context,
//       builder: (context) {
//         return AlertDialog(
//           title: const Text('制限対象アプリを編集'),
//           content: Form(
//             key: formKey,
//             child: SingleChildScrollView(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   TextFormField(
//                     decoration: const InputDecoration(
//                       labelText: 'アプリ名',
//                     ),
//                     initialValue: appName,
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return 'アプリ名を入力してください';
//                       }
//                       return null;
//                     },
//                     onSaved: (value) {
//                       appName = value!;
//                     },
//                   ),
//                   const SizedBox(height: 16),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: TextFormField(
//                           decoration: const InputDecoration(
//                             labelText: '実行ファイルパス',
//                           ),
//                           initialValue: executablePath,
//                           validator: (value) {
//                             if (value == null || value.isEmpty) {
//                               return '実行ファイルパスを入力してください';
//                             }
//                             return null;
//                           },
//                           onSaved: (value) {
//                             executablePath = value!;
//                           },
//                         ),
//                       ),
//                       IconButton(
//                         icon: const Icon(Icons.folder_open),
//                         onPressed: () async {
//                           final result = await FilePicker.platform.pickFiles(
//                             type: FileType.custom,
//                             allowedExtensions: ['exe'],
//                           );

//                           if (result != null && result.files.isNotEmpty) {
//                             executablePath = result.files.first.path!;
//                             // フォームフィールドを更新するには、コントローラーを使用する必要があります
//                           }
//                         },
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     decoration: const InputDecoration(
//                       labelText: '1時間あたりのポイントコスト',
//                     ),
//                     keyboardType: TextInputType.number,
//                     initialValue: pointCostPerHour.toString(),
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return 'ポイントコストを入力してください';
//                       }
//                       final number = int.tryParse(value);
//                       if (number == null || number <= 0) {
//                         return '正の整数を入力してください';
//                       }
//                       return null;
//                     },
//                     onSaved: (value) {
//                       pointCostPerHour = int.parse(value!);
//                     },
//                   ),
//                   const SizedBox(height: 16),
//                   TextFormField(
//                     decoration: const InputDecoration(
//                       labelText: '1ポイントあたりの分数',
//                     ),
//                     keyboardType: TextInputType.number,
//                     initialValue: minutesPerPoint.toString(),
//                     validator: (value) {
//                       if (value == null || value.isEmpty) {
//                         return '分数を入力してください';
//                       }
//                       final number = int.tryParse(value);
//                       if (number == null || number <= 0) {
//                         return '正の整数を入力してください';
//                       }
//                       return null;
//                     },
//                     onSaved: (value) {
//                       minutesPerPoint = int.parse(value!);
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           actions: [
//             TextButton(
//               child: const Text('キャンセル'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             TextButton(
//               child: const Text('削除'),
//               style: TextButton.styleFrom(
//                 foregroundColor: Colors.red,
//               ),
//               onPressed: () {
//                 final provider =
//                     Provider.of<AppRestrictionProvider>(context, listen: false);
//                 provider.removeRestrictedApp(app.id!);
//                 Navigator.of(context).pop();
//               },
//             ),
//             ElevatedButton(
//               child: const Text('保存'),
//               onPressed: () {
//                 if (formKey.currentState!.validate()) {
//                   formKey.currentState!.save();

//                   final provider = Provider.of<AppRestrictionProvider>(context,
//                       listen: false);

//                   provider.updateRestrictedApp(app.copyWith(
//                     name: appName,
//                     executablePath: executablePath,
//                     pointCostPerHour: pointCostPerHour,
//                     minutesPerPoint: minutesPerPoint,
//                   ));

//                   Navigator.of(context).pop();
//                 }
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }
// }
