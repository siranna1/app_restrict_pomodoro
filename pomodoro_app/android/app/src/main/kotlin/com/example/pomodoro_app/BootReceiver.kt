package com.example.pomodoro_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            
            // SharedPreferencesから監視設定を読み込む
            val prefs = context.getSharedPreferences("pomodoro_app_prefs", Context.MODE_PRIVATE)
            val monitoringEnabled = prefs.getBoolean("app_monitoring_enabled", false)
            
            if (monitoringEnabled) {
                // 監視が有効ならサービスを起動
                val serviceIntent = Intent(context, AppMonitorService::class.java)
                serviceIntent.action = "START_MONITORING"
                
                // 制限パッケージリストも読み込む
                val restrictedPackages = prefs.getStringSet("restricted_packages", setOf())?.toList() ?: listOf()
                serviceIntent.putStringArrayListExtra("packages", ArrayList(restrictedPackages))
                
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }
}