
package com.example.pomodoro_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.loader.FlutterLoader;

class ExpirationCheckReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        println("期限切れチェックブロードキャストを受信")
        if (intent.action == "com.example.pomodoro_app.CHECK_EXPIRATIONS") {
            println("期限切れチェックブロードキャストを受信")
            val flutterLoader = FlutterLoader();
            // FlutterMainを初期化
            flutterLoader.startInitialization(context)
            flutterLoader.ensureInitializationComplete(context, null)
            
            // FlutterEngineを作成
            val flutterEngine = FlutterEngine(context)
            flutterEngine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )
            
            // MethodChannelを作成してメソッド呼び出し
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.pomodoro_app/app_control")
            channel.invokeMethod("checkUnlockExpirations", null)
            
            println("Dartメソッド 'checkUnlockExpirations' を呼び出しました")
        }
    }
}