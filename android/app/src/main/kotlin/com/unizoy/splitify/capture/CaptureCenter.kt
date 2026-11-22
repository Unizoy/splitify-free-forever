package com.unizoy.splitify.capture

import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.util.Log
import java.util.UUID

/** SharedPreferences behind [CaptureStore] (file `splitify_capture`, separate from Flutter's prefs). */
private class PrefsKv(private val prefs: SharedPreferences) : KeyValue {
    override fun get(key: String): String? = prefs.getString(key, null)
    override fun put(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }
}

/**
 * Glue between the Android sources and the parser/store/bubble (phase 18b T2). One per process; every call
 * comes on the main thread (service callbacks, method channel). Logs carry ids and reasons only, never text.
 */
class CaptureCenter private constructor(private val context: Context) {
    val debug = isDebug(context)
    val recipes: Recipes by lazy {
        Recipes.parse(context.assets.open(Recipes.ASSET).bufferedReader().use { it.readText() })
    }
    val parser by lazy { PaymentParser(recipes) }
    val store = CaptureStore(PrefsKv(context.getSharedPreferences(CaptureStore.PREFS, Context.MODE_PRIVATE)))

    /** Package → when its pay screen was last seen (smart capture episodes, S-220). In memory only. */
    private val payingSeen = mutableMapOf<String, Long>()

    fun onNotification(pkg: String, title: String?, text: String?, postedAt: Long) {
        val config = store.config()
        if (!config.enabled || !config.notifications) return
        val app = recipes.app(pkg, debug) ?: return
        if (!config.appOn(app)) return
        when (val r = parser.parseNotification(pkg, title, text, debug)) {
            is ParseResult.Ignored -> log("ignored $pkg: ${r.reason}")
            is ParseResult.Debit -> keep(r.payment, app, postedAt)
        }
    }

    fun onScreen(pkg: String, text: String, now: Long = System.currentTimeMillis()) {
        val config = store.config()
        if (!config.enabled || !config.smart) return
        val app = recipes.app(pkg, debug) ?: return
        if (!config.appOn(app)) return
        val r = parser.parseScreen(pkg, text, debug)
        when (r.stage) {
            ScreenStage.PAYING -> {
                payingSeen[pkg] = now
                if (config.bubble && config.duringPayment) BubbleController.showDuringPayment(context)
            }
            ScreenStage.PIN -> {
                payingSeen[pkg] = now
                BubbleController.hideDuringPin()
            }
            ScreenStage.SUCCESS -> {
                val seen = payingSeen.remove(pkg)
                if (seen == null || now - seen > EPISODE_MS) {
                    log("success screen without a pay screen: ignored")
                    return
                }
                keep(r.payment!!, app, now)
            }
            ScreenStage.NONE -> Unit
        }
    }

    private fun keep(p: ParsedPayment, app: RecipeApp, at: Long) {
        val capture = Capture(UUID.randomUUID().toString(), p.amountPaise, p.payee, null, p.ref, app.packageName, app.name, p.source, at)
        when (val added = store.add(capture)) {
            is CaptureStore.AddResult.Added -> {
                log("capture added ${capture.id} ${p.source.wire} ${p.rule}")
                present(added.capture)
            }
            is CaptureStore.AddResult.Merged -> {
                log("capture merged ${added.capture.id}")
                BubbleController.update(added.capture)
                CaptureNotifier.update(context, added.capture)
            }
            CaptureStore.AddResult.Duplicate -> log("duplicate ignored")
        }
    }

    /** The bubble when it may draw, else the heads-up notification (S-225). */
    fun present(capture: Capture, sample: Boolean = false) {
        val config = store.config()
        if (config.bubble && BubbleController.show(context, capture, sample)) return
        CaptureNotifier.show(context, capture, sample)
    }

    /** Turns the listener and accessibility components on or off with the master switch (off by default). */
    fun applyComponents(enabled: Boolean) {
        val pm = context.packageManager
        val state = if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        for (cls in listOf(PaymentNotificationListener::class.java, SmartCaptureService::class.java)) {
            pm.setComponentEnabledSetting(ComponentName(context, cls), state, PackageManager.DONT_KILL_APP)
        }
        if (!enabled) BubbleController.hide("feature off")
    }

    private fun log(msg: String) {
        if (debug) Log.i(TAG, msg)
    }

    companion object {
        const val TAG = "SplitifyCapture"
        const val EPISODE_MS = 10 * 60 * 1000L

        @Volatile
        private var instance: CaptureCenter? = null

        fun get(context: Context): CaptureCenter =
            instance ?: synchronized(this) { instance ?: CaptureCenter(context.applicationContext).also { instance = it } }

        fun isDebug(context: Context?): Boolean =
            context != null && (context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }
}
