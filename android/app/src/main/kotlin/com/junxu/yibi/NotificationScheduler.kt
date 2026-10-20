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

    fun notificationsEnabled(context: Context): Boolean {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && !manager.areNotificationsEnabled()) {
            return false
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = manager.getNotificationChannel(CHANNEL_ID)
            if (channel != null && channel.importance == NotificationManager.IMPORTANCE_NONE) {
                return false
            }
        }
        return true
    }

    fun canScheduleExactAlarms(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return context.getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
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
            setOneShot(alarm, nextTime(hour, minute), pending)
        }
    }

    fun scheduleRecurringCheck(context: Context) {
        val alarm = context.getSystemService(AlarmManager::class.java)
        val pending = pendingIntent(context, ACTION_RECURRING, 2102)
        alarm.cancel(pending)
        setOneShot(alarm, nextTime(8, 0), pending)
    }

    fun scheduleNextDaily(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean("daily_enabled", false)) return
        val alarm = context.getSystemService(AlarmManager::class.java)
        setOneShot(
            alarm,
            nextTime(prefs.getInt("daily_hour", 20), prefs.getInt("daily_minute", 0)),
            pendingIntent(context, ACTION_DAILY, 2101),
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

    private fun setOneShot(alarm: AlarmManager, triggerAtMillis: Long, pending: PendingIntent) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || alarm.canScheduleExactAlarms()) {
            alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        } else {
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pending)
        }
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
