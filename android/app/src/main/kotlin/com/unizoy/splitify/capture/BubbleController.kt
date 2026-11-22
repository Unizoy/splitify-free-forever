package com.unizoy.splitify.capture

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.format.DateFormat
import android.util.Log
import android.view.Display
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import com.unizoy.splitify.R
import java.util.Date
import kotlin.math.hypot

/**
 * The floating payment bubble (phase 18b T3, S-225): a 56 dp handle on the screen edge that can be dragged,
 * snaps to the nearest edge and is hidden by dropping it on the ✕ target; tapping it opens a card with the
 * captured payment, recent group/friend chips, **Add to Splitify** and **Not now**. Native only, so it works
 * while the Flutter engine is not running; nothing polls — two timers run only while it is on screen.
 */
@SuppressLint("StaticFieldLeak")
object BubbleController {
    private const val TAG = "SplitifyBubble"
    private const val COLLAPSE_MS = 8_000L
    private const val HIDE_MS = 60_000L

    private val main = Handler(Looper.getMainLooper())
    private var wm: WindowManager? = null
    private var ui: BubbleUi? = null
    private var appContext: Context? = null
    private var handle: FrameLayout? = null
    private var handleParams: WindowManager.LayoutParams? = null
    private var card: View? = null
    private var target: View? = null
    private var windowType = 0

    /** The payment on show; null while only the "Splitting this?" handle is up (during a payment). */
    var current: Capture? = null
        private set
    private var sample = false

    private val collapse = Runnable { collapseCard() }
    private val autoHide = Runnable { hide("timeout") }

    val showing: Boolean get() = handle != null

    /** Shows [capture] expanded; false when no overlay is possible (the caller then posts the notification). */
    fun show(context: Context, capture: Capture, isSample: Boolean = false): Boolean {
        if (!ensureWindow(context)) return false
        current = capture
        sample = isSample
        addHandle()
        expand()
        restartTimers()
        log("shown ${capture.id}")
        return true
    }

    /** Collapsed "Splitting this?" handle while the UPI app shows its pay screen (smart capture). */
    fun showDuringPayment(context: Context): Boolean {
        if (current != null) return true
        if (!ensureWindow(context)) return false
        addHandle()
        restartTimers()
        log("payment in progress")
        return true
    }

    /** Never cover a PIN screen: drop a payment-in-progress handle (a captured payment stays). */
    fun hideDuringPin() {
        if (current == null && handle != null) hide("pin")
    }

    /** A later source filled in a missing ref or name: redraw the open card. */
    fun update(capture: Capture) {
        if (current?.id != capture.id) return
        current = capture
        if (card != null) {
            removeCard()
            expand()
        }
    }

    fun hide(reason: String) {
        main.removeCallbacks(collapse)
        main.removeCallbacks(autoHide)
        removeCard()
        removeTarget()
        handle?.let { safeRemove(it) }
        handle = null
        current = null
        sample = false
        log("hidden ($reason)")
    }

    // ----------------------------------------------------------------------------------------------- windows

    private fun ensureWindow(context: Context): Boolean {
        val app = context.applicationContext
        val center = CaptureCenter.get(app)
        val smart = SmartCaptureService.instance
        val (type, ctx) = when {
            Build.VERSION.SDK_INT >= 26 && Settings.canDrawOverlays(app) ->
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY to windowContext(app, WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
            Build.VERSION.SDK_INT >= 26 && smart != null ->
                WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY to (smart as Context)
            else -> return false
        }
        // The app's theme or the phone's dark mode may have changed since the bubble was drawn: redraw then.
        val theme = BubbleTheme.of(ctx, center.store.config().theme)
        if (handle != null && type == windowType && ui?.theme == theme) return true
        if (handle != null) {
            val keep = current
            hide("restyle")
            current = keep
        }
        windowType = type
        appContext = app
        wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        ui = BubbleUi(ctx, theme)
        return true
    }

    private fun windowContext(app: Context, type: Int): Context {
        if (Build.VERSION.SDK_INT < 30) return app
        val display = (app.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager).getDisplay(Display.DEFAULT_DISPLAY)
        return app.createWindowContext(display, type, null)
    }

    private fun params(w: Int, h: Int, focusOutside: Boolean = false) = WindowManager.LayoutParams(
        w,
        h,
        windowType,
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            (if (focusOutside) WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH else 0),
        PixelFormat.TRANSLUCENT,
    ).apply { gravity = Gravity.TOP or Gravity.START }

    private fun screen(): Pair<Int, Int> {
        val w = wm ?: return 1080 to 2400
        return if (Build.VERSION.SDK_INT >= 30) {
            val b = w.currentWindowMetrics.bounds
            b.width() to b.height()
        } else {
            val m = appContext!!.resources.displayMetrics
            m.widthPixels to m.heightPixels
        }
    }

    private fun safeRemove(v: View) {
        try {
            wm?.removeView(v)
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "view already gone: ${e.message}")
        }
    }

    // ------------------------------------------------------------------------------------------------ handle

    @SuppressLint("ClickableViewAccessibility")
    private fun addHandle() {
        if (handle != null) {
            refreshHandleLabel()
            return
        }
        val u = ui ?: return
        val view = u.handle(handleLabel())
        val size = u.dp(72)
        val (sw, sh) = screen()
        val p = params(size, size).apply {
            x = sw - size
            y = (sh * 0.30).toInt()
        }
        val slop = ViewConfiguration.get(view.context).scaledTouchSlop
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var dragging = false
        view.setOnTouchListener { _, e ->
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = e.rawX; downY = e.rawY; startX = p.x; startY = p.y; dragging = false
                    restartTimers()
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX
                    val dy = e.rawY - downY
                    if (!dragging && hypot(dx, dy) > slop) {
                        dragging = true
                        removeCard()
                        showTarget()
                    }
                    if (dragging) {
                        p.x = (startX + dx).toInt()
                        p.y = (startY + dy).toInt().coerceIn(0, sh - size)
                        wm?.updateViewLayout(view, p)
                        target?.isActivated = overTarget(p, size)
                        target?.scaleX = if (overTarget(p, size)) 1.15f else 1f
                        target?.scaleY = target?.scaleX ?: 1f
                    }
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    if (dragging) {
                        val drop = overTarget(p, size)
                        removeTarget()
                        if (drop) hide("dropped on target") else snap(view, p, size)
                    } else if (e.actionMasked == MotionEvent.ACTION_UP) {
                        view.performClick()
                    }
                    true
                }
                else -> false
            }
        }
        view.setOnClickListener { if (card == null) expand() else collapseCard() }
        try {
            wm?.addView(view, p)
            handle = view
            handleParams = p
            view.post { logUi(view) }
        } catch (e: RuntimeException) {
            Log.w(TAG, "cannot add the bubble: ${e.message}")
        }
    }

    private fun handleLabel(): String {
        val c = appContext ?: return ""
        val cap = current
        return if (cap == null) {
            c.getString(R.string.capture_bubble_during)
        } else {
            c.getString(R.string.capture_bubble_handle, IndianMoney.format(cap.amountPaise), cap.payee ?: cap.appName)
        }
    }

    private fun refreshHandleLabel() {
        handle?.contentDescription = handleLabel()
    }

    private fun snap(view: View, p: WindowManager.LayoutParams, size: Int) {
        val (sw, _) = screen()
        val end = if (p.x + size / 2 < sw / 2) 0 else sw - size
        ValueAnimator.ofInt(p.x, end).apply {
            duration = 180
            addUpdateListener {
                p.x = it.animatedValue as Int
                if (handle === view) wm?.updateViewLayout(view, p)
            }
            start()
        }
    }

    private fun showTarget() {
        val u = ui ?: return
        if (target != null) return
        val size = u.dp(64)
        val (sw, sh) = screen()
        val view = u.target(appContext!!.getString(R.string.capture_bubble_target))
        val p = params(size, size).apply {
            x = (sw - size) / 2
            y = sh - size - u.dp(96)
        }
        try {
            wm?.addView(view, p)
            target = view
        } catch (e: RuntimeException) {
            Log.w(TAG, "no target: ${e.message}")
        }
    }

    private fun overTarget(p: WindowManager.LayoutParams, size: Int): Boolean {
        val u = ui ?: return false
        val (sw, sh) = screen()
        val cx = p.x + size / 2f
        val cy = p.y + size / 2f
        return hypot(cx - sw / 2f, cy - (sh - u.dp(96) - u.dp(32))) < u.dp(72)
    }

    private fun removeTarget() {
        target?.let { safeRemove(it) }
        target = null
    }

    // -------------------------------------------------------------------------------------------------- card

    private fun expand() {
        val u = ui ?: return
        val ctx = appContext ?: return
        removeCard()
        val view = buildCard(u, ctx)
        val (sw, sh) = screen()
        val width = minOf(sw - u.dp(16), u.dp(392))
        view.measure(
            View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec(sh, View.MeasureSpec.AT_MOST),
        )
        val h = view.measuredHeight
        val hp = handleParams
        val below = (hp?.y ?: (sh * 0.3).toInt()) + u.dp(72)
        val p = params(width, WindowManager.LayoutParams.WRAP_CONTENT, focusOutside = true).apply {
            x = (sw - width) / 2
            y = if (below + h < sh - u.dp(24)) below else maxOf(u.dp(24), (hp?.y ?: 0) - h)
        }
        if (Build.VERSION.SDK_INT >= 31 && wm?.isCrossWindowBlurEnabled == true) {
            p.flags = p.flags or WindowManager.LayoutParams.FLAG_BLUR_BEHIND
            p.blurBehindRadius = u.dp(16)
            p.dimAmount = 0f
        }
        view.setOnTouchListener { _, e ->
            if (e.actionMasked == MotionEvent.ACTION_OUTSIDE) collapseCard()
            restartTimers()
            false
        }
        try {
            wm?.addView(view, p)
            card = view
            view.sendAccessibilityEvent(AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED)
            view.post { logUi(view) }
        } catch (e: RuntimeException) {
            Log.w(TAG, "cannot add the card: ${e.message}")
        }
        main.removeCallbacks(collapse)
        main.postDelayed(collapse, COLLAPSE_MS)
    }

    private fun collapseCard() {
        main.removeCallbacks(collapse)
        removeCard()
    }

    private fun removeCard() {
        card?.let { safeRemove(it) }
        card = null
    }

    private fun restartTimers() {
        main.removeCallbacks(autoHide)
        main.postDelayed(autoHide, HIDE_MS)
        if (card != null) {
            main.removeCallbacks(collapse)
            main.postDelayed(collapse, COLLAPSE_MS)
        }
    }

    private fun buildCard(u: BubbleUi, ctx: Context): View {
        val t = u.theme
        val cap = current
        val outer = FrameLayout(ctx).apply { setPadding(u.dp(8), u.dp(8), u.dp(8), u.dp(16)) }
        val body = u.column().apply {
            val glass = Build.VERSION.SDK_INT >= 31 && wm?.isCrossWindowBlurEnabled == true
            background = u.rounded(if (glass) t.surfaceGlass else t.surface, 28, t.border)
            elevation = u.dp(10).toFloat()
            setPadding(u.dp(20), u.dp(18), u.dp(20), u.dp(14))
        }
        outer.addView(body, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT))

        // Header: app icon, "GOOGLE PAY · 10:42", ⋮
        val icon = ImageView(ctx).apply {
            val pkg = cap?.appPackage ?: ctx.packageName
            setImageDrawable(
                try {
                    ctx.packageManager.getApplicationIcon(pkg)
                } catch (_: Exception) {
                    ctx.packageManager.getApplicationIcon(ctx.packageName)
                },
            )
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
        val caption = if (cap == null) {
            ctx.getString(R.string.capture_bubble_during_caption)
        } else {
            "${cap.appName} · ${DateFormat.getTimeFormat(ctx).format(Date(cap.capturedAt))}"
        }
        val head = u.text(caption, 12f, t.textSecondary, bold = true, caps = true).apply { maxLines = 2 }
        val more = u.text("⋮", 22f, t.textPrimary, bold = true).apply {
            gravity = Gravity.CENTER
            minWidth = u.dp(48)
            minHeight = u.dp(48)
            contentDescription = ctx.getString(R.string.capture_bubble_more)
            isClickable = true
            noFocusHighlight()
        }
        val headRow = u.row(icon, head, more)
        (icon.layoutParams as LinearLayout.LayoutParams).apply { width = u.dp(32); height = u.dp(32); marginEnd = u.dp(10) }
        (head.layoutParams as LinearLayout.LayoutParams).apply { width = 0; weight = 1f }
        body.addView(headRow)

        if (cap == null) {
            body.addView(u.gap(10))
            body.addView(u.text(ctx.getString(R.string.capture_bubble_during), 22f, t.textPrimary, bold = true))
            body.addView(u.gap(6))
            body.addView(u.text(ctx.getString(R.string.capture_bubble_during_body), 15f, t.textSecondary))
            body.addView(u.gap(12))
            body.addView(u.pill(ctx.getString(R.string.capture_bubble_hide), primary = false) { hide("user") })
            more.visibility = View.GONE
            return outer
        }

        body.addView(u.gap(8))
        body.addView(u.text(ctx.getString(R.string.capture_bubble_paid), 15f, t.textSecondary))
        body.addView(u.amount(IndianMoney.format(cap.amountPaise), 40f))
        if (cap.payee != null) {
            body.addView(
                u.text(ctx.getString(R.string.capture_bubble_to, cap.payee), 17f, t.textPrimary, bold = true).apply { maxLines = 2 },
            )
        }

        val actions = u.column()
        val menu = u.column().apply { visibility = View.GONE }
        val recents = if (sample) emptyList() else CaptureCenter.get(ctx).store.recents().take(3)
        if (recents.isNotEmpty()) {
            actions.addView(u.gap(14))
            actions.addView(u.text(ctx.getString(R.string.capture_bubble_add_to), 12f, t.textSecondary, bold = true, caps = true))
            actions.addView(u.gap(8))
            val flow = FlowLayout(ctx, u.dp(8))
            recents.forEach { r ->
                flow.addView(u.chip(r.name, ctx.getString(R.string.capture_bubble_add_to_named, r.name)) { add(r.id) })
            }
            actions.addView(flow)
        }
        actions.addView(u.gap(16))
        actions.addView(u.pill(ctx.getString(R.string.capture_bubble_add), primary = true) { add(null) })
        actions.addView(u.gap(4))
        actions.addView(u.pill(ctx.getString(R.string.capture_bubble_not_now), primary = false) { notNow() })
        body.addView(actions)

        menu.addView(u.gap(12))
        menu.addView(u.pill(ctx.getString(R.string.capture_bubble_mute_app, cap.appName), primary = false) { muteApp() })
        menu.addView(u.pill(ctx.getString(R.string.capture_bubble_settings), primary = false) { openSettings() })
        menu.addView(u.pill(ctx.getString(R.string.capture_bubble_back), primary = false) {
            menu.visibility = View.GONE
            actions.visibility = View.VISIBLE
        })
        body.addView(menu)
        more.setOnClickListener {
            val open = menu.visibility == View.VISIBLE
            menu.visibility = if (open) View.GONE else View.VISIBLE
            actions.visibility = if (open) View.VISIBLE else View.GONE
            restartTimers()
        }
        body.contentDescription = handleLabel()
        return outer
    }

    // ----------------------------------------------------------------------------------------------- actions

    private fun add(groupId: String?) {
        val cap = current ?: return
        val ctx = appContext ?: return
        if (sample) {
            hide("sample")
            return
        }
        val link = Uri.Builder().scheme("splitify").authority("capture").appendQueryParameter("id", cap.id).apply {
            if (groupId != null) appendQueryParameter("group", groupId)
        }.build()
        open(ctx, link)
        hide("add")
    }

    private fun notNow() {
        val cap = current ?: return
        if (!sample) CaptureCenter.get(appContext!!).store.dismiss(cap.id)
        hide("not now")
    }

    private fun muteApp() {
        val cap = current ?: return
        val center = CaptureCenter.get(appContext!!)
        if (!sample) {
            val c = center.store.config()
            center.store.setConfig(c.copy(apps = c.apps + (cap.appPackage to false)))
            center.store.dismiss(cap.id)
        }
        hide("muted ${cap.appPackage}")
    }

    private fun openSettings() {
        val ctx = appContext ?: return
        open(ctx, Uri.parse("splitify://app/account/payment-bubble"))
        hide("settings")
    }

    private fun open(ctx: Context, uri: Uri) {
        val intent = Intent(Intent.ACTION_VIEW, uri).setPackage(ctx.packageName)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        try {
            ctx.startActivity(intent)
        } catch (e: RuntimeException) {
            Log.w(TAG, "cannot open the app: ${e.message}")
        }
    }

    private fun log(msg: String) {
        if (CaptureCenter.isDebug(appContext)) Log.i(TAG, msg)
    }

    /**
     * Debug builds only: the bubble's texts and the screen centre of every tappable view, so the e2e script can
     * check the content and tap the real views (`uiautomator dump` does not see overlay windows).
     */
    private fun logUi(root: View) {
        if (!CaptureCenter.isDebug(appContext)) return
        fun walk(v: View) {
            if (v.visibility != View.VISIBLE) return
            val label = (v as? android.widget.TextView)?.text?.toString() ?: v.contentDescription?.toString()
            if (v.isClickable && label != null) {
                val at = IntArray(2)
                v.getLocationOnScreen(at)
                Log.i(TAG, "ui tap $label @ ${at[0] + v.width / 2} ${at[1] + v.height / 2}")
            } else if (v is android.widget.TextView && v.text.isNotEmpty()) {
                Log.i(TAG, "ui text ${v.text}")
            }
            if (v is android.view.ViewGroup) for (i in 0 until v.childCount) walk(v.getChildAt(i))
        }
        walk(root)
    }
}

/** ₹ with Indian grouping from paise, integer arithmetic only ("₹1,23,456.50", "₹500"). */
object IndianMoney {
    fun format(paise: Long): String {
        val rupees = paise / 100
        val rest = (paise % 100).toInt()
        val digits = rupees.toString()
        val grouped = if (digits.length <= 3) {
            digits
        } else {
            val head = digits.substring(0, digits.length - 3)
            val tail = digits.substring(digits.length - 3)
            head.reversed().chunked(2).joinToString(",").reversed() + "," + tail
        }
        return if (rest == 0) "₹$grouped" else "₹$grouped.${rest.toString().padStart(2, '0')}"
    }
}
