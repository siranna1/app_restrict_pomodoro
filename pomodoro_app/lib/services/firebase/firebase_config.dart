// firebase_config.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

class FirebaseConfig {
  static Future<void> initialize() async {
    print('FirebaseConfig initialize');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Windows(Web)向け設定
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      // await Firebase.initializeApp(
      //   options: const FirebaseOptions(
      //       apiKey: "AIzaSyDGzmWpHli-Kc9038OquP-OQ6qt8Jic7EU",
      //       authDomain: "pomodoroappsync.firebaseapp.com",
      //       databaseURL:
      //           "https://pomodoroappsync-default-rtdb.asia-southeast1.firebasedatabase.app",
      //       projectId: "pomodoroappsync",
      //       storageBucket: "pomodoroappsync.firebasestorage.app",
      //       messagingSenderId: "931892292987",
      //       appId: "1:931892292987:web:578677421dfa49edb4a1de",
      //       measurementId: "G-9DN5X3MVWB"),
      // );
    }
    // Android/iOSはgoogle-services.jsonから自動設定
    else {
      //await Firebase.initializeApp();
    }
  }
}
