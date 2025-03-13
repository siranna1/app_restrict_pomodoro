// auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 現在のユーザーID取得
  String? get userId => _auth.currentUser?.uid;
  // ユーザーのログイン状態監視
  Stream<User?> get authStateChanges {
    // UI更新処理を含む場合はメインスレッドで実行されるよう保証
    return _auth.authStateChanges();
  }

  // メールとパスワードで登録
  Future<String?> registerWithEmailPassword(
      String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user?.uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw 'パスワードが弱すぎます';
      } else if (e.code == 'email-already-in-use') {
        throw 'このメールアドレスは既に使用されています';
      } else {
        throw 'エラー: ${e.message}';
      }
    } catch (e) {
      throw '登録エラー: $e';
    }
  }

  // メールとパスワードでログイン
  Future<String?> signInWithEmailPassword(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user?.uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw 'このメールアドレスのユーザーが見つかりません';
      } else if (e.code == 'wrong-password') {
        throw 'パスワードが間違っています';
      } else {
        throw 'エラー: ${e.message}';
      }
    } catch (e) {
      throw 'ログインエラー: $e';
    }
  }

  // パスワードリセットメール送信
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw 'パスワードリセットエラー: $e';
    }
  }

  // ログアウト
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 匿名サインイン（最も簡単な認証方法）
  //今は使ってない
  // Future<String?> signInAnonymously() async {
  //   try {
  //     final result = await _auth.signInAnonymously();
  //     return result.user?.uid;
  //   } catch (e) {
  //     print('Anonymous sign in error: $e');
  //     return null;
  //   }
  // }
}
