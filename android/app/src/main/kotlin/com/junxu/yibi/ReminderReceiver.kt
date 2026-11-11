package com.junxu.yibi

import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        NotificationScheduler.createChannel(context)
        when (intent.action) {
            NotificationScheduler.ACTION_DAILY -> try {
                NotificationScheduler.recordDailyDelivery(
                    context,
                    notifyDaily(context),
                )
            } finally {
                NotificationScheduler.scheduleNextDaily(context)
            }
            NotificationScheduler.ACTION_RECURRING -> try {
                notifyRecurringIfNeeded(context)
            } finally {
                NotificationScheduler.scheduleRecurringCheck(context)
            }
        }
    }

    fun showTest(context: Context): Boolean {
        NotificationScheduler.createChannel(context)
        return show(context, 3199, "记账提醒测试成功", "之后会在设定时间提醒你记账")
    }

    private fun notifyDaily(context: Context): Boolean =
        show(
            context,
            3101,
            "记账时间到了",
            "打开一笔，记录今天的收支吧",
            launchAction = "new_entry",
        )

    private fun notifyRecurringIfNeeded(context: Context) {
        withDatabase(context) { db ->
            val now = Calendar.getInstance()
            val dueRules = mutableListOf<Pair<Int, String>>()
            db.rawQuery("SELECT id, name, frequency, anchor_date FROM recurring_rules WHERE enabled = 1", null).use { cursor ->
                val parser = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                while (cursor.moveToNext()) {
                    val id = cursor.getInt(0)
                    val name = cursor.getString(1)
                    val frequency = cursor.getString(2)
                    val anchor = Calendar.getInstance().apply { time = parser.parse(cursor.getString(3)) ?: now.time }
                    val due = when (frequency) {
                        "day" -> true
                        "week" -> anchor.get(Calendar.DAY_OF_WEEK) == now.get(Calendar.DAY_OF_WEEK)
                        "month" -> anchor.get(Calendar.DAY_OF_MONTH).coerceAtMost(now.getActualMaximum(Calendar.DAY_OF_MONTH)) == now.get(Calendar.DAY_OF_MONTH)
                        "year" -> anchor.get(Calendar.MONTH) == now.get(Calendar.MONTH) && anchor.get(Calendar.DAY_OF_MONTH) == now.get(Calendar.DAY_OF_MONTH)
                        else -> false
                    }
                    if (due) dueRules += id to name
                }
            }
            if (dueRules.isNotEmpty()) {
                show(
                    context,
                    3102,
                    "🔔 今天有 ${dueRules.size} 笔待记账",
                    dueRules.take(3).joinToString("、") { it.second },
                    launchAction = "recurring_rule",
                    recurringRuleId = dueRules.first().first,
                )
            }
        }
    }

    private fun withDatabase(context: Context, block: (SQLiteDatabase) -> Unit) {
        val path = context.getDatabasePath("oneentry.db")
        if (!path.exists()) return
        val database = SQLiteDatabase.openDatabase(path.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
        try {
            block(database)
        } finally {
            database.close()
        }
    }

    private fun show(
        context: Context,
        id: Int,
        title: String,
        body: String?,
        launchAction: String? = null,
        recurringRuleId: Int? = null,
    ): Boolean {
        if (!NotificationScheduler.notificationsEnabled(context)) return false
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        launch?.putExtra("oneentry_notification_action", launchAction)
        if (recurringRuleId != null) {
            launch?.putExtra("oneentry_recurring_rule_id", recurringRuleId)
        }
        val contentIntent = launch?.let {
            PendingIntent.getActivity(context, id, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val builder = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            Notification.Builder(context, NotificationScheduler.CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setPriority(Notification.PRIORITY_DEFAULT)
            .build()
        return try {
            context.getSystemService(NotificationManager::class.java).notify(id, notification)
            true
        } catch (_: SecurityException) {
            false
        }
    }
}
