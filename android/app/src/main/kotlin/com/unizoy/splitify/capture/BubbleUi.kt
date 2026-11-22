package com.unizoy.splitify.capture

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextPaint
import android.text.TextUtils
import android.text.style.MetricAffectingSpan
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.unizoy.splitify.R

/**
 * Design tokens for the native bubble, copied from `lib/ui/theme/app_colors.dart` (light + dark), radii from
 * `app_radii.dart`, fonts from the Flutter assets (Instrument Serif for money, Inter for text) — S-225.
 */
data class BubbleTheme(
    val surface: Int,
    val surfaceGlass: Int,
    val border: Int,
    val textPrimary: Int,
    val textSecondary: Int,
    val chip: Int,
    val onChip: Int,
    val primaryFill: Int,
    val onPrimaryFill: Int,
    val money: Int,
    val onMoney: Int,
    val target: Int,
    val dark: Boolean,
) {
    companion object {
        private val LIGHT = BubbleTheme(
            surface = 0xFFFFFFFF.toInt(), surfaceGlass = 0xEBFFFFFF.toInt(), border = 0xFFE3E8EF.toInt(),
            textPrimary = 0xFF121926.toInt(), textSecondary = 0xFF697586.toInt(), chip = 0xFFEEF2F6.toInt(),
            onChip = 0xFF121926.toInt(), primaryFill = 0xFF5057EA.toInt(), onPrimaryFill = 0xFFFFFFFF.toInt(),
            money = 0xFFFDB022.toInt(), onMoney = 0xFF121926.toInt(), target = 0xE6121926.toInt(), dark = false,
        )
        private val DARK = BubbleTheme(
            surface = 0xFF141419.toInt(), surfaceGlass = 0xEB141419.toInt(), border = 0xFF2C2C36.toInt(),
            textPrimary = 0xFFF5F5F7.toInt(), textSecondary = 0xFFA1A1AA.toInt(), chip = 0xFF24242D.toInt(),
            onChip = 0xFFF5F5F7.toInt(), primaryFill = 0xFF5057EA.toInt(), onPrimaryFill = 0xFFFFFFFF.toInt(),
            money = 0xFFFDB022.toInt(), onMoney = 0xFF121926.toInt(), target = 0xE6F5F5F7.toInt(), dark = true,
        )

        /** [mode] is the app's theme setting ("system" | "light" | "dark"). */
        fun of(context: Context, mode: String): BubbleTheme {
            val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
            return when (mode) {
                "dark" -> DARK
                "light" -> LIGHT
                else -> if (night) DARK else LIGHT
            }
        }
    }
}

/** Small view helpers so the bubble code reads like a layout. */
class BubbleUi(private val context: Context, val theme: BubbleTheme) {
    private val density = context.resources.displayMetrics.density

    val serif: Typeface by lazy { font("InstrumentSerif-Regular.ttf") ?: Typeface.SERIF }
    val sans: Typeface by lazy { font("Inter-Variable.ttf") ?: Typeface.SANS_SERIF }
    val sansBold: Typeface by lazy {
        if (android.os.Build.VERSION.SDK_INT >= 28) Typeface.create(sans, 600, false) else Typeface.create(sans, Typeface.BOLD)
    }

    fun dp(v: Int): Int = (v * density).toInt()

    private fun font(name: String): Typeface? = try {
        Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/$name")
    } catch (_: RuntimeException) {
        null
    }

    fun rounded(color: Int, radiusDp: Int, strokeColor: Int? = null): GradientDrawable = GradientDrawable().apply {
        setColor(color)
        cornerRadius = dp(radiusDp).toFloat()
        if (strokeColor != null) setStroke(dp(1), strokeColor)
    }

    fun circle(color: Int): GradientDrawable = GradientDrawable().apply {
        shape = GradientDrawable.OVAL
        setColor(color)
    }

    fun text(value: CharSequence, sizeSp: Float, color: Int, bold: Boolean = false, caps: Boolean = false): TextView =
        TextView(context).apply {
            text = value
            setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
            setTextColor(color)
            typeface = if (bold) sansBold else sans
            if (caps) {
                isAllCaps = true
                letterSpacing = 0.12f
            }
            includeFontPadding = false
        }

    /** "₹500": the rupee sign in Inter (Instrument Serif has no ₹ glyph, LEARNINGS phase 08), digits serif. */
    fun amount(formatted: String, sizeSp: Float): TextView {
        val s = SpannableStringBuilder(formatted)
        formatted.forEachIndexed { i, ch ->
            val face = if (ch.isDigit() || ch == ',' || ch == '.') serif else sans
            s.setSpan(FaceSpan(face), i, i + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        return text(s, sizeSp, theme.textPrimary).apply { maxLines = 1; ellipsize = TextUtils.TruncateAt.END }
    }

    /** A pill button; [primary] = amber money action (06 §2), else a quiet text button. */
    fun pill(label: String, primary: Boolean, onClick: () -> Unit): TextView = text(label, 16f, if (primary) theme.onMoney else theme.textPrimary, bold = true).apply {
        gravity = Gravity.CENTER
        minHeight = dp(if (primary) 52 else 48)
        setPadding(dp(20), dp(12), dp(20), dp(12))
        background = if (primary) rounded(theme.money, 999) else null
        isClickable = true
        noFocusHighlight()
        setOnClickListener { onClick() }
    }

    fun chip(label: String, description: String, onClick: () -> Unit): TextView = text(label, 14f, theme.onChip, bold = true).apply {
        gravity = Gravity.CENTER
        maxLines = 1
        ellipsize = TextUtils.TruncateAt.END
        maxWidth = dp(320)
        minHeight = dp(40)
        setPadding(dp(14), dp(8), dp(14), dp(8))
        background = rounded(theme.chip, 999)
        contentDescription = description
        isClickable = true
        noFocusHighlight()
        setOnClickListener { onClick() }
    }

    /** The 56 dp handle: indigo circle, white Splitify mark, amber "₹" badge. */
    fun handle(description: String): FrameLayout = FrameLayout(context).apply {
        val size = dp(56)
        val face = FrameLayout(context).apply {
            background = circle(theme.primaryFill)
            elevation = dp(6).toFloat()
            addView(
                ImageView(context).apply { setImageResource(R.drawable.ic_capture_mark) },
                FrameLayout.LayoutParams(dp(26), dp(26), Gravity.CENTER),
            )
        }
        addView(face, FrameLayout.LayoutParams(size, size, Gravity.CENTER))
        val badge = text("₹", 12f, theme.onMoney, bold = true).apply {
            gravity = Gravity.CENTER
            background = circle(theme.money)
            elevation = dp(7).toFloat()
        }
        addView(badge, FrameLayout.LayoutParams(dp(22), dp(22), Gravity.TOP or Gravity.END))
        setPadding(dp(8), dp(8), dp(8), dp(8))
        contentDescription = description
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        isClickable = true
        noFocusHighlight()
    }

    /** Round ✕ drop target shown at the bottom while the handle is dragged. */
    fun target(description: String): FrameLayout = FrameLayout(context).apply {
        background = circle(theme.target)
        contentDescription = description
        addView(
            ImageView(context).apply {
                setImageResource(R.drawable.ic_capture_close)
                setColorFilter(if (theme.dark) Color.BLACK else Color.WHITE)
            },
            FrameLayout.LayoutParams(dp(28), dp(28), Gravity.CENTER),
        )
    }

    fun row(vararg views: View, gravity: Int = Gravity.CENTER_VERTICAL): LinearLayout = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        this.gravity = gravity
        views.forEach { addView(it) }
    }

    fun column(): LinearLayout = LinearLayout(context).apply { orientation = LinearLayout.VERTICAL }

    fun gap(heightDp: Int): View = View(context).apply { layoutParams = ViewGroup.LayoutParams(1, dp(heightDp)) }
}

/**
 * Overlay windows are FLAG_NOT_FOCUSABLE: once the phone leaves touch mode (a key press) Android would draw its
 * grey default focus highlight over the bubble. TalkBack still reaches the views (clickable + described).
 */
fun View.noFocusHighlight() {
    if (android.os.Build.VERSION.SDK_INT >= 26) defaultFocusHighlightEnabled = false
}

/** Typeface span that works below API 28. */
private class FaceSpan(private val face: Typeface) : MetricAffectingSpan() {
    override fun updateDrawState(tp: TextPaint) {
        tp.typeface = face
    }

    override fun updateMeasureState(tp: TextPaint) {
        tp.typeface = face
    }
}

/** Lays chips out in rows, wrapping at the right edge (works at 200 % font size). */
class FlowLayout(context: Context, private val gapPx: Int) : ViewGroup(context) {
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val maxW = MeasureSpec.getSize(widthMeasureSpec) - paddingLeft - paddingRight
        var x = 0
        var y = 0
        var rowH = 0
        for (i in 0 until childCount) {
            val c = getChildAt(i)
            c.measure(MeasureSpec.makeMeasureSpec(maxW, MeasureSpec.AT_MOST), MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED))
            if (x > 0 && x + c.measuredWidth > maxW) {
                x = 0
                y += rowH + gapPx
                rowH = 0
            }
            x += c.measuredWidth + gapPx
            rowH = maxOf(rowH, c.measuredHeight)
        }
        setMeasuredDimension(MeasureSpec.getSize(widthMeasureSpec), y + rowH + paddingTop + paddingBottom)
    }

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        val maxW = r - l - paddingLeft - paddingRight
        var x = 0
        var y = 0
        var rowH = 0
        for (i in 0 until childCount) {
            val c = getChildAt(i)
            if (x > 0 && x + c.measuredWidth > maxW) {
                x = 0
                y += rowH + gapPx
                rowH = 0
            }
            c.layout(paddingLeft + x, paddingTop + y, paddingLeft + x + c.measuredWidth, paddingTop + y + c.measuredHeight)
            x += c.measuredWidth + gapPx
            rowH = maxOf(rowH, c.measuredHeight)
        }
    }
}
