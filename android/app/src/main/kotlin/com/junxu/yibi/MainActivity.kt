package com.junxu.yibi

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    NotificationScheduler.createChannel(this)
                    result.success(null)
                }
                "requestPermission" -> requestNotificationPermission(result)
                "scheduleDaily" -> {
                    NotificationScheduler.scheduleDaily(
                        this,
                        call.argument<Boolean>("enabled") ?: false,
                        call.argument<Int>("hour") ?: 20,
                        call.argument<Int>("minute") ?: 0,
                    )
                    result.success(null)
                }
                "scheduleRecurringCheck" -> {
                    NotificationScheduler.scheduleRecurringCheck(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error("permission_in_progress", "A notification permission request is already active", null)
            return
        }
        permissionResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_NOTIFICATIONS) {
            permissionResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }

    companion object {
        private const val CHANNEL = "com.junxu.yibi/notifications"
        private const val REQUEST_NOTIFICATIONS = 901
    }
}
