// services/sound_service.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _enableSounds = true;

  SoundService() {
    _loadSettings();
  }

  // 設定を読み込む
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _enableSounds = prefs.getBool('enableSounds') ?? true;
  }

  // 音声の有効/無効を設定
  Future<void> setEnableSounds(bool enable) async {
    _enableSounds = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableSounds', enable);
  }

  // 音声が有効かどうか
  bool get enableSounds => _enableSounds;

  // ポモドーロ完了時の音声を再生
  Future<void> playPomodoroCompleteSound() async {
    if (!_enableSounds) return;
    print("音声再生");
    try {
      await _audioPlayer.play(AssetSource('sounds/pomodoro_complete.mp3'),
          volume: 1.0);
    } catch (e) {
      print('音声再生エラー: $e');
    }
  }

  // 休憩時間完了時の音声を再生
  Future<void> playBreakCompleteSound() async {
    if (!_enableSounds) return;

    try {
      await _audioPlayer.play(AssetSource('sounds/break_complete.mp3'),
          volume: 1.0);
    } catch (e) {
      print('音声再生エラー: $e');
    }
  }

  void stopAllSounds() {
    try {
      _audioPlayer.stop();
    } catch (e) {
      print('音声停止エラー: $e');
    }
    _audioPlayer.stop();
  }

  // リソースを解放
  void dispose() {
    _audioPlayer.dispose();
  }
}
