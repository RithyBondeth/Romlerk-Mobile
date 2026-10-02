package dev.romlerk.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// A FragmentActivity because local_auth's system prompt is a fragment.
class MainActivity : FlutterFragmentActivity() {

    private var localAi: LocalAiBridge? = null
    private var voice: VoiceBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // App-level channel rather than a plugin: the adapter is specific to
        // this product's task schema and has no reuse value outside it.
        localAi = LocalAiBridge(flutterEngine.dartExecutor.binaryMessenger)
        voice = VoiceBridge(this, flutterEngine.dartExecutor.binaryMessenger)
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
