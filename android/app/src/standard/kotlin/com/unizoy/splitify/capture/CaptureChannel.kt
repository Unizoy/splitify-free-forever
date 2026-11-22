package com.unizoy.splitify.capture

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * `standard` flavour (D-028, S-275): no payment bubble. The same MethodChannel `splitify/capture` answers that
 * capture is not supported, keeps nothing, and still opens the app's notification settings and app info (the
 * notification settings screen uses them). The real channel lives in src/full.
 */
class CaptureChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    fun attach(messenger: BinaryMessenger) = MethodChannel(messenger, NAME).setMethodCallHandler(this)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "permissions" -> result.success(
                JSONObject().put("supported", false).put("sdk", Build.VERSION.SDK_INT).toString(),
            )
            "export" -> result.success("""{"captures":[],"dismissed":[]}""")
            "config" -> result.success("{}")
            "apps" -> result.success("[]")
            "sample" -> result.success(false)
            "open" -> result.success(open(call.argument<String>("access").orEmpty()))
            "ack", "dismiss", "setConfig", "setRecents", "reset" -> result.success(null)
            else -> result.notImplemented()
        }
    }

    private fun open(access: String): Boolean {
        val intent = when (access) {
            "postNotifications" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
            "appInfo" -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}"))
            else -> return false
        }
        return try {
            activity.startActivity(intent)
            true
        } catch (_: RuntimeException) {
            false
        }
    }

    companion object {
        const val NAME = "splitify/capture"
    }
}
