package com.unizoy.splitify.capture

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * MethodChannel `splitify/capture` (S-224): the Flutter side reads/acks captures, reads permissions, opens the
 * exact system screens, writes the config and the recent chips, and asks for the sample bubble. JSON strings
 * keep the codec simple and the same as the store.
 */
class CaptureChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val center get() = CaptureCenter.get(activity)

    fun attach(messenger: BinaryMessenger) = MethodChannel(messenger, NAME).setMethodCallHandler(this)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "export" -> result.success(center.store.export().toString())
                "ack" -> {
                    center.store.ack(call.argument<List<String>>("captures").orEmpty(), call.argument<List<String>>("dismissed").orEmpty())
                    for (id in call.argument<List<String>>("captures").orEmpty()) CaptureNotifier.cancel(activity, id)
                    result.success(null)
                }
                "dismiss" -> {
                    val id = call.argument<String>("id")!!
                    center.store.dismiss(id)
                    center.store.ack(emptyList(), listOf(id))
                    CaptureNotifier.cancel(activity, id)
                    result.success(null)
                }
                "permissions" -> result.success(permissions().toString())
                "open" -> result.success(open(call.argument<String>("access")!!))
                "config" -> result.success(center.store.config().toJson().toString())
                "setConfig" -> {
                    val next = CaptureConfig.fromJson(JSONObject(call.argument<String>("json")!!))
                    center.store.setConfig(next)
                    // Always (idempotent): an app update can leave the components in their manifest default (off).
                    center.applyComponents(next.enabled)
                    SmartCaptureService.instance?.refresh()
                    result.success(null)
                }
                "apps" -> result.success(apps().toString())
                "setRecents" -> {
                    center.store.setRecents(call.argument<String>("json")!!)
                    result.success(null)
                }
                "sample" -> {
                    val sample = Capture(
                        "sample", 45000, call.argument<String>("payee"), null, null, activity.packageName,
                        call.argument<String>("app") ?: "Splitify", CaptureSource.NOTIFICATION, System.currentTimeMillis(),
                    )
                    center.present(sample, sample = true)
                    result.success(BubbleController.showing)
                }
                "reset" -> {
                    center.store.reset()
                    BubbleController.hide("signed out")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: RuntimeException) {
            result.error("capture", e.message, null)
        }
    }

    private fun permissions(): JSONObject {
        val nm = activity.getSystemService(android.app.NotificationManager::class.java)
        val post = if (Build.VERSION.SDK_INT >= 33) {
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else {
            nm.areNotificationsEnabled()
        }
        return JSONObject()
            .put("supported", Build.VERSION.SDK_INT >= 26)
            .put("sdk", Build.VERSION.SDK_INT)
            .put("notifications", listenerEnabled())
            .put("overlay", Build.VERSION.SDK_INT >= 26 && Settings.canDrawOverlays(activity))
            .put("accessibility", accessibilityEnabled())
            .put("post_notifications", post)
            .put("listening", PaymentNotificationListener.connected)
            .put("smart_connected", SmartCaptureService.instance != null)
    }

    private fun listenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(activity.contentResolver, "enabled_notification_listeners") ?: return false
        val me = ComponentName(activity, PaymentNotificationListener::class.java)
        return flat.split(':').any { ComponentName.unflattenFromString(it) == me }
    }

    private fun accessibilityEnabled(): Boolean {
        val flat = Settings.Secure.getString(activity.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val me = ComponentName(activity, SmartCaptureService::class.java)
        val split = TextUtils.SimpleStringSplitter(':').apply { setString(flat) }
        return split.any { ComponentName.unflattenFromString(it) == me }
    }

    /** Opens the exact system screen for [access]; false when no screen could open. */
    private fun open(access: String): Boolean {
        val pkg = Uri.parse("package:${activity.packageName}")
        val intents = when (access) {
            "notifications" -> listOfNotNull(
                if (Build.VERSION.SDK_INT >= 30) {
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).putExtra(
                        Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                        ComponentName(activity, PaymentNotificationListener::class.java).flattenToString(),
                    )
                } else {
                    null
                },
                Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS),
            )
            "overlay" -> listOf(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, pkg))
            "accessibility" -> listOf(
                Intent("android.settings.ACCESSIBILITY_DETAILS_SETTINGS").putExtra(
                    Intent.EXTRA_COMPONENT_NAME,
                    ComponentName(activity, SmartCaptureService::class.java).flattenToString(),
                ),
                Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS),
            )
            "postNotifications" -> listOf(
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName),
            )
            "appInfo" -> listOf(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg))
            else -> emptyList()
        }
        for (i in intents) {
            try {
                activity.startActivity(i)
                return true
            } catch (_: RuntimeException) {
                // try the next, more general screen
            }
        }
        return false
    }

    private fun apps(): JSONArray {
        val pm = activity.packageManager
        val out = JSONArray()
        for (a in center.recipes.apps) {
            if (a.debugOnly && !center.debug) continue
            val installed = try {
                pm.getPackageInfo(a.packageName, 0)
                true
            } catch (_: PackageManager.NameNotFoundException) {
                false
            }
            out.put(
                JSONObject().put("package", a.packageName).put("name", a.name).put("kind", a.kind.name.lowercase())
                    .put("default_on", a.defaultOn).put("installed", installed),
            )
        }
        return out
    }

    companion object {
        const val NAME = "splitify/capture"
    }
}
