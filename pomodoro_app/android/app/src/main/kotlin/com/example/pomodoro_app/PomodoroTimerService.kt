package com.example.pomodoro_app

import android.app.*
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.*
import android.os.PowerManager.WakeLock
import androidx.core.app.NotificationCompat

class PomodoroTimerService : Service() {
    companion object {
        private const val NOTIFICATION_ID_TIMER = 2001       // タイマー通知のID
        private const val NOTIFICATION_ID_COMPLETE = 2002    // 完了通知のID
        private const val NOTIFICATION_ID_ACTION = 2003      // アクション通知のID
    }
    private var pomodoroTimer: CountDownTimer? = null
    private var isTimerRunning = false
    private var isPaused = false
    private var isBreak = false
    private var remainingTimeMillis: Long = 0
    private var totalTimeMillis: Long = 0
    private var currentTaskId: Int = -1
    private var currentTaskName: String = ""
    private var sessionStartTime: Long = 0
    private var wakeLock: WakeLock? = null
    
    private val CHANNEL_ID = "PomodoroTimerChannel"
    private val NOTIFICATION_ID = 2001
    
    // Binderの実装
    private val binder = LocalBinder()
    
    inner class LocalBinder : Binder() {
        fun getService(): PomodoroTimerService = this@PomodoroTimerService
    }
    
    override fun onBind(intent: Intent): IBinder {
        return binder
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_POMODORO" -> {
                val minutes = intent.getIntExtra("minutes", 25)
                val taskId = intent.getIntExtra("taskId", -1)
                val taskName = intent.getStringExtra("taskName") ?: ""
                startPomodoro(minutes, taskId, taskName)
            }
            "START_BREAK" -> {
                val minutes = intent.getIntExtra("minutes", 5)
                val isLongBreak = intent.getBooleanExtra("isLongBreak", false)
                startBreak(minutes, isLongBreak)
            }
            "PAUSE_TIMER" -> {
                pausePomodoro()
            }
            "RESUME_TIMER" -> {
                resumePomodoro()
            }
            "STOP_TIMER" -> {
                stopPomodoro()
            }
            "SKIP_TIMER" -> {
                skipTimer()
            }
            "CANCEL_NOTIFICATIONS" -> {
                cancelCompletionNotifications()
            }
        }
        
        // サービスが強制終了された場合に再起動
        return START_STICKY
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ポモドーロタイマー",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "ポモドーロタイマーの状態を表示します"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(title: String, message: String, ongoing: Boolean): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                PendingIntent.FLAG_IMMUTABLE else 0
        )
        
        val pauseResumeIntent = Intent(this, PomodoroTimerService::class.java).apply {
            action = if (isPaused) "RESUME_TIMER" else "PAUSE_TIMER"
        }
        val pauseResumePendingIntent = PendingIntent.getService(
            this, 1, pauseResumeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                PendingIntent.FLAG_IMMUTABLE else 0)
        )
        
        val stopIntent = Intent(this, PomodoroTimerService::class.java).apply {
            action = "STOP_TIMER"
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 2, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                PendingIntent.FLAG_IMMUTABLE else 0)
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentIntent(pendingIntent)
            .setOngoing(ongoing)
            .addAction(0, if (isPaused) "再開" else "一時停止", pauseResumePendingIntent)
            .addAction(0, "停止", stopPendingIntent)
            .build()
    }
    
    // タイマー開始メソッド
    fun startPomodoro(minutes: Int, taskId: Int, taskName: String) {
         // 既存の通知をキャンセル
        cancelCompletionNotifications()
        stopPomodoro() // 既存のタイマーがあれば停止
        
        isTimerRunning = true
        isPaused = false
        isBreak = false
        totalTimeMillis = minutes * 60 * 1000L
        remainingTimeMillis = totalTimeMillis
        currentTaskId = taskId
        currentTaskName = taskName
        sessionStartTime = System.currentTimeMillis()
        
        // PowerManagerを使用してCPUをスリープ状態にさせない
        acquireWakeLock()
        
        startCountDown()
        startForeground(NOTIFICATION_ID_TIMER, createNotification(
            "ポモドーロ実行中", 
            formatTime(remainingTimeMillis), 
            true
        ))
    }
    
    // 休憩タイマー開始メソッド
    fun startBreak(minutes: Int, isLongBreak: Boolean = false) {
         // 既存の通知をキャンセル
        cancelCompletionNotifications()
        stopPomodoro() // 既存のタイマーがあれば停止
        
        isTimerRunning = true
        isPaused = false
        isBreak = true
        totalTimeMillis = minutes * 60 * 1000L
        remainingTimeMillis = totalTimeMillis
        sessionStartTime = System.currentTimeMillis()
        
        // PowerManagerを使用してCPUをスリープ状態にさせない
        acquireWakeLock()
        
        startCountDown()
        startForeground(NOTIFICATION_ID_TIMER, createNotification(
            "休憩中", 
            formatTime(remainingTimeMillis), 
            true
        ))
    }
    
    // WakeLockを取得
    private fun acquireWakeLock() {
        releaseWakeLock() // 既存のWakeLockがあれば解放
        
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "PomodoroApp::PomodoroWakeLock"
        )
        wakeLock?.acquire(totalTimeMillis + 5000) // タイマー時間+5秒間スリープを防止
    }
    
    // WakeLockを解放
    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }
    
    // カウントダウン処理
    private fun startCountDown() {
        pomodoroTimer?.cancel()
        
        pomodoroTimer = object : CountDownTimer(remainingTimeMillis, 1000) {
            override fun onTick(millisUntilFinished: Long) {
                remainingTimeMillis = millisUntilFinished
                // 通知を更新して残り時間を表示
                val notification = createNotification(
                    if (isBreak) "休憩中" else "ポモドーロ実行中",
                    formatTime(remainingTimeMillis),
                    true
                )
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.notify(NOTIFICATION_ID_TIMER, notification)
                
                // Flutter側に進捗を通知
                sendTimerUpdate()
            }
            
            override fun onFinish() {
                if (!isBreak) {
                    // ポモドーロ完了
                    completePomodoro()
                } else {
                    // 休憩完了
                    completeBreak()
                }
            }
        }.start()
    }
    
    // ポモドーロ完了時の処理
    private fun completePomodoro() {
        isTimerRunning = false
        releaseWakeLock()
        
        // セッション完了通知
        val title = "ポモドーロ完了"
        val message = "休憩時間です。次のセッションを始める準備をしましょう。"
        
        // 通知を更新
        showCompletionNotification(title, message, "pomodoro_complete")
        
        // Flutter側に完了を通知
        sendPomodoroComplete()
    }
    
    // 休憩完了時の処理
    private fun completeBreak() {
        isTimerRunning = false
        releaseWakeLock()
        
        // 休憩完了通知
        val title = "休憩終了"
        val message = "次のポモドーロセッションを始めましょう。"
        
        // 通知を更新
        showCompletionNotification(title, message, "break_complete")
        
        // Flutter側に完了を通知
        sendBreakComplete()
    }
    
    // タイマー一時停止
    fun pausePomodoro() {
        if (isTimerRunning && !isPaused) {
            isPaused = true
            pomodoroTimer?.cancel()
            
            val notification = createNotification("一時停止中", formatTime(remainingTimeMillis), true)
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID_TIMER, notification)
            
            sendTimerUpdate()
        }
    }
    
    // タイマー再開
    fun resumePomodoro() {
        if (isTimerRunning && isPaused) {
            isPaused = false
            startCountDown()
            
            val notification = createNotification(
                if (isBreak) "休憩中" else "ポモドーロ実行中",
                formatTime(remainingTimeMillis),
                true
            )
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(NOTIFICATION_ID_TIMER, notification)
        }
    }
    
    // タイマーをスキップ
    fun skipTimer() {
        if (isTimerRunning) {
            pomodoroTimer?.cancel()
            
            if (!isBreak) {
                // 作業時間をスキップ - 実際に経過した時間を記録
                val elapsedMillis = totalTimeMillis - remainingTimeMillis
                val elapsedMinutes = (elapsedMillis / 1000 / 60).toInt()
                
                //if (elapsedMinutes >= 1) {
                    // 1分以上経過していれば記録
                    val data = HashMap<String, Any>()
                    data["taskId"] = currentTaskId
                    data["taskName"] = currentTaskName
                    data["startTime"] = sessionStartTime
                    data["endTime"] = System.currentTimeMillis()
                    data["durationMinutes"] = elapsedMinutes
                    data["skipped"] = true
                    
                    val intent = Intent("com.example.pomodoro_app.POMODORO_SKIPPED")
                    intent.putExtra("taskId", currentTaskId)
                    intent.putExtra("taskName", currentTaskName)
                    intent.putExtra("startTime", sessionStartTime)
                    intent.putExtra("endTime", System.currentTimeMillis())
                    intent.putExtra("durationMinutes", elapsedMinutes)
                    intent.putExtra("skipped", true)
                    intent.setPackage(packageName)
                    sendBroadcast(intent)
                //}
                
                // 休憩モードに移行するか聞く
                val title = "ポモドーロスキップ"
                val message = "${elapsedMinutes}分間の作業を記録しました。休憩を開始しますか？"
                //showActionNotification(title, message, "skip_to_break")
            } else {
                // 休憩をスキップして次のポモドーロへ
                sendBreakComplete()
            }
            
            isTimerRunning = false
            releaseWakeLock()
        }
    }
    
    // タイマー停止
    fun stopPomodoro() {
        pomodoroTimer?.cancel()
        isTimerRunning = false
        isPaused = false
        releaseWakeLock()
        
        // フォアグラウンドサービスを停止（通知を削除）
        stopForeground(true)
        
        sendTimerUpdate()
    }
    
    // 残り時間を整形するヘルパーメソッド
    private fun formatTime(timeMillis: Long): String {
        val minutes = (timeMillis / 1000) / 60
        val seconds = (timeMillis / 1000) % 60
        return String.format("%02d:%02d", minutes, seconds)
    }
    
    // 完了通知を表示するためのヘルパーメソッド
    private fun showCompletionNotification(title: String, message: String, action: String) {
        // 別のチャンネルを使用して音を出す通知を表示
        val channelId = "pomodoro_completion_channel"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "ポモドーロ完了通知",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "ポモドーロまたは休憩完了時の通知"
                enableVibration(true)
                enableLights(true)
                lightColor = Color.GREEN
            }
            notificationManager.createNotificationChannel(channel)
        }
        
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        intent?.action = action
        val pendingIntent = PendingIntent.getActivity(
            this, 1, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                PendingIntent.FLAG_IMMUTABLE else 0)
        )
        
        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .build()
        
        // 通常の通知とは別のIDを使用
        notificationManager.notify(NOTIFICATION_ID_COMPLETE, notification)
        
        // バイブレーション
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
        }
    }
    
    // アクション付き通知を表示
    private fun showActionNotification(title: String, message: String, action: String) {
        val channelId = "pomodoro_action_channel"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "ポモドーロアクション通知",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "ポモドーロアクション選択用の通知"
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }
        
        // アプリを開くインテント
        val appIntent = packageManager.getLaunchIntentForPackage(packageName)
        appIntent?.action = action
        val appPendingIntent = PendingIntent.getActivity(
            this, 3, appIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                PendingIntent.FLAG_IMMUTABLE else 0)
        )
        
        // 休憩を開始するインテント
        val breakIntent = Intent(this, PomodoroTimerService::class.java).apply {
            this.action = "START_BREAK"
            putExtra("minutes", 5) // デフォルトの休憩時間
        }
        val breakPendingIntent = PendingIntent.getService(
            this, 4, breakIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                PendingIntent.FLAG_IMMUTABLE else 0)
        )
        
        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentIntent(appPendingIntent)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .addAction(0, "はい", breakPendingIntent)
            .addAction(0, "いいえ", appPendingIntent)
            .build()
        
        notificationManager.notify(NOTIFICATION_ID_ACTION, notification)
    }

    // 完了通知をキャンセルするメソッド
    private fun cancelCompletionNotifications() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // 完了通知のIDを使用してキャンセル
        notificationManager.cancel(NOTIFICATION_ID_COMPLETE)
        notificationManager.cancel(NOTIFICATION_ID_ACTION)
        println("完了通知をキャンセルしました")
    }
    
    // Flutter側にタイマー更新を通知
    private fun sendTimerUpdate() {
        val intent = Intent("com.example.pomodoro_app.TIMER_UPDATE")
        intent.putExtra("isRunning", isTimerRunning)
        intent.putExtra("isPaused", isPaused)
        intent.putExtra("isBreak", isBreak)
        intent.putExtra("remainingSeconds", (remainingTimeMillis / 1000).toInt())
        intent.putExtra("totalSeconds", (totalTimeMillis / 1000).toInt())
        intent.setPackage(packageName)
        sendBroadcast(intent)
        // デバッグログを追加
        println("タイマー更新を送信: ${(remainingTimeMillis / 1000).toInt()}秒 - isRunning: $isTimerRunning")
    }
    
    // Flutter側にポモドーロ完了を通知
    private fun sendPomodoroComplete() {
        val intent = Intent("com.example.pomodoro_app.POMODORO_COMPLETE")
        intent.putExtra("taskId", currentTaskId)
        intent.putExtra("taskName", currentTaskName)
        intent.putExtra("startTime", sessionStartTime)
        intent.putExtra("endTime", System.currentTimeMillis())
        intent.putExtra("durationMinutes", (totalTimeMillis / 1000 / 60).toInt())
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }
    
    // Flutter側に休憩完了を通知
    private fun sendBreakComplete() {
        val intent = Intent("com.example.pomodoro_app.BREAK_COMPLETE")
        intent.setPackage(packageName)
        sendBroadcast(intent)
    }
    // 現在のタイマー状態を取得するメソッド
    fun getTimerStatus(): Map<String, Any> {
        val status = HashMap<String, Any>()
        status["isRunning"] = isTimerRunning
        status["isPaused"] = isPaused
        status["isBreak"] = isBreak
        status["remainingSeconds"] = (remainingTimeMillis / 1000).toInt()
        status["totalSeconds"] = (totalTimeMillis / 1000).toInt()
        return status
    }
    
    override fun onDestroy() {
        stopPomodoro()
        super.onDestroy()
        
        // サービスの自己再起動（追加の安全策）
        val intent = Intent(applicationContext, PomodoroTimerService::class.java)
        intent.action = "START_POMODORO"
        startService(intent)
    }
}