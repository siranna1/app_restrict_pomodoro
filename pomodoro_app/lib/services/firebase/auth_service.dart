// auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 現在のユーザーID取得
  String? get userId => _auth.currentUser?.uid;

  // 匿名サインイン（最も簡単な認証方法）
  Future<String?> signInAnonymously() async {
    try {
      final result = await _auth.signInAnonymously();
      return result.user?.uid;
    } catch (e) {
      print('Anonymous sign in error: $e');
      return null;
    }
  }

  // メール/パスワード認証（オプション）
  Future<String?> signInWithEmailPassword(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user?.uid;
    } catch (e) {
      print('Email/password sign in error: $e');
      return null;
    }
  }
}
