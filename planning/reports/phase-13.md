# Phase 13 report — Notifications and reminders (#19, #23)

- Date: 2026-11-22 · Branch: `phase/13-notifications` · Base: `origin/main` (phases 01–09 + 12); `origin/main` with
  phase 10 merged in (bdf6d1f)
- Commits: `3d5e66f..HEAD` · Status: done-with-blockers (push delivery needs the owner's Firebase setup — D-020
  dummy mode, not a blocker; TC-19-04's dumpsys part is `needs-owner`)

## Summary

Every add, edit, delete, payment, comment, reminder and member change now creates an in-app notification for the
people it concerns (never the one who did it), written by the server from the activity log. The Activity tab's bell
shows an unread badge and opens the Notifications list (unread dot, "Mark all read", tap opens the expense,
payment or group, works offline). Account settings → Notifications lets each person switch push and in-app per kind
and mute groups. "Remind" on a balance row where someone owes you sends them "Mohit reminded you about ₹500 in
“Goa trip”" (once per 24 h per pair, hidden for name-only members). The push pipeline (pg_net → `send-push` Edge
Function) is deployed and live; without the FCM secret it marks pushes `skipped`, and the app runs with push off
until the owner adds Firebase.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| T1 Firebase on Android | done (dummy mode) | Google Services plugin applied only when `secrets/google-services.json` exists (copied to `android/app/`, git-ignored); `initPush()` → `FirebasePushMessaging` or `DisabledPushMessaging`; one channel per kind; status-bar icon; `POST_NOTIFICATIONS` (S-144) |
| T2 Migration | done | `0016_notifications.sql` (S-099 number) applied to dev: tables + RLS, fan-out trigger, push queue (pg_net), realtime nudge, `mark_notifications_read`, `upsert_notification_settings`, `register_device`/`unregister_device`, `send_reminder`; pgTAP `130_notifications.test.sql` 80/80 (S-140, S-141, S-145) |
| T3 `send-push` | done | Pre-built function deployed via MCP (verify_jwt false); live: 404 for an unknown id, `skipped` for a real notification (no FCM secret); deno fmt/lint/test 45/45 |
| T4 Client | done | Drift v4 cache + local-first read marks/settings (S-142, S-143); bell badge, `/notifications`, `/account/notifications`, pre-prompt sheet, token register/refresh/unregister on sign-out, foreground display + tap → route (S-146, S-147) |
| T5 Reminders | done | Remind button on "X owes you" balance rows (direct/friend groups use the same Balances tab); throttle copy; server amount + 24 h throttle |
| T6 Integration | done (in-app) / SKIPPED (dumpsys) | `integration_test/notifications_test.dart`: B adds expense → A's notification row → `send-push` marks `skipped` live → bell badge → list → tap opens the expense, read mark reaches the server; reminders both ways. `dumpsys notification` needs Firebase → `needs-owner` |

## Features delivered

- #19 Notifications: in-app bell (badge, list, mark read, tap to open), per-kind push/in-app settings, muted groups,
  push pipeline end to end up to FCM (dummy until Firebase), device tokens removed on sign-out.
- #23 Reminder: Remind on balance rows, server-side amount and throttle, recipient notification with the spec copy.

## Tests

- New tests: unit 81 · widget 96 · golden 24 cases (6 screens × light/dark × 100/200 %) · integration 1 ·
  SQL 80 (+ `001_schema` updated) · edge-fn 0 new (45 existing re-run) · migration 3
- Coverage: GATE_COVERAGE
- Test IDs now passing: TC-19-01, TC-19-02, TC-19-03, TC-19-05, TC-19-06..09 (new), TC-23-01, TC-23-02; TC-19-04
  in-app part
- Skipped: TC-19-04 dumpsys part (`needs-owner`: Firebase project + `FCM_SERVICE_ACCOUNT_JSON`)

## Gates

GATES_TABLE

## Decisions made (S-0xx)

S-140 fan-out recipients / in-app vs push / muted · S-141 server-written texts + `data` targets · S-142 bell cache
by seq + local-first read marks and settings · S-143 Drift v4 alongside phase 14's v3 · S-144 push behind its
config check · S-145 reminder amount + throttle + button · S-146 UI layout of bell/list/settings/pre-prompt ·
S-147 sign-out hook + `?tab=balances`.

## Blockers (BLK-xxx)

None new. Push delivery is D-020 dummy mode (owner decision), not a blocker.

## Learnings and skills added or changed

LEARNINGS: `lpad` cuts long text; dry-run migration + pgTAP in one rolled-back call; Drift table/class name
clashes; `deno fmt` vs CRLF checkouts (`git -c core.autocrlf=false archive`); google-services plugin on AGP 9.3;
`001_schema` counts seq triggers.

## Owner actions

- Optional (when you like the app, D-020): create a Firebase project for `com.unizoy.splitify`, put
  `google-services.json` in `secrets/`, set the Edge secret `FCM_SERVICE_ACCOUNT_JSON` (service-account JSON) in
  the Supabase dashboard, rebuild; the next session re-runs TC-19-04's dumpsys check.
- Release reminder: users on ISPs that block `*.supabase.co` need a Supabase custom domain/proxy.

## Next phase

Phase 14 (currencies) merges after this one: keep both Drift steps (v3 rates, v4 notifications), regenerate
`drift_schema_v4.json` and the migration test (S-143); `001_schema.test.sql` counts 9 `bump_seq` triggers now.
Phase 11's friend page can reuse `RemindButton` (lib/features/notifications/presentation/remind_button.dart).
