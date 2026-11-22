# Phase 13 — Notifications and reminders (#19, #23)

- Depends on: 12 · Owner setup: 00 E (Firebase: `secrets/google-services.json`, `FCM_SERVICE_ACCOUNT_JSON`
  secret) · Branch: `phase/13-notifications`
- Read first: `03-backend.md` §5 §7, `08-feature-specs.md` #19 #23 + notification kinds, `research/05` §8.

## Tasks

- [x] T1 Firebase on Android: copy `secrets/google-services.json` → `android/app/` (git-ignored), Google Services
      Gradle plugin, `firebase_core` init (try without `firebase_options.dart`; if it fails, generate options from
      the JSON at build time into a git-ignored file and log an S-decision), `firebase_messaging`,
      `flutter_local_notifications` with one channel per kind.
- [x] T2 Migration 0010: notifications, notification_settings, device_tokens, `private.settings` (dev project URL),
      fan-out trigger, push queue (pg_net → `send-push`), `send_reminder`, `register_device`/`unregister_device`,
      `mark_notifications_read`; pgTAP (recipients exclude actor/muted, throttle, RLS).
- [x] T3 `send-push` Edge Function (Web Crypto JWT → OAuth token cache → FCM v1; idempotent; delete token on
      UNREGISTERED) + deno tests with mocked fetch; deploy (`verify_jwt` false).
- [x] T4 Client: permission pre-prompt sheet (after first group create/join), token register/refresh/unregister on
      sign-out, foreground display, tap → route, bell with unread badge, Notifications screen, settings page (per
      kind push/in-app, muted groups).
- [x] T5 Reminders: Remind buttons on balances/friend rows (hidden for name-only), throttle copy.
- [x] T6 Integration: harness B adds expense in A's group → notification row for A → push visible in
      `dumpsys notification` on the emulator → tap opens the expense.

## Tests

TC-19-01…05, TC-23-01…02. If the FCM secret is missing: TC-19-02 live part and TC-19-04 are `needs-owner`
(BLK), everything else must pass.

> **Amendment (D-020, 2026-11-21):** services the owner has not set up yet run in dummy mode — build and test them behind their config checks with fakes; missing Google client id / Resend / Firebase file is not a blocker.

Pre-built (phase 06 session, branch prep/edge-functions): `supabase/functions/send-push/{index,push,push_test}.ts`, `supabase/functions/_shared/{fcm,fcm_test,admin_client,admin_client_test}.ts`; deploy + table DDL still in this phase.

> **Amendment (S-099, S-140..S-147, 2026-11-22, phase 13 session):** the migration is `0016_notifications.sql`
> (applied to dev); T1 runs in D-020 dummy mode (Gradle applies Google Services only when
> `secrets/google-services.json` exists, `initPush()` falls back to `DisabledPushMessaging`); notifications are
> fetched by seq with an RLS select, not through `pull_changes`; Drift schema v4. When the owner adds Firebase:
> put `google-services.json` in `secrets/`, set the `FCM_SERVICE_ACCOUNT_JSON` Edge secret, rebuild, then re-run
> TC-19-04's dumpsys part on the emulator.
