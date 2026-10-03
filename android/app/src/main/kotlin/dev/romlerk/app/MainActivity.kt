package dev.romlerk.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import android.widget.Toast

// A FragmentActivity because local_auth's system prompt is a fragment.
class MainActivity : FlutterFragmentActivity() {

    private var localAi: LocalAiBridge? = null
    private var voice: VoiceBridge? = null
    private var captureChannel: MethodChannel? = null
    private val capturePrefs by lazy { getSharedPreferences("capture_inbox", MODE_PRIVATE) }

    private fun captureQueue(): MutableList<JSONObject> {
        val array = JSONArray(capturePrefs.getString("pending", "[]"))
        val queue = (0 until array.length()).map {
            val old = array.get(it)
            if (old is JSONObject) old else JSONObject().put("id", UUID.randomUUID().toString()).put("text", old.toString())
        }.toMutableList()
        // Persist legacy IDs before handing a request to Dart.
        if (!capturePrefs.edit().putString("pending", JSONArray(queue).toString()).commit()) throw IllegalStateException("Capture storage unavailable")
        return queue
    }
    private fun receiveCapture(intent: Intent?) {
        val text = when {
            intent?.action == Intent.ACTION_SEND && intent.type == "text/plain" -> intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: return
            intent?.action == "dev.romlerk.app.CAPTURE" -> ""
            intent?.action == Intent.ACTION_VIEW && intent.data?.scheme == "romlerk" && intent.data?.host == "capture" -> intent.data?.getQueryParameter("text") ?: ""
            else -> return
        }
        try {
            val queue = captureQueue()
            if (text.length > 12000 || queue.size >= 100) {
                Toast.makeText(this, R.string.capture_inbox_full, Toast.LENGTH_LONG).show()
                return
            }
            queue.add(JSONObject().put("id", UUID.randomUUID().toString()).put("text", text))
            if (!capturePrefs.edit().putString("pending", JSONArray(queue).toString()).commit()) throw IllegalStateException()
            captureChannel?.invokeMethod("available", null)
            // Clear the launch intent only after text is safely queued.
            setIntent(Intent(this, MainActivity::class.java))
        } catch (error: Exception) {
            Toast.makeText(this, R.string.capture_inbox_unavailable, Toast.LENGTH_LONG).show()
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        receiveCapture(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // App-level channel rather than a plugin: the adapter is specific to
        // this product's task schema and has no reuse value outside it.
        localAi = LocalAiBridge(flutterEngine.dartExecutor.binaryMessenger)
        voice = VoiceBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        captureChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.romlerk/capture")
        captureChannel?.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "clear" -> {
                        if (!capturePrefs.edit().remove("pending").commit()) throw IllegalStateException()
                        result.success(null)
                    }
                    "peek" -> {
                        val first = captureQueue().firstOrNull()
                        result.success(first?.let { mapOf("id" to it.getString("id"), "text" to it.getString("text")) })
                    }
                    "acknowledge" -> {
                        val queue = captureQueue()
                        if (queue.firstOrNull()?.getString("id") == call.arguments as? String) queue.removeAt(0)
                        if (!capturePrefs.edit().putString("pending", JSONArray(queue).toString()).commit()) throw IllegalStateException()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("CAPTURE_STORAGE", "Could not access capture inbox", null)
            }
        }
        receiveCapture(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (voice?.onPermissionResult(requestCode, grantResults) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    // ML Kit GenAI is foreground-only, and the BRD forbids background
    // generative work outright, so the bridge tracks the activity lifecycle
    // rather than assuming it is safe to run.
    override fun onResume() {
        super.onResume()
        localAi?.isForeground = true
    }

    override fun onPause() {
        localAi?.isForeground = false
        super.onPause()
    }

    override fun onDestroy() {
        localAi?.dispose()
        localAi = null
        voice?.dispose()
        voice = null
        super.onDestroy()
    }
}
