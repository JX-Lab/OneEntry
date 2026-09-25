package com.junxu.yibi

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

object NotificationScheduler {
    const val ACTION_DAILY = "com.junxu.yibi.DAILY_REMINDER"
    const val ACTION_RECURRING = "com.junxu.yibi.RECURRING_REMINDER"
    const val CHANNEL_ID = "ledger_reminders"
    private const val PREFS = "oneentry_reminders"

    fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val channel = NotificationChannel(CHANNEL_ID, "记账提醒", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "每日记账与周期账目提醒"
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    fun scheduleDaily(context: Context, enabled: Boolean, hour: Int, minute: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean("daily_enabled", enabled)
            .putInt("daily_hour", hour)
            .putInt("daily_minute", minute)
            .apply()
        val alarm = context.getSystemService(AlarmManager::class.java)
        val pending = pendingIntent(context, ACTION_DAILY, 2101)
        alarm.cancel(pending)
        if (enabled) {
            alarm.setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                nextTime(hour, minute),
                AlarmManager.INTERVAL_DAY,
                pending,
            )
        }
    }

    fun scheduleRecurringCheck(context: Context) {
        val alarm = context.getSystemService(AlarmManager::class.java)
        val pending = pendingIntent(context, ACTION_RECURRING, 2102)
        alarm.cancel(pending)
        alarm.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            nextTime(8, 0),
            AlarmManager.INTERVAL_DAY,
            pending,
        )
    }

    fun reschedule(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        scheduleDaily(
            context,
            prefs.getBoolean("daily_enabled", false),
            prefs.getInt("daily_hour", 20),
            prefs.getInt("daily_minute", 0),
        )
        scheduleRecurringCheck(context)
    }

    private fun pendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).setAction(action)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun nextTime(hour: Int, minute: Int): Long {
        val now = Calendar.getInstance()
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour.coerceIn(0, 23))
            set(Calendar.MINUTE, minute.coerceIn(0, 59))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (!after(now)) add(Calendar.DAY_OF_YEAR, 1)
        }
        return next.timeInMillis
    }
}
