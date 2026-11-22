package com.unizoy.splitify

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import com.unizoy.splitify.capture.CaptureChannel
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity: local_auth shows the system BiometricPrompt from a fragment (X2).
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        preferHighRefreshRate()
    }

    /**
     * Asks for the screen's fastest refresh rate at the current resolution (90/120 Hz phones), S-260:
     * many phones keep apps at 60 Hz unless the window asks. Same as flutter_displaymode's
     * setHighRefreshRate, without the plugin.
     */
    private fun preferHighRefreshRate() {
        @Suppress("DEPRECATION")
        val display = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else windowManager.defaultDisplay)
            ?: return
        val current = display.mode
        val best = display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .maxByOrNull { it.refreshRate } ?: return
        if (window.attributes.preferredDisplayModeId == best.modeId) return
        window.attributes = window.attributes.apply { preferredDisplayModeId = best.modeId }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // App lock privacy flags (lib/core/platform/secure_window.dart).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "splitify/window")
            .setMethodCallHandler { call, result ->
                val on = call.arguments as? Boolean ?: false
                when (call.method) {
                    // While the lock screen shows: no screenshots, blank in recents.
                    "setSecure" -> {
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    // While app lock is on: no preview in recent apps (Android 13+), screenshots still allowed.
                    "setRecentsHidden" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            setRecentsScreenshotEnabled(!on)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // Payment bubble (phase 18b): captures, permissions and settings for the Flutter side.
        CaptureChannel(this).attach(flutterEngine.dartExecutor.binaryMessenger)
    }
}
