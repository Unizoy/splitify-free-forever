package dev.splitify.fakeupi;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * Posts a payment notification like a UPI app (phase 18b e2e). Also a broadcast receiver so the PC script can
 * post any text: adb shell am broadcast -n dev.splitify.fakeupi/.Notifier --es title "…" --es text "…"
 * (needs `pm grant dev.splitify.fakeupi android.permission.POST_NOTIFICATIONS`).
 */
public class Notifier extends BroadcastReceiver {
    private static final String CHANNEL = "payments";
    private static int next = 100;

    @Override
    public void onReceive(Context context, Intent intent) {
        String title = intent.getStringExtra("title");
        String text = intent.getStringExtra("text");
        post(context, title == null ? "" : title, text == null ? "" : text);
    }

    static void post(Context context, String title, String text) {
        NotificationManager nm = context.getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel(CHANNEL, "Payments", NotificationManager.IMPORTANCE_DEFAULT));
        Notification n = new Notification.Builder(context, CHANNEL)
            .setSmallIcon(android.R.drawable.stat_notify_more)
            .setContentTitle(title)
            .setContentText(text)
            .setAutoCancel(true)
            .build();
        nm.notify(next++, n);
        Log.i(PayActivity.TAG, "notified " + title);
    }
}
