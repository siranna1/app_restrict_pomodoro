// screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pomodoro_app/services/firebase/auth_service.dart';
import 'package:flutter/foundation.dart';
import '../settings_screen.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true; // true = ログイン, false = 登録
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      // プラットフォームごとに処理を分ける
      if (defaultTargetPlatform == TargetPlatform.windows) {
        // Windowsでは明示的にasync処理をUI更新後に実行
        await Future.delayed(Duration.zero); // イベントループを一巡させる
      }
      if (_isLogin) {
        // ログイン処理
        await authService.signInWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        // 登録処理
        await authService.registerWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }

      // 成功したらホーム画面に遷移
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Windows環境では特別な処理を追加
      if (defaultTargetPlatform == TargetPlatform.windows) {
        await Future.delayed(Duration.zero);
      }

      final userId = await authService.signInWithGoogle();

      if (userId != null) {
        // 成功したらホーム画面に遷移
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'ログイン' : 'アカウント登録'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: EdgeInsets.all(8),
                  color: Colors.red[100],
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red[900]),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _signInWithGoogle,
                icon: Image.asset(
                  'assets/google_logo.png',
                  height: 24,
                ),
                label: Text('Googleでログイン'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                ),
              ),
              SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'メールアドレス'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'メールアドレスを入力してください';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return '正しいメールアドレスを入力してください';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'パスワード'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'パスワードを入力してください';
                  }
                  if (value.length < 6) {
                    return 'パスワードは6文字以上にしてください';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // if (!_isLoading)
                  //   WidgetsBinding.instance.scheduleTask(() async {
                  //     _submit();
                  //   });
                  // _isLoading
                  //     ? null
                  //     : () {
                  //         if (defaultTargetPlatform == TargetPlatform.windows) {
                  //           // ScheduleTaskを使用してメインスレッドでの実行を保証
                  //           WidgetsBinding.instance.scheduleFrameCallback((_) {
                  //             _submit();
                  //           });
                  //         } else {
                  //           _submit();
                  //         }
                  //       };
                  _isLoading ? null : _submit();
                },
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text(_isLogin ? 'ログイン' : '登録'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _errorMessage = null;
                  });
                },
                child: Text(_isLogin ? 'アカウントを作成する' : '既にアカウントをお持ちの方はこちら'),
              ),
              if (_isLogin)
                TextButton(
                  onPressed: () async {
                    if (_emailController.text.isEmpty) {
                      setState(() {
                        _errorMessage = 'パスワードをリセットするにはメールアドレスを入力してください';
                      });
                      return;
                    }

                    try {
                      final authService =
                          Provider.of<AuthService>(context, listen: false);
                      await authService
                          .sendPasswordResetEmail(_emailController.text.trim());
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('パスワードリセットメールを送信しました')),
                      );
                    } catch (e) {
                      setState(() {
                        _errorMessage = e.toString();
                      });
                    }
                  },
                  child: Text('パスワードを忘れた場合'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void setIsLoading() {
    setState(() {
      _isLoading = !_isLoading;
    });
  }
}
