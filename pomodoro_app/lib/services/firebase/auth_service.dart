// auth_service.dartscopes
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../utils/platform_utils.dart';
import 'package:collection/collection.dart';

class AuthService {
  final platform = PlatformUtils();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn =
      defaultTargetPlatform == TargetPlatform.windows
          ? GoogleSignIn(
              clientId:
                  '931892292987-h6fukl6u7fb18qm2g1d07jdkdirgvi8d.apps.googleusercontent.com',
              //scopes: ['email', 'profile'],
            )
          : GoogleSignIn();
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
      await _handleMultiFactorException(() async {
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        print("登録成功: ${userCredential.user}");
      });
      return _auth.currentUser?.uid;
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
      await _handleMultiFactorException(() async {
        print("登録開始: $email");
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print("登録成功: ${userCredential.user}");
      });

      // 登録が成功したら現在のユーザーのUIDを返す
      return _auth.currentUser?.uid;
    } catch (e) {
      print("登録エラー: $e");
      rethrow;
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

  // Google認証でログイン
  Future<String?> signInWithGoogle() async {
    try {
      await _handleMultiFactorException(() async {
        print("Google認証開始");

        // Google認証フロー
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          print("Google認証キャンセル");
          return;
        }

        // 認証情報を取得
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Firebase認証に使用するCredentialを作成
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Firebase認証を実行
        final userCredential = await _auth.signInWithCredential(credential);
        print("Google認証成功: ${userCredential.user}");
      });

      // 認証が成功したら現在のユーザーのUIDを返す
      return _auth.currentUser?.uid;
    } catch (e) {
      print("Google認証エラー: $e");
      rethrow;
    }
  }

  // ログアウト
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // auth_service.dart に追加

  Future<void> _handleMultiFactorException(
    Future<void> Function() authFunction,
  ) async {
    try {
      // 認証関数を実行
      await authFunction();
    } on FirebaseAuthMultiFactorException catch (e) {
      print("多要素認証が必要: ${e.message}");

      // SMSによる多要素認証の処理
      final firstPhoneHint = e.resolver.hints
          .firstWhereOrNull((element) => element is PhoneMultiFactorInfo);

      if (firstPhoneHint is! PhoneMultiFactorInfo) {
        print("電話以外の多要素認証はサポートされていません");
        rethrow;
      }

      // 電話番号認証のためのセッション作成
      // この部分は実際のUIと連携する必要があります
      await _auth.verifyPhoneNumber(
        multiFactorSession: e.resolver.session,
        multiFactorInfo: firstPhoneHint,
        verificationCompleted: (_) {
          print("多要素認証の検証が完了しました");
        },
        verificationFailed: (e) {
          print("多要素認証の検証に失敗しました: ${e.message}");
        },
        codeSent: (String verificationId, int? resendToken) async {
          // SMSコードを取得する処理
          // 実際のアプリではダイアログなどでユーザーに入力してもらいます
          print("SMSコードが送信されました: verificationId = $verificationId");

          // SMSコードの入力を待つ
          // ここではダミーのコード「123456」を使用していますが、
          // 実際のアプリではユーザーから入力を受け取ります
          final smsCode = "123456"; // ダミーコード

          if (smsCode != null) {
            try {
              // 認証情報を作成
              final credential = PhoneAuthProvider.credential(
                verificationId: verificationId,
                smsCode: smsCode,
              );

              // 多要素認証を完了
              await e.resolver.resolveSignIn(
                PhoneMultiFactorGenerator.getAssertion(
                  credential,
                ),
              );
              print("多要素認証が完了しました");
            } catch (e) {
              print("多要素認証の解決中にエラーが発生しました: $e");
            }
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print("SMSコードの自動取得がタイムアウトしました: $verificationId");
        },
      );
    } on FirebaseAuthException catch (e) {
      print("Firebase認証エラー: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      print("予期せぬエラー: $e");
      rethrow;
    }
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
