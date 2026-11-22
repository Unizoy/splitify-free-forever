package com.unizoy.splitify.capture

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Source ② "smart capture" (X4, S-220): limited to allow-listed UPI apps, reads the visible text of their pay and
 * success screens. Never reads editable or password nodes, stops at the first "UPI PIN" text (so the PIN pad is
 * never read), keeps nothing but the parsed fields. Content changes are coalesced (one read per 300 ms); there
 * is no polling. Declares `isAccessibilityTool="false"`.
 */
class SmartCaptureService : AccessibilityService() {
    private val main = Handler(Looper.getMainLooper())
    private var pendingPkg: String? = null
    private val read = Runnable { readNow() }

    override fun onServiceConnected() {
        instance = this
        refresh()
    }

    /** Re-applies the allow-list and the per-app switches (called again when the settings change). */
    fun refresh() {
        val center = CaptureCenter.get(this)
        val config = center.store.config()
        val packages = center.recipes.apps
            .filter { it.kind == AppKind.UPI && (center.debug || !it.debugOnly) && config.appOn(it) }
            .map { it.packageName }
        serviceInfo = serviceInfo.apply { packageNames = packages.toTypedArray() }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return
        if (pkg == packageName) return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        ) {
            return
        }
        pendingPkg = pkg
        main.removeCallbacks(read)
        main.postDelayed(read, if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) 120L else 300L)
    }

    private fun readNow() {
        val pkg = pendingPkg ?: return
        val center = CaptureCenter.get(this)
        // Feature or smart capture off (e.g. after sign-out): read no screen at all (phase 19, S-208).
        val config = center.store.config()
        if (!config.enabled || !config.smart) return
        val root = rootInActiveWindow ?: return
        if (root.packageName?.toString() != pkg) return
        val texts = mutableListOf<String>()
        val pin = collect(root, texts, center.recipes.pin, 0)
        center.onScreen(pkg, if (pin) PIN_MARKER else texts.joinToString("\n"))
    }

    /** Depth-first visible text; returns true (and stops) when the screen asks for a UPI PIN. */
    private fun collect(node: AccessibilityNodeInfo, out: MutableList<String>, pin: Regex, depth: Int): Boolean {
        if (depth > MAX_DEPTH || out.size > MAX_NODES) return false
        if (node.isPassword || node.isEditable || node.className?.contains("EditText") == true) return false
        val t = node.text?.toString() ?: node.contentDescription?.toString()
        if (!t.isNullOrBlank()) {
            if (pin.containsMatchIn(t)) return true
            out += t
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (collect(child, out, pin, depth + 1)) return true
        }
        return false
    }

    override fun onInterrupt() = Unit

    override fun onDestroy() {
        main.removeCallbacks(read)
        if (instance === this) instance = null
        super.onDestroy()
    }

    companion object {
        private const val MAX_DEPTH = 30
        private const val MAX_NODES = 400

        /** What the parser sees for a PIN screen: matches the recipes' `pin` pattern, nothing else read. */
        private const val PIN_MARKER = "Enter UPI PIN"

        /** The connected service (its context can add accessibility overlays without "display over apps"). */
        @Volatile
        var instance: SmartCaptureService? = null
            private set
    }
}
