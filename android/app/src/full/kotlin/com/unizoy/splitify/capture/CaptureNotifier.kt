package com.unizoy.splitify.capture

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import com.unizoy.splitify.R

/**
 * Fallback when the bubble cannot draw (no "display over other apps", S-225): a heads-up notification with
 * **Add** (opens the capture link straight from the notification, no trampoline) and **Not now**.
 */
object CaptureNotifier {
    private const val CHANNEL = "payment_capture"

    fun show(context: Context, capture: Capture, sample: Boolean = false) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 24 && !nm.areNotificationsEnabled()) return
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, context.getString(R.string.capture_channel), NotificationManager.IMPORTANCE_HIGH)
                    .apply { description = context.getString(R.string.capture_channel_description) },
            )
        }
        val amount = IndianMoney.format(capture.amountPaise)
        val title = if (capture.payee == null) {
            context.getString(R.string.capture_bubble_paid_amount, amount)
        } else {
            context.getString(R.string.capture_bubble_paid_to, amount, capture.payee)
        }
        val link = Uri.parse(if (sample) "splitify://app/account/payment-bubble" else "splitify://capture?id=${capture.id}")
        val open = PendingIntent.getActivity(
            context,
            capture.id.hashCode(),
            Intent(Intent.ACTION_VIEW, link).setPackage(context.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val later = PendingIntent.getBroadcast(
            context,
            capture.id.hashCode(),
            Intent(context, CaptureActionReceiver::class.java).setAction(CaptureActionReceiver.NOT_NOW)
                .putExtra(CaptureActionReceiver.EXTRA_ID, capture.id).putExtra(CaptureActionReceiver.EXTRA_SAMPLE, sample),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
        b.setSmallIcon(R.drawable.ic_stat_splitify)
            .setColor(0xFF5057EA.toInt())
            .setContentTitle(title)
            .setContentText(context.getString(R.string.capture_notification_text, capture.appName))
            .setCategory(Notification.CATEGORY_RECOMMENDATION)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, context.getString(R.string.capture_bubble_add_short), open).build())
            .addAction(Notification.Action.Builder(null, context.getString(R.string.capture_bubble_not_now), later).build())
        if (Build.VERSION.SDK_INT >= 26) b.setTimeoutAfter(CaptureStore.KEEP_MS)
        nm.notify(tag(capture.id), ID, b.build())
    }

    /** Redraws an already posted notification with filled-in fields (no new alert). */
    fun update(context: Context, capture: Capture) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.activeNotifications.any { it.tag == tag(capture.id) }) show(context, capture)
    }

    fun cancel(context: Context, id: String) {
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(tag(id), ID)
    }

    private const val ID = 18_02
    private fun tag(id: String) = "capture:$id"
}

/** "Not now" from the fallback notification. */
class CaptureActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != NOT_NOW) return
        val id = intent.getStringExtra(EXTRA_ID) ?: return
        if (!intent.getBooleanExtra(EXTRA_SAMPLE, false)) CaptureCenter.get(context).store.dismiss(id)
        CaptureNotifier.cancel(context, id)
    }

    companion object {
        const val NOT_NOW = "com.unizoy.splitify.capture.NOT_NOW"
        const val EXTRA_ID = "id"
        const val EXTRA_SAMPLE = "sample"
    }
}
