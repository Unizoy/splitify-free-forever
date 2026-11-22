package com.unizoy.splitify

import com.unizoy.splitify.capture.CaptureChannel
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Payment bubble (phase 18b): captures, permissions and settings for the Flutter side.
        CaptureChannel(this).attach(flutterEngine.dartExecutor.binaryMessenger)
    }
}
