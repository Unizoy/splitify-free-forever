# Decision register

Single source of truth for every choice the build depends on. Precedence when documents disagree:

1. `docs/PLAN.md` "Rules the app must follow" (product rules) — never broken.
2. This file (owner decisions `D-0xx`, then technical decisions `T-0xx`).
3. The spec documents in `planning/` (architecture, data model, money, sync, design, screens, features, testing).
4. `planning/research/*` (background evidence; may contain options we rejected).

A session that has to make a new decision while executing adds it at the bottom as `S-0xx` with date, phase,
reason and the alternatives it rejected. It never asks the owner.

---

## Owner decisions (asked and answered 2026-11-21)

| ID | Topic | Decision | Notes |
| --- | --- | --- | --- |
| D-001 | Git during plan execution | Work on one branch per phase (`phase/NN-slug`). Commit freely on it and push that branch to `origin`. **Never** commit to, merge into or push `main`. Never force-push, never rewrite pushed history. | Explicit owner exception to the global "ask before commit/push" rule, scoped to plan-execution sessions in this repo. Outside plan execution the global rule still applies. |
| D-002 | Session scope | One phase per session. The session picks the next phase from `planning/PROGRESS.md`, completes it with all gates green, writes the phase report, pushes, and stops. | The owner starts the next phase by saying "execute the plan" again. |
| D-003 | Permissions | Execution sessions run in **bypass permissions** mode (set only in the git-ignored `.claude/settings.local.json`). Committed `.claude/settings.json` adds deny rules and guard hooks that still block dangerous actions. | Bypass is never committed, so contributors who clone the public repo are not put in bypass mode. |
| D-004 | One-time cloud setup | The owner does it by hand from `planning/phases/phase-00-owner-setup.md` before the first cloud phase. | Sessions never ask; if an owner item is missing they log a blocker and continue with work that doesn't need it. |
| D-005 | Accounts and devices | Owner has a Supabase account and a Google account. **No** Play Console account. **No** real Android phone: everything is tested on the emulator `Pixel_9_API_36`. | Real-UPI-app checks become optional manual checks; automated tests use a fake UPI handler app on the emulator. |
| D-006 | App identity | Display name **"Splitify Free Forever"**. Android `applicationId`/package **`com.unizoy.splitify`**. Dart package name `splitify`. | Package ID is permanent once released. |
| D-007 | Sign-in | **Google sign-in + email one-time code.** Email is sent by **Resend** over SMTP using the owner's own domain (configured in Supabase Auth by the owner in Phase 0). Debug builds also have a dev-only email+password login used by automated tests; it is compiled out of release builds. | Supabase's built-in mailer only delivers to the project's own team, so a custom SMTP provider is required. |
| D-008 | Edit/delete rights | **Any group member** can edit or delete any expense or payment in that group. Every change is kept in edit history and deletes can be restored. | PLAN.md open decision closed with its default. |
| D-009 | Extra features | Add **X1 Import from Splitwise (CSV)**, **X2 App lock (biometric / device PIN)**, **X3 Home-screen balance widget**. **No Hindi** for now (English only, but all strings go through ARB files so translation is easy later). | Specs in `08-feature-specs.md`. |
| D-010 | Brand colours | Atlys-like: **indigo primary** (~`#4F5BE8`, exact tokens in `06-design-system.md`), **amber** for the main money actions, crisp black/white, lavender gradients. Green = you are owed, red = you owe. | |
| D-011 | UI style | Match the Atlys screenshots closely **for the look only** — features come only from PLAN.md + X1–X3. Carry all four signatures: (1) serif display headlines + letter-spaced UPPERCASE labels, (2) photo/gradient hero + frosted glass card + white sheet overlapping the hero, (3) floating capsule bottom nav whose active tab expands into a black pill with its label, (4) skeuomorphic/3D showpiece cards (wallet/metal card, arc gauge) + playful motion (stacked-card loader, settle-up celebration). | Reference images live **outside** the repo in `C:\Users\mohit\OneDrive\Desktop\theCode\splitify-design-reference\atlys\` (they contain a real person's data — never copy them into the repo). |
| D-012 | Mockups | No separate mockups. Sessions build the UI directly from `06-design-system.md` + `07-screens-and-flows.md` and verify with emulator screenshots compared against the spec and the Atlys reference images. | |
| D-013 | Group covers | Default covers are **generated gradient/mesh art drawn in code**, one family per group type (trip, home, couple, other), seeded by the group id so each group looks different but stable. Users can still upload their own cover photo. | No bundled photos, no licensing risk. |
| D-014 | Distribution | **No Play Store for now.** The release phase produces a signed release APK published as a **draft GitHub Release** (the owner clicks Publish). Play Store can be added later. | Owner must create the prod Supabase project before the release phase (checklist in the release phase doc). |
| D-015 | Open-source licence | MIT, copyright Unizoy (already decided in PLAN.md). | |
| D-016 | Starting categories | PLAN.md default list: Food, Groceries, Travel, Rent, Utilities, Shopping, Entertainment, Other — plus the sub-categories and icons defined in `08-feature-specs.md`. | |
| D-017 | Public hosting | Deferred to the release phase, as PLAN.md allows. Default assumption: the released APK talks to a Unizoy-owned prod Supabase project on the free plan. | |

| D-018 | UI priority (2026-11-21) | **Good UI is the top priority.** Every screen must closely match the Atlys reference look (layout rhythm, typography, radii, colour, imagery, motion) and pass the `ui-review` rubric (≥ 8/10 on every criterion) before its phase can ship. When time or tokens are short, cut elsewhere — never UI quality. | |
| D-019 | Token economy (2026-11-21) | Save tokens: the main session (Opus) plans, writes app/UI code and does UI review; **test writing goes to the `test-writer` sub-agent (Sonnet)**, **test running/log triage to `test-runner` (Haiku)**, file searches to Explore. Read only the spec sections a task needs; no re-reading files already in context; short reports. | `.claude/agents/` |

## Technical decisions

Filled in from the research in `planning/research/` (see each row's source).

| ID | Topic | Decision | Source |
| --- | --- | --- | --- |
| T-001 | Local database | Drift (SQLite) via `drift_flutter`; FTS5 for search; schema dumps + migration tests | research 04 |
| T-002 | State management / DI | Riverpod 3 with `riverpod_annotation` codegen; `riverpod_lint` (no `custom_lint`) | research 04 |
| T-003 | Navigation | go_router 18, `StatefulShellRoute.indexedStack`, deep links `splitify://` | research 04 |
| T-004 | Sync | Custom outbox + `apply_mutations`/`pull_changes` RPCs, global `seq` cursor, Realtime broadcast as nudge; no PowerSync/Brick/Electric | `04-sync-engine.md`, research 04/05 |
| T-005 | Models | freezed 4 + json_serializable | research 04 |
| T-006 | Android levels | minSdk 24, compileSdk 37, targetSdk 36, core library desugaring; emulator stays API 36 | verified build, research 04 |
| T-007 | Conflict rule | "Later save wins" = later `client_updated_at` (client clock corrected by server offset, clamped to server now); loser kept as `conflict_lost` version | `04-sync-engine.md` §3 |
| T-008 | Google sign-in | google_sign_in 7.2 `initialize(serverClientId)` → `authenticate()` → `signInWithIdToken`; Supabase "Skip nonce checks" ON | research 04/05 |
| T-009 | Email OTP | `signInWithOtp` + `verifyOTP(type: email)`; both "Magic Link" and "Confirm signup" templates carry `{{ .Token }}`; Resend SMTP | research 05 |
| T-010 | Rounding | Equal splits: leftover units in fixed member order; ratio splits/conversions: largest remainder with fixed-order ties; FX rounding half away from zero | `05-money-engine.md` |
| T-011 | Simplify debts | Exact opposites first, then greedy largest debtor → largest creditor, fixed-order ties; ≤ n−1 transfers | `05-money-engine.md` §5 |
| T-012 | Who-owes-whom (simplify off) | Per-expense nets matched debtor→creditor in fixed order (exact), summed per pair, minus payments | `05-money-engine.md` §5 |
| T-013 | Writes | Clients have no direct table writes; all writes via `security definer` RPCs; RLS on every table for reads | `03-backend.md` §1 |
| T-014 | Payers/shares storage | `jsonb` maps on the expense row (atomic sync, simple history) + local derived `expense_parts` table | `03-backend.md` §2 |
| T-015 | Friend expenses | Hidden `direct` groups (2 members) | `03-backend.md` §2 |
| T-016 | Server jobs without secrets | `send-push` and `fetch-rates` are idempotent, `verify_jwt=false`, self-throttling; recurring generation is pure SQL cron. No Vault secrets needed. Only secret: `FCM_SERVICE_ACCOUNT_JSON` (owner) | `03-backend.md` §5–7 |
| T-017 | Exchange rates | Frankfurter **v2** (`api.frankfurter.dev`, 160+ currencies incl. INR, AED, SAR, VND, LKR, NPR, BDT), EUR base stored, cross rates computed | research 05 |
| T-018 | Fonts / icons | Instrument Serif + Inter (OFL, bundled); Phosphor icons (MIT) | `06-design-system.md` |
| T-019 | UPI | Intent link via chooser + always-visible fallbacks (copy UPI ID/amount, UPI QR); payment recorded only on "Mark as paid"; tested with fake UPI handler app | research 06 |
| T-020 | Tests | integration_test for flows, Patrol only for native dialogs, alchemist goldens, glados properties, pgTAP via MCP + CI `supabase start` | `09-testing-strategy.md` |
| T-021 | Release | Signed APKs (per-ABI + universal) + SHA-256 on a draft GitHub Release; register package + key with Android developer verification before India rollout (2027) | research 06 |

## Session decisions

Added by execution sessions (format: `S-0xx | date | phase | decision | reason | rejected alternatives`).

| ID | Date | Phase | Decision | Reason | Rejected alternatives |
| --- | --- | --- | --- | --- | --- |
| S-001 | 2026-11-21 | 01 | Keep `package:flutter/material.dart` (deprecated in 3.50 in favour of `material_ui`, info-level only); do not add `material_ui` | Not in the §5 package table; deprecation is non-fatal (`--no-fatal-infos`) | Add `material_ui` now (revisit when the lint becomes a warning) |
| S-002 | 2026-11-21 | 01 | `dart format` and CI format check cover `lib test integration_test tool` only | `dart format .` crashes on transient Gradle dirs under `build/` | Format `.` |
| S-003 | 2026-11-21 | 01 | Generated l10n Dart files (`lib/l10n/app_localizations*.dart`) are committed; `l10n.yaml` has no `synthetic-package` | Flutter 3.50 ignores that key; CI needs them without extra steps | Git-ignore and generate in CI |
| S-004 | 2026-11-21 | 01 | `very_good_analysis` info lints are not fatal (`--no-fatal-infos`); warnings/errors are | Matches the verify skill; new 3.50 lints are noisy | Fix all infos now |
