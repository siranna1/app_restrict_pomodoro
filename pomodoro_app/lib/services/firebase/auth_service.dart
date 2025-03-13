// auth_service.dartscopes
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../utils/platform_utils.dart';
import 'package:collection/collection.dart';
import '../../utils/platform_utils.dart';

class AuthService {
  final platform = PlatformUtils();
  //final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn =
      defaultTargetPlatform == TargetPlatform.windows
          ? GoogleSignIn(
              clientId:
                  '931892292987-h6fukl6u7fb18qm2g1d07jdkdirgvi8d.apps.googleusercontent.com',
              //scopes: ['email', 'profile'],
            )
          : GoogleSignIn();
  // 現在のユーザーID取得
  String? get userId => _firebaseAuth?.currentUser?.uid;
  // ユーザーのログイン状態監視
  Stream<User?> get authStateChanges {
    // UI更新処理を含む場合はメインスレッドで実行されるよう保証
    return _firebaseAuth.authStateChanges();
  }

  // Firebase認証インスタンス
  dynamic _firebaseAuth;

  // 現在のユーザー
  dynamic _currentUser;

  // ユーザー認証状態のリスナー
  StreamSubscription? _authStateSubscription;

  // 認証状態
  bool _isInitialized = false;
  bool _isLoggedIn = false;

  // シングルトンパターン
  static final AuthService _instance = AuthService._internal();

  // ファクトリーコンストラクタ
  factory AuthService() {
    return _instance;
  }

  // プライベートコンストラクタ
  AuthService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Windowsプラットフォームではスレッド関連の問題に対処
      if (platform.isWindows) {
        // WidgetsBindingを使用してUIスレッドで処理を実行
        await _initializeOnUiThread();
      } else {
        // 他のプラットフォームでは通常通り初期化
        await _initializeFirebaseAuth();
      }

      _isInitialized = true;
    } catch (e) {
      print('AuthService: Error initializing: $e');
      rethrow;
    }
  }

  void dispose() {
    _authStateSubscription?.cancel();
  }

  // UIスレッドでの初期化（Windows向け）
  Future<void> _initializeOnUiThread() async {
    final completer = Completer<void>();

    // UIスレッドで実行するためにWidgetsBindingを使用
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _initializeFirebaseAuth();
        completer.complete();
      } catch (e) {
        completer.completeError(e);
      }
    });

    return completer.future;
  }

  // Firebase Auth初期化の共通部分
  Future<void> _initializeFirebaseAuth() async {
    try {
      // FirebaseAuthのインポートとインスタンス化
      // ここではdynamic型を使用していますが、実際には適切な型を使用すべきです
      // Webの場合
      if (kIsWeb) {
        try {
          // Webプラットフォーム用の初期化
          // import 'package:firebase_auth/firebase_auth.dart';
          _firebaseAuth = FirebaseAuth.instance;
          print('AuthService: Initialized for Web platform');
        } catch (e) {
          print('AuthService: Error initializing for Web: $e');
        }
      } else {
        try {
          // ネイティブプラットフォーム用の初期化
          // import 'package:firebase_auth/firebase_auth.dart';
          _firebaseAuth = FirebaseAuth.instance;
          print('AuthService: Initialized for native platform');
        } catch (e) {
          print('AuthService: Error initializing for native platform: $e');
        }
      }

      // 認証状態の監視設定
      _setupAuthStateListener();
    } catch (e) {
      print('AuthService: Error in _initializeFirebaseAuth: $e');
      rethrow;
    }
  }

  // 認証状態監視
  void _setupAuthStateListener() {
    try {
      // 既存のサブスクリプションをクリーンアップ
      _authStateSubscription?.cancel();

      // 認証状態の変更を監視
      _authStateSubscription = _firebaseAuth?.authStateChanges().listen((user) {
        _currentUser = user;
        _isLoggedIn = user != null;
        print('AuthService: Auth state changed, user: ${user?.uid}');
      }, onError: (error) {
        print('AuthService: Auth state listener error: $error');
        _handleMultiFactorException(error);
      });
    } catch (e) {
      print('AuthService: Error setting up auth state listener: $e');
    }
  }

  // メールとパスワードで登録
  Future<String?> registerWithEmailAndPassword(
      String email, String password) async {
    if (!_isInitialized) await initialize();

    try {
      if (platform.isWindows) {
        // Windows向けにUIスレッドで実行
        final completer = Completer<String?>();

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final userCredential =
                await _firebaseAuth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            _currentUser = userCredential.user;
            _isLoggedIn = _currentUser != null;
            completer.complete(_currentUser?.uid);
          } catch (e) {
            print('AuthService: Error registering: $e');
            completer.complete(null);
          }
        });

        return completer.future;
      } else {
        // 他のプラットフォーム向け
        final userCredential =
            await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        _currentUser = userCredential.user;
        _isLoggedIn = _currentUser != null;
        return _currentUser?.uid;
      }
    } catch (e) {
      print('AuthService: Error registering: $e');
      return null;
    }
  }

  // メールとパスワードでログイン
  Future<String?> signInWithEmailAndPassword(
      String email, String password) async {
    if (!_isInitialized) await initialize();

    try {
      if (platform.isWindows) {
        // Windows向けにUIスレッドで実行
        final completer = Completer<String?>();

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final userCredential =
                await _firebaseAuth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            _currentUser = userCredential.user;
            _isLoggedIn = _currentUser != null;
            completer.complete(_currentUser?.uid);
          } catch (e) {
            print('AuthService: Error signing in: $e');
            completer.complete(null);
          }
        });

        return completer.future;
      } else {
        // 他のプラットフォーム向け
        final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        _currentUser = userCredential.user;
        _isLoggedIn = _currentUser != null;
        return _currentUser?.uid;
      }
    } catch (e) {
      print('AuthService: Error signing in: $e');
      return null;
    }
  }

  // パスワードリセットメール送信
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw 'パスワードリセットエラー: $e';
    }
  }

  // 現在のユーザーIDを取得
  String? getCurrentUserId() {
    if (!_isInitialized || !_isLoggedIn || _currentUser == null) return null;
    return _currentUser.uid;
  }

  // 現在のユーザーのIDトークンを取得（REST API用）
  Future<String?> getCurrentUserIdToken() async {
    if (!_isInitialized || !_isLoggedIn || _currentUser == null) return null;

    try {
      if (platform.isWindows) {
        // Windows向けにUIスレッドで実行
        final completer = Completer<String?>();

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            final idToken = await _currentUser.getIdToken();
            completer.complete(idToken);
          } catch (e) {
            print('AuthService: Error getting ID token: $e');
            completer.complete(null);
          }
        });

        return completer.future;
      } else {
        // 他のプラットフォーム向け
        return await _currentUser.getIdToken();
      }
    } catch (e) {
      print('AuthService: Error getting ID token: $e');
      return null;
    }
  }

  // ユーザーがログインしているかどうか
  bool get isUserLoggedIn => _isLoggedIn;

  // 現在のユーザーのメールアドレスを取得
  String? get userEmail => _currentUser?.email;

  // サービスが初期化されているかどうか
  bool get isInitialized => _isInitialized;

  // Google認証でログイン
  Future<String?> signInWithGoogle() async {
    //try {
    //  await _handleMultiFactorException(() async {
    //    print("Google認証開始");
//
    //    // Google認証フロー
    //    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//
    //    if (googleUser == null) {
    //      print("Google認証キャンセル");
    //      return;
    //    }
//
    //    // 認証情報を取得
    //    final GoogleSignInAuthentication googleAuth =
    //        await googleUser.authentication;
//
    //    // Firebase認証に使用するCredentialを作成
    //    final credential = GoogleAuthProvider.credential(
    //      accessToken: googleAuth.accessToken,
    //      idToken: googleAuth.idToken,
    //    );
//
    //    // Firebase認証を実行
    //    final userCredential = await _auth.signInWithCredential(credential);
    //    print("Google認証成功: ${userCredential.user}");
    //  });
//
    //  // 認証が成功したら現在のユーザーのUIDを返す
    //  return _auth.currentUser?.uid;
    //} catch (e) {
    //  print("Google認証エラー: $e");
    //  rethrow;
    //}
  }

  // ログアウト
  // サインアウト
  Future<bool> signOut() async {
    if (!_isInitialized) await initialize();

    try {
      if (platform.isWindows) {
        // Windows向けにUIスレッドで実行
        final completer = Completer<bool>();

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          try {
            await _firebaseAuth.signOut();
            _isLoggedIn = false;
            _currentUser = null;
            completer.complete(true);
          } catch (e) {
            print('AuthService: Error signing out: $e');
            completer.complete(false);
          }
        });

        return completer.future;
      } else {
        // 他のプラットフォーム向け
        await _firebaseAuth.signOut();
        _isLoggedIn = false;
        _currentUser = null;
        return true;
      }
    } catch (e) {
      print('AuthService: Error signing out: $e');
      return false;
    }
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
      await _firebaseAuth.verifyPhoneNumber(
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
