# Build progress

Updated by plan-execution sessions only (see `11-execution-protocol.md`). Status values:
`todo` Â· `in-progress` Â· `done` Â· `done-with-blockers` Â· `blocked` Â· `owner` (owner-only phase).

Current phase: _none in progress_ (05 + 06 leftovers finished 2026-11-22 on `phase/06-sync-engine`: 06 T5/T7, 05 T9; S-046 sync triggers moved to phase 15)

| # | Phase | Depends on | Needs owner setup | Status | Branch | Finished | Last commit | Report |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 00 | [Owner setup (one-time, by hand)](phases/phase-00-owner-setup.md) | â€” | is the setup | owner: Supabase done (MCP needs `/mcp` login); rest dummy per D-020 | â€” | | | |
| 01 | [Bootstrap, tooling, CI](phases/phase-01-bootstrap.md) | â€” | no | done | phase/01-bootstrap | 2026-11-21 | see git log | [report](reports/phase-01.md) |
| 02 | [Design system and app shell](phases/phase-02-design-system.md) | 01 | no | done | phase/02-design-system | 2026-11-21 | 2e29185 | [report](reports/phase-02.md) |
| 03 | [Money engine (pure Dart)](phases/phase-03-money-engine.md) | 01 | no | done | phase/03-money-engine | 2026-11-21 | eaaac63 | [report](reports/phase-03.md) |
| 04 | [Backend foundation](phases/phase-04-backend-foundation.md) | 03 | 00 (Supabase + MCP) | done | phase/04-backend-foundation | 2026-11-21 | 1a69ee8 | [report](reports/phase-04.md) |
| 05 | [Auth, profile, account](phases/phase-05-auth-profile.md) | 02, 04 | 00 (Google OAuth, Resend) | done | phase/05-auth-profile (follow-up on phase/06-sync-engine) | 2026-11-22 | 77c9f6a | [report](reports/phase-05.md) |
| 06 | [Local database and sync engine](phases/phase-06-sync-engine.md) | 04, 05 | 00 | done | phase/06-sync-engine | 2026-11-22 | 77c9f6a | [report](reports/phase-06.md) |
| 07 | [Groups, members, invites](phases/phase-07-groups-members.md) | 06 | 00 | done | phase/07-groups-members | 2026-11-22 | see git log | [report](reports/phase-07.md) |
| 08 | [Expenses and split types](phases/phase-08-expenses-splits.md) | 07 | 00 | done (phase 07 merged in; G5 device PASS) | phase/08-expenses-splits | 2026-11-22 | 8fd7bef (+ docs commit) | [report](reports/phase-08.md) |
| 09 | [Balances, payments, activity, totals](phases/phase-09-balances-payments.md) | 08 | 00 | done (G5 device PASS, no migration) | phase/09-balances-payments | 2026-11-22 | see git log | [report](reports/phase-09.md) |
| 10 | [Multiple payers, IOU, receipt photos](phases/phase-10-payers-iou-receipts.md) | 09 | 00 | done (G5 device PASS, migration 0013) | phase/10-payers-iou-receipts | 2026-11-22 | see git log | [report](reports/phase-10.md) |
| 11 | [Friends, simplify debts, Pay via UPI](phases/phase-11-friends-simplify-upi.md) | 09 | 00 | done (G5 device PASS incl. fake UPI app, migration 0014) | phase/11-friends-simplify-upi | 2026-11-22 | see git log | [report](reports/phase-11.md) |
| 12 | [Edit history, restore, comments](phases/phase-12-history-comments.md) | 09 | 00 | done (phase 09 merged in; G5 device PASS) | phase/12-history-comments | 2026-11-22 | ca1c8b7 (+ docs commit) | [report](reports/phase-12.md) |
| 13 | [Notifications and reminders](phases/phase-13-notifications.md) | 12 | 00 (Firebase) | done (push in D-020 dummy mode; dumpsys check needs-owner) | phase/13-notifications | 2026-11-22 | see git log | [report](reports/phase-13.md) |
| 14 | [Currencies and conversion](phases/phase-14-currencies.md) | 09 | 00 | done (G5 device PASS; migration 0017 applied; fetch-rates deployed + cron) | phase/14-currencies | 2026-11-22 | see git log | [report](reports/phase-14.md) |
| 15 | [Offline polish](phases/phase-15-offline-polish.md) | 10, 11, 12, 14 | 00 | done (G5 device PASS: real airplane mode + kill e2e, conflict UX, perf numbers; no migration, Drift v5 unchanged) | phase/15-offline-polish | 2026-11-22 | see git log | [report](reports/phase-15.md) |
| 16 | [Recurring bills and search](phases/phase-16-recurring-search.md) | 15 | 00 | done (G5 device PASS; migration 0019 applied + generate-recurring cron; pgTAP on dev) | phase/16-recurring-search | 2026-11-22 | see git log | [report](reports/phase-16.md) |
| 17 | [Charts and CSV export](phases/phase-17-charts-export.md) | 14 | 00 | done (G5 device PASS; no migration, 0020 unused; TC-22-02 moved to 18) | phase/17-charts-export | 2026-11-22 | see git log | [report](reports/phase-17.md) |
| 18 | [Splitwise import, app lock, home widget](phases/phase-18-extras.md) | 15 | 00 | done (G5 device PASS incl. PIN app lock + home widget; migration 0021 applied; Drift v7) | phase/18-extras | 2026-11-22 | see git log | [report](reports/phase-18.md) |
| 19 | [Hardening and polish](phases/phase-19-hardening.md) | 13, 16, 17, 18 | 00 | in-progress | phase/19-hardening | | | |
| 20 | [Release (signed APK, draft GitHub Release)](phases/phase-20-release.md) | 19 | checklist R (prod project) | todo | phase/20-release | | | |

## Notes

- Phases 01â€“03 need no cloud access, so they can run while the owner is still doing phase 00.
- Each phase file lists its tasks as checkboxes; ticked boxes are the live state of an in-progress phase.
