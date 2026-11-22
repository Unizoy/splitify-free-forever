# Phase 18b — Payment bubble: catch UPI payments and add them to Splitify (X4)

- Added by the owner on 2026-11-22 (D-025). Runs before phase 19, which also hardens this feature.
- Depends on: 15 (outbox, sync triggers), 11 (UPI rules) · Owner setup: none · Branch: `phase/18b-payment-bubble`
- Migration: `0023_payment_capture.sql` only if the server needs a change (e.g. `source = 'capture'`). Decisions:
  S-220…S-229.
- Goal: when the owner pays with Google Pay, PhonePe, Paytm, BHIM or any other UPI app (or a bank app or card),
  Splitify shows a small floating **bubble**: during the payment it says "Splitting this?". After the payment it
  shows the captured amount and payee with **Add to Splitify**, which opens the expense editor already filled in.
  The look and feel is inspired by Wispr Flow's keyboard bubble and Messenger chat heads. Everything runs on the
  phone, is off by default and is opt-in per source.

## Product spec (X4)

**Sources.** Each source is opt-in and has its own switch; the default when the feature is on is ① + ③.

| # | Source | Android API | Catches | Notes |
|---|---|---|---|---|
| ① | Payment notifications | `NotificationListenerService` | "Paid ₹500 to Rahul" / "₹500 sent" from UPI apps; bank debit SMS shown as notifications by the SMS app (Google Messages, Samsung Messages) | No SMS permission needed. Main "after payment" source. |
| ② | Smart capture | `AccessibilityService` limited to allow-listed UPI packages (`android:packageNames`) | The payment screen (amount, payee) → collapsed bubble "Splitting this?"; the success screen (amount, payee, UPI ref) → expanded bubble | Optional and advanced. Never reads PIN/password fields or the NPCI PIN pad. If an app hides its views (`accessibilityDataSensitive`), fall back to ①. |
| ③ | The bubble | `WindowManager` `TYPE_APPLICATION_OVERLAY` ("Display over other apps") | — | Fallback when not granted: a heads-up notification with **Add** / **Not now** actions. |

**Allow-list.** Seed it with the package names verified in T0: Google Pay, PhonePe, Paytm, BHIM, Amazon Pay, CRED,
WhatsApp, the top bank apps, Google Messages and Samsung Messages. Debug builds also allow `tool/fake_upi_app`
and `com.android.shell` so tests can post notifications.

**Parsing.** Only debits and successful payments count. Credits, OTPs, failures, requests, cashback and promos are
ignored. Amounts like "₹1,234.50", "Rs. 1234.5", "INR 1,234" and "Rs 500.00" become integer paise (no floats;
same rules as `lib/core/money`). The parser also reads the payee name or VPA, the UPI ref / txn id, the app and the
time.
- Recipes live in one versioned JSON (`android/app/src/main/assets/payment_recipes.json`) of regex per source, so
  they can be fixed without code changes.
- Shared vectors `test/fixtures/payment_capture_vectors.json` hold real-looking texts per app and bank with the
  expected result (or "ignore"). They run in Kotlin JUnit and in a Dart test.

**De-duplication.** One payment shown by several sources (notification + bank SMS + screen) gives one bubble. The
key is the UPI ref when present, else amount + normalised payee within 10 minutes.

**Bubble UX.**
- A 56 dp round handle with the Splitify mark, on the screen edge. It can be dragged, snaps to the nearest edge,
  and is dismissed by dragging it onto a ✕ target.
- Tapping it expands a frosted card:
  - "Paid **₹500** to **Rahul**" with the app icon and time;
  - chips for the 3 most recently used groups and friends;
  - **Add to Splitify** (primary) and **Not now**;
  - a ⋮ menu with "Don't show for <app>" and "Bubble settings".
- It auto-collapses after 8 s and auto-hides after 60 s if untouched.
- During a payment (source ②) it is collapsed with a small "₹" badge, and it expands when the success is captured.
- It uses design tokens (indigo/amber, radii, serif amount), works in light and dark mode, has TalkBack labels,
  and keeps working at 200 % font size. It never covers the UPI app's Pay/PIN button: it starts on the right edge
  at about 30 % of the screen height.

**Add flow.**
- Tapping Add or a group chip opens `splitify://capture?id=<captureId>`, which leads to the expense editor
  prefilled with:
  - amount (INR), description (payee name, or the note if there is one) and date/time;
  - payer = me;
  - notes "Paid via <app> · UPI ref <ref>";
  - the group, if a chip was tapped.
- The person picks the split and taps Save, which goes through the normal outbox. Nothing is ever saved without
  that tap.
- The captured expense gets `source = 'capture'` (server check updated if needed).

**Pending payments.**
- Captures are stored on the phone in a local-only Drift table `payment_captures`. It is not synced and holds no
  raw notification text, only the parsed fields.
- Kept 7 days, then removed automatically, or as soon as the capture is added or dismissed.
- Shown as "Payments to add (N)" on the Groups hero and the Activity tab, so a bubble that was missed is not lost.

**Settings and onboarding (Account → Payment bubble).**
- A master switch (off by default) and the per-source switches. Per-app switches. "Show during payment" (needs ②).
- Live permission state for each source with a **Grant** button that opens the exact system screen:
  - notification access;
  - display over other apps;
  - accessibility.
- A step-by-step card for **"Allow restricted settings"**: on Android 13+ sideloaded APKs must do App info → ⋮
  before notification or accessibility access can be turned on.
- Privacy text: "Splitify reads payment alerts only from the apps you allow. Everything stays on this phone until
  you tap Add."
- A test button, "Show a sample bubble".

**Battery and robustness.**
- No polling. The services are event-driven, and only the overlay runs, and only while it is shown.
- It survives app kill and reboot: the listener rebinds itself; `BOOT_COMPLETED` is not needed for the listener.
- The bubble works when the Flutter engine is not running: it is native Kotlin and only opens the app on tap.

## Tasks

- [ ] T0 Research (web): current Android 14–16 rules for notification listener, accessibility
      (`accessibilityDataSensitive`, `isAccessibilityTool`, restricted settings for sideloaded apps), overlay
      limits (untrusted touches, background starts); real notification and SMS formats of GPay, PhonePe, Paytm,
      BHIM, Amazon Pay, CRED and the top 6 banks' debit SMS; how Wispr Flow, Truecaller, Walnut/Axio/Fold-style
      trackers do bubbles and capture. Write `planning/research/09-payment-capture.md` and adjust this spec where
      the facts differ (log S-rows).
- [ ] T1 Kotlin capture core: recipe loader, parser to paise, de-dup, the allow-list. JUnit tests for the shared
      vectors (≥ 40 cases including the ignore cases). Plus a Dart test of the same vectors through a small Dart
      validator used by the deep-link handler.
- [ ] T2 `PaymentNotificationListener` (source ①) and `SmartCaptureService` (source ②, package-limited, no
      PIN/password fields), both writing captures through one `CaptureStore` (SharedPreferences/JSON, read by
      Flutter at start and on resume into `payment_captures`).
- [ ] T3 Native bubble overlay service and the heads-up notification fallback, matching the design tokens (light
      and dark), including the recent group/friend chips. The app writes recent groups for the chips, like the
      home widget does.
- [ ] T4 Flutter side:
      - the `splitify://capture` route, the editor prefill and `source='capture'` (migration 0023 if the server
        check needs it, plus pgTAP);
      - the "Payments to add" list on the Groups hero and the Activity tab;
      - the Payment bubble settings screen with permission states, the restricted-settings guide and the sample
        bubble;
      - ARB strings, goldens in light, dark and text 2.0.
- [ ] T5 Emulator E2E, holding the lock:
      - grant access via adb:
        - `appops set com.unizoy.splitify SYSTEM_ALERT_WINDOW allow`
        - `cmd notification allow_listener com.unizoy.splitify/<listener>`
        - `settings put secure enabled_accessibility_services …` and `accessibility_enabled 1`
      - extend `tool/fake_upi_app` with GPay-like payment and success screens plus a "payment successful"
        notification;
      - send a bank SMS with `adb emu sms send 5554 "…debited…"`;
      - check that the bubble appears (uiautomator dump), the expanded card shows ₹ and the payee, Add opens the
        prefilled editor, Save syncs to dev, and a duplicate notification + SMS gives one bubble;
      - check that credit, OTP and promo texts give no bubble;
      - screenshots in light, dark and 200 %.
- [ ] T6 Docs: test catalog rows TC-X4-01…08, LEARNINGS, a report and a real-phone checklist for the owner (pay ₹1
      with GPay, PhonePe and Paytm; note which ones bubble).

## Tests

- TC-X4-01: parser vectors.
- TC-X4-02: dedup.
- TC-X4-03: notification gives a bubble.
- TC-X4-04: SMS gives a bubble.
- TC-X4-05: smart capture on the payment and success screens.
- TC-X4-06: Add gives the prefilled editor, and saving syncs.
- TC-X4-07: ignore cases give no bubble.
- TC-X4-08: permissions and settings screen states.
