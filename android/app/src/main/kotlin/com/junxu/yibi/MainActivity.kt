package com.junxu.yibi

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.RecognitionService
import android.speech.SpeechRecognizer
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private var speechPermissionResult: MethodChannel.Result? = null
    private var fileResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null
    private var speechChannel: MethodChannel? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var lastPartialText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    NotificationScheduler.createChannel(this)
                    result.success(null)
                }
                "requestPermission" -> requestNotificationPermission(result)
                "notificationsEnabled" -> {
                    NotificationScheduler.createChannel(this)
                    result.success(NotificationScheduler.notificationsEnabled(this))
                }
                "canScheduleExactAlarms" -> result.success(
                    NotificationScheduler.canScheduleExactAlarms(this),
                )
                "dailyReminderStatus" -> result.success(
                    NotificationScheduler.dailyStatus(this),
                )
                "scheduleRecurringCheck" -> {
                    NotificationScheduler.scheduleRecurringCheck(this)
                    result.success(null)
                }
                "scheduleDaily" -> {
                    NotificationScheduler.scheduleDaily(
                        this,
                        call.argument<Boolean>("enabled") ?: false,
                        call.argument<Int>("hour") ?: 20,
                        call.argument<Int>("minute") ?: 0,
                    )
                    result.success(null)
                }
                "showTestNotification" -> result.success(ReminderReceiver().showTest(this))
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(null)
                }
                "openExactAlarmSettings" -> {
                    openExactAlarmSettings()
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
        speechChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> requestSpeechPermission(result)
                    "hasPermission" -> result.success(
                        checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED,
                    )
                    "openPermissionSettings" -> {
                        openAppPermissionSettings()
                        result.success(null)
                    }
                    "isAvailable" -> result.success(SpeechRecognizer.isRecognitionAvailable(this))
                    "start" -> result.success(startSpeechRecognition())
                    "stop" -> {
                        sendSpeechEvent("processing")
                        speechRecognizer?.stopListening()
                        result.success(null)
                    }
                    "cancel" -> {
                        speechRecognizer?.cancel()
                        releaseSpeechRecognizer()
                        sendSpeechEvent("idle")
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        NotificationScheduler.createChannel(this)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(NotificationScheduler.notificationsEnabled(this))
            return
        }
        if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(NotificationScheduler.notificationsEnabled(this))
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
            val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
            permissionResult?.success(granted && NotificationScheduler.notificationsEnabled(this))
            permissionResult = null
        }
        if (requestCode == REQUEST_RECORD_AUDIO) {
            speechPermissionResult?.success(
                grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED,
            )
            speechPermissionResult = null
        }
    }

    private fun requestSpeechPermission(result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        if (speechPermissionResult != null) {
            result.error("permission_in_progress", "A microphone permission request is already active", null)
            return
        }
        speechPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_RECORD_AUDIO)
    }

    private fun startSpeechRecognition(): Boolean {
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            sendSpeechEvent("error", message = "需要麦克风权限")
            return false
        }
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            sendSpeechEvent("error", message = "当前设备没有可用的语音识别服务")
            return false
        }
        ensureSpeechRecognizer()
        lastPartialText = null
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "zh-CN")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1_500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1_500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1_000L)
        }
        return try {
            speechRecognizer?.startListening(intent)
            sendSpeechEvent("listening")
            true
        } catch (error: Exception) {
            sendSpeechEvent("error", message = error.message ?: "无法启动语音识别")
            false
        }
    }

    private fun ensureSpeechRecognizer() {
        if (speechRecognizer != null) return
        val service = preferredRecognitionService()
        Log.i(SPEECH_LOG_TAG, "Using recognition service: ${service?.flattenToShortString() ?: "system default"}")
        val recognizer = if (service == null) {
            SpeechRecognizer.createSpeechRecognizer(this)
        } else {
            SpeechRecognizer.createSpeechRecognizer(this, service)
        }
        speechRecognizer = recognizer.apply {
            setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) = sendSpeechEvent("listening")
                override fun onBeginningOfSpeech() = sendSpeechEvent("listening")
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() = sendSpeechEvent("processing")

                override fun onError(error: Int) {
                    Log.w(SPEECH_LOG_TAG, "Speech recognition error: $error")
                    val partial = lastPartialText?.trim().orEmpty()
                    if (
                        partial.isNotEmpty() &&
                        (error == SpeechRecognizer.ERROR_NO_MATCH ||
                            error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT)
                    ) {
                        sendSpeechEvent("result", text = partial)
                    } else {
                        sendSpeechEvent("error", message = speechErrorMessage(error))
                    }
                    releaseSpeechRecognizer()
                }

                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    val text = matches?.firstOrNull()?.trim().orEmpty()
                        .ifEmpty { lastPartialText?.trim().orEmpty() }
                    if (text.isEmpty()) {
                        sendSpeechEvent("error", message = "没有听清，请再试一次")
                    } else {
                        Log.i(SPEECH_LOG_TAG, "Speech recognition result received")
                        sendSpeechEvent("result", text = text)
                    }
                    releaseSpeechRecognizer()
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    lastPartialText = partialResults
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()
                        ?.trim()
                        ?.takeIf { it.isNotEmpty() }
                        ?: lastPartialText
                }
                override fun onEvent(eventType: Int, params: Bundle?) = Unit
            })
        }
    }

    private fun preferredRecognitionService(): ComponentName? {
        val googleService = ComponentName(
            "com.google.android.googlequicksearchbox",
            "com.google.android.voicesearch.serviceapi.GoogleRecognitionService",
        )
        val googleAvailable = runCatching {
            packageManager.getServiceInfo(googleService, PackageManager.MATCH_ALL)
        }.isSuccess
        if (googleAvailable) return googleService

        val services = packageManager.queryIntentServices(
            Intent(RecognitionService.SERVICE_INTERFACE),
            PackageManager.MATCH_ALL,
        ).mapNotNull { resolveInfo ->
            val info = resolveInfo.serviceInfo ?: return@mapNotNull null
            ComponentName(info.packageName, info.name)
        }
        Log.i(
            SPEECH_LOG_TAG,
            "Visible recognition services: ${services.joinToString { it.flattenToShortString() }}",
        )
        return services.firstOrNull {
            it.packageName == "com.google.android.googlequicksearchbox"
        } ?: services.firstOrNull {
            val name = it.className.lowercase()
            !name.contains("wakeup") && !name.contains("copilot")
        }
    }

    private fun sendSpeechEvent(status: String, text: String? = null, message: String? = null) {
        speechChannel?.invokeMethod(
            "speechEvent",
            mapOf("status" to status, "text" to text, "message" to message),
        )
    }

    private fun releaseSpeechRecognizer() {
        speechRecognizer?.destroy()
        speechRecognizer = null
        lastPartialText = null
    }

    private fun speechErrorMessage(error: Int): String = when (error) {
        SpeechRecognizer.ERROR_AUDIO -> "麦克风录音失败"
        SpeechRecognizer.ERROR_CLIENT -> "系统语音服务启动失败，请检查手机的语音输入服务"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "需要麦克风权限"
        SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "语音识别网络不可用"
        SpeechRecognizer.ERROR_NO_MATCH -> "没有听清，请再试一次"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "语音识别正在忙，请稍后重试"
        SpeechRecognizer.ERROR_SERVER -> "语音识别服务暂时不可用"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "没有听到语音"
        else -> "语音识别失败（$error）"
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                putExtra(Settings.EXTRA_CHANNEL_ID, NotificationScheduler.CHANNEL_ID)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
        }
        startActivity(intent)
    }

    private fun openAppPermissionSettings() {
        startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            },
        )
    }

    private fun openExactAlarmSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            startActivity(
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:$packageName")
                },
            )
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

    override fun onDestroy() {
        releaseSpeechRecognizer()
        speechChannel = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "com.junxu.yibi/notifications"
        private const val FILE_CHANNEL = "com.junxu.yibi/files"
        private const val SPEECH_CHANNEL = "com.junxu.yibi/speech"
        private const val REQUEST_NOTIFICATIONS = 901
        private const val REQUEST_OPEN_FILE = 902
        private const val REQUEST_SAVE_FILE = 903
        private const val REQUEST_RECORD_AUDIO = 904
        private const val SPEECH_LOG_TAG = "OneEntrySpeech"
    }
}
