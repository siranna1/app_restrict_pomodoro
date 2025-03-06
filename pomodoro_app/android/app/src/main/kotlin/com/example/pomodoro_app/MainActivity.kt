package com.example.pomodoro_app

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: FlutterActivity() {
    private lateinit var appController: AndroidAppController
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // AndroidAppControllerの初期化と登録
        appController = AndroidAppController(applicationContext, this)
        AndroidAppController.registerWith(flutterEngine, applicationContext, this)
    }
    
    override fun onDestroy() {
        if (::appController.isInitialized) {
            appController.dispose()
        }
        super.onDestroy()
    }
}