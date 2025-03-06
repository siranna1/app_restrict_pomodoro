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
            "startMonitoring" -> {
                startMonitoring()
                result.success(true)
            }
            "stopMonitoring" -> {
                stopMonitoring()
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
            else -> {
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
    
    private fun updateRestrictedPackages(packages: List<String>) {
        this.restrictedPackages = packages
    }
    
    private fun startMonitoring() {
        if (isMonitoring) return
        
        isMonitoring = true
        monitorTimer = Timer().apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    val currentApp = getCurrentForegroundApp()
                    if (currentApp != null && restrictedPackages.contains(currentApp)) {
                        killApp(currentApp)
                        activity.runOnUiThread {
                            // 通知処理
                        }
                    }
                }
            }, 0, 1000)
        }
    }
    
    private fun stopMonitoring() {
        monitorTimer?.cancel()
        monitorTimer = null
        isMonitoring = false
    }
    
    private fun killApp(packageName: String) {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        am.killBackgroundProcesses(packageName)
    }
    
    private fun getCurrentForegroundApp(): String? {
        if (!hasUsageStatsPermission()) {
            return null
        }
        
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        val appList = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, time - 60000, time)
        
        if (appList != null && appList.isNotEmpty()) {
            val mySortedMap = TreeMap<Long, UsageStats>()
            for (usageStats in appList) {
                mySortedMap[usageStats.lastTimeUsed] = usageStats
            }
            if (mySortedMap.isNotEmpty()) {
                return mySortedMap[mySortedMap.lastKey()]?.packageName
            }
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
        stopMonitoring()
    }
}