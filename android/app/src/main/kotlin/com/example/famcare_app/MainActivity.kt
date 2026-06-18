package com.example.famcare_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.provider.Settings
import android.os.Build
import android.view.WindowManager
import android.os.Bundle

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.famcare/settings"
    private val ALARM_CHANNEL = "com.famcare/alarm"
    private var alarmChannel: MethodChannel? = null
    private var pendingAlarmId: Int? = null

    private fun isFullScreenAlarmModeEnabled(): Boolean {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            prefs.getBoolean("flutter.alarm_style_fullscreen", true)
        } catch (_: Exception) {
            true
        }
    }

    private fun shouldWakeForAlarm(intent: Intent?): Boolean {
        val alarmId = intent?.getIntExtra("alarm_id", -1) ?: -1
        return alarmId != -1 && isFullScreenAlarmModeEnabled()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (intent?.getBooleanExtra("reschedule_alarms", false) == true) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.needs_reschedule", true).apply()
        }

        if (shouldWakeForAlarm(intent)) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(true)
                setTurnScreenOn(true)
            } else {
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
                )
            }
        }

        // Check intent for alarm_id (from AlarmService.startActivity)
        extractAlarmIdFromIntent(intent)

        if (pendingAlarmId != null && !isFullScreenAlarmModeEnabled()) {
            moveTaskToBack(true)
        }
    }

    private fun extractAlarmIdFromIntent(intent: Intent?) {
        val alarmId = intent?.getIntExtra("alarm_id", -1) ?: -1
        if (alarmId != -1) {
            pendingAlarmId = alarmId
            // Also store in SharedPreferences as backup
            try {
                val prefs = getSharedPreferences("alarm_plugin_prefs", MODE_PRIVATE)
                prefs.edit().putInt("ringing_alarm_id", alarmId).apply()
            } catch (_: Exception) {}
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Alarm MethodChannel — Flutter calls "getRingingAlarmId" when ready
        alarmChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
        alarmChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getRingingAlarmId" -> {
                    // First check pendingAlarmId from intent extras
                    if (pendingAlarmId != null) {
                        val id = pendingAlarmId
                        pendingAlarmId = null
                        // Also clear from SharedPreferences
                        try {
                            val prefs = getSharedPreferences("alarm_plugin_prefs", MODE_PRIVATE)
                            prefs.edit().remove("ringing_alarm_id").apply()
                        } catch (_: Exception) {}
                        result.success(id)
                        return@setMethodCallHandler
                    }
                    // Fallback: check SharedPreferences
                    try {
                        val prefs = getSharedPreferences("alarm_plugin_prefs", MODE_PRIVATE)
                        val alarmId = prefs.getInt("ringing_alarm_id", -1)
                        if (alarmId != -1) {
                            prefs.edit().remove("ringing_alarm_id").apply()
                            result.success(alarmId)
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // If we have a pending alarm ID, send it to Flutter immediately
        if (pendingAlarmId != null) {
            val id = pendingAlarmId
            pendingAlarmId = null
            flutterEngine.dartExecutor.binaryMessenger.let {
                // Send after a small delay to ensure Dart listener is ready
                android.os.Handler(mainLooper).postDelayed({
                    try {
                        alarmChannel?.invokeMethod("onAlarmRing", id)
                    } catch (_: Exception) {}
                }, 500)
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAutoStart" -> {
                        try {
                            val manufacturer = Build.MANUFACTURER.lowercase()
                            val intent = when {
                                manufacturer.contains("xiaomi") || manufacturer.contains("redmi") ->
                                    Intent().apply {
                                        setClassName("com.miui.securitycenter",
                                            "com.miui.permcenter.autostart.AutoStartManagementActivity")
                                    }
                                manufacturer.contains("oppo") ->
                                    Intent().apply {
                                        setClassName("com.coloros.safecenter",
                                            "com.coloros.safecenter.permission.startup.FakeActivity")
                                    }
                                manufacturer.contains("vivo") ->
                                    Intent().apply {
                                        setClassName("com.vivo.permissionmanager",
                                            "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")
                                    }
                                manufacturer.contains("oneplus") ->
                                    Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                        data = Uri.parse("package:$packageName")
                                    }
                                else ->
                                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                        data = Uri.parse("package:$packageName")
                                    }
                            }
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            // Fallback to app details
                            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallback)
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra("reschedule_alarms", false)) {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            prefs.edit().putBoolean("flutter.needs_reschedule", true).apply()
            return
        }
        // Check for alarm_id in the new intent (from AlarmService.startActivity)
        val alarmId = intent.getIntExtra("alarm_id", -1)
        if (alarmId != -1) {
            try {
                alarmChannel?.invokeMethod("onAlarmRing", alarmId)
            } catch (_: Exception) {}
            return
        }
        // Fallback: check SharedPreferences
        try {
            val prefs = getSharedPreferences("alarm_plugin_prefs", MODE_PRIVATE)
            val storedAlarmId = prefs.getInt("ringing_alarm_id", -1)
            if (storedAlarmId != -1) {
                prefs.edit().remove("ringing_alarm_id").apply()
                alarmChannel?.invokeMethod("onAlarmRing", storedAlarmId)
            }
        } catch (_: Exception) {}
    }
}
