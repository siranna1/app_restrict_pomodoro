package com.example.pomodoro_app

import android.app.*
import android.os.*
import android.graphics.Color
import android.annotation.SuppressLint
import android.app.Activity
import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.util.Base64
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.*
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Vibrator
import android.os.VibrationEffect
import android.view.Gravity
import android.view.LayoutInflater
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import android.view.View
import android.view.MotionEvent
import android.os.PowerManager

class AppMonitorService : Service() {
    private var monitorTimer: Timer? = null
    private var restrictedPackages: List<String> = ArrayList()
    private var isRunning = false
    private val CHANNEL_ID = "PomodoroAppMonitorService"
    private val NOTIFICATION_ID = 1001
    // 現在表示中のオーバーレイを追跡するための変数
    private var currentOverlayView: View? = null
    private var overlayShownTimestamp: Long = 0
    private var lastRestrictedPackage: String? = null
    private var unlockExpirationsTimer: Timer? = null

    private val unlockedApps = HashMap<String, Long>()
    
    // Binderの実装
    private val binder = LocalBinder()
    
    inner class LocalBinder : Binder() {
        fun getService(): AppMonitorService = this@AppMonitorService
    }
    
    override fun onBind(intent: Intent): IBinder {
        return binder
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // コマンドに応じた処理
        when (intent?.action) {
            "START_MONITORING" -> {
                val packages = intent.getStringArrayListExtra("packages")
                if (packages != null) {
                    restrictedPackages = packages
                    startMonitoring()
                }
            }
            "STOP_MONITORING" -> {
                stopMonitoring()
            }
            "UPDATE_PACKAGES" -> {
                val packages = intent.getStringArrayListExtra("packages")
                if (packages != null) {
                    println("制限パッケージリストを更新: $packages")
                    restrictedPackages = packages
                }
            }
            "START_EXPIRATION_CHECKER" -> {
                startUnlockExpirationChecker()
            }
            "CHECK_EXPIRATIONS_INTERNAL" -> {
                // 直接チェックを実行
                startUnlockExpirationChecker()
            }
            "UPDATE_UNLOCK_INFO" -> {
                loadUnlockInfo()
            }
            else -> {
                println("不明なコマンド: ${intent?.action}")
            }
        }
        
        // フォアグラウンドサービスとして実行
        startForeground(NOTIFICATION_ID, createNotification())
        
        // サービスが強制終了された場合に再起動
        return START_STICKY
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "アプリ監視サービス",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "ポモドーロ中にアプリ使用を制限するサービス"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                PendingIntent.FLAG_IMMUTABLE else 0
        )
        
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        
        return builder
            .setContentTitle("ポモドーロアプリ")
            .setContentText("アプリ制限機能が動作中です")
            .setSmallIcon(R.mipmap.ic_launcher) // アイコンを追加
            .setContentIntent(pendingIntent)
            .build()
    }
    
    private fun startMonitoring() {
        if (isRunning) return
        
        if (!hasUsageStatsPermission()) {
            return
        }
        println("アプリ監視サービスを開始 at appmonitorservice.kt")
        isRunning = true

        startUnlockExpirationChecker()

        monitorTimer = Timer().apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    try {
                        // for (app in restrictedPackages) {
                        //     // 制限が無効な場合はスキップ
                        //     if (!app.isRestricted) continue;
                            
                        //     // 現在のアプリが解除リストにあり、まだ期限内かチェック
                        //     val packageName = app.executablePath  // または適切なフィールド
                        //     val expiryTime = unlockedApps[packageName]
                            
                        //     if (expiryTime != null && System.currentTimeMillis() < expiryTime) {
                        //         // まだ解除期間内なのでスキップ
                        //         continue
                        //     }
                            
                        //     // それ以外は通常通り制限チェック
                        //     val isRunning = false // 一時的に無効化、後ほど適切な実装に置き換え
                            
                        //     if (isRunning) {
                        //         // 制限中のアプリが実行されていれば終了
                        //         //_terminateApplication(app.executablePath)
                        //         //_showNotification(app)
                        //     }
                        // }
                        
                        val currentApp = getCurrentForegroundApp()
                        println("現在実行中のアプリ: $currentApp")
                        //解除制限をチェック
                        checkUnlockExpirations()
                        if (currentApp != null && restrictedPackages.contains(currentApp)) {
                            
                            //val expiryTime = unlockedApps[currentApp]
                            
                            //if (expiryTime == null || System.currentTimeMillis() > expiryTime) {
                            //if(!unlockedApps.containsKey(currentApp)) {
                                println("制限対象アプリを検出: $currentApp")

                                // UI通知用にメインスレッドで処理する
                                Handler(Looper.getMainLooper()).post {
                                    killApp(currentApp)
                                }
                            //}
                        }
                    } catch (e: Exception) {
                        println("アプリ監視中にエラー: ${e.message}")
                        e.printStackTrace()
                    }
                }
            }, 0, 3000) // 3秒ごとにチェック
        }
    }
    
    private fun stopMonitoring() {
        monitorTimer?.cancel()
        monitorTimer = null
        isRunning = false
        
        unlockExpirationsTimer?.cancel()
        unlockExpirationsTimer = null

        // フォアグラウンドサービスを停止
        stopForeground(true)
        stopSelf()
    }

    // 期限切れをチェックするタイマーを開始
    private fun startUnlockExpirationChecker() {
        unlockExpirationsTimer?.cancel()

        unlockExpirationsTimer = Timer().apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    try {
                        checkUnlockExpirations()
                    } catch (e: Exception) {
                        println("期限切れチェック中にエラー: ${e.message}")
                    }
                }
            }, 0, 60000) // 1分ごとにチェック
        }
        println("期限切れチェックタイマーを開始しました")
    }
    // 期限切れチェックを修正
    private fun checkUnlockExpirations() {
        val now = System.currentTimeMillis()
        val prefs = getSharedPreferences("app_unlock_prefs", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        var hasChanged = false
    
      // 現在保持している解除情報をチェック
        val expiredApps = ArrayList<String>()
        for ((packageName, expiryTime) in unlockedApps) {
            if (now > expiryTime) {
                // 期限切れ
                expiredApps.add(packageName)
                editor.remove("unlock_expiry_$packageName")
                hasChanged = true
                println("アプリの解除期限切れ: $packageName")
            }
        }

        // 期限切れのアプリを削除
        for (packageName in expiredApps) {
            unlockedApps.remove(packageName)
            restrictedPackages = restrictedPackages + packageName
        }

        if (hasChanged) {
          // 変更があれば保存
            editor.apply()    
          // Flutterアプリに通知（アプリが起動している場合のみ）
            val intent = Intent("com.example.pomodoro_app.EXPIRATIONS_UPDATED")
            intent.setPackage(packageName)
            sendBroadcast(intent)
        }
    }

    // 解除情報をロード
    private fun loadUnlockInfo() {
        val prefs = getSharedPreferences("app_unlock_prefs", Context.MODE_PRIVATE)
        unlockedApps.clear()
        
        // すべてのキーを取得し、アンロック情報を探す
        for (key in prefs.all.keys) {
            if (key.startsWith("unlock_expiry_")) {
                val packageName = key.substringAfter("unlock_expiry_")
                val expiryTime = prefs.getLong(key, 0)
        
                if (expiryTime > 0) {
                    unlockedApps[packageName] = expiryTime
                    println("解除情報をロード: $packageName, 期限: ${Date(expiryTime)}")
                }
            }
        }
    }
    
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
    
    private fun getCurrentForegroundApp(): String? {
        if (!hasUsageStatsPermission()) {
            return null
        }
        
        try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val time = System.currentTimeMillis()
            val appList = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 5000, time)
            
            if (appList != null && appList.isNotEmpty()) {
                var recentApp = appList[0]
                
                for (usageStats in appList) {
                    if (usageStats.lastTimeUsed > recentApp.lastTimeUsed) {
                        recentApp = usageStats
                    }
                }
                
                return recentApp.packageName
            }
        } catch (e: Exception) {
            println("フォアグラウンドアプリ取得エラー: ${e.message}")
        }
        
        return null
    }
    
    private fun killApp(packageName: String) {
        try {
            println("アプリ $packageName を終了させます")
            // オーバーレイダイアログを表示
            showOverlayRestrictionDialog(packageName)
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            //am.killBackgroundProcesses(packageName)
            println("アプリ $packageName を終了させました")
        } catch (e: Exception) {
            println("アプリの終了エラー: ${e.message}")
        }
    }
    
    // サービス用に修正したオーバーレイダイアログ表示関数
    private fun showOverlayRestrictionDialog(packageName: String) {
        if (!Settings.canDrawOverlays(this)) {
            // オーバーレイ権限がない場合は権限設定画面を開く
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
            intent.data = Uri.parse("package:${packageName}")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            return
        }
    
        // 同じパッケージに対するオーバーレイが5秒以内に表示されていたらスキップ
        val currentTime = System.currentTimeMillis()
        if (lastRestrictedPackage == packageName && 
            currentTime - overlayShownTimestamp < 5000) {
            return
        }
    
        // メインスレッドでUIを操作
        Handler(Looper.getMainLooper()).post {
            // 既存のオーバーレイがあれば閉じる
            removeCurrentOverlay()
    
            val appName = getAppName(packageName)
    
            // オーバーレイウィンドウの作成
            val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
            val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    
            // レイアウトをインフレート
            val view = inflater.inflate(R.layout.overlay_restriction, null)
    
            // タイトルとメッセージのセット
            val titleTextView = view.findViewById<TextView>(R.id.overlay_title)
            val messageTextView = view.findViewById<TextView>(R.id.overlay_message)
            val closeButton = view.findViewById<Button>(R.id.close_button)
    
            titleTextView.text = "アプリ制限"
            messageTextView.text = "「$appName」は現在制限されています。\nポモドーロを完了して、アプリを解除しましょう。"
    
            // ウィンドウパラメータの設定
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,  // 幅を画面いっぱいに
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) 
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else 
                    WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or // タッチイベントを受け取る
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or  
                    WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,  // 外部タッチを監視
                PixelFormat.TRANSLUCENT
            )
    
            params.gravity = Gravity.CENTER
    
            // 閉じるボタンのクリックリスナー
            closeButton.setOnClickListener {
                removeCurrentOverlay()
    
                // ホーム画面に戻る
                val homeIntent = Intent(Intent.ACTION_MAIN)
                homeIntent.addCategory(Intent.CATEGORY_HOME)
                homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(homeIntent)
    
                // バイブレーション（触覚フィードバック）
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                    vibrator.vibrate(VibrationEffect.createOneShot(300, VibrationEffect.DEFAULT_AMPLITUDE))
                }
            }
    
            // 画面全体のタッチイベントを処理
            view.setOnTouchListener { _, event ->
                // タッチイベントを検出したら、閉じるボタンと同じ処理を実行
                if (event.action == MotionEvent.ACTION_DOWN) {
                    removeCurrentOverlay()
    
                    // ホーム画面に戻る
                    val homeIntent = Intent(Intent.ACTION_MAIN)
                    homeIntent.addCategory(Intent.CATEGORY_HOME)
                    homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(homeIntent)
    
                    // バイブレーション
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                        vibrator.vibrate(VibrationEffect.createOneShot(300, VibrationEffect.DEFAULT_AMPLITUDE))
                    }
                    true
                } else {
                    false
                }
            }
            
            // 保存して表示
            try {
                windowManager.addView(view, params)
                currentOverlayView = view
                overlayShownTimestamp = currentTime
                lastRestrictedPackage = packageName
            } catch (e: Exception) {
                println("オーバーレイ表示エラー: ${e.message}")
            }
        }
    }
    
    // 現在のオーバーレイを削除するヘルパーメソッド
    private fun removeCurrentOverlay() {
        val view = currentOverlayView
        if (view != null) {
            try {
                val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
                windowManager.removeView(view)
            } catch (e: Exception) {
                println("オーバーレイ削除エラー: ${e.message}")
            }
            currentOverlayView = null
        }
    }
    
    // パッケージ名からアプリ名を取得するヘルパーメソッド
    private fun getAppName(packageName: String): String {
        try {
            val pm = packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            return pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            println("アプリ名取得エラー: ${e.message}")
            return packageName
        }
    }
    
    override fun onDestroy() {
        stopMonitoring()
        super.onDestroy()
        
        // サービスの自己再起動（追加の安全策）
        val restartIntent = Intent(applicationContext, AppMonitorService::class.java)
        restartIntent.action = "START_MONITORING"
        restartIntent.putStringArrayListExtra("packages", ArrayList(restrictedPackages))
        startService(restartIntent)
    }
}