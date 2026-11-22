package com.unizoy.splitify.capture

import android.app.Notification
import android.os.Build
import android.os.Bundle
import android.os.Parcelable
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Source ① (X4): reads payment alerts posted by allow-listed UPI, bank and SMS apps. Event-driven (the system
 * binds it and rebinds after reboot or a process kill); text goes straight to the parser and is never stored.
 */
class PaymentNotificationListener : NotificationListenerService() {
    override fun onListenerConnected() {
        connected = true
    }

    override fun onListenerDisconnected() {
        connected = false
    }
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName == packageName || sbn.isOngoing) return
        val n = sbn.notification ?: return
        if ((n.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return
        val center = CaptureCenter.get(this)
        if (center.recipes.app(sbn.packageName, center.debug) == null) return
        // Feature off (never turned on, or signed out): don't even look at the text (phase 19, S-208).
        val config = center.store.config()
        if (!config.enabled || !config.notifications) return
        val extras = n.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = lastMessage(extras)
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
            ?: extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        center.onNotification(sbn.packageName, title, text, sbn.postTime)
    }

    companion object {
        /** True while Android has the listener bound (settings screen + e2e wait for it). */
        @Volatile
        var connected = false
            private set
    }

    /** SMS apps use MessagingStyle: the newest message is the SMS that just arrived. */
    private fun lastMessage(extras: Bundle): String? {
        val messages: Array<out Parcelable>? = if (Build.VERSION.SDK_INT >= 33) {
            extras.getParcelableArray(Notification.EXTRA_MESSAGES, Parcelable::class.java)
        } else {
            @Suppress("DEPRECATION")
            extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        }
        val last = messages?.lastOrNull() as? Bundle ?: return null
        return last.getCharSequence("text")?.toString()
    }
}
