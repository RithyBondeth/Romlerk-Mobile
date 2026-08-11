package com.example.romlerk_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    private var localAi: LocalAiBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // App-level channel rather than a plugin: the adapter is specific to
        // this product's task schema and has no reuse value outside it.
        localAi = LocalAiBridge(flutterEngine.dartExecutor.binaryMessenger)
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
        super.onDestroy()
    }
}
