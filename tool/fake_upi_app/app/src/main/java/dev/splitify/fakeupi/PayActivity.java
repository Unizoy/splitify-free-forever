package dev.splitify.fakeupi;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.widget.TextView;

/**
 * Fake UPI app: logs the exact link it was opened with (logcat tag {@code FAKE_UPI}), shows it for a moment
 * and goes back to the caller with a "SUCCESS" result, like a UPI app after the PIN step. Splitify never trusts
 * that result (rule 13: a payment is recorded only on "Mark as paid").
 */
public class PayActivity extends Activity {
    static final String TAG = "FAKE_UPI";
    static final long HOLD_MS = 1500;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Uri data = getIntent().getData();
        String uri = data == null ? "" : data.toString();
        Log.i(TAG, uri);

        TextView view = new TextView(this);
        view.setText("Fake UPI\n\n" + uri);
        view.setTextIsSelectable(true);
        view.setPadding(48, 96, 48, 48);
        view.setTextSize(16);
        setContentView(view);

        Intent result = new Intent();
        result.putExtra("Status", "SUCCESS");
        result.putExtra("responseCode", "00");
        result.putExtra("txnId", "FAKE" + System.currentTimeMillis());
        setResult(RESULT_OK, result);
        new Handler(Looper.getMainLooper()).postDelayed(this::finish, HOLD_MS);
    }
}
