package dev.splitify.fakeupi;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.Typeface;
import android.os.Bundle;
import android.text.InputType;
import android.view.Gravity;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * GPay-like payment flow for the payment-bubble e2e (phase 18b T5): pay screen ("Paying X … Proceed to pay") →
 * UPI PIN screen (a password field and a pad, which Splitify must never read) → success screen ("₹420 Paid to X
 * … UPI transaction ID …"), optionally followed by a "Payment successful" notification like a real UPI app.
 *
 *   adb shell am start -n dev.splitify.fakeupi/.FlowActivity --es payee "Arjun Rao" --es amount 250 \
 *       --es vpa arjun@okaxis --es ref 612345678911 --ez notify true
 */
public class FlowActivity extends Activity {
    private String payee;
    private String amount;
    private String vpa;
    private String ref;
    private boolean notify;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        payee = extra("payee", "Arjun Rao");
        amount = extra("amount", "250");
        vpa = extra("vpa", "arjun@okaxis");
        ref = extra("ref", "612345678911");
        notify = getIntent().getBooleanExtra("notify", false);
        showPay();
    }

    private String extra(String key, String fallback) {
        String v = getIntent().getStringExtra(key);
        return v == null || v.isEmpty() ? fallback : v;
    }

    private LinearLayout page() {
        LinearLayout l = new LinearLayout(this);
        l.setOrientation(LinearLayout.VERTICAL);
        l.setPadding(56, 160, 56, 56);
        l.setBackgroundColor(Color.WHITE);
        return l;
    }

    private TextView text(String s, float size, boolean bold) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(size);
        t.setTextColor(Color.rgb(32, 33, 36));
        if (bold) t.setTypeface(Typeface.DEFAULT_BOLD);
        t.setPadding(0, 12, 0, 12);
        return t;
    }

    private Button button(String s, Runnable onClick) {
        Button b = new Button(this);
        b.setText(s);
        b.setAllCaps(false);
        b.setOnClickListener(v -> onClick.run());
        return b;
    }

    /** Stage 1: amount and payee, before the PIN. */
    private void showPay() {
        LinearLayout l = page();
        l.addView(text("Paying " + payee, 22, true));
        l.addView(text(vpa, 16, false));
        l.addView(text("₹" + amount, 44, true));
        l.addView(text("Add a note", 16, false));
        l.addView(button("Proceed to pay", this::showPin));
        setContentView(l);
    }

    /** Stage 2: the NPCI-style PIN screen (password field + pad). */
    private void showPin() {
        LinearLayout l = page();
        l.addView(text("HDFC Bank - 1234", 16, false));
        l.addView(text("Pay ₹" + amount + " to " + payee, 18, true));
        l.addView(text("Enter UPI PIN", 22, true));
        EditText pin = new EditText(this);
        pin.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD);
        pin.setText("1234");
        l.addView(pin);
        LinearLayout pad = new LinearLayout(this);
        pad.setGravity(Gravity.CENTER);
        for (String d : new String[] {"1", "2", "3"}) pad.addView(button(d, () -> { }));
        l.addView(pad);
        l.addView(button("Pay", this::showSuccess));
        setContentView(l);
    }

    /** Stage 3: success, like GPay's receipt screen. */
    private void showSuccess() {
        LinearLayout l = page();
        l.addView(text("₹" + amount, 44, true));
        l.addView(text("Paid to", 16, false));
        l.addView(text(payee, 22, true));
        l.addView(text(vpa, 16, false));
        l.addView(text("UPI transaction ID", 14, false));
        l.addView(text(ref, 16, false));
        l.addView(button("Done", this::finish));
        setContentView(l);
        if (notify) {
            Notifier.post(this, "Payment successful", "₹" + amount + " paid to " + payee + ". UPI Ref No " + ref);
        }
    }
}
