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
            NotificationScheduler.ACTION_DAILY -> notifyDailyIfNeeded(context)
            NotificationScheduler.ACTION_RECURRING -> notifyRecurringIfNeeded(context)
        }
    }

    private fun notifyDailyIfNeeded(context: Context) {
        withDatabase(context) { db ->
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)
            val count = db.rawQuery("SELECT COUNT(*) FROM transactions WHERE local_date = ?", arrayOf(today)).use { cursor ->
                if (cursor.moveToFirst()) cursor.getInt(0) else 0
            }
            if (count == 0) show(context, 3101, "今天还没有记账，记得记录一下哦", null)
        }
    }

    private fun notifyRecurringIfNeeded(context: Context) {
        withDatabase(context) { db ->
            val now = Calendar.getInstance()
            val names = mutableListOf<String>()
            db.rawQuery("SELECT name, frequency, anchor_date FROM recurring_rules WHERE enabled = 1", null).use { cursor ->
                val parser = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                while (cursor.moveToNext()) {
                    val name = cursor.getString(0)
                    val frequency = cursor.getString(1)
                    val anchor = Calendar.getInstance().apply { time = parser.parse(cursor.getString(2)) ?: now.time }
                    val due = when (frequency) {
                        "day" -> true
                        "week" -> anchor.get(Calendar.DAY_OF_WEEK) == now.get(Calendar.DAY_OF_WEEK)
                        "month" -> anchor.get(Calendar.DAY_OF_MONTH).coerceAtMost(now.getActualMaximum(Calendar.DAY_OF_MONTH)) == now.get(Calendar.DAY_OF_MONTH)
                        "year" -> anchor.get(Calendar.MONTH) == now.get(Calendar.MONTH) && anchor.get(Calendar.DAY_OF_MONTH) == now.get(Calendar.DAY_OF_MONTH)
                        else -> false
                    }
                    if (due) names += name
                }
            }
            if (names.isNotEmpty()) {
                show(context, 3102, "🔔 今天有 ${names.size} 笔待记账", names.take(3).joinToString("、"))
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

    private fun show(context: Context, id: Int, title: String, body: String?) {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val contentIntent = launch?.let {
            PendingIntent.getActivity(context, id, it, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val builder = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            Notification.Builder(context, NotificationScheduler.CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .setPriority(Notification.PRIORITY_DEFAULT)
            .build()
        context.getSystemService(NotificationManager::class.java).notify(id, notification)
    }
}
