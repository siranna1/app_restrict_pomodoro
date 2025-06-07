package com.example.pomodoro_app

import android.content.BroadcastReceiver
import android.content.ServiceConnection
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.os.Build
import android.os.IBinder
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
    override fun onResume() {
        super.onResume()
        
        try {
            // アプリがフォアグラウンドに復帰した際に完了通知をクリア
            val serviceIntent = Intent(this, PomodoroTimerService::class.java).apply {
                action = "CANCEL_NOTIFICATIONS"
            }
            startService(serviceIntent)
        } catch (e: Exception) {
            println("通知キャンセルエラー: ${e.message}")
        }
    }
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Flutterエンジンにプラグインを登録
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // AndroidAppControllerの初期化と登録
        appController = AndroidAppController(applicationContext, this)
        AndroidAppController.registerWith(flutterEngine, applicationContext, this)

         // ポモドーロタイマー用のチャンネルを設定
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.pomodoro_app/pomodoro_timer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startPomodoro" -> {
                        val minutes = call.argument<Int>("minutes") ?: 25
                        val taskId = call.argument<Int>("taskId") ?: -1
                        val taskName = call.argument<String>("taskName") ?: ""

                        // サービスを開始
                        val serviceIntent = Intent(this, PomodoroTimerService::class.java).apply {
                            action = "START_POMODORO"
                            putExtra("minutes", minutes)
                            putExtra("taskId", taskId)
                            putExtra("taskName", taskName)
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }

                        result.success(true)
                    }
                    "startBreak" -> {
                        val minutes = call.argument<Int>("minutes") ?: 5
                        val isLongBreak = call.argument<Boolean>("isLongBreak") ?: false
                        // サービスを開始
                        val serviceIntent = Intent(this, PomodoroTimerService::class.java).apply {
                            action = "START_BREAK"
                            putExtra("minutes", minutes)
                            putExtra("isLongBreak", isLongBreak)
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(serviceIntent)
                        } else {
                            startService(serviceIntent)
                        }

                        result.success(true)
                    }
                    "pausePomodoro" -> {
                        val serviceIntent = Intent(this, PomodoroTimerService::class.java).apply {
                            action = "PAUSE_TIMER"
                        }
                        startService(serviceIntent)
                        result.success(true)
                    }
                    "resumePomodoro" -> {
                        val serviceIntent = Intent(this, PomodoroTimerService::class.java).apply {
                            action = "RESUME_TIMER"
                        }
                        startService(serviceIntent)
                        result.success(true)
                    }
                    "stopPomodoro" -> {
                        val serviceIntent = Intent(this, PomodoroTimerService::class.java).apply {
                            action = "STOP_TIMER"
                        }
                        startService(serviceIntent)
                        result.success(true)
                    }
                    "skipTimer" -> {
                        val serviceIntent = Intent(this, PomodoroTimerService::class.java).apply {
                            action = "SKIP_TIMER"
                        }
                        startService(serviceIntent)
                        result.success(true)
                    }
                    "getTimerStatus" -> {
                        try {
                            // サービスが実行中かチェック
                            val serviceIntent = Intent(this, PomodoroTimerService::class.java)
                            val serviceConnection = object : ServiceConnection {
                                override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
                                    val binder = service as PomodoroTimerService.LocalBinder
                                    val timerService = binder.getService()
                                    val status = timerService.getTimerStatus()

                                    // 接続を解除
                                    unbindService(this)

                                    // 結果を返す
                                    result.success(status)
                                }

                                override fun onServiceDisconnected(name: ComponentName?) {
                                    // サービスが実行されていない
                                    result.success(mapOf("isRunning" to false))
                                }
                            }

                            // サービスとバインド
                            if (!bindService(serviceIntent, serviceConnection, Context.BIND_AUTO_CREATE)) {
                                // バインド失敗
                                result.success(mapOf("isRunning" to false))
                            }
                        } catch (e: Exception) {
                            println("タイマー状態取得エラー: ${e.message}")
                            result.success(mapOf("isRunning" to false))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    
        // ブロードキャストレシーバーを登録
        val filter = IntentFilter("com.example.pomodoro_app.EXPIRATIONS_UPDATED")
        registerReceiver(expirationReceiver, filter)

         // タイマー関連のブロードキャストレシーバーを登録
        val timerFilter = IntentFilter().apply {
            addAction("com.example.pomodoro_app.TIMER_UPDATE")
            addAction("com.example.pomodoro_app.POMODORO_COMPLETE")
            addAction("com.example.pomodoro_app.POMODORO_SKIPPED")
            addAction("com.example.pomodoro_app.BREAK_COMPLETE")
        }
        registerReceiver(timerUpdateReceiver, timerFilter)
    }
    
    override fun onDestroy() {
        if (::appController.isInitialized) {
            appController.dispose()
        }
        unregisterReceiver(expirationReceiver)
        unregisterReceiver(timerUpdateReceiver)
        super.onDestroy()
    }
    // override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    // // ここを追加
    // super.onActivityResult(requestCode, resultCode, data);
    // // ここで色々する
    // }
    // タイマー更新用のBroadcastReceiverを追加
    private val timerUpdateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            println("ブロードキャスト受信: ${intent.action}")
            if (flutterEngine != null) {
                val channel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, 
                                        "com.example.pomodoro_app/pomodoro_timer")

                when (intent.action) {
                    "com.example.pomodoro_app.TIMER_UPDATE" -> {
                        val data = HashMap<String, Any>()
                        data["isRunning"] = intent.getBooleanExtra("isRunning", false)
                        data["isPaused"] = intent.getBooleanExtra("isPaused", false)
                        data["isBreak"] = intent.getBooleanExtra("isBreak", false)
                        data["remainingSeconds"] = intent.getIntExtra("remainingSeconds", 0)
                        data["totalSeconds"] = intent.getIntExtra("totalSeconds", 0)
                        println("Flutter側にタイマー更新を送信: ${data["remainingSeconds"]}秒")
                        channel.invokeMethod("timerUpdate", data)
                    }
                    "com.example.pomodoro_app.POMODORO_COMPLETE" -> {
                        val data = HashMap<String, Any>()
                        data["taskId"] = intent.getIntExtra("taskId", -1)
                        data["taskName"] = intent.getStringExtra("taskName") ?: ""
                        data["startTime"] = intent.getLongExtra("startTime", 0)
                        data["endTime"] = intent.getLongExtra("endTime", 0)
                        data["durationMinutes"] = intent.getIntExtra("durationMinutes", 0)

                        channel.invokeMethod("pomodoroComplete", data)
                    }
                    "com.example.pomodoro_app.POMODORO_SKIPPED" -> {
                        val data = HashMap<String, Any>()
                        data["taskId"] = intent.getIntExtra("taskId", -1)
                        data["taskName"] = intent.getStringExtra("taskName") ?: ""
                        data["startTime"] = intent.getLongExtra("startTime", 0)
                        data["endTime"] = intent.getLongExtra("endTime", 0)
                        data["durationMinutes"] = intent.getIntExtra("durationMinutes", 0)
                        data["skipped"] = intent.getBooleanExtra("skipped", false)

                        channel.invokeMethod("pomodoroSkipped", data)
                    }
                    "com.example.pomodoro_app.BREAK_COMPLETE" -> {
                        channel.invokeMethod("breakComplete", null)
                    }
                }
            }
            else {
                println("Flutterエンジンが初期化されていません")
            }
        }
    }
}