package dev.romlerk.app

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Android side of the `dev.romlerk/voice` channel (FR-16, Journey C).
 *
 * Uses [SpeechRecognizer.createOnDeviceSpeechRecognizer] (API 31+), which is
 * guaranteed to run locally. The ordinary recognizer, even with
 * `EXTRA_PREFER_OFFLINE`, may hand audio to a server — so below API 31, or
 * where no on-device recognizer is installed, this reports `unsupported` and
 * the app keeps text capture as the path (NFR-07).
 */
class VoiceBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val PERMISSION_REQUEST_CODE = 0x566F  // "Vo"
        private const val CHANNEL = "dev.romlerk/voice"
    }

    private val channel = MethodChannel(messenger, CHANNEL).apply {
        setMethodCallHandler(this@VoiceBridge)
    }

    private var recognizer: SpeechRecognizer? = null
    private var pendingPermission: MethodChannel.Result? = null

    /** Bumped per session so a late callback cannot reach the next one. */
    private var session = 0

    fun dispose() {
        cancel()
        pendingPermission?.success(false)
        pendingPermission = null
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "availability" -> result.success(mapOf("status" to availability()))
            "requestPermission" -> requestPermission(result)
            "start" -> start(call.argument<String>("locale"), result)
            "stop" -> {
                recognizer?.stopListening()
                result.success(null)
            }
            "cancel" -> {
                cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ---------------------------------------------------------- availability

    private fun onDeviceSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(activity)

    private fun hasPermission(): Boolean =
        activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * Language support is only knowable by trying on API 31-32, so a missing
     * language surfaces as `LANGUAGE_UNSUPPORTED` from [start] instead.
     */
    private fun availability(): String = when {
        !onDeviceSupported() -> "unsupported"
        hasPermission() -> "available"
        // Android does not say whether the user has been asked before; the
        // request itself returns false at once if they chose "don't ask".
        else -> "permissionNeeded"
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) {
            result.success(true)
            return
        }
        pendingPermission?.success(false)
        pendingPermission = result
        activity.requestPermissions(
            arrayOf(Manifest.permission.RECORD_AUDIO),
            PERMISSION_REQUEST_CODE,
        )
    }

    /** Forwarded from [MainActivity.onRequestPermissionsResult]. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermission?.success(granted)
        pendingPermission = null
        return true
    }

    // ---------------------------------------------------------------- session

    private fun start(locale: String?, result: MethodChannel.Result) {
        cancel()
        if (!onDeviceSupported()) {
            result.error("UNAVAILABLE", null, null)
            return
        }
        if (!hasPermission()) {
            result.error("PERMISSION_DENIED", null, null)
            return
        }

        session += 1
        val current = session
        val created = SpeechRecognizer.createOnDeviceSpeechRecognizer(activity)
        created.setRecognitionListener(Listener(current))
        recognizer = created

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            if (!locale.isNullOrEmpty()) {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            }
        }
        created.startListening(intent)
        result.success(null)
    }

    private fun cancel() {
        session += 1
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
    }

    private fun finish(error: String?) {
        session += 1
        recognizer?.destroy()
        recognizer = null
        channel.invokeMethod("onEnded", if (error == null) emptyMap<String, Any>() else mapOf("error" to error))
    }

    private fun sendTranscript(results: Bundle?, isFinal: Boolean) {
        val text = results
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            ?.firstOrNull()
            ?: return
        channel.invokeMethod(
            "onTranscript",
            mapOf("text" to text, "isFinal" to isFinal),
        )
    }

    private inner class Listener(private val id: Int) : RecognitionListener {
        private fun live() = id == session

        override fun onPartialResults(partialResults: Bundle?) {
            if (live()) sendTranscript(partialResults, isFinal = false)
        }

        override fun onResults(results: Bundle?) {
            if (!live()) return
            sendTranscript(results, isFinal = true)
            finish(null)
        }

        override fun onError(error: Int) {
            if (!live()) return
            finish(
                when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH,
                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "NO_SPEECH"
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "PERMISSION_DENIED"
                    SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
                    SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "LANGUAGE_UNSUPPORTED"
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY,
                    SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "BUSY"
                    else -> "RECOGNITION_FAILED"
                },
            )
        }

        override fun onReadyForSpeech(params: Bundle?) {}
        override fun onBeginningOfSpeech() {}
        override fun onRmsChanged(rmsdB: Float) {}
        override fun onBufferReceived(buffer: ByteArray?) {}
        override fun onEndOfSpeech() {}
        override fun onEvent(eventType: Int, params: Bundle?) {}
    }
}
