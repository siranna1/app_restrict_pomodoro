package com.example.pomodoro_app

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

class AndroidAppController(
    private val context: Context,
    private val activity: Activity
) : MethodChannel.MethodCallHandler {
    
    companion object {
        private const val CHANNEL = "com.example.pomodoro_app/app_control"
        
        fun registerWith(flutterEngine: FlutterEngine, context: Context, activity: Activity) {
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            channel.setMethodCallHandler(AndroidAppController(context, activity))
        }
    }
    // 現在表示中のオーバーレイを追跡するための変数
    private var currentOverlayView: View? = null
    private var overlayShownTimestamp: Long = 0
    private var lastRestrictedPackage: String? = null
    // 監視タイマーの間隔を長くする（1秒から3秒に）
    private val MONITORING_INTERVAL = 3000L  // 3秒ごとにチェック
    
    private var monitorTimer: Timer? = null
    private var restrictedPackages: List<String> = ArrayList()
    private var isMonitoring = false
    
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> {
                result.success(true)
            }
            "hasUsageStatsPermission" -> {
                result.success(hasUsageStatsPermission())
            }
            "openUsageStatsSettings" -> {
                openUsageStatsSettings()
                result.success(true)
            }
            "updateRestrictedPackages" -> {
                val packages = call.argument<List<String>>("packages")
                if (packages != null) {
                    updateRestrictedPackages(packages)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENT", "パッケージリストが提供されていません", null)
                }
            }
            "killApp" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    killApp(packageName)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENT", "パッケージ名が提供されていません", null)
                }
            }
            "getCurrentForegroundApp" -> {
                val foregroundApp = getCurrentForegroundApp()
                if (foregroundApp != null) {
                    result.success(foregroundApp)
                } else {
                    result.error("PERMISSION_DENIED", "Usage Stats権限がありません", null)
                }
            }
            "getInstalledApps" -> {
                result.success(getInstalledApps())
            }
            "checkOverlayPermission" -> {
                result.success(Settings.canDrawOverlays(context))
            }
            "requestOverlayPermission" -> {
                val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                intent.data = Uri.parse("package:${context.packageName}")
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)
                result.success(true)
            }
            "startMonitoringService" -> {
                
                val packages = call.argument<List<String>>("packages")
                if (packages != null) {
                    val success = startMonitoringService(packages)
                    result.success(success)
                } else {
                    result.error("INVALID_ARGUMENT", "パッケージリストが提供されていません", null)
                }
            }
            "stopMonitoringService" -> {
                val success = stopMonitoringService()
                result.success(success)
            }
            "isServiceRunning" -> {
                val isRunning = isServiceRunning()
                result.success(isRunning)
            }
            "checkBatteryOptimization" -> {
                result.success(isBatteryOptimizationIgnored())
            }
            "openBatteryOptimizationSettings" -> {
                openBatteryOptimizationSettings()
                result.success(true)
            }
            "registerAppUnlock" -> {
                val packageName = call.argument<String>("packageName")
                val expiryTime = call.argument<Long>("expiryTime")

                if (packageName != null && expiryTime != null) {
                    val success = registerAppUnlock(packageName, expiryTime)
                    result.success(success)
                } else {
                    result.error("INVALID_ARGUMENT", "パッケージ名または期限が無効です", null)
                }
            }else -> {
            result.notImplemented()
            }
        }
        
    }

    
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        } else {
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }
    
    private fun openUsageStatsSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        activity.startActivity(intent)
    }

    // 制限対象アプリのリストを更新
    fun updateRestrictedPackages(packages: List<String>): Boolean {
        try {
            println("AndroidAppController: 制限パッケージリストを更新します: $packages")

            // メンバー変数を更新
            restrictedPackages = packages
            // 監視中ならサービスにも通知
            if (isMonitoring) {
                val intent = Intent(context, AppMonitorService::class.java)
                intent.action = "UPDATE_PACKAGES"
                intent.putStringArrayListExtra("packages", ArrayList(packages))

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                println("サービスに制限パッケージ更新通知を送信しました")
            }

            return true
        } catch (e: Exception) {
            println("制限パッケージ更新エラー: ${e.message}")
            e.printStackTrace()
            return false
        }
    }
    fun registerAppUnlock(packageName: String, expiryTimeMillis: Long): Boolean {
        try {
            // Shared Preferencesに保存
            val prefs = context.getSharedPreferences("app_unlock_prefs", Context.MODE_PRIVATE)
            prefs.edit()
                .putLong("unlock_expiry_$packageName", expiryTimeMillis)
                .apply()

            println("アプリ解除情報を保存しました: $packageName, 期限: ${Date(expiryTimeMillis)}")

            // サービスにも通知
            val intent = Intent(context, AppMonitorService::class.java)
            intent.action = "UPDATE_UNLOCK_INFO"
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }

            return true
        } catch (e: Exception) {
            println("アプリ解除登録エラー: ${e.message}")
            return false
        }
    }
    
    

    // サービス関連メソッドの追加

    fun startMonitoringService(packages: List<String>): Boolean {
        try {
            if(isMonitoring) 
            {
                println("サービスは既に起動しています")
                return true
            }
            if (!hasUsageStatsPermission()) {
                println("使用状況アクセス権限がありません - 監視開始できません")
                return false
            }
            println("サービス起動を開始します。パッケージ数: ${packages.size}")
            val intent = Intent(context, AppMonitorService::class.java)
            intent.action = "START_MONITORING"
            intent.putStringArrayListExtra("packages", ArrayList(packages))
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                println("startForegroundService を呼び出します")
                context.startForegroundService(intent)
            } else {
                println("startService を呼び出します")
                context.startService(intent)
            }

            isMonitoring = true

            println("サービス起動が成功しました")
            return true
        } catch (e: Exception) {
            println("サービス起動エラー: ${e.message}")
            e.printStackTrace()
            return false
        }
    }
    fun stopMonitoringService(): Boolean {
        try {
            isMonitoring = false
            val intent = Intent(context, AppMonitorService::class.java)
            intent.action = "STOP_MONITORING"
            context.startService(intent)


            return true
        } catch (e: Exception) {
            println("サービス停止エラー: ${e.message}")
            return false
        }
    }
    // サービス状態確認メソッドの実装
    fun isServiceRunning(): Boolean {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        for (service in manager.getRunningServices(Integer.MAX_VALUE)) {
            if (AppMonitorService::class.java.name == service.service.className) {
                return true
            }
        }
        return false
    }

    private fun requestIgnoreBatteryOptimization() {
        // 何もしない - 設定画面への自動遷移を停止
        // ユーザーがダイアログで「設定を開く」を選択した場合のみ設定画面を開く

        //try {
        //    val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        //    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
        //        !powerManager.isIgnoringBatteryOptimizations(context.packageName)) {
        //        
        //        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
        //        intent.data = Uri.parse("package:${context.packageName}")
        //        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        //        context.startActivity(intent)
        //    }
        //} catch (e: Exception) {
        //    println("バッテリー最適化除外リクエストエラー: ${e.message}")
        //}
    }

    // バッテリー最適化の状態をチェック
    fun isBatteryOptimizationIgnored(): Boolean {
        try {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                powerManager.isIgnoringBatteryOptimizations(context.packageName)
            } else {
                true // Android M未満ではこの設定は不要
            }
        } catch (e: Exception) {
            println("バッテリー最適化状態チェックエラー: ${e.message}")
            return false
        }
    }

    // バッテリー最適化設定画面を開く
    fun openBatteryOptimizationSettings() {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
            intent.data = Uri.parse("package:${context.packageName}")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)
        } catch (e: Exception) {
            println("バッテリー最適化設定画面オープンエラー: ${e.message}")
        }
    }
    
    private fun killApp(packageName: String) {
        try {
            println("アプリ $packageName を終了させます")
            // オーバーレイダイアログを表示
            showOverlayRestrictionDialog(packageName)
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            //am.killBackgroundProcesses(packageName)
            println("アプリ $packageName を終了させました")
        } catch (e: Exception) {
            println("アプリの終了エラー: ${e.message}")
        }
    }
    // 新しく追加するオーバーレイダイアログ表示関数
    private fun showOverlayRestrictionDialog(packageName: String) {
        if (!Settings.canDrawOverlays(context)) {
            // オーバーレイ権限がない場合は権限設定画面を開く
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
            intent.data = Uri.parse("package:${context.packageName}")
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            context.startActivity(intent)
            return
        }

          // 同じパッケージに対するオーバーレイが5秒以内に表示されていたらスキップ
        val currentTime = System.currentTimeMillis()
        if (lastRestrictedPackage == packageName && 
            currentTime - overlayShownTimestamp < 5000) {
            return
        }

        activity.runOnUiThread {
            // 既存のオーバーレイがあれば閉じる
            removeCurrentOverlay()

            val appName = getAppName(packageName)

            // オーバーレイウィンドウの作成
            val inflater = context.getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
            val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

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
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or// タッチイベントを受け取る
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
                context.startActivity(homeIntent)

                // バイブレーション（触覚フィードバック）
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
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
                    context.startActivity(homeIntent)

                    // バイブレーション
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
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

            // 5秒後に自動的に閉じる（オプション）
            /*
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    windowManager.removeView(view)
                    // ホーム画面に戻る
                    val homeIntent = Intent(Intent.ACTION_MAIN)
                    homeIntent.addCategory(Intent.CATEGORY_HOME)
                    homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    context.startActivity(homeIntent)
                } catch (e: Exception) {
                    // ビューがすでに削除されている可能性がある
                }
            }, 5000)
            */
        }
    }
     // 現在のオーバーレイを削除するヘルパーメソッド
    private fun removeCurrentOverlay() {
        val view = currentOverlayView
        if (view != null) {
            try {
                val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
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
            val pm = context.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            return pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            return packageName
        }
    }
    
    private fun getCurrentForegroundApp(): String? {
        if (!hasUsageStatsPermission()) {
            return null
        }

        try {
            val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val time = System.currentTimeMillis()
            // 過去5秒間の使用状況を取得
            val appList = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 5000, time)

            if (appList != null && appList.isNotEmpty()) {
                // 最後に使用したアプリを特定
                var recentApp: UsageStats? = null
                var latestTime = 0L

                for (usageStats in appList) {
                    if (usageStats.lastTimeUsed > latestTime) {
                        latestTime = usageStats.lastTimeUsed
                        recentApp = usageStats
                    }
                }

                if (recentApp != null) {
                    return recentApp.packageName
                }
            }
        } catch (e: Exception) {
            println("現在のフォアグラウンドアプリ取得エラー: ${e.message}")
        }

        return null
    }

    // // Drawableを画像データに変換
    // private fun drawableToBase64(drawable: Drawable): String {
    //     val bitmap = Bitmap.createBitmap(
    //         drawable.intrinsicWidth,
    //         drawable.intrinsicHeight,
    //         Bitmap.Config.ARGB_8888
    //     )
    //     val canvas = Canvas(bitmap)
    //     drawable.setBounds(0, 0, canvas.width, canvas.height)
    //     drawable.draw(canvas)
        
    //     val byteArrayOutputStream = ByteArrayOutputStream()
    //     bitmap.compress(Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream)
    //     val byteArray = byteArrayOutputStream.toByteArray()
    //     return Base64.encodeToString(byteArray, Base64.DEFAULT)
    // }

    @SuppressLint("QueryPermissionsNeeded")
    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = context.packageManager
        val appList = mutableListOf<Map<String, Any>>()
        
        try {
            // 全てのアプリを取得するためのインテント
            val mainIntent = Intent(Intent.ACTION_MAIN, null)
            mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)
            
            // ランチャーアプリ（起動可能なアプリ）のリストを取得
            val resolveInfos = pm.queryIntentActivities(mainIntent, 0)
            
            for (resolveInfo in resolveInfos) {
                try {
                    val packageName = resolveInfo.activityInfo.packageName
                    val appInfo = pm.getApplicationInfo(packageName, 0)
                    
                    // システム設定アプリなど、特定のカテゴリを除外
                    if (packageName.startsWith("com.android.settings") || 
                        packageName.startsWith("com.android.systemui") ||
                        packageName.startsWith("com.android.providers")) {
                        continue
                    }
                    
                    // アプリの基本情報
                    val appName = pm.getApplicationLabel(appInfo).toString()
                    val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

                    
                    // ユーザーアプリのみ表示（または主要アプリ）
                    if (!isSystemApp || isImportantSystemApp(packageName)) {
                        // アプリアイコンを取得してBase64エンコード
                        val icon = resolveInfo.loadIcon(pm)
                        val iconBase64 = if (icon != null) drawableToBase64(icon) else null
                        appList.add(mapOf(
                            "name" to appName,
                            "packageName" to packageName,
                            "isSystemApp" to isSystemApp,
                            "isLauncher" to true,
                            "iconBase64" to (iconBase64 ?: "")
                        ))
                    }
                } catch (e: Exception) {
                    // 個別アプリの処理に失敗しても続行
                    continue
                }
            }
            
            // ユーザーアプリを先頭に、次にアプリ名でソート
            return appList.sortedWith(
                compareBy(
                    { it["isSystemApp"] as Boolean },  // ユーザーアプリを先に（falseが先）
                    { it["name"] as String }           // 名前でソート
                )
            )
            
        } catch (e: Exception) {
            // 全体的な処理に失敗した場合は空のリストを返す
            e.printStackTrace()
            return emptyList()
        }
    }

    // Drawableを画像データに変換
    private fun drawableToBase64(drawable: android.graphics.drawable.Drawable): String {
        try {
            val bitmap = android.graphics.Bitmap.createBitmap(
                drawable.intrinsicWidth.coerceAtMost(200),  // サイズ制限を設ける
                drawable.intrinsicHeight.coerceAtMost(200),
                android.graphics.Bitmap.Config.ARGB_8888
            )

            val canvas = android.graphics.Canvas(bitmap)
            drawable.setBounds(0, 0, canvas.width, canvas.height)
            drawable.draw(canvas)

            val byteArrayOutputStream = java.io.ByteArrayOutputStream()
            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, byteArrayOutputStream)
            val byteArray = byteArrayOutputStream.toByteArray()
            return android.util.Base64.encodeToString(byteArray, android.util.Base64.NO_WRAP)
        } catch (e: Exception) {
            e.printStackTrace()
            return ""
        }
    }

    // 重要な標準アプリかどうかを判定
    private fun isImportantSystemApp(packageName: String): Boolean {
        val importantApps = listOf(
            "com.google.android.gm",       // Gmail
            "com.google.android.apps.maps", // Google Maps
            "com.google.android.youtube",   // YouTube
            "com.google.android.apps.photos", // Google Photos
            "com.android.chrome",          // Chrome
            "com.android.calculator2",     // 電卓
            "com.android.calendar",        // カレンダー
            "com.android.camera",          // カメラ
            "com.android.contacts"         // 連絡先
        )
        return importantApps.contains(packageName)
    }
    
    // アプリケーションが終了する時にリソースを解放
    fun dispose() {
        //stopMonitoringService()
        removeCurrentOverlay()
    }
}