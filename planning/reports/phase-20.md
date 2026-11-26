# Phase 20 report — Release (production backend, signed APK, draft GitHub Release)

- Date: 2026-11-26 · Branch: `phase/20-release` · Base: `origin/main` (after PR #30, payment bubble off main)
- Status: done (owner decision D-031 started this phase; D-030 shipped one build without the payment bubble)

## Summary

The production Supabase project **splitify-prod** (ref `lhjnbixfpgfdszeuocvi`, Mumbai, Free plan) is live, with
every migration, Edge Function, cron job and today's exchange rates. The release-signed APK 0.2.0 talks to it, and
Google sign-in against production works on the emulator. The APKs are on a **draft** GitHub Release for the owner
to download, share or publish.

## Tasks

| Task | Result | Notes |
| --- | --- | --- |
| Checklist R (owner) | done | Project created and auth/SMTP/secret/Google redirect configured in the dashboard by the coordinator through the owner's Chrome; the owner pasted the Gmail app password and the Firebase key and logged in the `supabase-prod` MCP server. Email OTP length set to 6 (prod defaulted to 8), expiry 600 s, 100 emails/h, code templates on Magic link and Confirm sign-up, Confirm email ON. |
| T1 Migrations | done | 20 of 20 applied (0001–0010, 0013–0017, 0019, 0021–0024) through `supabase-prod`. SQL suite on prod inside rollbacks: 25 files, 968/968 checks, attack suite 288/288. |
| T2 Functions, settings, cron | done | `fetch-rates` and `send-push` (verify_jwt off), `delete-account` (verify_jwt on), all ACTIVE v1 with `_shared`. `private.settings.project_url` set. Cron: fetch-rates morning/evening, generate-recurring, housekeeping. First rates fetch: 4,573 rows, newest 2026-11-26. |
| T3 `secrets/env.prod.json` | done | Prod URL + publishable key, `DEV_LOGIN=false`, `EMAIL_OTP_LENGTH=6` (git-ignored). |
| T4 Version + signed APKs | done | Version **0.2.0+3** (S-300, not 1.0.0). `tool/build_release.ps1 -EnvFile secrets/env.prod.json`: arm64-v8a 17.8 MB, armeabi-v7a 17.4 MB, x86_64 18.4 MB, universal 32.1 MB, all signed with the release key (SHA-1 EB:03:F7:95…), no listener/accessibility/overlay/SMS permission; the arm64 APK contains the prod host and not the dev host. `SHA256SUMS.txt` written. |
| T5 Smoke test | done | Emulator, release x64 build pinned to the prod IP (this PC's ISP blocks `*.supabase.co`): welcome renders, Get started → Continue with Google → account picker → Groups (empty production account, "Create your first group"). Screenshot `splitify-artifacts\screenshots\prod-smoke-groups.png`. |
| T6 Privacy + developer verification note | done | `docs/PRIVACY.md` already linked from the README. Owner action below. |
| T7 Draft GitHub Release | done | Draft `v0.2.0` "Splitify Free Forever 0.2.0" targeting `phase/20-release` with the arm64, universal and armeabi-v7a APKs and `SHA256SUMS.txt`. Not published (D-014). |

## Gates

| Gate | Result | Evidence |
| --- | --- | --- |
| G1 Static | PASS | PR #30 (format, analyze 0 errors/warnings, guards) |
| G2 Tests | PASS | PR #30: 3,261 Flutter tests, coverage 95.7 % |
| G3 Backend | PASS | Prod: 968/968 pgTAP checks; advisors as on dev (18 WARN "signed-in users can execute SECURITY DEFINER function" by design; INFO only otherwise) |
| G4 Build | PASS | 4 release-signed APKs from `build_release.ps1` with the permission check |
| G5 Device | PASS | Prod smoke test above |
| G6 Docs | PASS | This report, D-030/D-031, phase file ticks |

## Decisions made

- S-300: first production build is 0.2.0 (owner and friends), not 1.0.0.
- S-301: prod set up by a separate Claude Code process limited to the `supabase-prod` tools, after phase 20 was
  started properly (the MCP guard opens prod only while phase 20 is in progress).
- S-302: the draft release targets `phase/20-release`; it is merged into `main` right after.

## Owner actions

- **Install:** uninstall earlier test builds (different signing key), then install `splitify-arm64-v8a.apk` from the
  draft release. Production starts empty.
- **Friends with Google sign-in:** add their Gmail under Google Cloud → Google Auth Platform → Audience → Test users,
  or publish the consent screen (home page = repo URL, privacy policy = `docs/PRIVACY.md`). Email codes work for anyone.
- **Publish the draft release** when you want a public download link.
- **Stale `.git\index.lock` in the main checkout came back** (OneDrive + VS Code Git). Close VS Code and delete it again;
  consider moving the repo out of OneDrive.
- **Back up** `secrets/splitify-release.jks` and `secrets/release-key.properties`.
- **Android developer verification:** register package `com.unizoy.splitify` and the release key's SHA-256 before
  Google's India rollout of sideload verification (research 06 §3).
- **Free plan:** production pauses after 7 days without activity; move to Pro when real users arrive.
