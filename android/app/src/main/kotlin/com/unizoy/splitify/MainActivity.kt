package com.unizoy.splitify

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.HapticFeedbackConstants
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import java.io.File
import java.util.UUID
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity: local_auth shows the system BiometricPrompt from a fragment (X2).
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Share to Splitify (D-034 A7): a shared picture or text opens the add-expense editor as an app link.
        shareLink(intent)?.let { intent = it }
        super.onCreate(savedInstanceState)
        preferHighRefreshRate()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(shareLink(intent) ?: intent)
    }

    /**
     * Turns an ACTION_SEND (a receipt picture or text such as a UPI app's "Paid ₹250 to …") into
     * `splitify://expense/new?share=<token>`; the editor takes the payload once over `splitify/share`. A shared
     * picture is copied into the app's cache first (Dart cannot read content:// URIs). Null for other intents.
     */
    private fun shareLink(incoming: Intent?): Intent? {
        if (incoming == null || incoming.action != Intent.ACTION_SEND) return null
        val payload = HashMap<String, String>()
        incoming.getStringExtra(Intent.EXTRA_TEXT)?.takeIf { it.isNotBlank() }?.let { payload["text"] = it.take(4000) }
        val type = incoming.type ?: ""
        if (type.startsWith("image/")) {
            val stream: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                incoming.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                incoming.getParcelableExtra(Intent.EXTRA_STREAM)
            }
            stream?.takeIf { sharedFromOtherApp(it) }?.let { copyShared(it) }?.let { payload["image"] = it }
        }
        if (payload.isEmpty()) return null
        val token = UUID.randomUUID().toString()
        shares[token] = payload
        return Intent(Intent.ACTION_VIEW, Uri.parse("splitify://expense/new?share=$token"))
    }

    /**
     * Only content:// pictures another app offers (R4, S-478). A file:// URI, or one of Splitify's own provider,
     * could point at Splitify's private files (its database, the saved sign-in, other people's receipts), which
     * Splitify itself can read and would copy into the editor for upload.
     */
    private fun sharedFromOtherApp(uri: Uri): Boolean =
        uri.scheme == "content" && uri.authority != null && uri.authority != "$packageName.files"

    /** Copies a shared picture (max 25 MB) to cache/shared/; returns its path or null. */
    private fun copyShared(uri: Uri): String? = try {
        val dir = File(cacheDir, "shared").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() }
        val file = File(dir, "receipt-${UUID.randomUUID()}.jpg")
        contentResolver.openInputStream(uri)?.use { input ->
            file.outputStream().use { output ->
                val buffer = ByteArray(64 * 1024)
                var total = 0L
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    total += n
                    if (total > 25L * 1024 * 1024) throw IllegalStateException("too big")
                    output.write(buffer, 0, n)
                }
            }
        }
        if (file.length() > 0) file.absolutePath else null
    } catch (_: Exception) {
        null
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
        // Share to Splitify (D-034 A7): the editor takes what was shared, once.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "splitify/share")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "take" -> result.success(shares.remove(call.arguments as? String ?: ""))
                    else -> result.notImplemented()
                }
            }
        // Expense attachments (W2-Y): PDF pages through PdfRenderer, "Open with" another app.
        PdfBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        // Android's own settings screens (lib/core/platform/system_settings.dart): the blocked-push banner opens
        // Splitify's notification settings (app info on Android 7, which has no such screen).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "splitify/settings")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openNotificationSettings" -> result.success(openNotificationSettings())
                    else -> result.notImplemented()
                }
            }
        // "From contacts" (W2-X F15): the system contact picker, names only, no contacts permission.
        ContactsBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        // Success / error haptics (lib/ui/theme/app_motion.dart AppHaptics, S-453): Android 11+ has CONFIRM and
        // REJECT; older phones get a firm tick for success and two quick ticks for an error. Follows the
        // system's touch-feedback setting like every other tick.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "splitify/haptics")
            .setMethodCallHandler { call, result ->
                val view = window.decorView
                val modern = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
                when (call.method) {
                    "success" -> {
                        view.performHapticFeedback(
                            if (modern) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.KEYBOARD_TAP,
                        )
                        result.success(null)
                    }
                    "error" -> {
                        if (modern) {
                            view.performHapticFeedback(HapticFeedbackConstants.REJECT)
                        } else {
                            view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                            view.postDelayed({ view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP) }, 90)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun openNotificationSettings(): Boolean {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
        }
        return try {
            startActivity(intent)
            true
        } catch (_: RuntimeException) {
            false
        }
    }

    companion object {
        /** Shared payloads waiting for the editor, by token (kept only while the app process lives). */
        private val shares = HashMap<String, Map<String, String>>()
    }
}
