# 09 - Payment capture and the payment bubble (research, 2026-11-22, phase 18b T0)

Tags: [V] = checked against a source fetched or searched in this session; [E] = checked on the emulator
(Pixel_9_API_36, Android 16); [UNVERIFIED] = from memory or thin sources. The real-phone checklist in
`planning/reports/phase-18b.md` turns the UNVERIFIED rows into facts.

## 1. What Android allows (Android 13 to 17)

### 1.1 Restricted settings for sideloaded APKs [V]
- Since Android 13, an app installed from outside a store that uses the session install API (a downloaded APK,
  `adb install` counts only on some builds) cannot turn on **Accessibility** or **Notification access** until
  the user opens *App info → ⋮ → Allow restricted settings*. The menu item appears only after the user has once
  tried to switch the access on and seen the "Restricted setting" dialog.
  Sources: https://www.kaspersky.com/blog/android-restricted-settings/49991/ ,
  https://bayton.org/android/android-13-restricted-permissions/ ,
  https://niagaralauncher.helpscoutdocs.com/article/134-fix-restricted-settings ,
  https://gitlab.com/fdroid/fdroidclient/-/issues/2680
- Android 15 widened the list in the CDD: device admin, **display over other apps** and usage access are also
  restricted for sideloaded apps, and some builds show "Enhanced Confirmation Mode" ("for your security, this
  setting is currently unavailable"). https://9to5google.com/2024/09/12/android-15-sideloaded-apps-restrictions/ ,
  https://www.androidauthority.com/android-15-enhanced-confirmation-mode-3436697
- Our APK ships as a GitHub Release (D-014), so every user is sideloaded. The settings screen therefore needs
  the step-by-step "Allow restricted settings" card for all three accesses, with the order *try → see dialog →
  App info → ⋮ → Allow restricted settings → try again*. Android 16 specifics: no new public change found
  [UNVERIFIED]; the emulator (API 36, `adb install`) did not show the restriction [E, see report].

### 1.2 Notification listener (source ①) [V]
- `NotificationListenerService` is bound by the system once the user grants notification access; it rebinds
  after reboot and after the app process dies, no `BOOT_COMPLETED` needed. While bound the app counts as
  "foreground" for background-service limits (the listener is a system binding).
- **Android 15 redacts sensitive notifications** (one-time codes detected by Android System Intelligence) for
  listeners that lack the signature/role permission `RECEIVE_SENSITIVE_NOTIFICATIONS`: the text becomes
  "Sensitive notification content hidden". https://www.androidauthority.com/android-15-sensitive-notifications-3416414 ,
  https://bugs.kde.org/show_bug.cgi?id=495146 . We ignore OTP texts anyway, so this only means a bank SMS that
  mixes an OTP and a debit arrives redacted and is ignored (no match).
- No SMS permission is needed: Google Messages and Samsung Messages post one notification per SMS with the
  sender as title and the body in `EXTRA_TEXT` / `EXTRA_BIG_TEXT` / `EXTRA_MESSAGES` (MessagingStyle)
  [UNVERIFIED for Samsung]. Reading SMS directly (`READ_SMS`/`RECEIVE_SMS`) is a hard-restricted permission and
  Play allows it only for default SMS apps — expense trackers such as Trackk/Walnut-style apps that use it would
  not pass Play review for us. Decision: notifications only (S-220).
- Google Messages shows verified business senders by **name** ("HDFC Bank") and others by header
  ("VM-HDFCBK", "JD-SBIUPI-S"); an ordinary phone number is never a bank (the open-source UPI Expense Tracker
  rejects phone-number senders for the same reason: https://github.com/xxwarwolfxx/UPI-Expense-Tracker ,
  `BankSenders.kt`). Spoof guard: release builds ignore SMS notifications whose title is a phone number (S-223).

### 1.3 Accessibility service (source ②) [V]
- An accessibility service can be limited to packages with `android:packageNames` (and narrowed at runtime with
  `setServiceInfo`). Events `typeWindowStateChanged|typeWindowContentChanged` + `canRetrieveWindowContent` are
  enough to read visible text; nothing is polled.
- Android 14 (API 34) added `View.setAccessibilityDataSensitive`: views marked sensitive are hidden from every
  service that does not declare `isAccessibilityTool="true"`; views using `filterTouchesWhenObscured` are treated
  as sensitive automatically. Google recommends it for "payment flows". So **some UPI screens will be invisible to
  us on Android 14+** and the notification path must stay the main source.
  https://developer.android.com/blog/posts/enhancing-android-security-stop-malware-from-snooping-on-your-app-data ,
  https://guardsquare.com/mobile-app-security-research-center/malware/accessibility-data-sensitive
- Declaring `isAccessibilityTool="true"` without being an accessibility tool gets an app rejected by Play and
  blocked by Play Protect → we declare **false** (honest).
- Android 17 Beta 2 with **Advanced Protection** on blocks (and revokes) accessibility access for non-tools
  ("Restricted by Advanced Protection"). https://www.androidauthority.com/android-17-beta-2-advanced-protection-mode-accessibility-apps-3648860 ,
  https://thehackernews.com/2026/03/android-17-blocks-non-accessibility.html . Smart capture is optional for this
  reason too.
- Play policy (for phase 20 / a future Play listing): an AccessibilityService used for a non-accessibility purpose
  needs a prominent in-app disclosure and a Play declaration; Wispr Flow documents repeated Play permission
  questions (https://docs.wisprflow.ai/articles/1842649381-why-does-google-play-keep-asking-about-wispr-flow-permissions).
  Not a blocker for the GitHub APK.
- Real screen shapes (from the GPL-3.0 UPI Expense Tracker's scrubbed device dumps, facts only, no code copied):
  - Google Pay's money screen is the NPCI UPI-PIN screen; its flattened text carries "Pay ₹450", "To <name>",
    "Bank Name", "Masked Account Number", "Enter your PIN", "Never enter your UPI PIN to receive money" and the pad
    digits. PhonePe's sheet: "Total payable ₹350 … Pay ₹350 … Proceed To Pay"; PhonePe paints "Payment Successful
    <date>" **on top of** the old sheet, so both texts are in the tree at once.
  - Reading a receipt later (history, chat) looks like a payment: the tracker booked ₹19,509 of phantom payments
    that way. Lesson: a success screen counts only right after a pay screen of the same app (S-220).
  - Autopay mandate setup screens ("Setting an AUTOPAY of ₹12000.00") show a PIN pad but are not payments.
- Privacy rule for our service: skip editable and password nodes entirely (never their text), stop at a node
  whose text says "UPI PIN", never read digits of a pad, never store screen text (only parsed fields).

### 1.4 Overlay ("Display over other apps", the bubble) [V]
- `TYPE_APPLICATION_OVERLAY` needs `SYSTEM_ALERT_WINDOW` granted by the user (Settings intent
  `ACTION_MANAGE_OVERLAY_PERMISSION` with `package:` URI). An accessibility service may instead add a
  `TYPE_ACCESSIBILITY_OVERLAY` window without that permission.
- **Untrusted touches** (Android 12+): touches that pass *through* another app's overlay are blocked unless the
  window alpha is ≤ `InputManager.getMaximumObscuringOpacityForTouch()` (0.8). Our windows are small and
  `WRAP_CONTENT`, so touches outside them never pass through them.
  https://developer.android.com/privacy-and-security/risks/tapjacking , https://medium.com/androiddevelopers/untrusted-touch-events-2c0e0b9c374c
- Banking and UPI apps can call `Window.setHideOverlayWindows(true)` (`HIDE_OVERLAY_WINDOWS`, Android 12+) on PIN
  and login screens: every non-system overlay is hidden while that window is shown. Wispr Flow documents that
  "restricted banking apps, such as BHIM, hide it". https://developer.android.com/security/fraud-prevention/activities ,
  https://docs.wisprflow.ai/articles/2807859589-customize-flow-bubble-size-and-shrink-behavior-on-android .
  So "during payment" the bubble may simply not be visible on some apps — fine, the post-payment bubble is the
  main moment, and we hide it ourselves on PIN screens.
- Android 15 (target 35+): holding `SYSTEM_ALERT_WINDOW` exempts a background foreground-service start only while
  an overlay window is visible. https://developer.android.com/about/versions/15/behavior-changes-15 . We start no
  foreground service: the overlay is added from the already-bound listener/accessibility service context.
- Background activity launch: an app with a visible window (our bubble) or `SYSTEM_ALERT_WINDOW` may start
  activities; a notification action `PendingIntent.getActivity` is a system-sent intent and always allowed
  (no trampolines: actions start the activity directly). https://developer.android.com/guide/components/activities/background-starts
- Cross-window blur (`FLAG_BLUR_BEHIND` + `blurBehindRadius`, API 31) only works where
  `WindowManager.isCrossWindowBlurEnabled()`; the emulator and battery saver turn it off → the card falls back
  to an opaque surface (S-225).

## 2. Who does what (prior art)
| App | How it captures | Bubble / overlay |
|---|---|---|
| Wispr Flow (Android) [V] | Accessibility (focus/window events) to detect text fields | `SYSTEM_ALERT_WINDOW` bubble on the right edge; idle shrink after 5 s; size slider; snooze; hidden in password/numeric fields and in banking apps |
| Truecaller [UNVERIFIED] | Call state + its own number DB | Caller-ID overlay window (`SYSTEM_ALERT_WINDOW`) |
| UPI Expense Tracker (F-Droid, GPL-3.0) [V] | Accessibility on GPay/PhonePe/Paytm/CRED pay sheets + bank SMS (SBI/HDFC), dedup by bank ref | none (widgets) |
| PennyWise AI (open source) [V] | SMS reading + per-bank Kotlin parsers with large JUnit corpora | none |
| Trackk / Trakio / Walnut-style trackers [V, listings] | SMS permission, some read UPI notifications | in-app only |
| Messenger chat heads | `SYSTEM_ALERT_WINDOW`, drag, snap to edge, drag to ✕ to dismiss | the UX model for our handle |

## 3. Message formats

### 3.1 Bank SMS (debit) [V unless marked]
Shapes below are scrubbed samples from PennyWise's and UPI Expense Tracker's public JUnit corpora (real bank
templates, fake names/numbers). Amounts use "Rs.", "Rs ", "INR ", "₹" or none (SBI "debited by 250.0").

| Bank | Template |
|---|---|
| HDFC | `Sent Rs.500.00 From HDFC Bank A/C *1234 To RAHUL SHARMA On 01/01/26 Ref 123456789012 Not You? Call …/SMS BLOCK UPI to …` (multi-line on newer phones); card: `Spent Rs.572.25 On HDFC Bank Card 0000 At ..GAME ON On 2026-11-22:08:26:20.Not You? …`; HDFC sends UPI debit SMS only above ₹100 since 25 Jun 2024 (business-standard.com) |
| SBI | `Dear UPI user A/C X1234 debited by 250.0 on date 12Sep26 trf to Ramesh Kumar Refno 612345678901 If not u? call-1800… -SBI`; older `Dear SBI UPI User, Rs.49.50 debited from A/c X4321 and paid to chai@oksbi. UPI Ref No 100200300400.` |
| ICICI | `ICICI Bank Acct XX051 debited for Rs 180.00 on 10-Nov-25; DINDUGAL ORIGIN credited. UPI:568069174081. Call 18002662 for dispute.` (note "credited" inside a debit) |
| Axis | `INR 500.00 debited from A/c no. XX312225 on MERCHANT ABC 02-12-2025 20:38:23 IST. Avl bal: INR 10000.00. Not you? …`; UPI: `INR 500.00 debited A/c no. XX1234 21-11-26, 10:12:45 UPI/P2A/612345678901/RAHUL SHARMA Not you? …` [UNVERIFIED second] |
| Kotak | `Sent Rs.100.00 from Kotak Bank AC X5678 to phonepeqr123@ybl on 15-10-25.UPI Ref 9876543210. Not you, https://kotak.com/KBANKT/Fraud`; newer `Sent Rs.205.00 from XXXXXX1234 to ANNAPOORNESWARI K M on 26/05/2026. UPI ref no. 651229267141. …-Kotak` |
| PNB | `A/c X0000 debited INR 125.00 Dt 01-01-26 12:00:00 to Swiggy thru UPI:000000000001..Bal INR 9000.00-PNB` |
| Canara | `Dear Customer, Acct XX123 Dr. INR 250.50 on 18/10/2026 to testshop@ybl; UPI: 600000000005; Bal INR 3,749.50. …-CanaraBank` |
| Bank of Baroda | `Rs.500.00 Dr. from A/C XXXXXX1234 and Cr. to rahul@okicici. Ref:612345678901. AvlBal:Rs10000.00 …-Bank of Baroda` [UNVERIFIED] |

Texts that must **not** bubble (all seen in those corpora): OTPs ("123456 is your OTP for a Dr. INR 500.00
transaction"), credits ("credited with INR 1,000.00 … from"), collect requests ("ACME Stores has requested
Rs. 250.00 from you through UPI"), mandate/auto-pay reminders ("will be deducted on", "Upcoming mandate"),
declines/failures ("is declined", "Failed!"), bill reminders ("bill … due by"), promos ("Lifetime FREE … +
Rs.500 Amazon voucher"), reversals and refunds. NPCI requires debit SMS for every UPI debit and masks accounts
to the last 4 digits (NPCI circular 57/2018, https://www.npci.org.in/PDF/npci/upi/circular/2018/Circular%2057.pdf).

### 3.2 UPI app notifications [UNVERIFIED wording]
Google's help says "After the money has been sent, you'll get a notification on Google Pay. You should also
receive an SMS from your bank with the debited amount" [V, support.google.com/pay/india/answer/7296045]. No
source quotes the exact wording of GPay/PhonePe/Paytm/BHIM/Amazon Pay/CRED payment notifications, so the
recipes match **families** instead of exact strings ("Paid ₹500 to Rahul", "₹500 paid to Rahul",
"You sent ₹500 to Rahul", "Payment of ₹500 to Rahul successful", "Rs.500 sent successfully to Rahul"). The
real-phone checklist records the true texts; fixing a recipe is a JSON change (`payment_recipes.json`).

### 3.3 Package names [V: Play Store pages fetched 2026-11-22 unless marked]
Google Pay `com.google.android.apps.nbu.paisa.user` · PhonePe `com.phonepe.app` · Paytm `net.one97.paytm` ·
BHIM `in.org.npci.upiapp` · Amazon (Pay inside Amazon India) `in.amazon.mShop.android.shopping` · CRED
`com.dreamplug.androidapp` · super.money `money.super.payments` · WhatsApp `com.whatsapp` · Google Messages
`com.google.android.apps.messaging` · Samsung Messages `com.samsung.android.messaging` (preinstalled, not on Play)
[UNVERIFIED] · HDFC Bank `com.hdfcbank.android.now` · PayZapp `com.hdfcbank.payzapp` · YONO SBI
`com.sbi.lotusintouch` · ICICI iMobile `com.csam.icici.bank.imobile` · Axis Mobile `com.axis.mobile` · Kotak
`com.kotak811mobilebankingapp.instantsavingsupiscanandpayrecharge` and old `com.msf.kbank.mobile` · PNB ONE
`com.Version1` · bob World `com.bankofbaroda.mconnect` · Canara ai1 `com.canarabank.mobility`.

## 4. Design consequences (logged as S-220…S-229)
1. Notifications (UPI apps + SMS apps) are the main, always-available source; smart capture is optional and may
   see nothing on Android 14+ apps that mark views sensitive; a success screen counts only after a pay screen of
   the same app in the last 10 minutes; PIN screens are never read and hide the bubble.
2. No SMS permission, no foreground service, no polling, no network: the parser runs in the listener; the overlay
   lives only while shown.
3. The restricted-settings card covers notification access, accessibility **and** overlay (Android 15).
4. Parser recipes are data (JSON, versioned), regex-portable between Java and Dart (no inline flags, text
   normalised to single spaces first), amounts to paise with string arithmetic.
5. Dedup across sources: same UPI ref, or same amount within 10 minutes when one side has no ref and the payees
   are compatible (a VPA or a missing name is compatible with any name); later sources fill missing fields.
6. Everything stays on the phone; the server only sees the expense the user saves (`source = 'capture'`).
