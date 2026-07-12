package com.example.famcare_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_REBOOT ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            Log.d("FamCare", "Boot received - flagging alarm reschedule")

            // C13: Do NOT call startActivity() from a BroadcastReceiver on Android 10+.
            // Background activity starts are restricted and will silently fail.
            // Instead, write a flag to FlutterSharedPreferences. When the user opens
            // the app, MainActivity.onCreate reads this flag and triggers _checkBootReschedule()
            // in main_app_shell.dart which reschedules all alarms.
            try {
                val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("flutter.needs_reschedule", true).apply()
                Log.d("FamCare", "Boot: needs_reschedule flag set in FlutterSharedPreferences")
            } catch (e: Exception) {
                Log.e("FamCare", "Boot: Failed to set reschedule flag: $e")
            }
        }
    }
}
