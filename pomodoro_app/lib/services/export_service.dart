// services/export_service.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_helper.dart';

class ExportService {
  // セッションデータをCSV形式でエクスポート
  Future<File?> exportSessionsToCSV() async {
    try {
      // データを取得
      final sessions = await DatabaseHelper.instance.getAllSessionsForExport();

      // CSVヘッダー
      final csvData = [
        [
          'ID',
          'タスク名',
          'カテゴリ',
          '開始時間',
          '終了時間',
          '所要時間(分)',
          '完了状態',
          '集中度',
          '時間帯',
          '中断回数',
          '気分',
          '休憩'
        ],
      ];

      // セッションデータをCSV行に変換
      for (final session in sessions) {
        csvData.add([
          session['id'],
          session['taskName'] ?? '',
          session['taskCategory'] ?? '',
          session['startTime'],
          session['endTime'],
          session['durationMinutes'],
          session['completed'] == 1 ? '完了' : '未完了',
          session['focusScore']?.toString() ?? '',
          session['timeOfDay'] ?? '',
          session['interruptionCount']?.toString() ?? '',
          session['mood'] ?? '',
          session['isBreak'] == 1 ? '休憩' : '作業',
        ]);
      }

      // CSVに変換
      final csv = const ListToCsvConverter().convert(csvData);

      // 一時ファイルに保存
      final directory = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final fileName =
          'pomodoro_sessions_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv);

      return file;
    } catch (e) {
      print('CSVエクスポートエラー: $e');
      return null;
    }
  }

  // CSVファイルを共有
  Future<bool> shareCSVFile(File file) async {
    try {
      await Share.shareXFiles([XFile(file.path)], text: 'ポモドーロセッションデータ');
      return true;
    } catch (e) {
      print('ファイル共有エラー: $e');
      return false;
    }
  }
}
