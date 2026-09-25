package com.junxu.yibi

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private var fileResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openFile" -> openFile(call.argument<List<String>>("mimeTypes") ?: listOf("*/*"), result)
                "saveFile" -> saveFile(
                    call.argument<String>("name") ?: "oneentry-backup.json",
                    call.argument<String>("mimeType") ?: "application/octet-stream",
                    call.argument<ByteArray>("bytes") ?: ByteArray(0),
                    result,
                )
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

    private fun openFile(mimeTypes: List<String>, result: MethodChannel.Result) {
        if (fileResult != null) {
            result.error("picker_in_progress", "A file picker is already active", null)
            return
        }
        fileResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = if (mimeTypes.size == 1) mimeTypes.first() else "*/*"
            if (mimeTypes.size > 1) putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes.toTypedArray())
        }
        startActivityForResult(intent, REQUEST_OPEN_FILE)
    }

    private fun saveFile(name: String, mimeType: String, bytes: ByteArray, result: MethodChannel.Result) {
        if (fileResult != null) {
            result.error("picker_in_progress", "A file picker is already active", null)
            return
        }
        fileResult = result
        pendingSaveBytes = bytes
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, name)
        }
        startActivityForResult(intent, REQUEST_SAVE_FILE)
    }

    @Deprecated("Deprecated in Android SDK but required by FlutterActivity compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_OPEN_FILE && requestCode != REQUEST_SAVE_FILE) return
        val result = fileResult
        fileResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pendingSaveBytes = null
            result?.success(null)
            return
        }
        val uri = data.data!!
        try {
            if (requestCode == REQUEST_SAVE_FILE) {
                contentResolver.openOutputStream(uri, "w")!!.use { it.write(pendingSaveBytes ?: ByteArray(0)) }
                pendingSaveBytes = null
                result?.success(true)
            } else {
                val bytes = contentResolver.openInputStream(uri)!!.use { it.readBytes() }
                result?.success(mapOf("name" to displayName(uri), "bytes" to bytes))
            }
        } catch (error: Exception) {
            pendingSaveBytes = null
            result?.error("file_io_failed", error.message, null)
        }
    }

    private fun displayName(uri: Uri): String {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            if (cursor != null && cursor.moveToFirst()) cursor.getString(0) else "import-file"
        } finally {
            cursor?.close()
        }
    }

    companion object {
        private const val CHANNEL = "com.junxu.yibi/notifications"
        private const val FILE_CHANNEL = "com.junxu.yibi/files"
        private const val REQUEST_NOTIFICATIONS = 901
        private const val REQUEST_OPEN_FILE = 902
        private const val REQUEST_SAVE_FILE = 903
    }
}
