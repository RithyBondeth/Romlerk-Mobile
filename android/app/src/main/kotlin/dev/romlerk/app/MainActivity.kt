package dev.romlerk.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import org.json.JSONArray
import android.widget.Toast

// A FragmentActivity because local_auth's system prompt is a fragment.
class MainActivity : FlutterFragmentActivity() {

    private var localAi: LocalAiBridge? = null
    private var voice: VoiceBridge? = null
    private var captureChannel: MethodChannel? = null
    private val capturePrefs by lazy { getSharedPreferences("capture_inbox", MODE_PRIVATE) }

    private fun captureQueue(): MutableList<String> {
        val array = JSONArray(capturePrefs.getString("pending", "[]"))
        return (0 until array.length()).map { array.getString(it) }.toMutableList()
    }
    private fun receiveCapture(intent: Intent?) {
        val text = when {
            intent?.action == Intent.ACTION_SEND && intent.type == "text/plain" -> intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: return
            intent?.action == "dev.romlerk.app.CAPTURE" -> ""
            intent?.action == Intent.ACTION_VIEW && intent.data?.scheme == "romlerk" && intent.data?.host == "capture" -> intent.data?.getQueryParameter("text") ?: ""
            else -> return
        }
        val queue = captureQueue()
        if (text.length > 12000 || queue.size >= 100) {
            Toast.makeText(this, R.string.capture_inbox_full, Toast.LENGTH_LONG).show()
            return
        }
        queue.add(text)
        if (capturePrefs.edit().putString("pending", JSONArray(queue).toString()).commit()) {
            captureChannel?.invokeMethod("available", null)
        }
        // Do not re-enqueue this launch intent if the engine is recreated.
        setIntent(Intent(this, MainActivity::class.java))
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
            if (call.method == "clear") {
                if (capturePrefs.edit().remove("pending").commit()) result.success(null)
                else result.error("CAPTURE_STORAGE", "Could not clear capture inbox", null)
            } else if (call.method != "take") { result.notImplemented() }
            else {
                val queue = captureQueue()
                val text = if (queue.isEmpty()) null else queue.removeAt(0)
                if (capturePrefs.edit().putString("pending", JSONArray(queue).toString()).commit()) result.success(text)
                else result.error("CAPTURE_STORAGE", "Could not read capture inbox", null)
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
