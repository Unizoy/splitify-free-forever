package com.unizoy.splitify

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.text.format.DateUtils
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen balance widget (X3, phase 18). The app writes the values with `home_widget`
 * (lib/features/widget/domain/widget_data.dart, keys in WidgetKeys); this only places them.
 * Tapping anywhere opens the app (which locks first when app lock is on).
 */
abstract class BalanceWidget(private val layout: Int) : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, layout)
            bind(context, views, widgetData)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun bind(context: Context, views: RemoteViews, data: SharedPreferences) {
        val brand = data.getString("brand", null) ?: context.getString(R.string.widget_brand)
        val status = data.getString("status", null) ?: context.getString(R.string.widget_open_app)
        val tone = data.getString("tone", null) ?: "signed_out"
        views.setTextViewText(R.id.widget_brand, brand)
        views.setTextViewText(R.id.widget_status, status)
        views.setTextColor(R.id.widget_status, context.getColor(toneColor(tone)))
        views.setTextViewText(R.id.widget_line1, data.getString("line1", null) ?: "")
        views.setTextViewText(R.id.widget_line2, data.getString("line2", null) ?: "")

        val pending = data.getString("pending", null) ?: ""
        val updatedAt = data.getString("updated_at", null)?.toLongOrNull() ?: 0L
        val template = data.getString("updated_template", null) ?: "%s"
        val footer = when {
            pending.isNotEmpty() -> pending
            updatedAt > 0L -> template.replace(
                "%s",
                DateUtils.getRelativeTimeSpanString(
                    updatedAt,
                    System.currentTimeMillis(),
                    DateUtils.MINUTE_IN_MILLIS,
                    DateUtils.FORMAT_ABBREV_RELATIVE,
                ).toString(),
            )
            else -> ""
        }
        views.setTextViewText(R.id.widget_footer, footer)
        views.setTextColor(
            R.id.widget_footer,
            context.getColor(
                if (pending.isNotEmpty()) R.color.widget_unsynced else R.color.widget_text_secondary,
            ),
        )
        views.setOnClickPendingIntent(
            R.id.widget_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )
    }

    private fun toneColor(tone: String): Int = when (tone) {
        "owed" -> R.color.widget_owed
        "owe" -> R.color.widget_owe
        "mixed" -> R.color.widget_primary
        else -> R.color.widget_settled
    }
}

/** 2x2 widget. */
class BalanceWidgetSmall : BalanceWidget(R.layout.widget_balance_small)

/** 4x2 widget. */
class BalanceWidgetWide : BalanceWidget(R.layout.widget_balance_wide)
