# Final QA pass 2: device, functions and taps (2026-11-22/23)

Branch `qa/final-device`. Decisions S-250 to S-259. No migration. Defect log with steps and screenshots:
`splitify-artifacts\final-qa\defects.md` (screenshots in the same folder).

## How it was tested

- Release x64 APK (`integration_test/support/pinned_main.dart`, DNS pin) on emulator-5554, signed in with the
  owner's Google account. Every screen of `07-screens-and-flows.md` was opened and its buttons, rows, chips,
  sheets, menus, back/close, pull to refresh, deep links and settings were tapped from `uiautomator` dumps.
- Two QA people (`qa-rahul`, `qa-asha` at splitify.test) joined by invite code and acted from the PC (Deno +
  supabase-js): expenses with exact/percent/adjust splits, a payment, comments, a push to the phone.
- Light and dark mode; the launcher icon, app drawer, app info, notification icon, recents and the widget picker.

## Fixed (with tests)

| Area | Defects |
| --- | --- |
| Accessibility | Buttons built as `Semantics(button, excludeSemantics)` (nav bar, + button, hero icons, Get started, group cards, wallet, keypad, chips, colour dots, comment send, receipt, remind, segmented pills, split ticks) had no tap action for TalkBack/Switch/Voice Access; new guideline in every golden and gallery check. Currency chip 36 → 48 dp tap area, loan amount 47 → 48 dp. |
| Navigation | Unknown `splitify://` links showed go_router's red debug page and a dead "Go to home page"; app links now map `splitify://<page>` and land on a friendly page. Groups bell opened "Coming soon". |
| Status bar | White icons on light pages after a hero page; text ran under the clock on scrolled hero pages (also the sliver group page). |
| Sync | No pull to refresh on Groups, a group, Friends, Activity; a refused Realtime join (new group) was never retried; Sync & storage said "Everything is synced" with a stopped photo upload. |
| Money and dates | Default dates and "Today/Yesterday" used the UTC day (00:08 IST saved the day before); settle prefill read "8822.5"; FX rate field showed 10 decimals; "You owes / gets back" on your own row. |
| Settle up | UPI method offered for USD; "Pay via UPI" stayed after picking Cash; no Settle up when all settled. |
| Sheets and forms | Messages from sheets were hidden under the sheet (copy code, reset); e-mail/UPI/code fields auto-capitalised; group/profile currency was a 160-button list without search; push pre-prompt never appeared after the first group (removed with the replaced page). |
| Consistency | One colour per person on every screen; split rows in member order; payment detail says who added it; review step shows the repeat; deleted groups left out of search and activity. |
| Android | Launcher label "Splitify" (was cut to "Splitify Free …"); widget picker previews with sample values and names; bubble header time on one line; two "Kotak" apps renamed; notifications row says On only when Android allows it; blocked push shows disabled switches and Open phone settings; Delete my account is a danger button; Continue with Google uses the official G. |

## Checked, no change needed

- Launcher icon: adaptive (foreground + background + monochrome) and legacy PNGs are in the release APK; app drawer,
  app info, notification icon and widget show the Splitify mark. The ring seen on the home screen is the Pixel
  launcher's predicted-app style. Play Protect's install dialog shows a generic robot for side-loaded APKs it has
  not scanned yet; that is Play Protect, not the APK.
- Google sign-in, invite share sheet, UPI link to a UPI app (exact `upi://pay` string), Mark as paid celebration,
  CSV export share sheet, Splitwise import (multi-currency fixture), app lock (PIN prompt, FLAG_SECURE), widget on
  the home screen, push notification with the brand icon, payment bubble sample, receipt photo picker and viewer.

## Not fixed / owner

- Realtime live updates cannot be seen on this emulator (DNS pin; no websocket reaches the dev project); verified by
  unit tests, resume and pull to refresh. Check on a real phone: another member's expense should appear without
  pulling.
