# Phase 18b report — Payment bubble (X4)

- Date: 2026-11-22 · Branch: `phase/18b-payment-bubble` · Base: `origin/main` (phase 18 merged in during the phase)
- Commits: `052e0fc..HEAD` · Status: see PROGRESS.md

## Summary

After a UPI payment (Google Pay, PhonePe, Paytm, BHIM, Amazon Pay, CRED, a bank app or a bank SMS), Splitify can
show a floating bubble with the amount and payee and **Add to Splitify**, which opens the expense editor already
filled in (amount in INR, payee/note, date, payer = me, "Paid via … · UPI ref …"). Optional smart capture shows a
small "Splitting this?" bubble on the UPI app's pay screen, hides it on the PIN screen and expands it on the
success screen. Everything is off by default, opt-in per source and per app, parsed on the phone, and nothing
leaves it until the user saves. Missed bubbles wait under "Payments to add" (Groups hero, Activity) for 7 days.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T0 research | done | `research/09-payment-capture.md`; spec amendment S-220…S-229 |
| T1 capture core | done | `payment_recipes.json` v1 (22 apps, 6 ignore + 17 debit + 2 screen rules), Kotlin parser/dedup/store, 68 shared vectors in JUnit + Dart, `CaptureValidator` |
| T2 sources | done | `PaymentNotificationListener`, `SmartCaptureService` (UPI apps only, no editable/password nodes, stops at "UPI PIN"), `CaptureStore`, MethodChannel `splitify/capture` |
| T3 bubble | done | native overlay (handle, card, ✕ target, chips, ⋮ menu, 8 s collapse / 60 s hide), heads-up notification fallback, light/dark tokens, TalkBack labels, sp text |
| T4 Flutter | done | Drift v8 `payment_captures` (local only), import on start/resume/link, `/capture` screen, editor prefill + `source='capture'`, Payments to add (Groups pill, Activity section, sheet), settings screen, ARB, goldens; migration 0023 applied on dev + pgTAP |
| T5 emulator e2e | see Gates G5 | `tool/e2e/capture_e2e.ps1` + `integration_test/capture_bubble_test.dart` + fake UPI `FlowActivity`/`Notifier` |
| T6 docs | done | catalog TC-X4-01…08, LEARNINGS, this report, real-phone checklist below |

## Features delivered

- X4 payment bubble (D-025): sources ① notifications (UPI apps + bank SMS through Google/Samsung Messages),
  ② smart capture (accessibility, optional), ③ overlay bubble with notification fallback; dedup across sources;
  Payments to add; settings with live permission state, Grant buttons and the "Allow restricted settings" guide.

## Tests

- New: Kotlin JUnit 12 (68 vectors inside) · Dart unit/widget ≈ 160 (vectors, validator, repository, editor
  prefill, settings, payments to add, capture screen) · golden 16 (4 screens × light/dark × text 1.0/2.0) ·
  SQL 14 (`230_capture.test.sql`) · e2e 1 scripted device scenario.
- Test IDs: TC-X4-01, 02, 06 (unit), 07 (unit), 08 pass; device rows in Gates.

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | | |
| G2 Tests | | |
| G3 Backend | PASS | 0023 dry run + applied; `230_capture` 14/14, `040_apply_mutations` 35/35 after 0023; advisors: no new finding |
| G4 Build | | |
| G5 Device | | `…\splitify-artifacts\phase-18b\` |
| G6 Docs | PASS | |

## Decisions made (S-0xx)

S-220 research outcome (sources, privacy rules, phantom-receipt guard) · S-221 recipes JSON + portable regex
rules · S-222 dedup · S-223 SMS spoof guard · S-224 native store + import protocol, Drift v8 · S-225 bubble
behaviour and window types · S-226 server `source='capture'` via dispatch + trigger · S-227 editor prefill ·
S-228 capture link + Payments to add · S-229 shared vectors in Kotlin and Dart.

## Blockers (BLK-xxx)

None. Real UPI apps cannot run on the emulator (D-005): their wording is covered by pattern families and the
owner checklist below.

## Learnings and skills added or changed

LEARNINGS.md (phase 18b lines): heredoc backslashes, Kotlin JVM tests + org.json, Java/Dart-portable regexes,
MCP declining `drop trigger`, host deep links without the auth gate, inert native bridges in host tests,
ASCII-only PowerShell e2e scripts.

## Owner actions

Optional — real-phone checklist (Android 13+, APK from GitHub/`flutter build apk`):

1. Install, sign in, Account → ⚙ → Preferences → **Payment bubble** → switch on.
2. Tap **Grant** for *Notification access*. If the switch is grey / "Restricted setting": follow the card
   (App info → ⋮ → *Allow restricted settings*), then Grant again. Same for *Display over other apps*.
3. Tap **Show a sample bubble**: it should appear on the right edge; drag it, drop it on ✕.
4. Pay **₹1** to a friend or yourself with **Google Pay**, then **PhonePe**, then **Paytm** (and BHIM/CRED if
   you use them). After each, note: did a bubble appear? from the app's notification or the bank SMS? were amount
   and name right? Did one payment give one bubble?
5. Tap **Add to Splitify** on one, pick a group, check the prefilled editor, Save.
6. Optional: turn on **Smart capture** (accessibility) and **Show during payment**; pay ₹1 again and note whether
   the small bubble appears on the pay screen and disappears on the PIN screen (some apps hide all overlays there,
   which is expected).
7. Send the notes (or screenshots of the payment notifications/SMS with names blurred) so the wording can be
   added to `android/app/src/main/assets/payment_recipes.json` — no code change needed.

## Next phase

19 — Hardening (runs in parallel in `../w19`); it must keep the `capture` dispatch in `apply_mutations` (amendment
in its phase file).
