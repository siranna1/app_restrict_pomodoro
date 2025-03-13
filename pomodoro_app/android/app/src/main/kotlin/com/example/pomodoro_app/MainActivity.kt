package com.example.pomodoro_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    private lateinit var appController: AndroidAppController
    
    // BroadcastReceiverを定義
    private val expirationReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == "com.example.pomodoro_app.EXPIRATIONS_UPDATED" && 
                flutterEngine != null) {
                // Flutter側に通知
                val channel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, 
                                        "com.example.pomodoro_app/app_control")
                channel.invokeMethod("checkUnlockExpirations", null)
                println("期限切れ更新をFlutter側に通知しました")
            }
        }
    }
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Flutterエンジンにプラグインを登録
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // AndroidAppControllerの初期化と登録
        appController = AndroidAppController(applicationContext, this)
        AndroidAppController.registerWith(flutterEngine, applicationContext, this)
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    
        // ブロードキャストレシーバーを登録
        val filter = IntentFilter("com.example.pomodoro_app.EXPIRATIONS_UPDATED")
        registerReceiver(expirationReceiver, filter)
    }
    
    override fun onDestroy() {
        if (::appController.isInitialized) {
            appController.dispose()
        }
        unregisterReceiver(expirationReceiver)
        super.onDestroy()
    }
    // override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    // // ここを追加
    // super.onActivityResult(requestCode, resultCode, data);
    // // ここで色々する
    // }
}